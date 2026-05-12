import 'package:flutter/foundation.dart';

/// Shared "NotebookLM-style" sources / notes used across tools and AI prompts.
class NotebookContextState extends ChangeNotifier {
  String _notebookText = '';
  String userId = 'local';

  String get notebookText => _notebookText;

  void setNotebookText(String value) {
    if (_notebookText == value) return;
    _notebookText = value;
    notifyListeners();
  }

  void setUserId(String id) {
    if (userId == id) return;
    userId = id;
    notifyListeners();
  }
}
