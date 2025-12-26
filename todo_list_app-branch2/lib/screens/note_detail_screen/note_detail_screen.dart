import 'package:flutter/material.dart';
import '../models/note.dart';
import '../services/note_service.dart';
import 'dart:math';

class NoteDetailScreen extends StatefulWidget {
  final Note? note;

  const NoteDetailScreen({super.key, this.note});

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _titleController.text = widget.note!.title;
      _contentController.text = widget.note!.content;
      _tags = widget.note!.tags;
    }
  }

  Future<void> _saveNote() async {
    final now = DateTime.now();
    final newNote = Note(
      id: widget.note?.id ?? Random().nextInt(1000000).toString(),
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      createdAt: widget.note?.createdAt ?? now,
      updatedAt: now,
      tags: _tags,
    );

    // Load all notes hiện tại
    List<Note> allNotes = await NoteService.loadNotes();
    if (widget.note != null) {
      // Update
      allNotes = allNotes.map((n) => n.id == newNote.id ? newNote : n).toList();
    } else {
      // Add new
      allNotes.add(newNote);
    }

    await NoteService.saveNotes(allNotes);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? 'Ghi chú mới' : 'Chỉnh sửa'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveNote,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Tiêu đề', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: 'Nội dung',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: null,
                keyboardType: TextInputType.multiline,
              ),
            ),
            const SizedBox(height: 16),
            // Tags (có thể dùng chip hoặc text field)
            Wrap(
              spacing: 8,
              children: _tags.map((tag) => Chip(label: Text(tag))).toList(),
            ),
          ],
        ),
      ),
    );
  }
}