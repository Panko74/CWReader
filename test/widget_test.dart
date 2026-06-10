import 'package:flutter_test/flutter_test.dart';
import 'package:cwreader/app.dart';

void main() {
  testWidgets('App should render home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const CWReaderApp());
    expect(find.text('CWReader'), findsOneWidget);
  });
}
