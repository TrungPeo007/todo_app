import 'package:uuid/uuid.dart';

class Achievement {
  final String id;
  final String name;
  final String description;
  final int progress;
  final int goal;
  final bool isCompleted;

  Achievement({
    String? id,
    required this.name,
    required this.description,
    this.progress = 0,
    required this.goal,
    this.isCompleted = false,
  }) : id = id ?? const Uuid().v4();

  Achievement copyWith({
    String? id,
    String? name,
    String? description,
    int? progress,
    int? goal,
    bool? isCompleted,
  }) {
    return Achievement(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      progress: progress ?? this.progress,
      goal: goal ?? this.goal,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  factory Achievement.fromMap(Map<String, dynamic> map) {
    return Achievement(
      id: map['id'] ?? const Uuid().v4(),
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      progress: map['progress'] ?? 0,
      goal: map['goal'] ?? 0,
      isCompleted: map['isCompleted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'progress': progress,
      'goal': goal,
      'isCompleted': isCompleted,
    };
  }
}
