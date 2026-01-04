import 'package:flutter/material.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        backgroundColor: Colors.red,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.admin_panel_settings,
              size: 80,
              color: Colors.red,
            ),
            SizedBox(height: 20),
            Text(
              "Đây là màn hình Admin",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "Chỉ người làm app mới được cấp quyền",
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
