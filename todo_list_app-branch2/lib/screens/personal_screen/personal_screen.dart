import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../db/db.dart';
import '../../Models/Task.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PersonalScreen extends StatefulWidget {
  const PersonalScreen({Key? key}) : super(key: key);

  @override
  State<PersonalScreen> createState() => _PersonalScreenState();
}

class _PersonalScreenState extends State<PersonalScreen> {
  final database = DatabaseService();
  int completedTasks = 0;
  int pendingTasks = 0;
  int completeToday = 0;

  Map<DateTime, int> completedTasksByDate = {};
  DateTime startDate = DateTime.now().subtract(const Duration(days: 15));
  List<Task> allTasks = []; // Lưu trữ danh sách tasks

  @override
  void initState() {
    super.initState();
    _loadTaskStats();
  }

  Future<void> _loadTaskStats() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    allTasks = await database.getTasks(); // Lưu danh sách tasks vào state
    Map<DateTime, int> taskCountMap = await database.getCompletedTasksByDate();

    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);

    int completed = 0;
    int pending = 0;

    // Lấy số lượng task hoàn thành hôm nay từ SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    int completedTodayCount =
        prefs.getInt('completed_today_count_$userId') ?? 0;

    // Kiểm tra và reset nếu là ngày mới
    final lastUpdatedDateString = prefs.getString('last_updated_date_$userId');
    if (lastUpdatedDateString != null) {
      final lastUpdatedDate = DateTime.parse(lastUpdatedDateString);
      if (lastUpdatedDate.year != today.year ||
          lastUpdatedDate.month != today.month ||
          lastUpdatedDate.day != today.day) {
        // Reset số lượng task hoàn thành hôm nay
        await prefs.setInt('completed_today_count_$userId', 0);
        completedTodayCount = 0;
      }
    }

    // Lưu ngày hiện tại vào SharedPreferences
    await prefs.setString('last_updated_date_$userId', today.toIso8601String());

    for (var task in allTasks) {
      if (task.userId == userId) {
        if (task.isCompleted) {
          completed++;
        } else {
          pending++;
        }
      }
    }

    if (mounted) {
      setState(() {
        completedTasks = completed;
        pendingTasks = pending;
        completeToday =
            completedTodayCount; // Sử dụng giá trị từ SharedPreferences
        completedTasksByDate = taskCountMap;
      });
    }
  }

  void _changeDateRange(int days) {
    setState(() {
      startDate = startDate.add(Duration(days: days));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Personal Statistics")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTaskCard("Tasks Pending", pendingTasks, Colors.orange),
                _buildTaskCard("Tasks Completed", completedTasks, Colors.green),
                _buildTaskCard("Completed Today", completeToday, Colors.blue),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: () => _changeDateRange(-15),
                  child: const Text("← Previous 15 Days"),
                ),
                ElevatedButton(
                  onPressed: () => _changeDateRange(15),
                  child: const Text("Next 15 Days →"),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: FutureBuilder(
                future:
                    _buildChartData(), // Sử dụng FutureBuilder để xử lý bất đồng bộ
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}"));
                  } else {
                    return _buildChart(
                      snapshot.data as List<BarChartGroupData>,
                    );
                  }
                },
              ),
            ), // Biểu đồ
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(String title, int count, Color color) {
    return Expanded(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "$count",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<BarChartGroupData>> _buildChartData() async {
    List<BarChartGroupData> barGroups = [];
    DateTime now = DateTime.now();
    DateTime firstDayOfMonth = DateTime(now.year, now.month, 1);
    DateTime lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

    DateTime adjustedStartDate =
        startDate.isBefore(firstDayOfMonth) ? firstDayOfMonth : startDate;

    List<DateTime> selectedDays = [];
    for (int i = 0; i < 15; i++) {
      DateTime day = adjustedStartDate.add(Duration(days: i));
      if (day.isAfter(lastDayOfMonth)) break;
      selectedDays.add(day);
    }

    double maxY = 5; // Giá trị tối thiểu
    final prefs = await SharedPreferences.getInstance();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return barGroups;

    for (var day in selectedDays) {
      int count = 0;

      // Đếm số lượng task hoàn thành trong ngày từ SharedPreferences
      final keys = prefs.getKeys();
      for (var key in keys) {
        if (key.startsWith('completed_date_${userId}_')) {
          final dateString = prefs.getString(key);
          if (dateString != null) {
            final completedDate = DateTime.parse(dateString);
            if (completedDate.year == day.year &&
                completedDate.month == day.month &&
                completedDate.day == day.day) {
              count++;
            }
          }
        }
      }

      maxY = count > maxY ? count.toDouble() : maxY;

      barGroups.add(
        BarChartGroupData(
          x: selectedDays.indexOf(day),
          barRods: [
            BarChartRodData(
              toY: count.toDouble(),
              color: Colors.blue,
              width: 12,
              borderRadius: BorderRadius.circular(6),
            ),
          ],
        ),
      );
    }

    return barGroups;
  }

  Widget _buildChart(List<BarChartGroupData> barGroups) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              barGroups.isNotEmpty
                  ? "Completed Tasks (${barGroups.first.x}-${barGroups.last.x})"
                  : "No Completed Tasks",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 20, // Giá trị tối đa của trục Y
                  barGroups: barGroups,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            "${value.toInt()}",
                            style: const TextStyle(fontSize: 12),
                          );
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
