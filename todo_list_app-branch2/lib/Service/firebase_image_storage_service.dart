import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';

class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Upload hình ảnh lên Firebase Storage
  Future<String> uploadImage(File image) async {
    try {
      // Lấy UID của người dùng hiện tại
      String uid = _auth.currentUser!.uid;

      // Tạo reference đến file trên Firebase Storage
      Reference ref = _storage.ref().child('profile_images/$uid.jpg');

      // Upload file
      await ref.putFile(image);

      // Lấy URL của file đã upload
      String downloadURL = await ref.getDownloadURL();
      return downloadURL;
    } catch (e) {
      print("Error uploading image: $e");
      rethrow;
    }
  }

  // Tải hình ảnh từ Firebase Storage
  Future<String?> downloadImage() async {
    try {
      // Lấy UID của người dùng hiện tại
      String uid = _auth.currentUser!.uid;

      // Tạo reference đến file trên Firebase Storage
      Reference ref = _storage.ref().child('profile_images/$uid.jpg');

      // Lấy URL của file
      String downloadURL = await ref.getDownloadURL();
      return downloadURL;
    } catch (e) {
      print("Error downloading image: $e");
      return null;
    }
  }
}