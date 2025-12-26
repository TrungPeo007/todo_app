// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:workmanager/workmanager.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'notification_service.dart';
// import '../Models/Task.dart';

// const checkTasksBackgroundTask = "check_tasks_background";

// void callbackDispatcher() {
//   Workmanager().executeTask((task, inputData) async {
//     if (task == checkTasksBackgroundTask) {
//       final prefs = await SharedPreferences.getInstance();
//       final tasksString = prefs.getStringList('tasks') ?? [];

//       for (String taskJson in tasksString) {
//         final Map<String, dynamic> taskMap = jsonDecode(taskJson);
//         Task task = Task.fromMap(taskMap);

//         final reminderTime = task.endDate.subtract(Duration(days: 3));

//         if (reminderTime.isBefore(DateTime.now()) &&
//             !task.isCompleted) {
//           NotificationService.showTaskReminderNotification(
//             task.id,
//             "Task sắp đến hạn!",
//             "Task '${task.description}' còn 3 ngày để hoàn thành.",
//             reminderTime,
//           );
//         }
//       }
//     }
//     return Future.value(true);
//   });
// }

// Future<void> registerBackgroundTask() async {
//   await Workmanager().initialize(callbackDispatcher);
//   await Workmanager().registerPeriodicTask(
//     "task_reminder",
//     checkTasksBackgroundTask,
//     frequency: Duration(hours: 6),
//   );
// }
