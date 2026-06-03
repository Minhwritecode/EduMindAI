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
        backgroundColor: const Color(0xFF1E1F22),
        title: const Text("Time's up! ⏰", style: TextStyle(color: Color(0xFFE3E3E3))),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              _audioPlayer.stop();
              Navigator.pop(context);
            },
            child: const Text("OK", style: TextStyle(color: Color(0xFF48A9A6), fontWeight: FontWeight.bold)),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF48A9A6) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double progress = _remainingSeconds / _getDurationForMode(_currentMode);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      backgroundColor: const Color(0xFF1E1F22),
      elevation: 20,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pomodoro Timer', 
                  style: TextStyle(
                    fontSize: 22, 
                    fontWeight: FontWeight.bold, 
                    color: Color(0xFFE3E3E3),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () {
                    _timer?.cancel();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Mode Selectors
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF131314),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.white10),
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
            const SizedBox(height: 40),

            // Timer Display
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 220,
                  height: 220,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 12,
                    strokeCap: StrokeCap.round,
                    backgroundColor: Colors.white.withOpacity(0.05),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF48A9A6)),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(_remainingSeconds),
                      style: const TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w200,
                        color: Color(0xFFE3E3E3),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentMode == TimerMode.focus ? 'Stay Focused' : 'Take a Break',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF48A9A6),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 40),

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
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      elevation: 8,
                      shadowColor: const Color(0xFF48A9A6).withOpacity(0.5),
                    ),
                    child: const Text('START', style: TextStyle(fontSize: 16, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                  )
                else
                  ElevatedButton(
                    onPressed: _pauseTimer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      elevation: 8,
                      shadowColor: Colors.orange.shade800.withOpacity(0.5),
                    ),
                    child: const Text('PAUSE', style: TextStyle(fontSize: 16, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                  ),
                const SizedBox(width: 16),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF131314),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white10),
                  ),
                  child: IconButton(
                    onPressed: _resetTimer,
                    icon: const Icon(Icons.refresh),
                    color: Colors.white70,
                    iconSize: 24,
                    tooltip: 'Reset Timer',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: _testAlarm,
              icon: const Icon(Icons.bug_report, size: 16),
              label: const Text('Test Alarm (5s)'),
              style: TextButton.styleFrom(foregroundColor: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }
}
