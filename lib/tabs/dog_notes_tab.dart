import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/app_user.dart';

class DogNotesTab extends StatefulWidget {
  final String dogId;

  const DogNotesTab({
    super.key,
    required this.dogId,
  });

  @override
  State<DogNotesTab> createState() => _DogNotesTabState();
}

class _DogNotesTabState extends State<DogNotesTab> {
  final supabase = Supabase.instance.client;

  List<dynamic> notes = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadNotes();
  }

  Future<void> loadNotes() async {
    setState(() => loading = true);

    final data = await supabase
        .from('dog_notes')
        .select()
        .eq('dog_id', widget.dogId)
        .order('is_pinned', ascending: false)
        .order('created_at', ascending: false);   // ✅ FIXED missing ;

    setState(() {
      notes = data;
      loading = false;
    });
  }

  Future<void> addNote(String title, String text) async {
    await supabase.from('dog_notes').insert({
      'dog_id': widget.dogId,
      'note_title': title,
      'note_text': text,
      'created_by': AppUser.name,
    });

    loadNotes();
  }

  Future<void> updateNote(String id, String title, String text) async {
    await supabase.from('dog_notes').update({
      'note_title': title,
      'note_text': text,
      'updated_by': AppUser.name,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);

    loadNotes();
  }

  Future<void> deleteNote(String id) async {
    await supabase.from('dog_notes').delete().eq('id', id);
    loadNotes();
  }

  Future<void> togglePin(Map note) async {
    final newValue = !(note['is_pinned'] ?? false);

    await supabase
        .from('dog_notes')
        .update({'is_pinned': newValue})
        .eq('id', note['id']);

    loadNotes();
  }

  void openNoteEditor({Map? note}) {
    final titleController =
        TextEditingController(text: note?['note_title'] ?? '');

    final textController =
        TextEditingController(text: note?['note_text'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                note == null ? 'Add Note' : 'Edit Note',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),

              const SizedBox(height: 10),

              TextField(
                controller: textController,
                maxLines: 6,
                decoration: const InputDecoration(labelText: 'Note'),
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: () async {
                  if (note == null) {
                    await addNote(
                      titleController.text,
                      textController.text,
                    );
                  } else {
                    await updateNote(
                      note['id'],
                      titleController.text,
                      textController.text,
                    );
                  }

                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Save'),
              ),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Note"),
        content: const Text("Are you sure you want to delete this note?"),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text("Delete"),
            onPressed: () async {
              Navigator.pop(context);
              await deleteNote(id);
            },
          ),
        ],
      ),
    );
  }

  Future<void> printNotes() async {
    DateTimeRange? range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
    );

    if (range == null) return;

    final results = await supabase
        .from('dog_notes')
        .select()
        .eq('dog_id', widget.dogId)
        .gte('created_at', range.start.toIso8601String())
        .lte('created_at', range.end.toIso8601String())
        .order('created_at');

    final buffer = StringBuffer();

    for (var note in results) {
      final date =
          DateFormat('yyyy-MM-dd').format(DateTime.parse(note['created_at']));

      buffer.writeln("$date - ${note['note_title']}");
      buffer.writeln(note['note_text']);
      buffer.writeln("");
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Printable Notes"),
        content: SingleChildScrollView(
          child: Text(buffer.toString()),
        ),
        actions: [
          TextButton(
            child: const Text("Close"),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
    );
  }

  Widget buildNoteCard(Map note) {
    final created =
        DateFormat('yyyy-MM-dd').format(DateTime.parse(note['created_at']));

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      child: ListTile(
        title: Row(
          children: [
            if (note['is_pinned'] == true)
              const Icon(Icons.push_pin, size: 16),

            const SizedBox(width: 6),

            Expanded(
              child: Text(
                note['note_title'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),

        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),

            Text(
              note['note_text'] ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 6),

            Text(
              "By ${note['created_by'] ?? ''} • $created",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),

        onTap: () => openNoteEditor(note: note),

        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [

            IconButton(
              icon: Icon(
                note['is_pinned'] == true
                    ? Icons.push_pin
                    : Icons.push_pin_outlined,
              ),
              onPressed: () => togglePin(note),
            ),

            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => confirmDelete(note['id']),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: notes.isEmpty
          ? const Center(child: Text("No notes yet"))
          : RefreshIndicator(
              onRefresh: loadNotes,
              child: ListView.builder(
                itemCount: notes.length,
                itemBuilder: (context, index) {
                  return buildNoteCard(notes[index]);
                },
              ),
            ),

      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          FloatingActionButton(
            heroTag: "print_notes",
            mini: true,
            onPressed: printNotes,
            child: const Icon(Icons.print),
          ),

          const SizedBox(height: 10),

          FloatingActionButton(
            heroTag: "add_note",
            onPressed: () => openNoteEditor(),
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}