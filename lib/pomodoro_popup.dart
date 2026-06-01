import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

enum TimerMode { focus, shortBreak, longBreak }

class PomodoroPopup extends StatefulWidget {
  const PomodoroPopup({super.key});

  @override
  _PomodoroPopupState createState() => _PomodoroPopupState();
}

class _PomodoroPopupState extends State<PomodoroPopup> {
  static const int focusDuration = 25 * 60;
  static const int shortBreakDuration = 5 * 60;
  static const int longBreakDuration = 15 * 60;

  TimerMode _currentMode = TimerMode.focus;
  int _remainingSeconds = focusDuration;
  bool _isRunning = false;
  Timer? _timer;
  
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
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
          _playAlarm();
          _showCompletionDialog();
        }
      });
    });
  }
  
  Future<void> _playAlarm() async {
    try {
      await _audioPlayer.play(AssetSource('alarm.wav'));
    } catch (e) {
      debugPrint("Could not play alarm: $e");
    }
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
  
  void _testAlarm() {
    _timer?.cancel();
    setState(() {
      _remainingSeconds = 5;
      _isRunning = true;
    });
    _startTimer();
  }

  void _showCompletionDialog() {
    String message = _currentMode == TimerMode.focus
        ? "Focus session complete! Take a break."
        : "Break is over! Time to focus.";
        
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Time's up! ⏰"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              _audioPlayer.stop();
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF48A9A6) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double progress = _remainingSeconds / _getDurationForMode(_currentMode);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Pomodoro Timer', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF002131))),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _timer?.cancel();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
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
                  _buildModeButton("Short", TimerMode.shortBreak),
                  _buildModeButton("Long", TimerMode.longBreak),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Timer Display
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 200,
                  height: 200,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF48A9A6)),
                  ),
                ),
                Text(
                  _formatTime(_remainingSeconds),
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w300,
                    color: Color(0xFF002131),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

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
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text('START', style: TextStyle(fontSize: 16, letterSpacing: 1.2)),
                  )
                else
                  ElevatedButton(
                    onPressed: _pauseTimer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text('PAUSE', style: TextStyle(fontSize: 16, letterSpacing: 1.2)),
                  ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: _resetTimer,
                  icon: const Icon(Icons.refresh),
                  color: Colors.grey.shade600,
                  iconSize: 28,
                  tooltip: 'Reset Timer',
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _testAlarm,
              icon: const Icon(Icons.bug_report, size: 16),
              label: const Text('Test Alarm (5s)'),
              style: TextButton.styleFrom(foregroundColor: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
