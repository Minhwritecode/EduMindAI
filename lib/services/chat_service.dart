import 'dart:convert';
import 'package:http/http.dart' as http;
import '../const.dart';

class ChatMessageItem {
  final String sender;
  final String messageText;
  final String? timestamp;

  ChatMessageItem({
    required this.sender,
    required this.messageText,
    this.timestamp,
  });

  factory ChatMessageItem.fromJson(Map<String, dynamic> json) {
    return ChatMessageItem(
      sender: json['sender'] ?? '',
      messageText: json['message_text'] ?? '',
      timestamp: json['timestamp'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sender': sender,
      'message_text': messageText,
      'timestamp': timestamp,
    };
  }
}

class ChatService {
  static Uri _uri(String path, [Map<String, String>? query]) {
    final base = apiBaseUrl.endsWith('/') ? apiBaseUrl.substring(0, apiBaseUrl.length - 1) : apiBaseUrl;
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  static Future<(List<ChatMessageItem>?, String?)> fetchChatHistory(String notebookId) async {
    try {
      final res = await http.get(_uri('/api/notebooks/$notebookId/chat'));
      if (res.statusCode != 200) return (null, 'HTTP ${res.statusCode}: ${res.body}');
      
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final list = map['messages'] as List? ?? [];
      
      List<ChatMessageItem> messages = list.map((i) => ChatMessageItem.fromJson(i)).toList();
      return (messages, null);
    } catch (e) {
      return (null, e.toString());
    }
  }

  static Future<(String?, String?)> sendChatMessage({
    required String notebookId,
    required String userId,
    required String messageText,
  }) async {
    try {
      final res = await http.post(
        _uri('/api/notebooks/$notebookId/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'message_text': messageText,
        }),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final map = jsonDecode(res.body) as Map<String, dynamic>;
        return (map['ai_response'] as String?, null);
      }
      return (null, 'HTTP ${res.statusCode}: ${res.body}');
    } catch (e) {
      return (null, e.toString());
    }
  }
}
