import 'package:flutter_test/flutter_test.dart';
import 'package:photo_swipe/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PhotoSwipeApp());
    expect(find.byType(PhotoSwipeApp), findsOneWidget);
  });
}
