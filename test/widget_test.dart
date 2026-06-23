// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pengawasan_kelas_smp_negeri_1_jenar/app.dart';

void main() {
  testWidgets('App loads with login screen', (WidgetTester tester) async {
    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({});

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        child: MyApp(bootstrapFuture: Future<void>.value()),
      ),
    );

    // Pump initial loading frame
    await tester.pump();
    
    // Pump another frame with a short duration to let the bootstrap Future resolve and build the LoginScreen
    await tester.pump(const Duration(milliseconds: 500));

    // Diagnostic print
    final textWidgets = tester.widgetList<Text>(find.byType(Text));
    print("Found ${textWidgets.length} Text widgets:");
    for (var widget in textWidgets) {
      print("Text: '${widget.data}'");
    }

    // Verify that login screen is displayed
    expect(find.text('Monitoring Kelas'), findsOneWidget);
    expect(find.text('SMP Negeri 1 Jenar'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
