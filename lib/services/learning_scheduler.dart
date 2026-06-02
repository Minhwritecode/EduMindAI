import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// A simple SM-2 spaced repetition scheduler for flashcard learning.
///
/// Stores review data locally using SharedPreferences.
/// Each card is identified by a unique key (e.g. hash of term+definition).
class LearningScheduler {
  static const _storageKey = 'edumind_sr_data';

  /// Get singleton instance
  static final LearningScheduler instance = LearningScheduler._();
  LearningScheduler._();

  Map<String, CardReviewData> _cards = {};
  bool _loaded = false;

  /// Load review data from SharedPreferences
  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _cards = map.map((k, v) => MapEntry(k, CardReviewData.fromJson(v as Map<String, dynamic>)));
      } catch (_) {
        _cards = {};
      }
    }
    _loaded = true;
  }

  /// Save review data to SharedPreferences
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final map = _cards.map((k, v) => MapEntry(k, v.toJson()));
    await prefs.setString(_storageKey, jsonEncode(map));
  }

  /// Record a review for a card.
  /// [quality] is 0-5, where 0 = complete blackout, 5 = perfect recall.
  /// For simplicity, "Đã thuộc" = 5, "Chưa thuộc" = 1.
  Future<void> recordReview(String cardId, int quality) async {
    await load();
    final data = _cards[cardId] ?? CardReviewData();
    data.applyReview(quality);
    _cards[cardId] = data;
    await _save();
  }

  /// Get all cards that are due for review (nextReview <= now).
  Future<List<String>> getDueCardIds() async {
    await load();
    final now = DateTime.now();
    return _cards.entries
        .where((e) => e.value.nextReview.isBefore(now) || e.value.nextReview.isAtSameMomentAs(now))
        .map((e) => e.key)
        .toList();
  }

  /// Get review data for a specific card.
  Future<CardReviewData?> getCardData(String cardId) async {
    await load();
    return _cards[cardId];
  }

  /// Get total stats.
  Future<Map<String, int>> getStats() async {
    await load();
    final now = DateTime.now();
    int totalCards = _cards.length;
    int dueCards = _cards.values.where((d) => !d.nextReview.isAfter(now)).length;
    int masteredCards = _cards.values.where((d) => d.repetitions >= 3 && d.easeFactor >= 2.5).length;
    return {
      'total': totalCards,
      'due': dueCards,
      'mastered': masteredCards,
    };
  }

  /// Record a quiz result for analytics.
  Future<void> recordQuizResult({
    required int correct,
    required int total,
    required String topic,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final historyRaw = prefs.getStringList('edumind_quiz_history') ?? [];
    final entry = jsonEncode({
      'correct': correct,
      'total': total,
      'topic': topic,
      'date': DateTime.now().toIso8601String(),
    });
    historyRaw.add(entry);
    // Keep last 100 entries
    if (historyRaw.length > 100) {
      historyRaw.removeRange(0, historyRaw.length - 100);
    }
    await prefs.setStringList('edumind_quiz_history', historyRaw);
  }

  /// Get quiz history for analytics.
  Future<List<Map<String, dynamic>>> getQuizHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyRaw = prefs.getStringList('edumind_quiz_history') ?? [];
    return historyRaw.map((e) {
      try {
        return jsonDecode(e) as Map<String, dynamic>;
      } catch (_) {
        return <String, dynamic>{};
      }
    }).where((m) => m.isNotEmpty).toList();
  }

  /// Record total study time in minutes for today.
  Future<void> addStudyMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = 'edumind_study_${DateTime.now().toIso8601String().substring(0, 10)}';
    final current = prefs.getInt(todayKey) ?? 0;
    await prefs.setInt(todayKey, current + minutes);
  }

  /// Get study minutes for the last N days.
  Future<Map<String, int>> getStudyHistory(int days) async {
    final prefs = await SharedPreferences.getInstance();
    final result = <String, int>{};
    for (int i = 0; i < days; i++) {
      final date = DateTime.now().subtract(Duration(days: i));
      final key = 'edumind_study_${date.toIso8601String().substring(0, 10)}';
      result[date.toIso8601String().substring(0, 10)] = prefs.getInt(key) ?? 0;
    }
    return result;
  }
}

/// SM-2 review data for a single card.
class CardReviewData {
  int repetitions;
  double easeFactor;
  int intervalDays;
  DateTime nextReview;
  DateTime lastReview;

  CardReviewData({
    this.repetitions = 0,
    this.easeFactor = 2.5,
    this.intervalDays = 1,
    DateTime? nextReview,
    DateTime? lastReview,
  })  : nextReview = nextReview ?? DateTime.now(),
        lastReview = lastReview ?? DateTime.now();

  /// Apply SM-2 algorithm after a review.
  void applyReview(int quality) {
    // quality: 0=blackout, 1=wrong, 2=hard, 3=ok, 4=good, 5=perfect
    quality = quality.clamp(0, 5);

    if (quality >= 3) {
      // Correct response
      if (repetitions == 0) {
        intervalDays = 1;
      } else if (repetitions == 1) {
        intervalDays = 6;
      } else {
        intervalDays = (intervalDays * easeFactor).round();
      }
      repetitions++;
    } else {
      // Incorrect — reset
      repetitions = 0;
      intervalDays = 1;
    }

    // Update ease factor
    easeFactor = easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    if (easeFactor < 1.3) easeFactor = 1.3;

    lastReview = DateTime.now();
    nextReview = DateTime.now().add(Duration(days: intervalDays));
  }

  Map<String, dynamic> toJson() => {
        'repetitions': repetitions,
        'easeFactor': easeFactor,
        'intervalDays': intervalDays,
        'nextReview': nextReview.toIso8601String(),
        'lastReview': lastReview.toIso8601String(),
      };

  factory CardReviewData.fromJson(Map<String, dynamic> json) => CardReviewData(
        repetitions: json['repetitions'] as int? ?? 0,
        easeFactor: (json['easeFactor'] as num?)?.toDouble() ?? 2.5,
        intervalDays: json['intervalDays'] as int? ?? 1,
        nextReview: json['nextReview'] != null ? DateTime.parse(json['nextReview'] as String) : null,
        lastReview: json['lastReview'] != null ? DateTime.parse(json['lastReview'] as String) : null,
      );
}
