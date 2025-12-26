import 'package:shared_preferences/shared_preferences.dart';
import '../Models/Task.dart';

class AlertManager {
  // Đổi thành một key chuỗi cho SharedPreferences
  static const String _alertPlayedKey = 'alertPlayed';

  // Kiểm tra xem cảnh báo đã được hiển thị chưa
  static Future<bool> hasAlertPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_alertPlayedKey) ??
        false; // Nếu chưa có giá trị, trả về false
  }

  // Đánh dấu cảnh báo đã được hiển thị
  static Future<void> setAlertPlayed(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_alertPlayedKey, value);
  }

  // Kiểm tra các nhiệm vụ sắp đến hạn và hiển thị cảnh báo nếu cần
  static Future<void> checkUpcomingDeadlines(
    List<Task> tasks,
    Function showAlert,
  ) async {
    bool alertPlayed = await hasAlertPlayed();

    if (alertPlayed) return; // Nếu cảnh báo đã hiển thị rồi, không làm gì cả

    DateTime now = DateTime.now();
    DateTime targetDate = now.add(const Duration(days: 3));

    List<Task> upcomingTasks =
        tasks
            .where(
              (task) =>
                  task.endDate.isAfter(now) &&
                  task.endDate.isBefore(targetDate),
            )
            .toList();

    if (upcomingTasks.isNotEmpty) {
      showAlert(upcomingTasks); // Gọi hàm showAlert để hiển thị cảnh báo
      await setAlertPlayed(true); // Đánh dấu đã hiển thị cảnh báo
    }
  }
}
