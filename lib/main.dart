import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:smart_learning_application/const.dart' show defaultUserId;
import 'package:smart_learning_application/splash_screen.dart';
import 'learning_style_page.dart';
import 'login_page.dart';
import 'signup_page.dart';
import 'state/notebook_context_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await dotenv.load(fileName: ".env");
    final geminiApiKey = dotenv.env['GEMINI_API_KEY'];
    if (geminiApiKey != null && geminiApiKey.isNotEmpty) {
      Gemini.init(apiKey: geminiApiKey);
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
