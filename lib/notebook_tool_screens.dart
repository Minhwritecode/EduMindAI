import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'gemini_helpers.dart';
import 'services/file_saver.dart';
import 'state/notebook_context_state.dart';
import 'widgets/tts_button.dart';

enum NotebookTool {
  mindmap,
  pomodoro,
  quiz,
  flashcard,
  slideDesk,
  report,
}

extension NotebookToolX on NotebookTool {
  String get title => switch (this) {
        NotebookTool.mindmap => 'Mindmap',
        NotebookTool.pomodoro => 'Pomodoro',
        NotebookTool.quiz => 'Quiz',
        NotebookTool.flashcard => 'Flashcard',
        NotebookTool.slideDesk => 'Slide Desk',
        NotebookTool.report => 'Report',
      };

  IconData get icon => switch (this) {
        NotebookTool.mindmap => Icons.account_tree_outlined,
        NotebookTool.pomodoro => Icons.timer_outlined,
        NotebookTool.quiz => Icons.quiz_outlined,
        NotebookTool.flashcard => Icons.style_outlined,
        NotebookTool.slideDesk => Icons.slideshow_outlined,
        NotebookTool.report => Icons.summarize_outlined,
      };
}

class NotebookToolScreen extends StatelessWidget {
  const NotebookToolScreen({super.key, required this.tool});

  final NotebookTool tool;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF48A9A6),
        title: Text(tool.title),
      ),
      body: switch (tool) {
        NotebookTool.pomodoro => const _PomodoroBody(),
        NotebookTool.flashcard => const _FlashcardToolBody(),
        NotebookTool.quiz => const _QuizToolBody(),
        _ => _AiToolBody(tool: tool),
      },
    );
  }
}

class _ContextBanner extends StatelessWidget {
  const _ContextBanner();

  @override
  Widget build(BuildContext context) {
    final t = context.watch<NotebookContextState>().notebookText.trim();
    return Card(
      color: Colors.teal.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ngữ cảnh Notebook (dùng cho prompt AI)', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              t.isEmpty ? 'Chưa có — hãy điền ở Dashboard.' : t,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Helper: Build the VARK style instruction
// ─────────────────────────────────────────────
String _buildStyleInstruction(String style) {
  switch (style.toLowerCase()) {
    case 'visual':
      return 'Tối ưu hóa cho người học có phong cách TRỰC QUAN (Visual learner): Sử dụng sơ đồ chữ, mindmap cây rõ ràng, so sánh hình ảnh, hoặc vẽ sơ đồ ASCII đơn giản khi cần.\n';
    case 'auditory':
      return 'Tối ưu hóa cho người học có phong cách THÍNH GIÁC (Auditory learner): Diễn đạt tự nhiên như lời nói giảng giải, khơi gợi thảo luận nhóm, đưa ra các câu hỏi để người học tự đọc to thảo luận.\n';
    case 'reading/writing':
      return 'Tối ưu hóa cho người học có phong cách ĐỌC/VIẾT (Reading/Writing learner): Viết bài có cấu trúc chặt chẽ, nhiều thông tin, phân đoạn rõ ràng bằng tiêu đề và gạch đầu dòng chi tiết.\n';
    case 'kinesthetic':
      return 'Tối ưu hóa cho người học có phong cách VẬN ĐỘNG (Kinesthetic learner): Đưa nhiều ví dụ thực tế đời sống, bài tập thực hành, case study thực tiễn và hoạt động tự trải nghiệm.\n';
    default:
      return '';
  }
}

String _buildHead(String ctx, String styleInstruction) {
  return ctx.isEmpty
      ? 'Người dùng chưa dán ngữ cảnh Notebook; hãy trả lời dựa trên kiến thức chung và ghi chú điều đó đầu câu trả lời.\n\n$styleInstruction\n'
      : 'Dựa trên ngữ cảnh sau (Notebook):\n"""\n$ctx\n"""\n\n$styleInstruction\n';
}

/// Try to parse JSON even if LLM wraps it in ```json ... ```
List<dynamic> _parseJsonArray(String raw) {
  var cleaned = raw.trim();
  // Remove markdown code fences
  final fenceRegex = RegExp(r'^```\w*\s*', multiLine: true);
  cleaned = cleaned.replaceAll(fenceRegex, '');
  cleaned = cleaned.replaceAll('```', '');
  cleaned = cleaned.trim();
  return jsonDecode(cleaned) as List<dynamic>;
}

// ═════════════════════════════════════════════
// 1. INTERACTIVE FLASHCARD TOOL
// ═════════════════════════════════════════════
class _FlashcardToolBody extends StatefulWidget {
  const _FlashcardToolBody();

  @override
  State<_FlashcardToolBody> createState() => _FlashcardToolBodyState();
}

class _FlashcardToolBodyState extends State<_FlashcardToolBody> {
  bool _loading = false;
  String? _err;
  List<Map<String, String>> _cards = [];

  String _buildPrompt() {
    final ctx = context.read<NotebookContextState>().notebookText.trim();
    final style = context.read<NotebookContextState>().learningStyle;
    final head = _buildHead(ctx, _buildStyleInstruction(style));
    return '${head}Viết 10 flashcard dạng JSON array. Mỗi phần tử là object có "term" và "definition". '
        'CHỈ trả về JSON array, KHÔNG giải thích thêm. Tiếng Việt.\n'
        'Ví dụ: [{"term":"Quang hợp","definition":"Quá trình thực vật chuyển đổi ánh sáng thành năng lượng hóa học."}]';
  }

  Future<void> _generate() async {
    setState(() { _loading = true; _err = null; _cards = []; });
    try {
      final raw = await geminiCompleteText(_buildPrompt());
      final parsed = _parseJsonArray(raw);
      final cards = parsed.map<Map<String, String>>((e) {
        final map = e as Map<String, dynamic>;
        return {
          'term': (map['term'] ?? '').toString(),
          'definition': (map['definition'] ?? '').toString(),
        };
      }).toList();
      if (cards.isEmpty) throw Exception('Không tìm thấy flashcard nào.');
      setState(() => _cards = cards);
    } catch (e) {
      setState(() => _err = geminiUserMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _ContextBanner(),
        const SizedBox(height: 16),
        Text(
          'Sinh thẻ ghi nhớ tương tác — lật thẻ để xem định nghĩa, đánh dấu "Đã thuộc" hoặc "Chưa thuộc".',
          style: TextStyle(color: Colors.grey.shade800, height: 1.35),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _loading ? null : _generate,
          icon: _loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.auto_awesome),
          label: Text(_loading ? 'Đang tạo…' : 'Tạo Flashcard với AI'),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF48A9A6)),
        ),
        if (_err != null) ...[
          const SizedBox(height: 12),
          Text(_err!, style: const TextStyle(color: Colors.red)),
        ],
        if (_cards.isNotEmpty) ...[
          const SizedBox(height: 20),
          _InteractiveFlashcardsWidget(cards: _cards),
        ],
      ],
    );
  }
}

// ─── Interactive Flashcards Widget ───
class _InteractiveFlashcardsWidget extends StatefulWidget {
  const _InteractiveFlashcardsWidget({required this.cards});
  final List<Map<String, String>> cards;

  @override
  State<_InteractiveFlashcardsWidget> createState() => _InteractiveFlashcardsWidgetState();
}

class _InteractiveFlashcardsWidgetState extends State<_InteractiveFlashcardsWidget> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _showingFront = true;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  final List<bool> _results = []; // true = memorized, false = still learning

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutBack),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _flip() {
    if (_showingFront) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
    setState(() => _showingFront = !_showingFront);
  }

  void _markCard(bool memorized) {
    _results.add(memorized);
    if (_currentIndex < widget.cards.length - 1) {
      // Reset flip
      _flipController.reset();
      setState(() {
        _currentIndex++;
        _showingFront = true;
      });
    } else {
      // Done — show summary
      setState(() => _currentIndex = -1);
    }
  }

  void _retry() {
    _flipController.reset();
    setState(() {
      _currentIndex = 0;
      _showingFront = true;
      _results.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Summary screen
    if (_currentIndex == -1) {
      final memorized = _results.where((r) => r).length;
      final total = _results.length;
      final pct = (memorized / total * 100).round();
      return _SummaryCard(
        icon: pct >= 70 ? Icons.emoji_events : Icons.refresh,
        iconColor: pct >= 70 ? Colors.amber : Colors.orange,
        title: pct >= 70 ? 'Xuất sắc! 🎉' : 'Cố gắng thêm nhé! 💪',
        subtitle: 'Bạn đã thuộc $memorized / $total thẻ ($pct%)',
        onRetry: _retry,
      );
    }

    final card = widget.cards[_currentIndex];
    return Column(
      children: [
        // Progress indicator
        Row(
          children: [
            Text('Thẻ ${_currentIndex + 1} / ${widget.cards.length}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const Spacer(),
            TtsButton(text: _showingFront ? card['term']! : card['definition']!),
          ],
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: LinearProgressIndicator(
            value: (_currentIndex + 1) / widget.cards.length,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF48A9A6)),
            minHeight: 5,
          ),
        ),
        const SizedBox(height: 16),
        // The flip card
        GestureDetector(
          onTap: _flip,
          child: AnimatedBuilder(
            animation: _flipAnimation,
            builder: (context, child) {
              final angle = _flipAnimation.value * pi;
              final isFront = angle < pi / 2;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(angle),
                child: isFront
                    ? _buildCardFace(card['term']!, Colors.teal.shade700, Colors.teal.shade50, 'Thuật ngữ', Icons.touch_app)
                    : Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(pi),
                        child: _buildCardFace(card['definition']!, Colors.deepPurple.shade700, Colors.deepPurple.shade50, 'Định nghĩa', null),
                      ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text('Chạm thẻ để lật', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        const SizedBox(height: 16),
        // Action buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _markCard(false),
                icon: const Icon(Icons.close, color: Colors.redAccent),
                label: const Text('Chưa thuộc'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _markCard(true),
                icon: const Icon(Icons.check),
                label: const Text('Đã thuộc'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF48A9A6),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCardFace(String text, Color textColor, Color bgColor, String label, IconData? hint) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 220),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: textColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(label, style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 16),
          Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textColor, height: 1.4)),
          if (hint != null) ...[
            const SizedBox(height: 16),
            Icon(hint, color: textColor.withOpacity(0.3), size: 28),
          ],
        ],
      ),
    );
  }
}

/// Animated builder wrapper — Flutter's AnimatedBuilder
class AnimatedBuilder extends StatelessWidget {
  const AnimatedBuilder({super.key, required this.animation, required this.builder});
  final Animation<double> animation;
  final Widget Function(BuildContext, Widget?) builder;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder2(listenable: animation, builder: builder);
  }
}

class AnimatedBuilder2 extends AnimatedWidget {
  const AnimatedBuilder2({super.key, required super.listenable, required this.builder});
  final Widget Function(BuildContext, Widget?) builder;

  Animation<double> get animation => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) => builder(context, null);
}

// ═════════════════════════════════════════════
// 2. INTERACTIVE QUIZ TOOL
// ═════════════════════════════════════════════
class _QuizToolBody extends StatefulWidget {
  const _QuizToolBody();

  @override
  State<_QuizToolBody> createState() => _QuizToolBodyState();
}

class _QuizToolBodyState extends State<_QuizToolBody> {
  bool _loading = false;
  String? _err;
  List<Map<String, dynamic>> _questions = [];

  String _buildPrompt() {
    final ctx = context.read<NotebookContextState>().notebookText.trim();
    final style = context.read<NotebookContextState>().learningStyle;
    final head = _buildHead(ctx, _buildStyleInstruction(style));
    return '${head}Viết 8 câu hỏi trắc nghiệm dạng JSON array. Mỗi phần tử là object có '
        '"question" (string), "options" (array 4 string), "answerIndex" (int 0-3), "explanation" (string). '
        'CHỈ trả về JSON array, KHÔNG giải thích thêm. Tiếng Việt.\n'
        'Ví dụ: [{"question":"Quang hợp xảy ra ở đâu?","options":["Ti thể","Lục lạp","Nhân tế bào","Ribosome"],"answerIndex":1,"explanation":"Lục lạp chứa diệp lục, nơi diễn ra quang hợp."}]';
  }

  Future<void> _generate() async {
    setState(() { _loading = true; _err = null; _questions = []; });
    try {
      final raw = await geminiCompleteText(_buildPrompt());
      final parsed = _parseJsonArray(raw);
      final questions = parsed.map<Map<String, dynamic>>((e) {
        final map = e as Map<String, dynamic>;
        return {
          'question': (map['question'] ?? '').toString(),
          'options': List<String>.from((map['options'] as List? ?? []).map((o) => o.toString())),
          'answerIndex': (map['answerIndex'] as num?)?.toInt() ?? 0,
          'explanation': (map['explanation'] ?? '').toString(),
        };
      }).toList();
      if (questions.isEmpty) throw Exception('Không tìm thấy câu hỏi nào.');
      setState(() => _questions = questions);
    } catch (e) {
      setState(() => _err = geminiUserMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _ContextBanner(),
        const SizedBox(height: 16),
        Text(
          'Sinh đề kiểm tra tương tác — chọn đáp án, xem giải thích chi tiết ngay lập tức.',
          style: TextStyle(color: Colors.grey.shade800, height: 1.35),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _loading ? null : _generate,
          icon: _loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.auto_awesome),
          label: Text(_loading ? 'Đang tạo…' : 'Tạo Quiz với AI'),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF48A9A6)),
        ),
        if (_err != null) ...[
          const SizedBox(height: 12),
          Text(_err!, style: const TextStyle(color: Colors.red)),
        ],
        if (_questions.isNotEmpty) ...[
          const SizedBox(height: 20),
          _InteractiveQuizWidget(questions: _questions),
        ],
      ],
    );
  }
}

// ─── Interactive Quiz Widget ───
class _InteractiveQuizWidget extends StatefulWidget {
  const _InteractiveQuizWidget({required this.questions});
  final List<Map<String, dynamic>> questions;

  @override
  State<_InteractiveQuizWidget> createState() => _InteractiveQuizWidgetState();
}

class _InteractiveQuizWidgetState extends State<_InteractiveQuizWidget> {
  int _currentIndex = 0;
  int? _selectedOption;
  int _score = 0;
  bool get _answered => _selectedOption != null;

  void _selectOption(int index) {
    if (_answered) return;
    final correct = widget.questions[_currentIndex]['answerIndex'] as int;
    setState(() {
      _selectedOption = index;
      if (index == correct) _score++;
    });
  }

  void _nextQuestion() {
    if (_currentIndex < widget.questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOption = null;
      });
    } else {
      setState(() => _currentIndex = -1); // summary
    }
  }

  void _retry() {
    setState(() {
      _currentIndex = 0;
      _selectedOption = null;
      _score = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentIndex == -1) {
      final total = widget.questions.length;
      final pct = (_score / total * 100).round();
      return _SummaryCard(
        icon: pct >= 70 ? Icons.emoji_events : Icons.refresh,
        iconColor: pct >= 70 ? Colors.amber : Colors.orange,
        title: pct >= 70 ? 'Tuyệt vời! 🎉' : 'Cần ôn thêm nhé! 📚',
        subtitle: 'Đúng $_score / $total câu ($pct%)',
        onRetry: _retry,
      );
    }

    final q = widget.questions[_currentIndex];
    final options = q['options'] as List<String>;
    final correctIndex = q['answerIndex'] as int;
    final explanation = q['explanation'] as String;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress
        Row(
          children: [
            Text('Câu ${_currentIndex + 1} / ${widget.questions.length}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF48A9A6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Điểm: $_score', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF48A9A6))),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: LinearProgressIndicator(
            value: (_currentIndex + 1) / widget.questions.length,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF48A9A6)),
            minHeight: 5,
          ),
        ),
        const SizedBox(height: 20),
        // Question
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(q['question'] as String, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.5)),
              ),
              TtsButton(text: q['question'] as String),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Options
        ...List.generate(options.length, (i) {
          Color bgColor = Colors.white;
          Color borderColor = Colors.grey.shade300;
          Color textColor = Colors.black87;
          IconData? trailingIcon;

          if (_answered) {
            if (i == correctIndex) {
              bgColor = Colors.green.shade50;
              borderColor = Colors.green;
              textColor = Colors.green.shade800;
              trailingIcon = Icons.check_circle;
            } else if (i == _selectedOption && i != correctIndex) {
              bgColor = Colors.red.shade50;
              borderColor = Colors.red;
              textColor = Colors.red.shade800;
              trailingIcon = Icons.cancel;
            }
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () => _selectOption(i),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _answered && i == correctIndex
                            ? Colors.green
                            : _answered && i == _selectedOption
                                ? Colors.red
                                : Colors.grey.shade300,
                      ),
                      child: Center(
                        child: Text(
                          String.fromCharCode(65 + i), // A, B, C, D
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _answered && (i == correctIndex || i == _selectedOption)
                                ? Colors.white
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(options[i], style: TextStyle(fontSize: 15, color: textColor))),
                    if (trailingIcon != null) Icon(trailingIcon, color: borderColor, size: 22),
                  ],
                ),
              ),
            ),
          );
        }),
        // Explanation
        if (_answered) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text('Giải thích', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.blue.shade700)),
                    const Spacer(),
                    TtsButton(text: explanation),
                  ],
                ),
                const SizedBox(height: 8),
                Text(explanation, style: TextStyle(color: Colors.blue.shade900, height: 1.45)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _nextQuestion,
              icon: Icon(_currentIndex < widget.questions.length - 1 ? Icons.arrow_forward : Icons.flag),
              label: Text(_currentIndex < widget.questions.length - 1 ? 'Câu tiếp theo' : 'Xem kết quả'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF48A9A6),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Summary Card (shared by Flashcard + Quiz) ───
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.icon, required this.iconColor, required this.title, required this.subtitle, required this.onRetry});
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade50, Colors.deepPurple.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 56),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(fontSize: 15, color: Colors.grey.shade700)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Làm lại'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF48A9A6),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════
// 3. GENERIC AI TOOL (mindmap, slideDesk, report)
// ═════════════════════════════════════════════
class _AiToolBody extends StatefulWidget {
  const _AiToolBody({required this.tool});

  final NotebookTool tool;

  @override
  State<_AiToolBody> createState() => _AiToolBodyState();
}

class _AiToolBodyState extends State<_AiToolBody> {
  String _out = '';
  bool _loading = false;
  String? _err;

  String _promptForTool() {
    final ctx = context.read<NotebookContextState>().notebookText.trim();
    final style = context.read<NotebookContextState>().learningStyle;
    final head = _buildHead(ctx, _buildStyleInstruction(style));

    return switch (widget.tool) {
      NotebookTool.mindmap =>
        '${head}Tạo mindmap dạng cây Markdown (dùng - và thụt đầu dòng) để ôn tập. Tiếng Việt.',
      NotebookTool.slideDesk =>
        '${head}Gợi ý 8 slide thuyết trình: mỗi slide có Tiêu đề + 3 gạch đầu dòng. Tiếng Việt.',
      NotebookTool.report =>
        '${head}Viết báo cáo tóm tắt học tập ngắn (mục tiêu, điểm chính, việc nên làm tiếp). Tiếng Việt.',
      _ => '',
    };
  }

  Future<void> _run() async {
    final p = _promptForTool();
    if (p.isEmpty) return;
    setState(() {
      _loading = true;
      _err = null;
      _out = '';
    });
    try {
      final text = await geminiCompleteText(p);
      setState(() => _out = text.trim());
    } catch (e) {
      setState(() => _err = geminiUserMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _ContextBanner(),
        const SizedBox(height: 16),
        Text(
          _blurb(widget.tool),
          style: TextStyle(color: Colors.grey.shade800, height: 1.35),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _loading ? null : _run,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(_loading ? 'Đang tạo…' : 'Tạo với AI (Gemini)'),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF48A9A6)),
        ),
        if (_err != null) ...[
          const SizedBox(height: 12),
          Text(_err!, style: const TextStyle(color: Colors.red)),
        ],
        if (_out.isNotEmpty) ...[
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _out));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã sao chép vào bộ nhớ tạm!')),
                  );
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Sao chép'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade50,
                  foregroundColor: Colors.teal.shade800,
                  elevation: 0,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  final fileName = '${widget.tool.title.toLowerCase()}_export.md';
                  try {
                    saveTextFile(_out, fileName);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Lỗi khi tải file: $e')),
                    );
                  }
                },
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Tải về (.md)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade50,
                  foregroundColor: Colors.teal.shade800,
                  elevation: 0,
                ),
              ),
              TtsButton(text: _out),
            ],
          ),
          const SizedBox(height: 16),
          SelectableText(_out, style: const TextStyle(height: 1.45)),
        ],
      ],
    );
  }

  String _blurb(NotebookTool t) {
    return switch (t) {
      NotebookTool.mindmap => 'Tạo cấu trúc cây từ nội dung Notebook — bạn có thể copy sang XMind / Obsidian.',
      NotebookTool.slideDesk => 'Khung slide để bạn làm PowerPoint / Google Slides.',
      NotebookTool.report => 'Tóm tắt và định hướng ôn tiếp theo.',
      _ => '',
    };
  }
}

// ═════════════════════════════════════════════
// 4. POMODORO TIMER (unchanged)
// ═════════════════════════════════════════════
class _PomodoroBody extends StatefulWidget {
  const _PomodoroBody();

  @override
  State<_PomodoroBody> createState() => _PomodoroBodyState();
}

class _PomodoroBodyState extends State<_PomodoroBody> {
  static const int workSec = 25 * 60;
  int _remaining = workSec;
  bool _running = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick(Timer t) {
    if (_remaining <= 1) {
      t.cancel();
      setState(() {
        _remaining = workSec;
        _running = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hết phiên Pomodoro — nghỉ ngắn rồi học tiếp nhé.')),
        );
      }
      return;
    }
    setState(() => _remaining--);
  }

  void _toggle() {
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
      return;
    }
    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _remaining = workSec;
      _running = false;
    });
  }

  String _fmt(int s) {
    final m = s ~/ 60;
    final r = s % 60;
    return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _ContextBanner(),
        const SizedBox(height: 24),
        Text(
          _fmt(_remaining),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w300, letterSpacing: 2),
        ),
        const SizedBox(height: 8),
        const Text('Phiên 25 phút — gắn với nội dung bạn đang học trong Notebook.', textAlign: TextAlign.center),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: _toggle,
              icon: Icon(_running ? Icons.pause : Icons.play_arrow),
              label: Text(_running ? 'Tạm dừng' : 'Bắt đầu'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF48A9A6)),
            ),
            const SizedBox(width: 12),
            OutlinedButton(onPressed: _running ? null : _reset, child: const Text('Đặt lại')),
          ],
        ),
      ],
    );
  }
}
