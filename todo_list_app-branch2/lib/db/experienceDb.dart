import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:todo_app/Models/Experience.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ExperienceDatabaseService {
  static final ExperienceDatabaseService _instance =
      ExperienceDatabaseService._constructor();
  static Database? _db;

  factory ExperienceDatabaseService() {
    return _instance;
  }

  ExperienceDatabaseService._constructor();

  final String _experienceTableName = "experience";

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
        // Tạo bảng experience
        await db.execute(''' 
        CREATE TABLE experience (
          id TEXT PRIMARY KEY,
          userId TEXT,
          level INTEGER,
          xp INTEGER,
          xpRequired INTEGER,
          xpCurrent INTEGER
        );
      ''');
      },
    );
  }

  Future<void> insertExperience(Experience experience) async {
    final db = await database;
    await db.insert(
      _experienceTableName,
      experience.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Experience?> getExperienceByUserId(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _experienceTableName,
      where: 'userId = ?',
      whereArgs: [userId],
    );

    if (maps.isNotEmpty) {
      return Experience.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<void> updateExperience(Experience experience) async {
    final db = await database;
    await db.update(
      _experienceTableName,
      experience.toMap(),
      where: 'id = ?',
      whereArgs: [experience.id],
    );
  }

  Future<void> deleteExperience(String id) async {
    final db = await database;
    await db.delete(_experienceTableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAllExperience() async {
    final db = await database;
    await db.delete(_experienceTableName); // Xóa toàn bộ bảng experience
  }

  Future<void> deleteExperienceByUserId(String userId) async {
    final db = await database;
    await db.delete(
      _experienceTableName,
      where: 'userId = ?',
      whereArgs: [userId],
    );
  }

  Future<void> updateExperienceByUserId(
    String userId,
    Experience experience,
  ) async {
    final db = await database;
    await db.update(
      _experienceTableName,
      experience.toMap(),
      where: 'userId = ?',
      whereArgs: [userId],
    );
  }

  Future<void> updateExperienceById(String id, Experience experience) async {
    final db = await database;
    await db.update(
      _experienceTableName,
      experience.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Experience>> getAllExperiences() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _experienceTableName,
    );

    return List.generate(maps.length, (i) {
      return Experience.fromMap(maps[i]);
    });
  }

  Future<void> clearExperienceTable() async {
    final db = await database;
    await db.delete(_experienceTableName); // Xóa toàn bộ bảng experience
  }

  Future<void> saveExperienceToFirebase(Experience experience) async {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('experience')
        .doc(experience.id) // Dùng ID dạng String
        .set(experience.toMap());
  }

  Future<void> deleteExperienceFromFirebase(String id) async {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('experience')
        .doc(id) // Dùng ID dạng String
        .delete();
  }

  Future<void> updateExperienceInFirebase(Experience experience) async {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('experience')
        .doc(experience.id) // Dùng ID dạng String
        .update(experience.toMap());
  }

  Future<Experience?> getExperienceByUserIdFromFirebase(String userId) async {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    try {
      // Truy vấn collection 'experience' của user từ Firestore
      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('experience')
              .doc(userId) // Dùng userId làm ID của document
              .get();

      if (snapshot.exists) {
        return Experience.fromMap(
          snapshot.data()!,
        ); // Trả về đối tượng Experience
      }
    } catch (e) {
      print("Lỗi khi lấy kinh nghiệm từ Firestore: $e");
    }
    return null; // Trả về null nếu không có dữ liệu
  }

  Future<void> deleteAllExperienceFromFirebase() async {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final QuerySnapshot snapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('experience')
            .get();

    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  // Trong file experienceDb.dart
  Future<void> addExperience(String userId, int xpToAdd) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('experience')
          .doc(userId); // Đảm bảo đường dẫn đúng

      return FirebaseFirestore.instance.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);

        if (doc.exists) {
          int currentXp = doc['xpCurrent'] ?? 0;
          int xpRequired = doc['xpRequired'] ?? 100;
          int level = doc['level'] ?? 1;

          int newXp = currentXp + xpToAdd;
          int newLevel = level;

          // Logic lên level
          while (newXp >= xpRequired) {
            newXp -= xpRequired;
            newLevel++;
            xpRequired = (xpRequired * 1.2).round();
          }

          transaction.update(docRef, {
            'xpCurrent': newXp,
            'xpRequired': xpRequired,
            'level': newLevel,
            'userId': userId, // Đảm bảo có trường userId
          });
        } else {
          transaction.set(docRef, {
            'xpCurrent': xpToAdd,
            'xpRequired': 100,
            'level': 1,
            'userId': userId,
          });
        }
      });
    } catch (e) {
      print('Error in addExperience: $e');
      rethrow;
    }
  }

  Future<void> deleteExperienceByUserIdFromFirebase(String userId) async {
    final QuerySnapshot snapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('experience')
            .get();

    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  Future<void> updateExperienceByUserIdInFirebase(
    String userId,
    Experience experience,
  ) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('experience')
        .doc(experience.id) // Dùng ID dạng String
        .update(experience.toMap());
  }
}
