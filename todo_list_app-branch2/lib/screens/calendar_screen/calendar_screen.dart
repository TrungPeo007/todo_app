import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../db/db.dart';
import '../../Models/Task.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({Key? key}) : super(key: key);

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

final database = DatabaseService();

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Task>> _tasksByDate = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTasks();
    });
  }

  Future<void> _loadTasks() async {
    List<Task> allTasks = await database.getTasks();
    print("All Tasks: $allTasks");

    Map<DateTime, List<Task>> taskMap = {};
    for (var task in allTasks) {
      DateTime currentDate = DateTime(
        task.startDate.year,
        task.startDate.month,
        task.startDate.day,
      );
      DateTime endDate = DateTime(
        task.endDate.year,
        task.endDate.month,
        task.endDate.day,
      );

      while (!currentDate.isAfter(endDate)) {
        if (taskMap.containsKey(currentDate)) {
          taskMap[currentDate]!.add(task);
        } else {
          taskMap[currentDate] = [task];
        }
        // Cộng thêm 1 ngày
        currentDate = currentDate.add(const Duration(days: 1));
      }
    }

    print("Tasks by Date: $taskMap");

    if (mounted) {
      setState(() {
        _tasksByDate = taskMap;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Task> selectedTasks =
        _selectedDay != null
            ? (_tasksByDate[DateTime(
                      _selectedDay!.year,
                      _selectedDay!.month,
                      _selectedDay!.day,
                    )] ??
                    [])
                .where(
                  (task) => !task.isCompleted,
                ) 
                .toList()
            : [];

    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: Column(
        children: [
          TableCalendar(
            focusedDay: _focusedDay,
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2100, 12, 31),
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            eventLoader: (day) {
              return (_tasksByDate[DateTime(day.year, day.month, day.day)] ??
                      [])
                  .where(
                    (task) => !task.isCompleted,
                  ) // 🔥 Chỉ lấy task chưa hoàn thành
                  .toList();
            },
          ),

          const SizedBox(height: 10),
          Expanded(
            child:
                selectedTasks.isNotEmpty
                    ? ListView.builder(
                      itemCount: selectedTasks.length,
                      itemBuilder: (context, index) {
                        Task task = selectedTasks[index];

                        // Màu sắc cho từng loại Task
                        final Map<String, Color> taskTypeColors = {
                          'General': Colors.grey,
                          'Work': Colors.blue,
                          'Personal': Colors.green,
                          'Urgent': Colors.red,
                        };

                        final taskColor =
                            taskTypeColors[task.type] ?? Colors.grey;

                        return Container(
                          margin: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 8,
                          ),
                          decoration: BoxDecoration(
                            color: taskColor.withOpacity(
                              0.3,
                            ), // Màu nền nhẹ hơn
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            title: Text(
                              task.description,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    )
                    : const Center(child: Text("No tasks for selected day")),
          ),
        ],
      ),
    );
  }
}
