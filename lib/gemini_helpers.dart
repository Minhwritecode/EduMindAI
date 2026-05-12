import 'dart:async';

import 'package:flutter_gemini/flutter_gemini.dart';

import 'const.dart';

/// Collects streamed Gemini output into a single string.
Future<String> geminiCompleteText(String prompt) async {
  if (geminiApiKeyIfConfigured.isEmpty) {
    throw StateError(
      'Thiếu GEMINI_API_KEY. Chạy: flutter run --dart-define=GEMINI_API_KEY=...',
    );
  }
  final gemini = Gemini.instance;
  final buffer = StringBuffer();
  final completer = Completer<String>();
  StreamSubscription<dynamic>? sub;
  sub = gemini.streamGenerateContent(prompt).listen(
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
      if (!completer.isCompleted) completer.completeError(e, st);
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
