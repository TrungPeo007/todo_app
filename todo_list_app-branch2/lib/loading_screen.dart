import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'dart:math'; // Thêm thư viện này để dùng Random

class LoadingScreen extends StatefulWidget { // Đổi thành StatefulWidget
  const LoadingScreen({Key? key}) : super(key: key);

  @override
  _LoadingScreenState createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  late String _randomQuote; // Biến lưu câu nói ngẫu nhiên

  // Danh sách các câu nói nổi tiếng
  final List<String> _quotes = [
    "The only way to do great work is to love what you do. - Steve Jobs",
    "Productivity is being able to do things that you were never able to do before. - Franz Kafka",
    "Your time is limited, don't waste it living someone else's life. - Steve Jobs",
    "The secret of getting ahead is getting started. - Mark Twain",
    "Do the hard work especially when you don't feel like it. - Hamza Ahmed",
    "Small daily improvements are the key to staggering long-term results. - Unknown",
    "Focus on being productive instead of busy. - Tim Ferriss",
    "It's not about having time, it's about making time. - Unknown",
    "The future depends on what you do today. - Mahatma Gandhi",
    "You don't have to be great to start, but you have to start to be great. - Zig Ziglar"
  ];

  @override
  void initState() {
    super.initState();
    // Chọn ngẫu nhiên một câu nói khi khởi tạo
    _randomQuote = _quotes[Random().nextInt(_quotes.length)];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0), // Thêm padding để tránh chữ sát mép
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(
                'assets/loadingScence.json',
                width: 150,
                height: 150,
                fit: BoxFit.cover,
              ),
              const SizedBox(height: 30),
              Text(
                "Please wait...",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 30),
              // Hiển thị câu nói ngẫu nhiên
              Text(
                _randomQuote,
                textAlign: TextAlign.center, // Căn giữa
                style: TextStyle(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}