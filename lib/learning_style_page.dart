import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:smart_learning_application/const.dart';
import 'package:smart_learning_application/learning_style_result_page.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  _QuizScreenState createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentQuestionIndex = 0;
  bool _submitting = false;

  // Questions data
  final List<Map<String, dynamic>> _questions = [
    {
      'question': 'Do you find it easier to remember information when you see it written down or when you hear it spoken?',
      'options': ['Written down', 'Spoken'],
      'selectedOption': null, // Initially no option selected
    },
    {
      'question': 'When studying, do you prefer reading textbooks and articles, or do you prefer listening to lectures and discussions?',
      'options': ['Reading textbooks and articles', 'Listening to lectures and discussions'],
      'selectedOption': null,
    },
    {
      'question': 'Do you use diagrams, charts, and maps to help understand and remember information?',
      'options': ['Yes', 'No'],
      'selectedOption': null,
    },
    {
      'question': 'Do you find hands-on activities and experiments more helpful than reading or listening to learn new material?',
      'options': ['Yes', 'No'],
      'selectedOption': null,
    },
    {
      'question': 'Do you take detailed notes during lectures or while reading, and then review them later?',
      'options': ['Yes', 'No'],
      'selectedOption': null,
    },
    {
      'question': 'Do you often read your notes out loud or use recordings to study?',
      'options': ['Yes', 'No'],
      'selectedOption': null,
    },
    {
      'question': 'When working on group projects, do you prefer discussing and explaining ideas with your teammates or creating visual presentations?',
      'options': ['Discussing and explaining ideas', 'Creating visual presentations'],
      'selectedOption': null,
    },
    {
      'question': 'Do you prefer learning through real-world examples and practical applications rather than theoretical concepts?',
      'options': ['Yes', 'No'],
      'selectedOption': null,
    },
    {
      'question': 'Do you often use lists, definitions, and handouts to study?',
      'options': ['Yes', 'No'],
      'selectedOption': null,
    },
    {
      'question': 'Do you enjoy summarizing information in your own words to help solidify your understanding of a topic?',
      'options': ['Yes', 'No'],
      'selectedOption': null,
    },
  ];

  int _optionIndex(int questionIndex) {
    final v = _questions[questionIndex]['selectedOption'];
    if (v is int) return v.clamp(0, 1);
    return 0;
  }

  /// Gộp 10 câu hỏi thành 5 đặc trưng số (1–5) khớp cột `learning_styles.csv` / Flask.
  Map<String, int> _payloadForModel() {
    int pair(int a, int b) => (1 + (_optionIndex(a) + _optionIndex(b)) * 2).clamp(1, 5);
    return {
      'Question1': pair(0, 1),
      'Question2': pair(2, 3),
      'Question3': pair(4, 5),
      'Question4': pair(6, 7),
      'Question5': pair(8, 9),
    };
  }

  Future<void> _submitQuiz() async {
    for (var i = 0; i < _questions.length; i++) {
      if (_questions[i]['selectedOption'] == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hãy chọn đáp án cho đủ 10 câu (dùng Next để xem lại).')),
        );
        return;
      }
    }
    setState(() => _submitting = true);
    try {
      final base = apiBaseUrl.endsWith('/') ? apiBaseUrl.substring(0, apiBaseUrl.length - 1) : apiBaseUrl;
      final uri = Uri.parse('$base/predictLearningStyle');
      final res = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(_payloadForModel()),
          )
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (res.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server ${res.statusCode}: ${res.body}')),
        );
        return;
      }
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final style = map['learningStyle']?.toString() ?? 'Unknown';
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (context) => LearningStyleResultPage(selectedStyle: style),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không gọi được Flask tại $apiBaseUrl. Chạy `python app.py` và kiểm tra --dart-define=API_BASE_URL=... ($e)',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _onPrimaryPressed() {
    if (_submitting) return;
    if (_questions[_currentQuestionIndex]['selectedOption'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chọn một đáp án trước khi tiếp tục.')),
      );
      return;
    }
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() => _currentQuestionIndex++);
    } else {
      _submitQuiz();
    }
  }

  void _handleOptionSelected(int questionIndex, int selectedOptionIndex) {
    setState(() {
      _questions[questionIndex]['selectedOption'] = selectedOptionIndex;
    });
  }

  List<Widget> _buildOptions(int questionIndex) {
    List<Widget> optionWidgets = [];
    List<String> options = _questions[questionIndex]['options'] as List<String>;
    for (int i = 0; i < options.length; i++) {
      optionWidgets.add(
        RadioListTile<int>(
          title: Text(options[i]),
          value: i,
          groupValue: _questions[questionIndex]['selectedOption'] as int?,
          onChanged: (value) {
            if (value == null) return;
            _handleOptionSelected(questionIndex, value);
          },
        ),
      );
    }
    return optionWidgets;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: NetworkImage('https://i.pinimg.com/736x/ee/e1/d4/eee1d4114e36fa5f1dc7358c60f4b290.jpg'), // Replace with your network image URL
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Custom heading
                const Text(
                  "Let's find your learning style!",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF002131)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Question card with options
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15.0),
                  ),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _questions[_currentQuestionIndex]['question'],
                          style: const TextStyle(fontSize: 18),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),

                        // Options
                        Column(
                          children: _buildOptions(_currentQuestionIndex),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Next or Submit button
                ElevatedButton(
                  onPressed: _submitting ? null : _onPrimaryPressed,
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color>(
                          (Set<WidgetState> states) {
                        // Set button color based on state
                        if (states.contains(WidgetState.disabled)) {
                          return Colors.grey; // Disabled color
                        } else {
                          return const Color(0xFF48A9A6); // Enabled color
                        }
                      },
                    ),
                  ),
                  child: Text(
                    _submitting
                        ? 'Đang gửi…'
                        : (_currentQuestionIndex < _questions.length - 1 ? 'Next' : 'Submit'),
                    style: const TextStyle(color: Colors.white), // Text color
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
