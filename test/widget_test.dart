import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/app.dart';

void main() {
  testWidgets('renders shell and navigates between sections', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: BooksApp()));
    await tester.pumpAndSettle();

    expect(find.text('BOOKS'), findsOneWidget);
    expect(find.text('Home content'), findsOneWidget);

    await tester.tap(find.text('Invoices').first);
    await tester.pumpAndSettle();
    expect(find.text('Invoices content'), findsOneWidget);
  });
}
