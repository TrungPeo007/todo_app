import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../db/achievementDb.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Đăng nhập với Email
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      await AchievementDb().initializeDefaultAchievements(); // Gọi sau khi đăng nhập thành công
      return userCredential;
    } catch (e) {
      print("Error in signInWithEmail: $e");
      rethrow;
    }
  }

  // Đăng ký với Email
  Future<UserCredential?> signUpWithEmail(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await AchievementDb().initializeDefaultAchievements(); // Gọi sau khi đăng ký thành công
      return userCredential;
    } catch (e) {
      print("Error in signUpWithEmail: $e");
      rethrow;
    }
  }

  // Đăng nhập với Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      await AchievementDb().initializeDefaultAchievements(); // Gọi sau khi đăng nhập với Google thành công
      return userCredential;
    } catch (e) {
      print("Error in signInWithGoogle: $e");
      rethrow;
    }
  }

  // Đăng xuất
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await GoogleSignIn().signOut();
    } catch (e) {
      print("Error in signOut: $e");
      rethrow;
    }
  }
}
