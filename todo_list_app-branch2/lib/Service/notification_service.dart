// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:timezone/data/latest_all.dart' as tz;
// import 'package:timezone/timezone.dart' as tz;

// class NotificationService {
//   static final FlutterLocalNotificationsPlugin _notificationsPlugin =
//       FlutterLocalNotificationsPlugin();

//   static Future<void> init() async {
//     tz.initializeTimeZones();
    
//     const AndroidInitializationSettings androidSettings =
//         AndroidInitializationSettings('@mipmap/ic_launcher');

//     final InitializationSettings settings =
//         InitializationSettings(android: androidSettings);

//     await _notificationsPlugin.initialize(settings);
//   }

//   static Future<void> showTaskReminderNotification(
//       String taskId, String title, String body, DateTime scheduleTime) async {
//     await _notificationsPlugin.zonedSchedule(
//       int.parse(taskId.replaceAll(RegExp(r'[^0-9]'), '')), // Chuyển UUID thành số
//       title,
//       body,
//       tz.TZDateTime.from(scheduleTime, tz.local),
//       const NotificationDetails(
//         android: AndroidNotificationDetails(
//           'task_reminder_channel',
//           'Task Reminders',
//           channelDescription: 'Notifies when a task is 3 days from deadline',
//           importance: Importance.high,
//           priority: Priority.high,
//         ),
//       ),
//       androidAllowWhileIdle: true,
//       uiLocalNotificationDateInterpretation:
//           UILocalNotificationDateInterpretation.absoluteTime,
//     );
//   }
// }
