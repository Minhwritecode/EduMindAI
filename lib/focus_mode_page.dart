import 'dart:async';
import 'package:flutter/material.dart';

enum TimerMode { focus, shortBreak, longBreak }

class FocusModePage extends StatefulWidget {
  const FocusModePage({super.key});

  @override
  _FocusModePageState createState() => _FocusModePageState();
}

class _FocusModePageState extends State<FocusModePage> {
  static const int focusDuration = 25 * 60;
  static const int shortBreakDuration = 5 * 60;
  static const int longBreakDuration = 15 * 60;

  TimerMode _currentMode = TimerMode.focus;
  int _remainingSeconds = focusDuration;
  bool _isRunning = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int _getDurationForMode(TimerMode mode) {
    switch (mode) {
      case TimerMode.focus:
        return focusDuration;
      case TimerMode.shortBreak:
        return shortBreakDuration;
      case TimerMode.longBreak:
        return longBreakDuration;
    }
  }

  void _setMode(TimerMode mode) {
    _timer?.cancel();
    setState(() {
      _currentMode = mode;
      _remainingSeconds = _getDurationForMode(mode);
      _isRunning = false;
    });
  }

  void _startTimer() {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _timer?.cancel();
          _isRunning = false;
          _showCompletionDialog();
        }
      });
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _remainingSeconds = _getDurationForMode(_currentMode);
      _isRunning = false;
    });
  }

  void _showCompletionDialog() {
    String message = _currentMode == TimerMode.focus
        ? "Focus session complete! Take a break."
        : "Break is over! Time to focus.";
        
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Time's up!"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("OK", style: TextStyle(color: Color(0xFF48A9A6))),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Widget _buildModeButton(String text, TimerMode mode) {
    bool isSelected = _currentMode == mode;
    return GestureDetector(
      onTap: () => _setMode(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF48A9A6) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double progress = _remainingSeconds / _getDurationForMode(_currentMode);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Pomodoro', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF48A9A6),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Mode Selectors
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildModeButton("Focus", TimerMode.focus),
                  _buildModeButton("Short Break", TimerMode.shortBreak),
                  _buildModeButton("Long Break", TimerMode.longBreak),
                ],
              ),
            ),
            const SizedBox(height: 60),

            // Timer Display
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 250,
                  height: 250,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 12,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF48A9A6)),
                  ),
                ),
                Text(
                  _formatTime(_remainingSeconds),
                  style: const TextStyle(
                    fontSize: 60,
                    fontWeight: FontWeight.w300,
                    color: Color(0xFF002131),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 60),

            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_isRunning)
                  ElevatedButton(
                    onPressed: _startTimer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF48A9A6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text('START', style: TextStyle(fontSize: 18, letterSpacing: 1.2)),
                  )
                else
                  ElevatedButton(
                    onPressed: _pauseTimer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text('PAUSE', style: TextStyle(fontSize: 18, letterSpacing: 1.2)),
                  ),
                const SizedBox(width: 20),
                IconButton(
                  onPressed: _resetTimer,
                  icon: const Icon(Icons.refresh),
                  color: Colors.grey.shade600,
                  iconSize: 32,
                  tooltip: 'Reset Timer',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
