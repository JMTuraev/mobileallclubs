import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobileallclubs/core/widgets/app_snackbar.dart';

void main() {
  testWidgets('shows a snackbar through the global messenger key', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: appScaffoldMessengerKey,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAppSnackBar(
                context,
                'Read-only mode',
                duration: const Duration(milliseconds: 10),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Read-only mode'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 20));
  });
}
