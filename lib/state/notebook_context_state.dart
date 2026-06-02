import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';

/// Shared "NotebookLM-style" sources / notes used across tools and AI prompts.
class NotebookContextState extends ChangeNotifier {
  String _notebookText = '';
  String userId = 'local';
  String _userName = 'Tien Minh';
  String _learningStyle = 'Visual';
  bool _isDarkMode = false;

  String get notebookText => _notebookText;
  String get userName => _userName;
  String get learningStyle => _learningStyle;
  bool get isDarkMode => _isDarkMode;

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

  void setLearningStyle(String value) {
    if (_learningStyle == value) return;
    _learningStyle = value;
    notifyListeners();
  }

  void setUserName(String value) {
    if (_userName == value) return;
    _userName = value;
    notifyListeners();
  }

  void toggleDarkMode() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  void clearUserData() {
    _notebookText = '';
    userId = 'local';
    _userName = '';
    _learningStyle = 'Visual';
    _isDarkMode = false;
    notifyListeners();
  }
}

