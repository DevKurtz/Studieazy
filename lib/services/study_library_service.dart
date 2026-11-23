import 'dart:convert';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/study_material_models.dart';

/// Local-first study library with an explicit sync queue.
/// Local persistence supports refresh/offline use; Firestore is the shared
/// account source that makes changes available on the user's other devices.
class StudyLibraryService {
  static const _boxName = 'study_library_v1';
  static const _cloudTimeout = Duration(seconds: 8);
  static Box<String>? _local;

  final FirebaseFirestore _firestore;
  StudyLibraryService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static Future<void> init() async {
    _local =
        Hive.isBoxOpen(_boxName)
            ? Hive.box<String>(_boxName)
            : await Hive.openBox<String>(_boxName);
  }

  Box<String> get _box {
    if (_local != null && _local!.isOpen) return _local!;
    if (Hive.isBoxOpen(_boxName)) return Hive.box<String>(_boxName);
    throw StateError('Study library storage has not been initialized.');
  }

  CollectionReference<Map<String, dynamic>> _collection(
    String userId,
    String name,
  ) => _firestore.collection('users').doc(userId).collection(name);

  String _key(String userId, String type) => '$userId:$type';
  String _queueKey(String userId) => '$userId:pending_sync';

  bool hasPendingSync(String userId) => _queue(userId).isNotEmpty;

  List<T> _read<T>(
    String userId,
    String type,
    T Function(String, Map<String, dynamic>) parse,
  ) {
    final raw = _box.get(_key(userId, type));
    if (raw == null) return [];
    try {
      final values = jsonDecode(raw) as List<dynamic>;
      return values.whereType<Map>().map((value) {
        final map = Map<String, dynamic>.from(value);
        return parse(map['id'] as String? ?? '', map);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _write<T>(
    String userId,
    String type,
    List<T> values,
    Map<String, dynamic> Function(T) encode,
  ) async {
    await _box.put(_key(userId, type), jsonEncode(values.map(encode).toList()));
  }

  List<Map<String, dynamic>> _queue(String userId) {
    try {
      return (jsonDecode(_box.get(_queueKey(userId)) ?? '[]') as List)
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _enqueue(
    String userId,
    String collection,
    String id,
    Map<String, dynamic>? data, {
    bool delete = false,
  }) async {
    final queue = _queue(userId);
    queue.removeWhere(
      (item) => item['collection'] == collection && item['id'] == id,
    );
    queue.add({
      'collection': collection,
      'id': id,
      'data': data,
      'delete': delete,
    });
    await _box.put(_queueKey(userId), jsonEncode(queue));
  }

  Future<bool> syncPending(String userId) async {
    final queue = _queue(userId);
    if (queue.isEmpty) return true;
    final remaining = <Map<String, dynamic>>[];
    for (final item in queue) {
      try {
        if (item['collection'] == 'study_materials' && item['data'] is Map) {
          final data = Map<String, dynamic>.from(item['data'] as Map);
          if (data['folderId'] == '__unsorted__') {
            data['folderId'] = null;
            item['data'] = data;
          }
        }
        final ref = _collection(
          userId,
          item['collection'] as String,
        ).doc(item['id'] as String);
        if (item['delete'] == true) {
          await ref.delete().timeout(_cloudTimeout);
        } else {
          await ref
              .set(Map<String, dynamic>.from(item['data'] as Map))
              .timeout(_cloudTimeout);
        }
      } catch (_) {
        remaining.add(item);
      }
    }
    await _box.put(_queueKey(userId), jsonEncode(remaining));
    return remaining.isEmpty;
  }

  Future<List<StudyFolder>> loadFolders(String userId) async {
    await syncPending(userId);
    final local = _read(userId, 'folders', StudyFolder.fromMap);
    try {
      final snapshot = await _collection(
        userId,
        'study_folders',
      ).orderBy('updatedAt', descending: true).get().timeout(_cloudTimeout);
      final remote =
          snapshot.docs
              .map((d) => StudyFolder.fromMap(d.id, d.data()))
              .toList();
      final merged = _mergePending(
        userId,
        'study_folders',
        remote,
        local,
        (item) => item.id,
      )..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      await _write(userId, 'folders', merged, (item) => item.toMap());
      return merged;
    } catch (_) {
      return local..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
  }

  Stream<List<StudyFolder>> watchFolders(String userId) async* {
    final local = _read(userId, 'folders', StudyFolder.fromMap);
    yield local;
    yield* _collection(userId, 'study_folders')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final remote =
              snapshot.docs
                  .map((d) => StudyFolder.fromMap(d.id, d.data()))
                  .toList();
          final merged = _mergePending(
            userId,
            'study_folders',
            remote,
            _read(userId, 'folders', StudyFolder.fromMap),
            (item) => item.id,
          )..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          await _write(userId, 'folders', merged, (item) => item.toMap());
          return merged;
        });
  }

  Future<List<StudyMaterial>> loadMaterials(String userId) async {
    await syncPending(userId);
    final local = _read(userId, 'materials', StudyMaterial.fromMap);
    var repairedLegacyUnsorted = false;
    for (var index = 0; index < local.length; index++) {
      final item = local[index];
      if (item.folderId == '__unsorted__') {
        repairedLegacyUnsorted = true;
        local[index] = StudyMaterial(
          id: item.id,
          name: item.name,
          extension: item.extension,
          size: item.size,
          folderId: null,
          extractedText: item.extractedText,
          createdAt: item.createdAt,
        );
      }
    }
    if (repairedLegacyUnsorted) {
      await _write(userId, 'materials', local, (item) => item.toMap());
    }
    try {
      final snapshot = await _collection(
        userId,
        'study_materials',
      ).orderBy('createdAt', descending: true).get().timeout(_cloudTimeout);
      final remote =
          snapshot.docs
              .map((d) => StudyMaterial.fromMap(d.id, d.data()))
              .toList();
      final merged = _mergePending(
        userId,
        'study_materials',
        remote,
        local,
        (item) => item.id,
      )..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      await _write(userId, 'materials', merged, (item) => item.toMap());
      return merged;
    } catch (_) {
      return local..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
  }

  Stream<List<StudyMaterial>> watchMaterials(String userId) async* {
    final local = _read(userId, 'materials', StudyMaterial.fromMap);
    yield local;
    yield* _collection(userId, 'study_materials')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final remote =
              snapshot.docs
                  .map((d) => StudyMaterial.fromMap(d.id, d.data()))
                  .toList();
          final merged = _mergePending(
            userId,
            'study_materials',
            remote,
            _read(userId, 'materials', StudyMaterial.fromMap),
            (item) => item.id,
          )..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          await _write(userId, 'materials', merged, (item) => item.toMap());
          return merged;
        });
  }

  List<T> _merge<T>(List<T> remote, List<T> local, String Function(T) idOf) {
    final items = <String, T>{for (final item in remote) idOf(item): item};
    for (final item in local) {
      items.putIfAbsent(idOf(item), () => item);
    }
    return items.values.toList();
  }

  List<T> _mergePending<T>(
    String userId,
    String collection,
    List<T> remote,
    List<T> local,
    String Function(T) idOf,
  ) {
    final queue = _queue(
      userId,
    ).where((entry) => entry['collection'] == collection);
    final pendingIds =
        queue
            .where((entry) => entry['delete'] != true)
            .map((entry) => entry['id'] as String?)
            .whereType<String>()
            .toSet();
    final deletedIds =
        queue
            .where((entry) => entry['delete'] == true)
            .map((entry) => entry['id'] as String?)
            .whereType<String>()
            .toSet();
    final pendingLocal =
        local.where((item) => pendingIds.contains(idOf(item))).toList();
    return _merge(
      remote.where((item) => !deletedIds.contains(idOf(item))).toList(),
      pendingLocal,
      idOf,
    );
  }

  Future<StudyFolder> createFolder(
    String userId,
    String name, {
    String? parentId,
  }) async {
    final id = const Uuid().v4();
    final folder = StudyFolder(
      id: id,
      name: name,
      updatedAt: DateTime.now(),
      parentId: parentId,
    );
    final folders = _read(userId, 'folders', StudyFolder.fromMap)
      ..insert(0, folder);
    await _write(userId, 'folders', folders, (item) => item.toMap());
    await _enqueue(userId, 'study_folders', id, folder.toMap()..remove('id'));
    await syncPending(userId);
    return folder;
  }

  Future<bool> deleteFolder(String userId, String folderId) async {
    final folders = _read(userId, 'folders', StudyFolder.fromMap);
    final target = folders.where((folder) => folder.id == folderId).firstOrNull;
    if (target == null) return true;
    final materials = _read(userId, 'materials', StudyMaterial.fromMap);

    // Keep all contents when deleting a folder: promote child folders and
    // direct materials to the deleted folder's parent.
    for (var i = 0; i < folders.length; i++) {
      final child = folders[i];
      if (child.parentId == folderId) {
        folders[i] = StudyFolder(
          id: child.id,
          name: child.name,
          updatedAt: DateTime.now(),
          parentId: target.parentId,
        );
        await _enqueue(
          userId,
          'study_folders',
          child.id,
          folders[i].toMap()..remove('id'),
        );
      }
    }
    for (var i = 0; i < materials.length; i++) {
      final material = materials[i];
      if (material.folderId == folderId) {
        materials[i] = StudyMaterial(
          id: material.id,
          name: material.name,
          extension: material.extension,
          size: material.size,
          folderId: target.parentId,
          extractedText: material.extractedText,
          createdAt: material.createdAt,
        );
        await _enqueue(
          userId,
          'study_materials',
          material.id,
          materials[i].toMap()..remove('id'),
        );
      }
    }
    folders.removeWhere((folder) => folder.id == folderId);
    await _write(userId, 'folders', folders, (item) => item.toMap());
    await _write(userId, 'materials', materials, (item) => item.toMap());
    await _enqueue(userId, 'study_folders', folderId, null, delete: true);
    return syncPending(userId);
  }

  Future<bool> saveMaterial(
    String userId, {
    required String name,
    required String extension,
    required int size,
    required String extractedText,
    String? folderId,
  }) async {
    final id = const Uuid().v4();
    final item = StudyMaterial(
      id: id,
      name: name,
      extension: extension.toLowerCase(),
      size: size,
      folderId: folderId,
      extractedText: extractedText,
      createdAt: DateTime.now(),
    );
    final items = _read(userId, 'materials', StudyMaterial.fromMap)
      ..insert(0, item);
    await _write(userId, 'materials', items, (value) => value.toMap());
    await _enqueue(userId, 'study_materials', id, item.toMap()..remove('id'));
    if (folderId != null) {
      final folders = _read(userId, 'folders', StudyFolder.fromMap);
      final index = folders.indexWhere((folder) => folder.id == folderId);
      if (index >= 0) {
        final updated = StudyFolder(
          id: folders[index].id,
          name: folders[index].name,
          updatedAt: DateTime.now(),
        );
        folders[index] = updated;
        await _write(userId, 'folders', folders, (value) => value.toMap());
        await _enqueue(
          userId,
          'study_folders',
          folderId,
          updated.toMap()..remove('id'),
        );
      }
    }
    return syncPending(userId);
  }

  Future<bool> moveMaterial(
    String userId,
    String materialId,
    String? folderId,
  ) async {
    final items = _read(userId, 'materials', StudyMaterial.fromMap);
    final index = items.indexWhere((item) => item.id == materialId);
    if (index < 0) return false;
    final current = items[index];
    items[index] = StudyMaterial(
      id: current.id,
      name: current.name,
      extension: current.extension,
      size: current.size,
      folderId: folderId,
      extractedText: current.extractedText,
      createdAt: current.createdAt,
    );
    await _write(userId, 'materials', items, (item) => item.toMap());
    await _enqueue(
      userId,
      'study_materials',
      materialId,
      items[index].toMap()..remove('id'),
    );
    return syncPending(userId);
  }

  Future<List<StudyHighlight>> loadHighlights(
    String userId,
    String materialId,
  ) async {
    await syncPending(userId);
    final local =
        _read(
          userId,
          'highlights',
          StudyHighlight.fromMap,
        ).where((item) => item.materialId == materialId).toList();
    try {
      final snapshot = await _collection(
        userId,
        'study_highlights',
      ).where('materialId', isEqualTo: materialId).get().timeout(_cloudTimeout);
      final remote =
          snapshot.docs
              .map((d) => StudyHighlight.fromMap(d.id, d.data()))
              .toList();
      final merged = _merge(remote, local, (item) => item.id);
      final all =
          _read(userId, 'highlights', StudyHighlight.fromMap)
            ..removeWhere((item) => item.materialId == materialId)
            ..addAll(merged);
      await _write(userId, 'highlights', all, (item) => item.toMap());
      return merged;
    } catch (_) {
      return local;
    }
  }

  Future<bool> saveHighlight(
    String userId,
    String materialId,
    String quote,
    String note,
  ) async {
    final id = const Uuid().v4();
    final item = StudyHighlight(
      id: id,
      materialId: materialId,
      quote: quote,
      note: note,
      color: 'yellow',
    );
    final highlights = _read(userId, 'highlights', StudyHighlight.fromMap)
      ..add(item);
    await _write(userId, 'highlights', highlights, (value) => value.toMap());
    await _enqueue(userId, 'study_highlights', id, {
      'materialId': materialId,
      'quote': quote,
      'note': note,
      'color': 'yellow',
      'createdAt': DateTime.now().toIso8601String(),
    });
    return syncPending(userId);
  }

  Future<bool> deleteMaterial(String userId, String materialId) async {
    final materials = _read(userId, 'materials', StudyMaterial.fromMap)
      ..removeWhere((item) => item.id == materialId);
    final highlights = _read(userId, 'highlights', StudyHighlight.fromMap)
      ..removeWhere((item) => item.materialId == materialId);
    await _write(userId, 'materials', materials, (item) => item.toMap());
    await _write(userId, 'highlights', highlights, (item) => item.toMap());
    await _enqueue(userId, 'study_materials', materialId, null, delete: true);
    // Remote highlight deletes are fetched and queued when possible.
    try {
      final snapshot = await _collection(
        userId,
        'study_highlights',
      ).where('materialId', isEqualTo: materialId).get().timeout(_cloudTimeout);
      for (final doc in snapshot.docs) {
        await _enqueue(userId, 'study_highlights', doc.id, null, delete: true);
      }
    } catch (_) {}
    return syncPending(userId);
  }
}
