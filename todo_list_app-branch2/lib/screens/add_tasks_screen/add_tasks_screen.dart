import 'package:flutter/material.dart';
import '../../Models/Task.dart'; // Import your Task model
import '../../db/db.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddTaskScreen extends StatefulWidget {
  final Function(Task) onTaskAdded;

  const AddTaskScreen({Key? key, required this.onTaskAdded}) : super(key: key);

  @override
  _AddTaskScreenState createState() => _AddTaskScreenState();
}

// Khởi tạo Database tại đây
final databaseService = DatabaseService();

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));

  String _selectedType = 'General'; // Mặc định loại công việc

  final Map<String, Color> _taskTypeColors = {
    'General': Colors.grey,
    'Work': Colors.blue,
    'Personal': Colors.green,
    'Urgent': Colors.red,
  };

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      String? uid = FirebaseAuth.instance.currentUser?.uid; // Lấy userId
      if (uid == null) return; // Nếu chưa đăng nhập, không thêm task

      // Create a new task
      Task newTask = Task(
        description: _descriptionController.text,
        startDate: _startDate,
        endDate: _endDate,
        isCompleted: false,
        isFavorite: false,
        type: _selectedType,
        userId: uid, // Thêm userId
      );

      // Add task vào Cơ sở dữ liệu
      await databaseService.addTask(newTask);

      // Debugging
      List<Task> tasks = await databaseService.getTasks();
      print('Added task: ${newTask.description}, Type: ${newTask.type}');
      print('Total tasks: ${tasks.length}');

      // Notify the parent widget (MainApp) about the new task
      widget.onTaskAdded(newTask);

      // Close the form screen
      Navigator.pop(context);
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(days: 1));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Task')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Start Date'),
                subtitle: Text('${_startDate.toLocal()}'),
                onTap: () => _selectDate(context, true),
              ),
              ListTile(
                title: const Text('End Date'),
                subtitle: Text('${_endDate.toLocal()}'),
                onTap: () => _selectDate(context, false),
              ),
              const SizedBox(height: 16),

              // ChoiceChip chọn loại công việc
              const Text(
                'Task Type',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Wrap(
                spacing: 8.0,
                children:
                    _taskTypeColors.keys.map((type) {
                      return ChoiceChip(
                        label: Text(
                          type,
                          style: TextStyle(color: Colors.white),
                        ),
                        selected: _selectedType == type,
                        selectedColor:
                            _taskTypeColors[type], // Màu sắc khi được chọn
                        backgroundColor: _taskTypeColors[type]!.withOpacity(
                          0.5,
                        ), // Màu nền mờ
                        onSelected: (selected) {
                          setState(() {
                            _selectedType = type;
                          });
                        },
                      );
                    }).toList(),
              ),

              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _submitForm,
                child: const Text('Add Task'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
