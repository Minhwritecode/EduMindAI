import 'package:flutter/material.dart';

import 'gemini_helpers.dart';
import 'state/notebook_context_state.dart';
import 'package:provider/provider.dart';

/// User pastes their weekly schedule; Gemini proposes concrete study slots.
class ScheduleAnalyzePage extends StatefulWidget {
  const ScheduleAnalyzePage({super.key});

  @override
  State<ScheduleAnalyzePage> createState() => _ScheduleAnalyzePageState();
}

class _ScheduleAnalyzePageState extends State<ScheduleAnalyzePage> {
  final TextEditingController _schedule = TextEditingController();
  final TextEditingController _goals = TextEditingController();
  String _result = '';
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _schedule.dispose();
    _goals.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    final notebook = context.read<NotebookContextState>().notebookText.trim();
    if (_schedule.text.trim().isEmpty) {
      setState(() => _error = 'Vui lòng nhập lịch của bạn.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _result = '';
    });
    try {
      final prompt = StringBuffer()
        ..writeln('Bạn là trợ lý lập kế hoạch học tập. Trả lời bằng tiếng Việt, ngắn gọn, dùng gạch đầu dòng và giờ cụ thể (vd: Thứ 3 19:30–20:45).')
        ..writeln()
        ..writeln('### Lịch / ràng buộc thời gian của người học')
        ..writeln(_schedule.text.trim())
        ..writeln()
        ..writeln('### Mục tiêu / môn muốn học')
        ..writeln(_goals.text.trim().isEmpty ? '(không ghi)' : _goals.text.trim())
        ..writeln();
      if (notebook.isNotEmpty) {
        prompt.writeln('### Ngữ cảnh từ Notebook (tài liệu / ghi chú người dùng)');
        prompt.writeln(notebook);
        prompt.writeln();
      }
      prompt.writeln(
        'Hãy đề xuất thời khóa học cụ thể trong tuần (các khung giờ nên khớp lịch trống), '
        'chia nhỏ phiên 25–50 phút nếu hợp lý, và ghi chú ưu tiên môn/hạng mục.',
      );

      final out = await geminiCompleteText(prompt.toString());
      setState(() => _result = out.trim());
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nb = context.watch<NotebookContextState>().notebookText;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF48A9A6),
        title: const Text('Analyze — Lịch học'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Notebook hiện có ${nb.isEmpty ? 0 : nb.length} ký tự ngữ cảnh.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
          const SizedBox(height: 12),
          const Text('Lịch / khung giờ bận — rảnh của bạn', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _schedule,
            minLines: 6,
            maxLines: 12,
            decoration: const InputDecoration(
              hintText: 'Ví dụ:\nThứ 2: 8h–17h đi học, tối rảnh sau 20h\nThứ 7: rảnh cả ngày trừ 14h–16h đi đá bóng\n...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Muốn học gì (môn, chủ đề, deadline)', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _goals,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Ví dụ: Ôn Python + làm project Flutter, thi giữa kỳ 20/6',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _loading ? null : _analyze,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(_loading ? 'Đang phân tích…' : 'Phân tích với AI'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF48A9A6)),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          if (_result.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Gợi ý lịch học', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            SelectableText(_result, style: const TextStyle(height: 1.4)),
          ],
        ],
      ),
    );
  }
}
