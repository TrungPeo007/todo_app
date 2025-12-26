import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

Future<File?> pickImage() async {
  final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
  return pickedFile != null ? File(pickedFile.path) : null;
}

String? getCurrentUserId() {
  return FirebaseAuth.instance.currentUser?.uid;
}

Future<void> saveImagePath(String path) async {
  final userId = getCurrentUserId();
  if (userId == null) return;

  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('profile_image_$userId', path);
}

Future<File?> loadSavedImage() async {
  final userId = getCurrentUserId();
  if (userId == null) return null;

  final prefs = await SharedPreferences.getInstance();
  final imagePath = prefs.getString('profile_image_$userId');

  if (imagePath != null && await File(imagePath).exists()) {
    return File(imagePath);
  }
  return null;
}

Future<void> deleteOldImage() async {
  final userId = getCurrentUserId();
  if (userId == null) return;

  final prefs = await SharedPreferences.getInstance();
  final oldImagePath = prefs.getString('profile_image_$userId');

  if (oldImagePath != null) {
    final oldImage = File(oldImagePath);
    if (await oldImage.exists()) {
      await oldImage.delete();
    }
    await prefs.remove('profile_image_$userId');
  }
}

Future<File> saveImage(File image) async {
  final userId = getCurrentUserId();
  if (userId == null) throw Exception('User not logged in');

  // Create user-specific directory if it doesn't exist
  final appDir = await getApplicationDocumentsDirectory();
  final userDir = Directory('${appDir.path}/user_$userId');
  if (!await userDir.exists()) {
    await userDir.create(recursive: true);
  }

  await deleteOldImage();

  final fileName = 'profile_image.png';
  final savedImage = await image.copy('${userDir.path}/$fileName');

  await saveImagePath(savedImage.path);

  return savedImage;
}