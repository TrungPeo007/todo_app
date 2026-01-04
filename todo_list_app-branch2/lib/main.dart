import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Đảm bảo đúng đường dẫn theo cấu trúc dự án của anh:
import 'widgets/firebase_options.dart';

import 'theme/app_theme.dart';
import 'loading_screen.dart';
import 'Listeners/auth_listener.dart'; // dùng chữ thường thống nhất

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Chỉ khởi tạo nếu chưa có app nào
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      name:"todoApp",
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TODO List App',
      theme: AppTheme.lightTheme, // nếu anh có theme riêng
      home: AuthStateListener(), // hoặc HomeScreen nếu anh muốn
    );
  }
}