import 'dart:async';

class Notebook {
  final String id;
  final String title;
  final String text;

  Notebook({required this.id, required this.title, required this.text});

  factory Notebook.fromJson(Map<String, dynamic> json) {
    return Notebook(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Untitled Notebook',
      text: json['text'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'text': text,
    };
  }
}

/// A mocked version of NotebookMongoSync for demo purposes without a backend.
class NotebookMongoSync {
  // In-memory static list to persist data while the app is running
  static final List<Notebook> _demoNotebooks = [
    Notebook(
      id: 'demo_1', 
      title: 'Welcome Notebook', 
      text: 'This is a demo notebook! You can edit this text, save it, and then switch to the AI Chat tab to ask questions about it. \n\nSince the backend is not connected, this data is saved in memory and will reset if you fully restart the app.'
    )
  ];

  static Future<(List<Notebook>?, String?)> fetchNotebooks(String userId) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    // Return a copy of the list
    return (_demoNotebooks.toList(), null);
  }

  static Future<(String?, String?)> saveNotebook({
    required String userId, 
    required String id, 
    required String title, 
    required String text
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (id.isEmpty) {
      // Create a new notebook
      final newId = DateTime.now().millisecondsSinceEpoch.toString();
      _demoNotebooks.add(Notebook(id: newId, title: title, text: text));
      return (newId, null);
    } else {
      // Update an existing notebook
      final index = _demoNotebooks.indexWhere((n) => n.id == id);
      if (index >= 0) {
        _demoNotebooks[index] = Notebook(id: id, title: title, text: text);
        return (id, null);
      } else {
        // If it was somehow deleted but they try to save, just add it back
        _demoNotebooks.add(Notebook(id: id, title: title, text: text));
        return (id, null);
      }
    }
  }

  static Future<String?> deleteNotebook(String userId, String notebookId) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    _demoNotebooks.removeWhere((n) => n.id == notebookId);
    return null;
  }
}
