class PasswordEntry {
  const PasswordEntry({
    required this.id,
    required this.title,
    required this.username,
    required this.password,
    required this.url,
    required this.notes,
    required this.favorite,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String username;
  final String password;
  final String url;
  final String notes;
  final bool favorite;
  final int createdAt;
  final int updatedAt;

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'title': title,
        'username': username,
        'password': password,
        'url': url,
        'notes': notes,
        'favorite': favorite ? 1 : 0,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory PasswordEntry.fromMap(Map<String, Object?> map) {
    return PasswordEntry(
      id: map['id']! as String,
      title: map['title']! as String,
      username: (map['username'] as String?) ?? '',
      password: (map['password'] as String?) ?? '',
      url: (map['url'] as String?) ?? '',
      notes: (map['notes'] as String?) ?? '',
      favorite: ((map['favorite'] as int?) ?? 0) == 1,
      createdAt: map['created_at']! as int,
      updatedAt: map['updated_at']! as int,
    );
  }
}
