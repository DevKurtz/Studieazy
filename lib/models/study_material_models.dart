class StudyFolder {
  final String id;
  final String name;
  final DateTime updatedAt;
  final String? parentId;

  const StudyFolder({
    required this.id,
    required this.name,
    required this.updatedAt,
    this.parentId,
  });

  factory StudyFolder.fromMap(String id, Map<String, dynamic> map) =>
      StudyFolder(
        id: id,
        name: map['name'] as String? ?? 'Untitled folder',
        updatedAt:
            DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
            DateTime.now(),
        parentId: map['parentId'] as String?,
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'updatedAt': updatedAt.toIso8601String(),
    'parentId': parentId,
  };
}

class StudyMaterial {
  final String id;
  final String name;
  final String extension;
  final int size;
  final String? folderId;
  final String extractedText;
  final DateTime createdAt;

  const StudyMaterial({
    required this.id,
    required this.name,
    required this.extension,
    required this.size,
    required this.folderId,
    required this.extractedText,
    required this.createdAt,
  });

  factory StudyMaterial.fromMap(String id, Map<String, dynamic> map) =>
      StudyMaterial(
        id: id,
        name: map['name'] as String? ?? 'Study material',
        extension: map['extension'] as String? ?? '',
        size: map['size'] as int? ?? 0,
        folderId: map['folderId'] as String?,
        extractedText: map['extractedText'] as String? ?? '',
        createdAt:
            DateTime.tryParse(map['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'extension': extension,
    'size': size,
    'folderId': folderId,
    'extractedText': extractedText,
    'createdAt': createdAt.toIso8601String(),
  };
}

class StudyHighlight {
  final String id;
  final String materialId;
  final String quote;
  final String note;
  final String color;

  const StudyHighlight({
    required this.id,
    required this.materialId,
    required this.quote,
    required this.note,
    required this.color,
  });

  factory StudyHighlight.fromMap(String id, Map<String, dynamic> map) =>
      StudyHighlight(
        id: id,
        materialId: map['materialId'] as String? ?? '',
        quote: map['quote'] as String? ?? '',
        note: map['note'] as String? ?? '',
        color: map['color'] as String? ?? 'yellow',
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'materialId': materialId,
    'quote': quote,
    'note': note,
    'color': color,
  };
}
