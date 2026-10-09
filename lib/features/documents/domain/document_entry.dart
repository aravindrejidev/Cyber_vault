enum DocumentKind {
  pdf,
  image;

  static const List<String> imageExtensions = <String>[
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
    'bmp',
  ];

  static List<String> get supportedExtensions =>
      <String>['pdf', ...imageExtensions];

  /// Returns null for unsupported file types.
  static DocumentKind? fromFileName(String name) {
    final int dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return null;
    final String ext = name.substring(dot + 1).toLowerCase();
    if (ext == 'pdf') return DocumentKind.pdf;
    if (imageExtensions.contains(ext)) return DocumentKind.image;
    return null;
  }

  String get label => this == DocumentKind.pdf ? 'PDF' : 'Image';
}

/// Metadata of an encrypted document. The file content itself lives in an
/// AES-256-GCM encrypted blob on disk (see DocumentRepository).
class DocumentEntry {
  const DocumentEntry({
    required this.id,
    required this.name,
    required this.kind,
    required this.size,
    required this.blobName,
    required this.createdAt,
  });

  final String id;
  final String name;
  final DocumentKind kind;
  final int size;
  final String blobName;
  final int createdAt;

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'name': name,
        'kind': kind.name,
        'size': size,
        'blob_name': blobName,
        'created_at': createdAt,
      };

  factory DocumentEntry.fromMap(Map<String, Object?> map) {
    return DocumentEntry(
      id: map['id']! as String,
      name: map['name']! as String,
      kind: DocumentKind.values.byName(map['kind']! as String),
      size: map['size']! as int,
      blobName: map['blob_name']! as String,
      createdAt: map['created_at']! as int,
    );
  }
}
