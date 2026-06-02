import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_learning_application/state/notebook_context_state.dart';

class DarkModeToggle extends StatelessWidget {
  const DarkModeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<NotebookContextState, bool>((s) => s.isDarkMode);
    return Switch(
      value: isDark,
      activeColor: const Color(0xFF48A9A6),
      onChanged: (_) {
        context.read<NotebookContextState>().toggleDarkMode();
      },
    );
  }
}
