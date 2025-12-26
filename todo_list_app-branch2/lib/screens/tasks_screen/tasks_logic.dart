import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import '../../Models/Task.dart';
import 'package:file_picker/file_picker.dart';

class TaskExportImport {
  final Function(Task) onTaskAdded;
  final BuildContext context;

  TaskExportImport({
    required this.onTaskAdded,
    required this.context,
  });

  // Xuất ra CSV
  Future<File> exportToCsv(List<Task> tasks) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/tasks_export_${DateTime.now().millisecondsSinceEpoch}.csv');

    String csvContent = 'Id,UserId,Description,StartDate,EndDate,Completed,Favorite,Type\n';

    for (var task in tasks) {
      csvContent += '"${task.id}",'
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

  // Xuất ra JSON
  Future<File> exportToJson(List<Task> tasks) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/tasks_export_${DateTime.now().millisecondsSinceEpoch}.json');

    final tasksJson = tasks.map((task) => task.toMap()).toList();

    await file.writeAsString(jsonEncode(tasksJson));
    return file;
  }

  // Import từ file
  Future<void> importFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'json'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.single.path!);
      final content = await file.readAsString();

      List<Task> importedTasks = [];

      if (file.path.endsWith('.csv')) {
        importedTasks = _parseCsv(content);
      } else {
        importedTasks = _parseJson(content);
      }

      for (var task in importedTasks) {
        onTaskAdded(task);
      }

      _showSuccessMessage('Đã import ${importedTasks.length} task');
    } catch (e) {
      _showErrorMessage('Lỗi khi import: $e');
    }
  }

  List<Task> _parseCsv(String content) {
    final lines = content.split('\n');
    final tasks = <Task>[];

    for (int i = 1; i < lines.length; i++) {
      if (lines[i].trim().isEmpty) continue;

      final values = _parseCsvLine(lines[i]);
      if (values.length < 8) continue;

      tasks.add(Task(
        id: values[0],
        userId: values[1],
        description: values[2],
        startDate: DateTime.tryParse(values[3]) ?? DateTime.now(),
        endDate: DateTime.tryParse(values[4]) ?? DateTime.now(),
        isCompleted: values[5].toLowerCase() == 'true',
        isFavorite: values[6].toLowerCase() == 'true',
        type: values[7],
      ));
    }

    return tasks;
  }

  List<Task> _parseJson(String content) {
    final jsonList = jsonDecode(content) as List;
    return jsonList.map((json) => Task.fromMap(json)).toList();
  }

  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    var current = StringBuffer();
    var inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i < line.length - 1 && line[i + 1] == '"') {
          current.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        result.add(current.toString());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }

    result.add(current.toString());
    return result;
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
