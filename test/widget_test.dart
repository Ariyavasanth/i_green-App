import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/app.dart';

void main() {
  void setViewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('renders shell and navigates between sections', (tester) async {
    setViewport(tester, const Size(1200, 800));
    await tester.pumpWidget(const ProviderScope(child: BooksApp()));
    await tester.pumpAndSettle();

    expect(find.text('BOOKS'), findsOneWidget);
    expect(find.text('My Organization'), findsOneWidget);

    await tester.tap(find.text('Invoices').first);
    await tester.pumpAndSettle();
    expect(find.text('All Invoices'), findsOneWidget);
  });

  testWidgets('uses drawer navigation on a mobile viewport', (tester) async {
    setViewport(tester, const Size(360, 800));
    await tester.pumpWidget(const ProviderScope(child: BooksApp()));
    await tester.pumpAndSettle();

    expect(find.text('BOOKS'), findsNothing);
    expect(find.text('My Organization'), findsNothing);
    expect(find.byTooltip('Quick create'), findsNothing);
    await tester.tap(find.byTooltip('Open navigation'));
    await tester.pumpAndSettle();

    expect(find.text('BOOKS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shell remains usable with large accessibility text', (
    tester,
  ) async {
    setViewport(tester, const Size(390, 844));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(const ProviderScope(child: BooksApp()));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Open navigation'), findsOneWidget);
    expect(find.byTooltip('Search current section'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
