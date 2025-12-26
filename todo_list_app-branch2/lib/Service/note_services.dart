import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/note.dart';

class NoteService {
  static Future<List<Note>> loadNotes() async {
    try {
      final jsonString = await rootBundle.loadString('assets/data/notes.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList.map((json) => Note.fromJson(json)).toList();
    } catch (e) {
      print('Lỗi load notes: $e');
      return [];
    }
  }

  // Save notes vào file local (nếu muốn persist sau khi restart app)
  static Future<void> saveNotes(List<Note> notes) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/notes.json');
    final jsonString = json.encode(notes.map((n) => n.toJson()).toList());
    await file.writeAsString(jsonString);
  }
}