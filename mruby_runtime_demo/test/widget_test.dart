import 'package:flutter_test/flutter_test.dart';

import 'package:ruby_runtime_demo/main.dart';

void main() {
  testWidgets('renders demo title', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Ruby Runtime Example'), findsWidgets);
    expect(find.textContaining('Result:'), findsOneWidget);
  });
}
