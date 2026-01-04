import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController displayNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  String selectedRole = 'child';

  Future<void> _signUp() async {
    String displayName = displayNameController.text.trim();
    String email = emailController.text.trim();
    String password = passwordController.text.trim();

    // Kiểm tra đầy đủ thông tin
    if (displayName.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng nhập đầy đủ thông tin")),
      );
      return;
    }

    try {
      // 1. Tạo tài khoản trong Firebase Auth
      UserCredential userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Lưu thông tin vào Firestore ngay lập tức
      await FirebaseFirestore.instance.collection('users').doc(userCred.user!.uid).set({
        'displayName': displayName,
        'email': email,
        'role': selectedRole, // 'parent' hoặc 'child'
        'parentUid': selectedRole == 'parent' ? null : null, // parent thì null, child sẽ được parent set sau
        'isLocked': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. Đăng xuất ngay để người dùng phải đăng nhập lại
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      // 4. Thông báo thành công và quay về màn hình Login
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Đăng ký thành công! Vui lòng đăng nhập lại."),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context); // quay về Login
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Lỗi đăng ký: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.orange),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Đăng ký tài khoản",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 30),

                // Tên hiển thị
                TextField(
                  controller: displayNameController,
                  decoration: const InputDecoration(
                    labelText: "Tên hiển thị",
                    hintText: "Ví dụ: Bố Trung , Con Minh Long",
                    prefixIcon: Icon(Icons.person, color: Colors.orange),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Email
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    prefixIcon: Icon(Icons.email, color: Colors.orange),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Chọn vai trò
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Bạn là:",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),

                RadioListTile<String>(
                  value: 'child',
                  groupValue: selectedRole,
                  title: const Text("Học sinh (Con)"),
                  activeColor: Colors.orange,
                  onChanged: (value) {
                    setState(() => selectedRole = value!);
                  },
                ),
                RadioListTile<String>(
                  value: 'parent',
                  groupValue: selectedRole,
                  title: const Text("Phụ huynh (Bố/Mẹ)"),
                  activeColor: Colors.orange,
                  onChanged: (value) {
                    setState(() => selectedRole = value!);
                  },
                ),
                const SizedBox(height: 16),

                // Mật khẩu
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Mật khẩu",
                    prefixIcon: Icon(Icons.lock, color: Colors.orange),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 30),

                // Nút đăng ký
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _signUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      "Đăng ký",
                      style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}