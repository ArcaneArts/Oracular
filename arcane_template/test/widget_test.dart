import 'package:flutter_test/flutter_test.dart';
import 'package:arcane_template/main.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ArcaneTemplateApp());

    // Verify that the app builds without errors
    expect(find.text('Arcane Template'), findsOneWidget);
  });
}
