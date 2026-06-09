import 'package:flutter_test/flutter_test.dart';
import 'package:ebook2cw/app.dart';

void main() {
  testWidgets('App should render home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const Ebook2CWApp());
    expect(find.text('Ebook2CW'), findsOneWidget);
  });
}
