import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_config.dart';
import '../../models/study_material_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/gemini_service.dart';
import '../../services/study_library_service.dart';
import '../../widgets/responsive_layout.dart';

class StudyLibraryScreen extends ConsumerStatefulWidget {
  const StudyLibraryScreen({super.key});
  @override
  ConsumerState<StudyLibraryScreen> createState() => _StudyLibraryScreenState();
}

class _StudyLibraryScreenState extends ConsumerState<StudyLibraryScreen> {
  final _service = StudyLibraryService();
  List<StudyFolder> _folders = [];
  List<StudyMaterial> _materials = [];
  bool _loading = true, _uploading = false;
  bool _pendingCloudSync = false;
  String? _watchingUserId;
  String? _loadingUserId;
  StreamSubscription<List<StudyFolder>>? _folderSubscription;
  StreamSubscription<List<StudyMaterial>>? _materialSubscription;
  Timer? _syncTimer;
  String? _activeFolder, _error;
  String _search = '';
  String get _userId => ref.read(currentUserProvider).valueOrNull!.id;

  @override
  void initState() {
    super.initState();
    _load();
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      final userId = ref.read(currentUserProvider).valueOrNull?.id;
      if (userId == null || !_service.hasPendingSync(userId)) return;
      final synced = await _service.syncPending(userId);
      if (synced && mounted) await _load();
    });
  }

  Future<void> _load() async {
    final userId = ref.read(currentUserProvider).valueOrNull?.id;
    if (userId == null || _loadingUserId == userId) return;
    _loadingUserId = userId;
    try {
      final data = await Future.wait([
        _service.loadFolders(userId),
        _service.loadMaterials(userId),
      ]);
      if (mounted)
        setState(() {
          _folders = data[0] as List<StudyFolder>;
          _materials = data[1] as List<StudyMaterial>;
          _loading = false;
          _error = null;
          _pendingCloudSync = _service.hasPendingSync(userId);
        });
      _watch(userId);
    } catch (e) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = '$e';
          _pendingCloudSync = _service.hasPendingSync(userId);
        });
    } finally {
      if (_loadingUserId == userId) _loadingUserId = null;
    }
  }

  void _watch(String userId) {
    if (_watchingUserId == userId) return;
    _folderSubscription?.cancel();
    _materialSubscription?.cancel();
    _watchingUserId = userId;
    _folderSubscription = _service
        .watchFolders(userId)
        .listen(
          (folders) {
            if (!mounted) return;
            setState(() {
              _folders = folders;
              _pendingCloudSync = _service.hasPendingSync(userId);
              _error = null;
            });
          },
          onError: (Object error) {
            if (!mounted) return;
            setState(() {
              _error = 'Live cloud sync is unavailable: $error';
              _pendingCloudSync = _service.hasPendingSync(userId);
            });
          },
        );
    _materialSubscription = _service
        .watchMaterials(userId)
        .listen(
          (materials) {
            if (!mounted) return;
            setState(() {
              _materials = materials;
              _pendingCloudSync = _service.hasPendingSync(userId);
            });
          },
          onError: (Object error) {
            if (!mounted) return;
            setState(() {
              _error = 'Live cloud sync is unavailable: $error';
              _pendingCloudSync = _service.hasPendingSync(userId);
            });
          },
        );
  }

  @override
  void dispose() {
    _folderSubscription?.cancel();
    _materialSubscription?.cancel();
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _createFolder() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Create a folder'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Folder name',
                hintText: 'e.g. Prelim Semester',
              ),
              onSubmitted:
                  (_) => Navigator.pop(context, controller.text.trim()),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('Create folder'),
              ),
            ],
          ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    try {
      final parentId = _activeFolder == '__unsorted__' ? null : _activeFolder;
      final folder = await _service.createFolder(
        _userId,
        name,
        parentId: parentId,
      );
      if (mounted)
        setState(() {
          _folders.insert(0, folder);
          _activeFolder = folder.id;
          _pendingCloudSync = _service.hasPendingSync(_userId);
        });
      if (_service.hasPendingSync(_userId)) {
        _toast(
          'Folder saved on this device. Cloud sync is pending; it will retry when access is available.',
        );
      } else {
        _toast('Folder synced to your account.');
      }
    } catch (e) {
      _toast('Could not create folder: $e', error: true);
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pptx', 'docx', 'txt'],
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _uploading = true);
    try {
      var accepted = 0;
      for (final file in result.files) {
        final Uint8List? bytes = file.bytes;
        if (bytes == null ||
            bytes.isEmpty ||
            bytes.length > AppConfig.maxUploadBytes) {
          _toast(
            '${file.name} could not be read or is larger than 10 MB.',
            error: true,
          );
          continue;
        }
        final ext = file.extension?.toLowerCase() ?? '';
        final text = await GeminiService().extractText(bytes, ext);
        if (text == null || text.trim().isEmpty) {
          _toast(
            '${file.name} has no extractable text. Study Mode supports PPTX, DOCX, and TXT.',
          );
          continue;
        }
        final synced = await _service.saveMaterial(
          _userId,
          name: file.name,
          extension: ext,
          size: bytes.length,
          extractedText: text.trim(),
          folderId: _activeFolder == '__unsorted__' ? null : _activeFolder,
        );
        if (!synced && mounted) {
          _toast(
            '${file.name} is saved on this device; cloud sync is pending.',
          );
        }
        accepted++;
      }
      await _load();
      if (accepted > 0) {
        final folder =
            _folders.where((f) => f.id == _activeFolder).firstOrNull?.name;
        if (!_service.hasPendingSync(_userId)) {
          _toast(
            '$accepted ${accepted == 1 ? 'file' : 'files'} synced${folder == null ? ' to your account.' : ' to $folder.'}',
          );
        }
      }
    } catch (e) {
      _toast('Upload failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _toast(String value, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value),
          backgroundColor: error ? Colors.red.shade700 : null,
          behavior: SnackBarBehavior.floating,
        ),
      );
  Future<void> _delete(StudyMaterial item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete material?'),
            content: Text('“${item.name}” and its highlights will be removed.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (ok == true) {
      await _service.deleteMaterial(_userId, item.id);
      await _load();
    }
  }

  Future<void> _deleteFolder(StudyFolder folder) async {
    final delete = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Delete “${folder.name}”?'),
            content: const Text(
              'Subfolders and files will be moved to the parent folder, so their contents are kept.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete folder'),
              ),
            ],
          ),
    );
    if (delete != true) return;
    final synced = await _service.deleteFolder(_userId, folder.id);
    if (!mounted) return;
    setState(() {
      if (_activeFolder == folder.id) _activeFolder = folder.parentId;
      _pendingCloudSync = _service.hasPendingSync(_userId);
    });
    await _load();
    _toast(
      synced
          ? 'Folder deleted.'
          : 'Folder deleted on this device; cloud sync is pending.',
    );
  }

  Future<void> _move(StudyMaterial item) async {
    final dest = await showDialog<String?>(
      context: context,
      builder:
          (context) => SimpleDialog(
            title: const Text('Move material to'),
            children: [
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, '__none__'),
                child: const Text('Unsorted files'),
              ),
              ..._folders.map(
                (f) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, f.id),
                  child: Text(f.name),
                ),
              ),
            ],
          ),
    );
    if (dest != null) {
      await _service.moveMaterial(
        _userId,
        item.id,
        dest == '__none__' ? null : dest,
      );
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeUser = ref.watch(currentUserProvider).valueOrNull;
    if (activeUser == null)
      return const Center(child: CircularProgressIndicator());
    if (_watchingUserId != activeUser.id && _loadingUserId != activeUser.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
    final desktop = ResponsiveBreakpoints.isDesktop(context),
        dark = Theme.of(context).brightness == Brightness.dark;
    final border = dark ? const Color(0xff334155) : const Color(0xffdce3ec),
        card = dark ? const Color(0xff1e293b) : Colors.white,
        foreground = dark ? Colors.white : const Color(0xff0f172a);
    final unsorted = _activeFolder == '__unsorted__',
        folder = _folders.where((f) => f.id == _activeFolder).firstOrNull;
    final folders =
        _folders
            .where(
              (f) =>
                  f.parentId == folder?.id &&
                  f.name.toLowerCase().contains(_search.toLowerCase()),
            )
            .toList();
    final items =
        _materials
            .where(
              (m) =>
                  m.name.toLowerCase().contains(_search.toLowerCase()) &&
                  (_activeFolder == null ||
                      (unsorted
                          ? m.folderId == null
                          : m.folderId == _activeFolder)),
            )
            .toList();
    final libraryIntro = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Study library',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: foreground,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Organize your class materials and keep your key ideas close.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    final libraryActions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: _uploading ? null : _pickFiles,
          icon:
              _uploading
                  ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Icon(Icons.upload_file_rounded),
          label: Text(_uploading ? 'Reading files…' : 'Upload files'),
        ),
        OutlinedButton.icon(
          onPressed: () => context.push('/study/quizzes'),
          icon: const Icon(Icons.quiz_outlined),
          label: const Text('My quizzes'),
        ),
      ],
    );
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: desktop ? 32 : 18,
        vertical: 24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder:
                    (context, constraints) =>
                        constraints.maxWidth < 560
                            ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                libraryIntro,
                                const SizedBox(height: 14),
                                libraryActions,
                              ],
                            )
                            : Row(
                              children: [
                                Expanded(child: libraryIntro),
                                const SizedBox(width: 16),
                                libraryActions,
                              ],
                            ),
              ),
              const SizedBox(height: 22),
              if (_error != null)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.cloud_off_rounded),
                    title: const Text('Could not load your study library'),
                    subtitle: Text(
                      _error!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      onPressed: () {
                        setState(() => _loading = true);
                        _load();
                      },
                      icon: const Icon(Icons.refresh),
                    ),
                  ),
                ),
              if (_pendingCloudSync)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.sync_problem_rounded),
                    title: const Text(
                      'Saved on this device; cloud sync is pending',
                    ),
                    subtitle: const Text(
                      'This material will appear on your other devices after it syncs to your account.',
                    ),
                    trailing: IconButton(
                      tooltip: 'Retry cloud sync',
                      onPressed: () async {
                        await _service.syncPending(_userId);
                        await _load();
                      },
                      icon: const Icon(Icons.sync_rounded),
                    ),
                  ),
                ),
              LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= 780;
                  return Flex(
                    direction: wide ? Axis.horizontal : Axis.vertical,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: wide ? 300 : null,
                        child: Column(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xff112c2a),
                                border: Border.all(
                                  color: const Color(0xff2b956c),
                                ),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.cloud_upload_outlined,
                                    color: Color(0xff78e3b4),
                                    size: 32,
                                  ),
                                  const SizedBox(height: 9),
                                  const Text(
                                    'Add materials to your library',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xffc2f5de),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  const Text(
                                    'PPTX, DOCX and TXT · Up to 10 MB per file',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xff91b9a8),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: _uploading ? null : _pickFiles,
                                    icon: const Icon(Icons.add),
                                    label: const Text('Browse files'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'FOLDERS',
                                    style: TextStyle(
                                      fontSize: 11,
                                      letterSpacing: 1.2,
                                      fontWeight: FontWeight.w800,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Create folder',
                                  onPressed: _createFolder,
                                  icon: const Icon(
                                    Icons.create_new_folder_outlined,
                                  ),
                                ),
                              ],
                            ),
                            _folderTile(
                              context,
                              'All materials',
                              Icons.auto_awesome_mosaic_outlined,
                              _materials.length,
                              _activeFolder == null,
                              border,
                              card,
                              () => setState(() => _activeFolder = null),
                            ),
                            if (_loading)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(18),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else
                              ...folders.map(
                                (f) => _folderTile(
                                  context,
                                  f.name,
                                  Icons.folder_rounded,
                                  _materials
                                      .where((m) => m.folderId == f.id)
                                      .length,
                                  _activeFolder == f.id,
                                  border,
                                  card,
                                  () => setState(() => _activeFolder = f.id),
                                  delete: () => _deleteFolder(f),
                                ),
                              ),
                            _folderTile(
                              context,
                              'Unsorted files',
                              Icons.inbox_outlined,
                              _materials
                                  .where((m) => m.folderId == null)
                                  .length,
                              unsorted,
                              border,
                              card,
                              () => setState(
                                () => _activeFolder = '__unsorted__',
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Files stay on this device after refresh. They appear on your other devices once cloud sync succeeds.',
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.5,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (wide)
                        const SizedBox(width: 28)
                      else
                        const SizedBox(height: 24),
                      SizedBox(
                        width: wide ? c.maxWidth - 328 : null,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    folder?.name ??
                                        (unsorted
                                            ? 'Unsorted files'
                                            : 'All materials'),
                                    style: TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w800,
                                      color: foreground,
                                    ),
                                  ),
                                ),
                                if (folder != null)
                                  IconButton(
                                    tooltip: 'Go to parent folder',
                                    onPressed:
                                        () => setState(
                                          () => _activeFolder = folder.parentId,
                                        ),
                                    icon: const Icon(
                                      Icons.arrow_upward_rounded,
                                    ),
                                  ),
                                OutlinedButton.icon(
                                  onPressed: _createFolder,
                                  icon: const Icon(
                                    Icons.create_new_folder_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('New folder'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              onChanged: (v) => setState(() => _search = v),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.search),
                                hintText: 'Search folders and materials',
                                filled: true,
                                fillColor: card,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(13),
                                  borderSide: BorderSide(color: border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(13),
                                  borderSide: BorderSide(color: border),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (!unsorted && folders.isNotEmpty)
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children:
                                    folders
                                        .map(
                                          (f) => SizedBox(
                                            width: wide ? 215 : 180,
                                            child: _folderCard(
                                              context,
                                              f,
                                              _materials
                                                  .where(
                                                    (m) => m.folderId == f.id,
                                                  )
                                                  .length,
                                              card,
                                              border,
                                              foreground,
                                              () => setState(
                                                () => _activeFolder = f.id,
                                              ),
                                              onDelete: () => _deleteFolder(f),
                                            ),
                                          ),
                                        )
                                        .toList(),
                              ),
                            if (!unsorted && folders.isNotEmpty)
                              const SizedBox(height: 18),
                            Text(
                              'MATERIALS · ${items.length}',
                              style: TextStyle(
                                fontSize: 11,
                                letterSpacing: 1,
                                fontWeight: FontWeight.w800,
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_loading)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (items.isEmpty)
                              _empty(context, card, border)
                            else
                              ...items.map(
                                (m) => Card(
                                  color: card,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(color: border),
                                  ),
                                  child: ListTile(
                                    leading: _fileIcon(m.extension),
                                    title: Text(
                                      m.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${m.extension.toUpperCase()} · ${_size(m.size)} · Readable',
                                      style: TextStyle(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                    ),
                                    trailing: PopupMenuButton<String>(
                                      onSelected: (v) async {
                                        if (v == 'delete') await _delete(m);
                                        if (v == 'move') await _move(m);
                                      },
                                      itemBuilder:
                                          (_) => const [
                                            PopupMenuItem(
                                              value: 'move',
                                              child: Text('Move to folder'),
                                            ),
                                            PopupMenuItem(
                                              value: 'delete',
                                              child: Text('Delete'),
                                            ),
                                          ],
                                    ),
                                    onTap:
                                        () => context.push(
                                          '/study/material/${m.id}',
                                          extra: m,
                                        ),
                                  ),
                                ),
                              ),
                            if (desktop && _materials.isEmpty)
                              Container(
                                margin: const EdgeInsets.only(top: 20),
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: card,
                                  border: Border.all(color: border),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  'Create a folder for each semester, add slides and notes, then open a file to read and highlight key passages.',
                                  style: TextStyle(
                                    height: 1.5,
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _folderTile(
    BuildContext context,
    String name,
    IconData icon,
    int count,
    bool selected,
    Color border,
    Color card,
    VoidCallback tap, {
    VoidCallback? delete,
  }) => Card(
    color:
        selected
            ? Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: .45)
            : card,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: border),
    ),
    child: ListTile(
      dense: true,
      leading: Icon(
        icon,
        color:
            name == 'All materials'
                ? const Color(0xff45d1a0)
                : const Color(0xffe6b85c),
      ),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      trailing:
          delete == null
              ? Text('$count', style: const TextStyle(color: Colors.grey))
              : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$count', style: const TextStyle(color: Colors.grey)),
                  IconButton(
                    tooltip: 'Delete folder',
                    visualDensity: VisualDensity.compact,
                    onPressed: delete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: Theme.of(context).colorScheme.error,
                  ),
                ],
              ),
      onTap: tap,
    ),
  );
  Widget _folderCard(
    BuildContext context,
    StudyFolder f,
    int count,
    Color card,
    Color border,
    Color title,
    VoidCallback tap, {
    VoidCallback? onDelete,
  }) => InkWell(
    onTap: tap,
    borderRadius: BorderRadius.circular(15),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Icon(
                    Icons.folder_rounded,
                    color: Color(0xffe6b85c),
                    size: 27,
                  ),
                ),
              ),
              if (onDelete != null)
                IconButton(
                  tooltip: 'Delete folder',
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: Theme.of(context).colorScheme.error,
                ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            f.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w700, color: title),
          ),
          const SizedBox(height: 4),
          Text(
            '$count ${count == 1 ? 'file' : 'files'}',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    ),
  );
  Widget _empty(BuildContext context, Color card, Color border) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(35),
    decoration: BoxDecoration(
      color: card,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: border),
    ),
    child: Column(
      children: [
        Icon(
          Icons.menu_book_outlined,
          size: 40,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 10),
        const Text(
          'No materials here yet',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        const Text(
          'Upload readable lecture files to start your reviewer.',
          style: TextStyle(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
  Widget _fileIcon(String ext) {
    final color =
        ext == 'pptx'
            ? const Color(0xffff9b79)
            : ext == 'docx'
            ? const Color(0xff83a9ff)
            : const Color(0xff71d8ae);
    return CircleAvatar(
      backgroundColor: color.withValues(alpha: .14),
      child: Icon(
        ext == 'pptx'
            ? Icons.slideshow_rounded
            : ext == 'docx'
            ? Icons.description_rounded
            : Icons.text_snippet_rounded,
        color: color,
      ),
    );
  }

  String _size(int bytes) =>
      bytes < 1048576
          ? '${(bytes / 1024).ceil()} KB'
          : '${(bytes / 1048576).toStringAsFixed(1)} MB';
}
