import 'package:flutter_test/flutter_test.dart';
import 'package:beauty_timer/main.dart';

void main() {
  testWidgets('Beauty Timer smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BeautyTimerApp());
    expect(find.text('Beauty'), findsOneWidget);
  });
}
