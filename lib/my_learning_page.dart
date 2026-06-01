import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'notebook_detail_page.dart';
import 'services/notebook_mongo_sync.dart';
import 'state/notebook_context_state.dart';

class MyLearningPage extends StatefulWidget {
  const MyLearningPage({super.key});

  @override
  State<MyLearningPage> createState() => _MyLearningPageState();
}

class _MyLearningPageState extends State<MyLearningPage> {
  bool _isLoading = false;
  List<Notebook> _notebooks = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchNotebooks();
  }

  Future<void> _fetchNotebooks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    final userId = context.read<NotebookContextState>().userId;
    final (notebooks, error) = await NotebookMongoSync.fetchNotebooks(userId);
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (error != null) {
          _error = error;
        } else {
          _notebooks = notebooks ?? [];
        }
      });
    }
  }

  void _createNewNotebook() {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create New Notebook'),
          content: TextField(
            controller: titleController,
            decoration: const InputDecoration(hintText: 'Notebook Title'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF48A9A6)),
              onPressed: () {
                final title = titleController.text.trim().isEmpty ? 'Untitled Notebook' : titleController.text.trim();
                Navigator.pop(context);
                
                final newNotebook = Notebook(id: '', title: title, text: '');
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => NotebookDetailPage(notebook: newNotebook)),
                ).then((_) => _fetchNotebooks());
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  void _deleteNotebook(Notebook notebook) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notebook?'),
        content: Text('Are you sure you want to delete "${notebook.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final userId = context.read<NotebookContextState>().userId;
    final err = await NotebookMongoSync.deleteNotebook(userId, notebook.id);
    if (!mounted) return;
    
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $err')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notebook deleted')));
      _fetchNotebooks();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131314),
      body: RefreshIndicator(
        onRefresh: _fetchNotebooks,
        child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF48A9A6)))
            : _error != null 
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Error loading notebooks: $_error', style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF48A9A6)),
                          onPressed: _fetchNotebooks, 
                          child: const Text('Retry', style: TextStyle(color: Colors.white)),
                        )
                      ],
                    ),
                  )
                : _notebooks.isEmpty
                    ? const Center(
                        child: Text(
                          'No notebooks yet. Tap + to create one.',
                          style: TextStyle(color: Colors.white38, fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _notebooks.length,
                        itemBuilder: (context, index) {
                          final nb = _notebooks[index];
                          return Card(
                            elevation: 0,
                            color: const Color(0xFF1E1F22),
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Colors.white10),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF48A9A6).withOpacity(0.1),
                                child: const Icon(Icons.menu_book, color: Color(0xFF48A9A6)),
                              ),
                              title: Text(nb.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFE3E3E3))),
                              subtitle: Text(
                                nb.text.isEmpty ? 'Empty notebook' : nb.text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white60),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _deleteNotebook(nb),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => NotebookDetailPage(notebook: nb)),
                                ).then((_) => _fetchNotebooks());
                              },
                            ),
                          );
                        },
                      ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewNotebook,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Notebook', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF48A9A6),
      ),
    );
  }
}
