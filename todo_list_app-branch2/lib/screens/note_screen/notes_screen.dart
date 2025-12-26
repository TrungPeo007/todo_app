import 'package:flutter/material.dart';
import '../models/note.dart';
import '../services/note_service.dart';
import 'note_detail_screen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<Note> _notes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final notes = await NoteService.loadNotes();
    setState(() {
      _notes = notes;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ghi chú'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Thêm search sau
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? const Center(child: Text('Chưa có ghi chú nào'))
              : ListView.builder(
                  itemCount: _notes.length,
                  itemBuilder: (context, index) {
                    final note = _notes[index];
                    return ListTile(
                      title: Text(note.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        note.content.substring(0, note.content.length > 50 ? 50 : note.content.length) + '...',
                        maxLines: 2,
                      ),
                      trailing: Text(
                        note.tags.join(', '),
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NoteDetailScreen(note: note),
                          ),
                        ).then((_) => _loadNotes()); // Reload khi quay lại
                      },
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const NoteDetailScreen(note: null), // null = tạo mới
            ),
          ).then((_) => _loadNotes());
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}