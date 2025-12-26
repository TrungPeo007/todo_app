import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import './Listeners/auth_listener.dart';
// import '../firebase_options.dart';
import './loading_screen.dart';
import 'dart:async';
// import './Service/background_service.dart';
// import './Service//notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // await NotificationService.init();
  // await registerBackgroundTask();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  Future<User?> _initializeFirebase() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await Future.delayed(const Duration(seconds: 3)); // Delay 3 giây để hiển thị animation
    return FirebaseAuth.instance.currentUser;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'My App',
      theme: ThemeData.light(),
      home: FutureBuilder<User?>(
        future: _initializeFirebase(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingScreen();
          } else if (snapshot.hasData) {
            return AuthStateListener();
          } else {
            return AuthStateListener();
          }
        },
      ),
    );
  }
}
