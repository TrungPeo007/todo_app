import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'package:share_plus/share_plus.dart';
import '../../Models/Task.dart';
import '../add_tasks_screen/add_tasks_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/acheivements_utils.dart';
import '../../Models/Experience.dart';
import '../../db/experienceDb.dart';
import '../../widgets/Task3DCard.dart';
import './tasks_logic.dart';
import 'package:open_file/open_file.dart';

class TasksScreen extends StatefulWidget {
  final List<Task> tasks;
  final Function(Task) onTaskUpdated;
  final Function(Task) onTaskDeleted;
  final Function(Task) onTaskAdded;

  const TasksScreen({
    Key? key,
    required this.tasks,
    required this.onTaskAdded,
    required this.onTaskUpdated,
    required this.onTaskDeleted,
  }) : super(key: key);

  @override
  _TasksScreenState createState() => _TasksScreenState();
}

int _calculateXpForTask(Task task) {
  // Base XP
  int baseXp = 10;
  // Thêm XP theo loại task
  switch (task.type) {
    case 'Urgent':
      return baseXp + 15; // 25 XP cho task khẩn cấp
    case 'Work':
      return baseXp + 10; // 20 XP cho công việc
    case 'Personal':
      return baseXp + 5; // 15 XP cho cá nhân
    default:
      return baseXp; // 10 XP cho task thường
  }
}

void _show3DTaskCard(BuildContext context, Task task) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withOpacity(0.5),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Center(
        child: Task3DCard(
          task: task,
          onClose: () => Navigator.of(context).pop(),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: FadeTransition(opacity: animation, child: child),
      );
    },
  );
}

class _TasksScreenState extends State<TasksScreen> {
  String _sortBy = 'None'; // Tiêu chí sắp xếp

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tasks'),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Doing"),
              Tab(text: "Completed"),
              Tab(text: "Favorite"),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.import_export),
              onPressed: () => _showExportOptions(context),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: DropdownButton<String>(
                value: _sortBy,
                items:
                    [
                      'None',
                      'Type (A-Z)',
                      'Type (Z-A)',
                      'Priority High to Low',
                      'Priority Low to High',
                    ].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _sortBy = newValue;
                    });
                  }
                },
              ),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildTaskList(
              widget.tasks.where((task) => !task.isCompleted).toList(),
            ),
            _buildTaskList(
              widget.tasks.where((task) => task.isCompleted).toList(),
            ),
            _buildTaskList(
              widget.tasks.where((task) => task.isFavorite).toList(),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => AddTaskScreen(
                      onTaskAdded: (newTask) {
                        widget.onTaskUpdated(newTask);
                      },
                    ),
              ),
            );
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  // Hàm xuất file CSV từ danh sách tasks
  // Hàm xuất file CSV từ danh sách tasks
  Future<File> _exportTasksToCsv(List<Task> tasks) async {
    final directory = await getApplicationDocumentsDirectory();
    print('Directory: ${directory.path}');
    // Tạo file CSV trong thư mục Documents
    final file = File('${directory.path}/tasks_export.csv');

    String csvContent =
        'Id,UserId,Description,StartDate,EndDate,Completed,Favorite,Type\n';

    for (var task in tasks) {
      csvContent +=
          '"${task.id}",'
          '"${task.userId}",'
          '"${task.description.replaceAll('"', '""')}",'
          '${task.startDate.toIso8601String()},'
          '${task.endDate.toIso8601String()},'
          '${task.isCompleted},'
          '${task.isFavorite},'
          '"${task.type}"\n';
    }

    await file.writeAsString(csvContent);
    return file;
  }

  // Hàm xuất file JSON từ danh sách tasks
  Future<File> _exportTasksToJson(List<Task> tasks) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(
      '${directory.path}/tasks_export_${DateTime.now().millisecondsSinceEpoch}.json',
    );

    final tasksJson = tasks.map((task) => task.toMap()).toList();
    await file.writeAsString(jsonEncode(tasksJson));
    return file;
  }

  // Hàm xuất và hiển thị tùy chọn mở file sau khi export
  Future<void> _exportTasks(String format) async {
    try {
      final currentTasks = widget.tasks;

      if (currentTasks.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No tasks to export')));
        return;
      }

      File exportedFile;
      if (format == 'csv') {
        exportedFile = await _exportTasksToCsv(currentTasks);
      } else {
        exportedFile = await _exportTasksToJson(currentTasks);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported to: ${exportedFile.path}')),
      );

      // Hiển thị hộp thoại cho người dùng chọn mở file hay không
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Export Successful'),
              content: Text(
                'File has been exported to:\n${exportedFile.path}\n\nDo you want to open the file?',
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.pop(context),
                ),
                TextButton(
                  child: const Text('Open File'),
                  onPressed: () {
                    Navigator.pop(context);
                    OpenFile.open(exportedFile.path);
                  },
                ),
              ],
            ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  // Hiển thị hộp thoại lựa chọn định dạng xuất file
  void _showExportOptions(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Export Tasks'),
            content: const Text('Choose export format:'),
            actions: [
              TextButton(
                child: const Text('CSV'),
                onPressed: () {
                  Navigator.pop(context);
                  _exportTasks('csv');
                },
              ),
              TextButton(
                child: const Text('JSON'),
                onPressed: () {
                  Navigator.pop(context);
                  _exportTasks('json');
                },
              ),
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
    );
  }

  List<Task> _sortTasks(List<Task> tasks) {
    // Định nghĩa mức độ ưu tiên theo loại task
    Map<String, int> priorityMap = {
      'Urgent': 1,
      'Work': 2,
      'Personal': 3,
      'General': 4,
    };

    if (_sortBy == 'Type (A-Z)') {
      tasks.sort((a, b) => a.type.compareTo(b.type));
    } else if (_sortBy == 'Type (Z-A)') {
      tasks.sort((a, b) => b.type.compareTo(a.type));
    } else if (_sortBy == 'Priority High to Low') {
      tasks.sort(
        (a, b) =>
            (priorityMap[a.type] ?? 999).compareTo(priorityMap[b.type] ?? 999),
      );
    } else if (_sortBy == 'Priority Low to High') {
      tasks.sort(
        (a, b) =>
            (priorityMap[b.type] ?? 999).compareTo(priorityMap[a.type] ?? 999),
      );
    }

    return tasks;
  }

  Widget _buildTaskList(List<Task> taskList) {
    final Map<String, Color> taskTypeColors = {
      'General': Colors.grey,
      'Work': Colors.blue,
      'Personal': Colors.green,
      'Urgent': Colors.red,
    };

    List<Task> sortedTasks = _sortTasks(taskList);

    return ListView.builder(
      itemCount: sortedTasks.length,
      itemBuilder: (context, index) {
        final task = sortedTasks[index];
        final taskColor = taskTypeColors[task.type] ?? Colors.grey;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          decoration: BoxDecoration(
            color: taskColor.withOpacity(0.3),
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListTile(
            title: GestureDetector(
              onTap: () {
                _show3DTaskCard(context, task);
              },
              child: Text(
                task.description,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    task.isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: task.isFavorite ? Colors.red : null,
                  ),
                  onPressed: () {
                    widget.onTaskUpdated(
                      task.copyWith(isFavorite: !task.isFavorite),
                    );
                  },
                ),
                Checkbox(
                  value: task.isCompleted,
                  onChanged: (value) async {
                    bool newValue = value ?? false;
                    widget.onTaskUpdated(task.copyWith(isCompleted: newValue));

                    final prefs = await SharedPreferences.getInstance();
                    final userId = FirebaseAuth.instance.currentUser?.uid;
                    if (userId == null) return;

                    if (newValue) {
                      // Lưu ngày hoàn thành
                      await prefs.setString(
                        'completed_date_${userId}_${task.id}',
                        DateTime.now().toIso8601String(),
                      );

                      // Tăng số lượng task hoàn thành hôm nay
                      int completedToday =
                          prefs.getInt('completed_today_count_$userId') ?? 0;
                      await prefs.setInt(
                        'completed_today_count_$userId',
                        completedToday + 1,
                      );

                      // Cập nhật thành tích
                      await AchievementUtils().updateAchievementsAfterAction(
                        "task_completed",
                      );

                      // Thêm XP khi hoàn thành task
                      try {
                        int xpEarned = _calculateXpForTask(task);
                        await ExperienceDatabaseService().addExperience(
                          userId,
                          xpEarned,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('+$xpEarned XP!'),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Lỗi cập nhật kinh nghiệm: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    } else {
                      // Xử lý khi bỏ chọn hoàn thành
                      await prefs.remove('completed_date_${userId}_${task.id}');
                      int completedToday =
                          prefs.getInt('completed_today_count_$userId') ?? 0;
                      if (completedToday > 0) {
                        await prefs.setInt(
                          'completed_today_count_$userId',
                          completedToday - 1,
                        );
                      }
                      try {
                        int xpLost = 5;
                        await ExperienceDatabaseService().addExperience(
                          userId,
                          -xpLost,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('-$xpLost XP!'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      } catch (e) {
                        print('Error reducing XP: $e');
                      }
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    widget.onTaskDeleted(task);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
