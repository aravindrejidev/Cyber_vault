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

/// One encrypted file (photo or PDF) that belongs to a document. The content
/// lives in an AES-256-GCM encrypted blob on disk (see DocumentRepository).
class DocumentFile {
  const DocumentFile({
    required this.id,
    required this.documentId,
    required this.name,
    required this.kind,
    required this.size,
    required this.blobName,
    required this.position,
    required this.createdAt,
  });

  final String id;
  final String documentId;
  final String name;
  final DocumentKind kind;

  /// Size of the original (decrypted) file in bytes.
  final int size;
  final String blobName;

  /// Order inside the document (0, 1, 2 ...).
  final int position;
  final int createdAt;

  DocumentFile withPosition(int newPosition) {
    return DocumentFile(
      id: id,
      documentId: documentId,
      name: name,
      kind: kind,
      size: size,
      blobName: blobName,
      position: newPosition,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'document_id': documentId,
        'name': name,
        'kind': kind.name,
        'size': size,
        'blob_name': blobName,
        'position': position,
        'created_at': createdAt,
      };

  factory DocumentFile.fromMap(Map<String, Object?> map) {
    return DocumentFile(
      id: map['id']! as String,
      documentId: map['document_id']! as String,
      name: map['name']! as String,
      kind: DocumentKind.values.byName(map['kind']! as String),
      size: map['size']! as int,
      blobName: map['blob_name']! as String,
      position: (map['position'] as int?) ?? 0,
      createdAt: map['created_at']! as int,
    );
  }
}

/// A document: a name, optional login details and a note, plus one or more
/// encrypted photos / PDFs.
class DocumentEntry {
  const DocumentEntry({
    required this.id,
    required this.name,
    required this.userId,
    required this.url,
    required this.password,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.files,
  });

  final String id;
  final String name;
  final String userId;
  final String url;
  final String password;
  final String notes;
  final int createdAt;
  final int updatedAt;
  final List<DocumentFile> files;

  int get totalSize =>
      files.fold<int>(0, (int sum, DocumentFile f) => sum + f.size);

  /// Row of the documents table (the files have their own table).
  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'name': name,
        'user_id': userId,
        'url': url,
        'password': password,
        'notes': notes,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory DocumentEntry.fromMap(
    Map<String, Object?> map,
    List<DocumentFile> files,
  ) {
    return DocumentEntry(
      id: map['id']! as String,
      name: map['name']! as String,
      userId: (map['user_id'] as String?) ?? '',
      url: (map['url'] as String?) ?? '',
      password: (map['password'] as String?) ?? '',
      notes: (map['notes'] as String?) ?? '',
      createdAt: map['created_at']! as int,
      updatedAt: map['updated_at']! as int,
      files: files,
    );
  }
}
