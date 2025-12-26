import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Service/AudioService.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _volume = 0.5; // Giá trị mặc định
  bool isNotificationEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadVolume();
  }

  // Tải mức âm lượng đã lưu từ SharedPreferences (nếu có)
  Future<void> _loadVolume() async {
    double savedVolume = await AudioService.getVolume();
    setState(() {
      _volume = savedVolume;
    });
  }

  // Lưu mức âm lượng vào SharedPreferences và cập nhật ngay cho AudioService
  Future<void> _saveVolume(double volume) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('notification_volume', volume);
    await AudioService.updateVolume(volume); // Cập nhật volume ngay lập tức
  }

  Future<void> _saveIsNotification (bool isNotificationEnabled) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isNotificationEnabled', isNotificationEnabled);
    print("isNotificationEnabled: $isNotificationEnabled");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back), // Nút quay lại
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Row(
          children: [
            Icon(Icons.settings), // Icon bánh răng
            SizedBox(width: 8),
            Text('Settings'),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Notification Volume",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Slider(
              value: _volume,
              min: 0.0,
              max: 1.0,
              divisions: 10,
              label: _volume.toStringAsFixed(1),
              onChanged: (double value) {
                setState(() {
                  _volume = value;
                });
                _saveVolume(_volume);
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Enable Notification',
            ),
            Switch(value: isNotificationEnabled, onChanged: (bool value) {
              setState(() {
                isNotificationEnabled = value;
              });
              _saveIsNotification(isNotificationEnabled);
            })
          ],
        ),
      ),
    );
  }
}
