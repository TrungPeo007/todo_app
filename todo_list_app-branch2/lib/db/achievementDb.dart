import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Models/Acheivement.dart';

class AchievementDb {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Thêm một Achievement mới cho user hiện tại.
  Future<void> addAchievement(Achievement achievement) async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // Nếu achievement chưa có ID, tạo ID mới (đã được xử lý trong model)
    Achievement achievementToSave = achievement;
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('achievements')
        .doc(achievementToSave.id)
        .set(achievementToSave.toMap());
  }

  /// Lấy danh sách Achievement của user hiện tại.
  Future<List<Achievement>> getAchievements() async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    QuerySnapshot snapshot =
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('achievements')
            .get();

    return snapshot.docs
        .map((doc) => Achievement.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }

  /// Cập nhật tiến trình của một Achievement.
  Future<void> updateAchievementProgress(
    String achievementId,
    int increment,
  ) async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return;

    DocumentReference docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('achievements')
        .doc(achievementId);

    DocumentSnapshot doc = await docRef.get();
    if (doc.exists) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      int currentProgress = data['progress'] ?? 0;
      int goal = data['goal'] ?? 0;
      int newProgress = currentProgress + increment;
      bool isCompleted = newProgress >= goal;

      await docRef.update({
        'progress': newProgress,
        'isCompleted': isCompleted,
      });
    }
  }

  /// Xóa một Achievement.
  Future<void> deleteAchievement(String achievementId) async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('achievements')
        .doc(achievementId)
        .delete();
  }

  /// Reset toàn bộ Achievement của user hiện tại.
  Future<void> resetAchievements() async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return;

    QuerySnapshot snapshot =
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('achievements')
            .get();

    for (DocumentSnapshot doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  Future<void> initializeDefaultAchievements() async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return;

    CollectionReference achievementsRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('achievements');

    // Kiểm tra xem user đã có thành tựu nào chưa
    QuerySnapshot snapshot = await achievementsRef.get();
    if (snapshot.docs.isEmpty) {
      // Danh sách thành tựu mặc định
      List<Achievement> defaultAchievements = [
        Achievement(
          name: "Task Starter",
          description: "Complete your first task",
          goal: 1,
        ),
        Achievement(
          name: "Task Enthusiast",
          description: "Complete 10 tasks",
          goal: 10,
        ),
        Achievement(
          name: "Task Master",
          description: "Complete 50 tasks",
          goal: 50,
        ),
        Achievement(
          name: "Your First Strike",
          description: "Complete tasks on 2 consecutive days",
          goal: 2,
        ),
        Achievement(
          name: "The Noob Striker",
          description: "Complete tasks on 5 consecutive days",
          goal: 5,
        ),
      ];

      // Thêm các thành tựu mặc định vào Firestore
      for (Achievement achievement in defaultAchievements) {
        await achievementsRef.doc(achievement.id).set(achievement.toMap());
      }
      print("Default achievements have been initialized for user $uid");
    } else {
      print("User $uid already has achievements.");
    }
  }
}
