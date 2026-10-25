import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/app.dart';

void main() {
  testWidgets('BooksApp handles initial web route without throwing Could not navigate exception', (tester) async {
    // Simulate web initial route "/site-visit-attendance-management"
    await tester.pumpWidget(
      const ProviderScope(
        child: BooksApp(),
      ),
    );

    // Initial splash frame should render without throwing "Could not navigate to initial route"
    expect(tester.takeException(), isNull);

    // Let animation proceed and settle
    await tester.pumpAndSettle(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });
}
