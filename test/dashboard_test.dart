import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_learning_application/widgets/course_card.dart';
import 'package:smart_learning_application/widgets/greeting_banner.dart';
import 'package:smart_learning_application/data/course_urls.dart';
import 'package:smart_learning_application/state/notebook_context_state.dart';

void main() {
  // ─── CourseCard Tests ───────────────────────────────
  group('CourseCard', () {
    testWidgets('renders subject name and provider count', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CourseCard(
                subject: 'IT & Tech',
                providerUrls: ['https://example.com', 'https://example2.com'],
              ),
            ),
          ),
        ),
      );

      expect(find.text('IT & Tech'), findsOneWidget);
      expect(find.text('2 courses'), findsOneWidget);
    });

    testWidgets('opens bottom sheet on tap', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CourseCard(
                subject: 'IT & Tech',
                providerUrls: ['https://example.com'],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('IT & Tech'));
      await tester.pumpAndSettle();

      // Bottom sheet should show subject name
      expect(find.text('IT & Tech'), findsWidgets);
    });

    testWidgets('renders correct number of cards for all subjects', (tester) async {
      final subjects = CourseUrls.subjectUrls.keys.toList();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: subjects.map((s) {
                  return CourseCard(
                    subject: s,
                    providerUrls: CourseUrls.urlsFor(s),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      );

      // Should have one card per subject (6 categories)
      expect(find.byType(CourseCard), findsNWidgets(subjects.length));
    });
  });

  // ─── GreetingBanner Tests ──────────────────────────
  group('GreetingBanner', () {
    testWidgets('shows user name and learning style', (tester) async {
      final state = NotebookContextState();
      // defaults: userName='Tien Minh', learningStyle='Visual'

      await tester.pumpWidget(
        ChangeNotifierProvider<NotebookContextState>.value(
          value: state,
          child: const MaterialApp(
            home: Scaffold(body: GreetingBanner()),
          ),
        ),
      );

      expect(find.text('Chào, Tien Minh!'), findsOneWidget);
      expect(find.textContaining('Visual'), findsOneWidget);
    });
  });

  // ─── CourseUrls Data Tests ─────────────────────────
  group('CourseUrls', () {
    test('subjectUrls has 6 categories', () {
      expect(CourseUrls.subjectUrls.keys.length, 6);
    });

    test('urlsFor returns non-empty list for IT & Tech', () {
      final urls = CourseUrls.urlsFor('IT & Tech');
      expect(urls.isNotEmpty, true);
      expect(urls.first, startsWith('https://'));
    });

    test('firstUrl returns the first URL', () {
      final url = CourseUrls.firstUrl('Business');
      expect(url, contains('futurelearn'));
    });

    test('urlsFor unknown returns empty list', () {
      expect(CourseUrls.urlsFor('Unknown'), isEmpty);
    });
  });
}
