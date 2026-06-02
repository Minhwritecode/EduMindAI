import 'package:flutter/material.dart';
import 'package:smart_learning_application/ai_tutor.dart';
import 'package:smart_learning_application/focus_mode_page.dart';

class DashboardToolbar extends StatelessWidget {
  const DashboardToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          tooltip: 'Notebook',
          icon: const Icon(Icons.menu_book_outlined),
          onPressed: () {
            // Open notebook drawer automatically
            Scaffold.of(context).openDrawer();
          },
        ),
        IconButton(
          tooltip: 'Focus Mode',
          icon: const Icon(Icons.timer),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => FocusModePage()));
          },
        ),
        IconButton(
          tooltip: 'AI Tutor',
          icon: const Icon(Icons.school),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AiTutorPage()));
          },
        ),
        IconButton(
          tooltip: 'Settings',
          icon: const Icon(Icons.settings),
          onPressed: () {
            // Placeholder for settings navigation
          },
        ),
      ],
    );
  }
}
