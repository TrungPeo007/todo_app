import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../db/achievementDb.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ===============================
  // LOGIN EMAIL (CÓ ROLE)
  // ===============================
  Future<String> signInWithEmail(String email, String password) async {
    UserCredential userCredential =
        await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = userCredential.user!.uid;
    final doc = await _firestore.collection('users').doc(uid).get();

    if (!doc.exists) {
      await _auth.signOut();
      throw Exception("User không tồn tại trong Firestore");
    }

    if (doc['isLocked'] == true) {
      await _auth.signOut();
      throw Exception("Tài khoản đã bị khóa");
    }

    await AchievementDb().initializeDefaultAchievements();

    return doc['role']; // parent | child | admin
  }

  // ===============================
  // REGISTER EMAIL (CÓ ROLE)
  // ===============================
  Future<void> signUpWithEmail(
    String email,
    String password,
    String role,
  ) async {
    UserCredential userCredential =
        await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = userCredential.user!.uid;

    await _firestore.collection('users').doc(uid).set({
      'email': email,
      'role': role,
      'isLocked': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await AchievementDb().initializeDefaultAchievements();
  }

  // ===============================
  // GOOGLE SIGN IN (CHƯA PHÂN ROLE)
  // ===============================
  Future<UserCredential?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser =
        await GoogleSignIn().signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return await _auth.signInWithCredential(credential);
  }

  // ===============================
  // SIGN OUT
  // ===============================
  Future<void> signOut() async {
    await _auth.signOut();
    await GoogleSignIn().signOut();
  }
}
