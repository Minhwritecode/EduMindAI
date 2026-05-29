import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:provider/provider.dart';
import 'package:smart_learning_application/const.dart'
    show defaultUserId, effectiveGeminiApiKey, geminiApiKeyFromDotenv;
import 'package:smart_learning_application/splash_screen.dart';
import 'learning_style_page.dart';
import 'login_page.dart';
import 'signup_page.dart';
import 'state/notebook_context_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  geminiApiKeyFromDotenv = dotenv.env['GEMINI_API_KEY'] ?? '';
  final apiKey = effectiveGeminiApiKey;
  if (apiKey.isNotEmpty) {
    Gemini.init(apiKey: apiKey);
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
      theme: ThemeData(
        primarySwatch: Colors.blue,

      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,// Set LoginPage as the initial page
      routes: {
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/learning-style': (context) => const QuizScreen(),
      },
    );
  }
}
