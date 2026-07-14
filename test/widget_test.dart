import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/app.dart';

void main() {
  testWidgets('renders shell and navigates between sections', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ProviderScope(child: BooksApp()));
    await tester.pumpAndSettle();

    expect(find.text('BOOKS'), findsOneWidget);
    expect(find.text('My Organization'), findsOneWidget);

    await tester.tap(find.text('Invoices').first);
    await tester.pumpAndSettle();
    expect(find.text('All Invoices'), findsOneWidget);
  });
}
