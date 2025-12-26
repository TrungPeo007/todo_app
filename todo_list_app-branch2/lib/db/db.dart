import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import '../Models/Task.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._constructor();
  static Database? _db;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._constructor();

  final String _tasksTableName = "tasks";

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final databaseDirPath = await getDatabasesPath();
    final databasePath = join(databaseDirPath, "master_db.db");

    return await openDatabase(
      databasePath,
      version: 1,
      onCreate: (db, version) async {
        // Tạo bảng tasks
        await db.execute('''
        CREATE TABLE tasks (
          id TEXT PRIMARY KEY,
          userId TEXT,
          description TEXT,
          startDate TEXT,
          endDate TEXT,
          isCompleted INTEGER,
          isFavorite INTEGER,
          type TEXT
        );
      ''');

        // Tạo bảng completed_tasks có userId
        await db.execute('''
        CREATE TABLE completed_tasks (
          date TEXT,
          userId TEXT,
          count INTEGER DEFAULT 0,
          PRIMARY KEY (date, userId)
        );
      ''');
      },
    );
  }

  Future<void> updateDate(DateTime date) async {
    final db = await database;
    String formattedDate =
        date.toIso8601String().split('T')[0]; // Lấy YYYY-MM-DD

    List<Map<String, dynamic>> existing = await db.query(
      'completed_tasks',
      where: 'date = ?',
      whereArgs: [formattedDate],
    );

    if (existing.isNotEmpty) {
      int currentCount = existing.first['count'];
      await db.update(
        'completed_tasks',
        {'count': currentCount + 1},
        where: 'date = ?',
        whereArgs: [formattedDate],
      );
      print('Updated count for date $formattedDate to ${currentCount + 1}');
    } else {
      await db.insert('completed_tasks', {'date': formattedDate, 'count': 1});
    }
  }

  Future<void> decreaseDate(DateTime date) async {
    final db = await database;
    String formattedDate = date.toIso8601String().split('T')[0];

    List<Map<String, dynamic>> existing = await db.query(
      'completed_tasks',
      where: 'date = ?',
      whereArgs: [formattedDate],
    );

    if (existing.isNotEmpty) {
      int currentCount = existing.first['count'];
      if (currentCount > 0) {
        // Đảm bảo count không xuống dưới 0
        await db.update(
          'completed_tasks',
          {'count': currentCount - 1},
          where: 'date = ?',
          whereArgs: [formattedDate],
        );
        print('Updated count for date $formattedDate to ${currentCount - 1}');
      }
    }
  }

  Future<Map<DateTime, int>> getCompletedTasksByDate() async {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return {};

    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      "completed_tasks",
      where: 'userId = ?', // Lọc theo userId
      whereArgs: [uid],
    );

    Map<DateTime, int> completedTasksByDate = {};
    for (var map in maps) {
      DateTime date = DateTime.parse(map['date']);
      int count = map['count'];
      completedTasksByDate[date] = count;
    }
    return completedTasksByDate;
  }

  Future<void> addTask(Task task) async {
    final db = await database;
    String? uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) return;

    String taskId = task.id.isEmpty ? const Uuid().v4() : task.id;

    await db.insert(_tasksTableName, {
      'id': taskId,
      'userId': uid, // Lưu userId
      'description': task.description,
      'startDate': task.startDate.toIso8601String(),
      'endDate': task.endDate.toIso8601String(),
      'isCompleted': task.isCompleted ? 1 : 0,
      'isFavorite': task.isFavorite ? 1 : 0,
      'type': task.type,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await saveTaskToFirebase(
      task.copyWith(id: taskId, userId: uid),
    ); // Lưu userId vào Firebase
  }

  Future<List<Task>> getTasks() async {
    final db = await database;
    String? uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) return []; // Nếu chưa đăng nhập, trả về danh sách rỗng

    final List<Map<String, dynamic>> maps = await db.query(
      _tasksTableName,
      where: 'userId = ?', // Lọc theo userId
      whereArgs: [uid],
    );

    return List.generate(maps.length, (i) {
      return Task.fromMap(maps[i]);
    });
  }

  Future<void> deleteTask(String id) async {
    final db = await database;
    int result = await db.delete(
      _tasksTableName,
      where: 'id = ?',
      whereArgs: [id],
    );

    print("Deleted $result row(s) from database with ID: $id");

    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('tasks')
          .doc(id) // Dùng ID dạng String
          .delete();
    }
  }

  Future<void> updateTask(Task task) async {
    final db = await database;
    await db.update(
      _tasksTableName,
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );

    print(
      "Updated task ${task.id}: type=${task.type}, isCompleted=${task.isCompleted}, isFavorite=${task.isFavorite}",
    );
  }

  Future<void> clearCompletedTasks() async {
    final db = await database;
    await db.delete('completed_tasks'); // Xóa toàn bộ bảng completed_tasks
  }

  Future<void> saveTaskToFirebase(Task task) async {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .doc(task.id.toString()) // Dùng ID từ SQLite để đồng bộ
        .set(task.toMap());
  }
}
