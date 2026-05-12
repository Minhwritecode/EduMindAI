import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:provider/provider.dart';
import 'package:smart_learning_application/const.dart' show defaultUserId, geminiApiKeyIfConfigured;
import 'package:smart_learning_application/splash_screen.dart';
import 'learning_style_page.dart';
import 'login_page.dart';
import 'signup_page.dart';
import 'state/notebook_context_state.dart';

void main() {
  if (geminiApiKeyIfConfigured.isNotEmpty) {
    Gemini.init(apiKey: geminiApiKeyIfConfigured);
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
      home: SplashScreen(),
      debugShowCheckedModeBanner: false,// Set LoginPage as the initial page
      routes: {
        '/login': (context) => LoginPage(),
        '/signup': (context) => SignUpPage(),
        '/learning-style': (context) => QuizScreen(),// Ensure this points to your signup page
      },
    );
  }
}
