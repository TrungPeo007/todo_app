import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService {
  static final AudioPlayer _notificationPlayer = AudioPlayer();

  // Lấy âm lượng từ SharedPreferences
  static Future<double> getVolume() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('notification_volume') ?? 0.5; // Mặc định 0.5 nếu chưa có dữ liệu
  }

  // Cập nhật âm lượng ngay khi thay đổi trong Setting
  static Future<void> updateVolume(double volume) async {
    await _notificationPlayer.setVolume(volume);
  }

  static Future<bool> getIsNotficationEnabled() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isNotificationEnabled') ?? false;
    // print('Got isNotificationEnabled: ${prefs.getBool('isNotificationEnabled')}');
  }

  // Phát âm thanh thông báo
  static Future<void> playNotification(String assetPath) async {
    double volume = await getVolume(); // Lấy volume từ SharedPreferences
    await _notificationPlayer.setVolume(volume);
    await _notificationPlayer.play(AssetSource(assetPath));
  }

  // Dừng âm thanh
  static Future<void> stopNotification() async {
    await _notificationPlayer.stop();
  }

  static AudioPlayer get notificationPlayer => _notificationPlayer;
}
