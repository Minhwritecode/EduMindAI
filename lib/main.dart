import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:provider/provider.dart';
import 'package:smart_learning_application/const.dart' show defaultUserId, effectiveGeminiApiKey, geminiApiKeyFromDotenv;
import 'package:smart_learning_application/splash_screen.dart';
import 'learning_style_page.dart';
import 'login_page.dart';
import 'signup_page.dart';
import 'state/notebook_context_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await dotenv.load(fileName: ".env");
    geminiApiKeyFromDotenv = dotenv.env['GEMINI_API_KEY'] ?? '';
    final apiKey = effectiveGeminiApiKey;
    if (apiKey.isNotEmpty) {
      Gemini.init(apiKey: apiKey);
    }
  } catch (e) {
    print('Error loading .env file: $e');
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => NotebookContextState()..userId = defaultUserId,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PMDEduMind',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF131314),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF48A9A6),
          secondary: Color(0xFFFF8C42),
          surface: Color(0xFF1E1F22),
          onSurface: Color(0xFFE3E3E3),
        ),
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
      routes: {
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/learning-style': (context) => const QuizScreen(),
      },
    );
  }
}
