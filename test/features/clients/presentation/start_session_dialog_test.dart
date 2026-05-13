import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileallclubs/features/clients/presentation/start_session_dialog.dart';

void main() {
  testWidgets('submits the locker number from the explicit action button', (
    WidgetTester tester,
  ) async {
    StartSessionDialogResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () async {
                  result = await showStartSessionDialog(
                    context,
                    clientName: 'Hikmatullayev Diyorbek',
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Give key'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '24');
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Give key'));
    await tester.pumpAndSettle();

    expect(result?.lockerNumber, '24');
  });

  testWidgets('keeps the action button visible above the keyboard inset', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(430, 932);
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () {
                  showStartSessionDialog(
                    context,
                    clientName: 'Hikmatullayev Diyorbek',
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final buttonRect = tester.getRect(find.widgetWithText(FilledButton, 'Give key'));
    expect(buttonRect.bottom, lessThanOrEqualTo(612));
  });
}
