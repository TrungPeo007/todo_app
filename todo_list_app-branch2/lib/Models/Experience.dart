import 'package:uuid/uuid.dart';

class Experience {
  String? id;
  String? userId;
  int level;
  int xp;
  int xpRequired;
  int xpCurrent;

  Experience({
    String? id,
    this.userId,
    this.level = 1,
    this.xp = 0,
    this.xpRequired = 100,
    this.xpCurrent = 0,
  }) : id = id ?? Uuid().v4(); // Sử dụng UUID để tạo ID nếu không có

  Experience copyWith({
    String? id,
    String? userId,
    int? level,
    int? xp,
    int? xpRequired,
    int? xpCurrent,
  }) {
    return Experience(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      xpRequired: xpRequired ?? this.xpRequired,
      xpCurrent: xpCurrent ?? this.xpCurrent,
    );
  }

  factory Experience.fromMap(Map<String, dynamic> map) {
    return Experience(
      id: map['id'] as String? ?? Uuid().v4(), // Nếu không có id, tạo mới UUID
      userId: map['userId'] as String? ?? '',
      level: map['level'] as int? ?? 1,
      xp: map['xp'] as int? ?? 0,
      xpRequired: map['xpRequired'] as int? ?? 100,
      xpCurrent: map['xpCurrent'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'level': level,
      'xp': xp,
      'xpRequired': xpRequired,
      'xpCurrent': xpCurrent,
    };
  }
}
