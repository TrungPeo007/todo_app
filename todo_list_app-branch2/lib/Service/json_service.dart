import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/user_model.dart';
import '../models/task.dart';

class JsonService {
  static Future<List<AppUser>> loadUsers() async {
    final jsonString = await rootBundle.loadString('assets/data/users.json');
    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList.map((e) => AppUser.fromJson(e)).toList();
  }

  static Future<List<Task>> loadTasks() async {
    final jsonString = await rootBundle.loadString('assets/data/tasks.json');
    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList.map((e) => Task.fromJson(e)).toList();
  }

  // Sau này có thể thêm save (vào file local) nếu cần persist thay đổi
}