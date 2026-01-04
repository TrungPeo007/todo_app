import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../screens/signin_screen/signin_screen.dart';
import '../home_screen.dart';
import '../screens/parent/parent_home_screen.dart';
import '../screens/admin/admin_home_screen.dart';
import '../loading_screen.dart';

class AuthStateListener extends StatelessWidget {
  const AuthStateListener({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }

        if (!authSnapshot.hasData) {
          return const LoginScreen();
        }

        final uid = authSnapshot.data!.uid;
        return FutureBuilder<DocumentSnapshot>(
          future:
              FirebaseFirestore.instance.collection('users').doc(uid).get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const LoadingScreen();
            }

            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              // fail-safe
              FirebaseAuth.instance.signOut();
              return const LoginScreen();
            }

            final data =
                userSnapshot.data!.data() as Map<String, dynamic>;
            final role = data['role'];

            if (role == 'child') {
              return HomeScreen();
            } else if (role == 'parent') {
              return ParentHomeScreen();
            } else if (role == 'admin') {
              return AdminHomeScreen();
            } else {
              FirebaseAuth.instance.signOut();
              return const LoginScreen();
            }
          },
        );
      },
    );
  }
}
