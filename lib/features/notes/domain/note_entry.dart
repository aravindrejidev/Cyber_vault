class NoteEntry {
  const NoteEntry({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String body;
  final int createdAt;
  final int updatedAt;

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'title': title,
        'body': body,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory NoteEntry.fromMap(Map<String, Object?> map) {
    return NoteEntry(
      id: map['id']! as String,
      title: map['title']! as String,
      body: (map['body'] as String?) ?? '',
      createdAt: map['created_at']! as int,
      updatedAt: map['updated_at']! as int,
    );
  }
}
