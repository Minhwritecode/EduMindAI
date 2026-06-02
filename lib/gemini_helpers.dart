import 'dart:async';

import 'package:flutter_gemini/flutter_gemini.dart';

import 'const.dart';

/// Vietnamese message for Gemini API / stream errors (429, 403, 404, …).
String geminiUserMessage(Object e) {
  final code = _geminiStatusCode(e);
  switch (code) {
    case 429:
      return 'Đã vượt giới hạn gọi API (429). Đợi vài phút rồi thử lại; kiểm tra hạn mức tại Google AI Studio và bật thanh toán nếu cần.';
    case 403:
      return 'Không có quyền truy cập API (403). Kiểm tra GEMINI_API_KEY trong .env và quyền khóa tại Google AI Studio.';
    case 404:
      return 'Không tìm thấy mô hình AI (404). Kiểm tra tên model trong cấu hình ứng dụng.';
  }
  if (e is StateError) return e.message;
  if (e is TimeoutException) {
    return 'Yêu cầu AI quá thời gian chờ. Vui lòng thử lại.';
  }
  if (e is GeminiException) {
    return 'Lỗi Gemini: ${e.message}';
  }
  return 'Không thể kết nối AI. Vui lòng thử lại sau.';
}

int? _geminiStatusCode(Object e) {
  if (e is! GeminiException) return null;
  final sc = e.statusCode;
  if (sc != null && sc > 0) return sc;
  final m = e.message.toString();
  final http = RegExp(r'HTTP\s*(\d{3})').firstMatch(m);
  if (http != null) return int.tryParse(http.group(1)!);
  for (final c in [429, 403, 404]) {
    if (m.contains('$c')) return c;
  }
  return null;
}

/// Collects streamed Gemini output into a single string.
Future<String> geminiCompleteText(String prompt) async {
  if (effectiveGeminiApiKey.isEmpty) {
    throw StateError(
      'Thiếu GEMINI_API_KEY. Thêm vào file .env (cp .env.example .env) hoặc chạy: flutter run --dart-define=GEMINI_API_KEY=...',
    );
  }
  final gemini = Gemini.instance;
  final buffer = StringBuffer();
  final completer = Completer<String>();
  StreamSubscription<dynamic>? sub;
  sub = gemini
      .streamGenerateContent(
        prompt,
        modelName: geminiGenerationModel,
      )
      .listen(
    (event) {
      final parts = event.content?.parts;
      if (parts == null) return;
      for (final p in parts) {
        final t = p.text;
        if (t != null && t.isNotEmpty) buffer.write(t);
      }
    },
    onDone: () {
      sub?.cancel();
      if (!completer.isCompleted) completer.complete(buffer.toString());
    },
    onError: (Object e, StackTrace st) {
      if (!completer.isCompleted) {
        completer.completeError(StateError(geminiUserMessage(e)), st);
      }
    },
    cancelOnError: true,
  );
  return completer.future.timeout(
    const Duration(minutes: 2),
    onTimeout: () {
      sub?.cancel();
      if (buffer.isEmpty) throw TimeoutException('Gemini stream timed out');
      return buffer.toString();
    },
  );
}
