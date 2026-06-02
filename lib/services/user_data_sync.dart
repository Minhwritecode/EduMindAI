import 'dart:convert';

import 'package:http/http.dart' as http;

import '../const.dart';

/// User profile, VARK quiz results, and task list via Flask + MongoDB.
class UserDataSync {
  static Uri _uri(String path, [Map<String, String>? query]) {
    final base = apiBaseUrl.endsWith('/') ? apiBaseUrl.substring(0, apiBaseUrl.length - 1) : apiBaseUrl;
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  /// POST upsert profile. Optional [password] is hashed on server only.
  static Future<String?> pushUserProfile({
    required String userId,
    String? displayName,
    String? email,
    String? password,
  }) async {
    try {
      final body = <String, dynamic>{'userId': userId};
      if (displayName != null) body['displayName'] = displayName;
      if (email != null) body['email'] = email;
      if (password != null && password.isNotEmpty) body['password'] = password;
      final res = await http.post(
        _uri('/api/user-profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) return null;
      return 'HTTP ${res.statusCode}: ${res.body}';
    } catch (e) {
      return e.toString();
    }
  }

  /// GET profile (no password fields).
  static Future<(Map<String, dynamic>?, String?)> fetchUserProfile(String userId) async {
    try {
      final res = await http.get(_uri('/api/user-profile', {'userId': userId}));
      if (res.statusCode != 200) return (null, 'HTTP ${res.statusCode}: ${res.body}');
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      return (map, null);
    } catch (e) {
      return (null, e.toString());
    }
  }

  static Future<String?> postQuizResult({
    required String userId,
    String quizType = 'vark',
    required String learningStyle,
    Map<String, dynamic>? payload,
  }) async {
    try {
      final body = <String, dynamic>{
        'userId': userId,
        'quizType': quizType,
        'learningStyle': learningStyle,
      };
      if (payload != null) body['payload'] = payload;
      final res = await http.post(
        _uri('/api/quiz-results'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) return null;
      return 'HTTP ${res.statusCode}: ${res.body}';
    } catch (e) {
      return e.toString();
    }
  }

  static Future<(List<String>?, String?)> fetchTasks(String userId) async {
    try {
      final res = await http.get(_uri('/api/tasks', {'userId': userId}));
      if (res.statusCode != 200) return (null, 'HTTP ${res.statusCode}: ${res.body}');
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final raw = map['tasks'];
      if (raw is! List) return (<String>[], null);
      return (raw.map((e) => e.toString()).toList(), null);
    } catch (e) {
      return (null, e.toString());
    }
  }

  static Future<String?> pushTasks(String userId, List<String> tasks) async {
    try {
      final res = await http.post(
        _uri('/api/tasks'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId, 'tasks': tasks}),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) return null;
      return 'HTTP ${res.statusCode}: ${res.body}';
    } catch (e) {
      return e.toString();
    }
  }

  static Future<(List<Map<String, dynamic>>?, String?)> fetchRecommendations(String userId) async {
    try {
      final res = await http.get(_uri('/api/recommendations', {'userId': userId}));
      if (res.statusCode != 200) return (null, 'HTTP ${res.statusCode}: ${res.body}');
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final recs = map['recommendations'];
      if (recs is! List) return (<Map<String, dynamic>>[], null);
      final list = recs.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      return (list, null);
    } catch (e) {
      return (null, e.toString());
    }
  }

  static Future<(String?, String?)> fetchLatestQuizResult(String userId, [String quizType = 'vark']) async {
    try {
      final res = await http.get(_uri('/api/quiz-results', {'userId': userId, 'quizType': quizType, 'limit': '1'}));
      if (res.statusCode != 200) return (null, 'HTTP ${res.statusCode}: ${res.body}');
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final results = map['results'];
      if (results is List && results.isNotEmpty) {
        final style = results[0]['learningStyle']?.toString();
        return (style, null);
      }
      return (null, null);
    } catch (e) {
      return (null, e.toString());
    }
  }
}
