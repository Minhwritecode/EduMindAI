import 'dart:convert';

import 'package:http/http.dart' as http;

import '../const.dart';

/// Sync notebook text with Flask + MongoDB (`/api/notebook-context`).
class NotebookMongoSync {
  static Uri _uri(String path, [Map<String, String>? query]) {
    final base = apiBaseUrl.endsWith('/') ? apiBaseUrl.substring(0, apiBaseUrl.length - 1) : apiBaseUrl;
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  static Future<String?> pushContext(String userId, String text) async {
    try {
      final res = await http.post(
        _uri('/api/notebook-context'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId, 'text': text}),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) return null;
      return 'HTTP ${res.statusCode}: ${res.body}';
    } catch (e) {
      return e.toString();
    }
  }

  static Future<(String?, String?)> fetchContext(String userId) async {
    try {
      final res = await http.get(_uri('/api/notebook-context', {'userId': userId}));
      if (res.statusCode != 200) return (null, 'HTTP ${res.statusCode}: ${res.body}');
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final text = map['text'] as String? ?? '';
      return (text, null);
    } catch (e) {
      return (null, e.toString());
    }
  }
}
