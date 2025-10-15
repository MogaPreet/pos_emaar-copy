// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:epos_printer_app/main.dart';

void main() {
  testWidgets('Epson printer app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(EpsonApp());

    // Verify that the app loads with printer status
    expect(find.text('Epson USB Printer'), findsOneWidget);
    expect(find.text('Printer Not Connected'), findsOneWidget);
    expect(find.text('Reconnect'), findsOneWidget);
    expect(find.text('Print Test'), findsOneWidget);
  });
}
