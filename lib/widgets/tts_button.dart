import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsButton extends StatefulWidget {
  const TtsButton({Key? key, required this.text}) : super(key: key);

  final String text;

  @override
  State<TtsButton> createState() => _TtsButtonState();
}

class _TtsButtonState extends State<TtsButton> {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _flutterTts.setLanguage('vi-VN').catchError((_) {});
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    _flutterTts.setStartHandler(() {
      setState(() => _isPlaying = true);
    });
    _flutterTts.setCompletionHandler(() {
      setState(() => _isPlaying = false);
    });
    _flutterTts.setErrorHandler((msg) {
      setState(() => _isPlaying = false);
    });
  }

  Future<void> _speak() async {
    if (widget.text.trim().isEmpty) return;
    await _flutterTts.speak(widget.text);
  }

  Future<void> _stop() async {
    await _flutterTts.stop();
    setState(() => _isPlaying = false);
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(_isPlaying ? Icons.stop : Icons.volume_up),
      tooltip: _isPlaying ? 'Dừng phát' : 'Phát âm',
      onPressed: _isPlaying ? _stop : _speak,
    );
  }
}
