import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/notebook_context_state.dart';
import '../theme/app_theme.dart';

class GreetingBanner extends StatelessWidget {
  const GreetingBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final ctx = context.watch<NotebookContextState>();
    final userName = ctx.userName.isNotEmpty ? ctx.userName : 'Tien Minh';
    final learningStyle = ctx.learningStyle;
    final styleIcon = _iconForStyle(learningStyle);
    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 800),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primary, AppTheme.secondary],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white.withOpacity(0.3),
              child: Text(
                userName[0],
                style: const TextStyle(fontSize: 28, color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chào, $userName!',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(styleIcon, size: 18, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        'Phong cách học: $learningStyle',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForStyle(String style) {
    switch (style.toLowerCase()) {
      case 'visual':
        return Icons.visibility;
      case 'auditory':
        return Icons.hearing;
      case 'reading/writing':
        return Icons.menu_book;
      case 'kinesthetic':
        return Icons.accessibility_new;
      default:
        return Icons.person;
    }
  }
}
