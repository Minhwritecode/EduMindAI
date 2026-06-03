import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../const.dart';

class AuthResult {
  final bool ok;
  final String? token;
  final String? userId;
  final String? error;

  AuthResult({required this.ok, this.token, this.userId, this.error});

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      ok: json['ok'] ?? false,
      token: json['token'],
      userId: json['userId'],
      error: json['error'],
    );
  }
}

class AuthService {
  static Uri _uri(String path) {
    final base = fastApiBaseUrl.endsWith('/') ? fastApiBaseUrl.substring(0, fastApiBaseUrl.length - 1) : fastApiBaseUrl;
    return Uri.parse('$base$path');
  }

  static Future<AuthResult> login(String username, String password) async {
    try {
      final res = await http.post(
        _uri('/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );
      final json = jsonDecode(res.body);
      final result = AuthResult.fromJson(json);
      if (result.ok && result.token != null && result.userId != null) {
        await _saveSession(result.token!, result.userId!);
      }
      return result;
    } catch (e) {
      return AuthResult(ok: false, error: e.toString());
    }
  }

  static Future<AuthResult> register(String username, String email, String password, String fieldOfInterest) async {
    try {
      final res = await http.post(
        _uri('/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
          'fieldOfInterest': fieldOfInterest,
        }),
      );
      final json = jsonDecode(res.body);
      final result = AuthResult.fromJson(json);
      if (result.ok && result.token != null && result.userId != null) {
        await _saveSession(result.token!, result.userId!);
      }
      return result;
    } catch (e) {
      return AuthResult(ok: false, error: e.toString());
    }
  }

  static Future<void> _saveSession(String token, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
    await prefs.setString('user_id', userId);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_id');
  }

  static Future<String?> getSavedUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }
}
