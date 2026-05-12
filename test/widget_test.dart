import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_learning_application/main.dart';
import 'package:smart_learning_application/state/notebook_context_state.dart';

void main() {
  testWidgets('PMDEduMind splash shows project name', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => NotebookContextState(),
        child: const MyApp(),
      ),
    );

    expect(find.text('PMDEduMind'), findsOneWidget);
  });
}
