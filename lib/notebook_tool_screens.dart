import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'gemini_helpers.dart';
import 'state/notebook_context_state.dart';

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
    final head = ctx.isEmpty
        ? 'Người dùng chưa dán ngữ cảnh Notebook; hãy trả lời dựa trên kiến thức chung và ghi chú điều đó đầu câu trả lời.\n\n'
        : 'Dựa trên ngữ cảnh sau (Notebook):\n"""\n$ctx\n"""\n\n';

    return switch (widget.tool) {
      NotebookTool.mindmap =>
        '${head}Tạo mindmap dạng cây Markdown (dùng - và thụt đầu dòng) để ôn tập. Tiếng Việt.',
      NotebookTool.quiz =>
        '${head}Viết 8 câu hỏi trắc nghiệm (4 đáp án A–D), kèm đáp án đúng ở cuối mỗi câu. Tiếng Việt.',
      NotebookTool.flashcard =>
        '${head}Viết 12 flashcard dạng: Thuật ngữ: Định nghĩa (một dòng mỗi thẻ). Tiếng Việt.',
      NotebookTool.slideDesk =>
        '${head}Gợi ý 8 slide thuyết trình: mỗi slide có Tiêu đề + 3 gạch đầu dòng. Tiếng Việt.',
      NotebookTool.report =>
        '${head}Viết báo cáo tóm tắt học tập ngắn (mục tiêu, điểm chính, việc nên làm tiếp). Tiếng Việt.',
      NotebookTool.pomodoro => '',
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
      setState(() => _err = e.toString());
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
          SelectableText(_out, style: const TextStyle(height: 1.45)),
        ],
      ],
    );
  }

  String _blurb(NotebookTool t) {
    return switch (t) {
      NotebookTool.mindmap => 'Tạo cấu trúc cây từ nội dung Notebook — bạn có thể copy sang XMind / Obsidian.',
      NotebookTool.quiz => 'Sinh đề kiểm tra nhanh từ tài liệu bạn đã dán ở Dashboard.',
      NotebookTool.flashcard => 'Sinh thẻ ghi nhớ để học lại từ vựng / định nghĩa.',
      NotebookTool.slideDesk => 'Khung slide để bạn làm PowerPoint / Google Slides.',
      NotebookTool.report => 'Tóm tắt và định hướng ôn tiếp theo.',
      NotebookTool.pomodoro => '',
    };
  }
}

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
