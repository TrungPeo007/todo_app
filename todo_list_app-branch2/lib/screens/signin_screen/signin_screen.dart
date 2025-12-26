import 'package:flutter/material.dart';
import '../../Service/authService.dart';
import '../register_screen/register_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  Future<void> _signInWithEmail() async {
    String email = emailController.text;
    String password = passwordController.text;

    try {
      await AuthService().signInWithEmail(email, password);
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi: ${e.toString()}")),
      );
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      await AuthService().signInWithGoogle();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi Google Sign-In: ${e.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: "Email"),
            ),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: "Mật khẩu"),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _signInWithEmail,
              child: Text("Đăng nhập"),
            ),
            ElevatedButton(
              onPressed: _signInWithGoogle,
              child: Text("Đăng nhập với Google"),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => RegisterScreen()),
              ),
              child: Text("Chưa có tài khoản? Đăng ký ngay!"),
            ),
          ],
        ),
      ),
    );
  }
}
