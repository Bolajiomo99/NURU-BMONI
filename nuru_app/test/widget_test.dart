import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nuru_app/main.dart';

void main() {
  testWidgets('NuruApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: NuruApp(),
      ),
    );
    expect(find.text('NURU'), findsOneWidget);
  });
}
