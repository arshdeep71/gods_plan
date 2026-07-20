import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gods_plan/screens/settings/sound_haptics_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'haptics_enabled': true,
      'sounds_enabled': true,
      'ui_volume': 0.8,
    });
  });

  testWidgets('SoundHapticsView renders correctly and responds to toggles', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SoundHapticsView(),
    ));

    // Wait for the mock SharedPreferences to load
    await tester.pumpAndSettle();

    // Verify UI elements exist
    expect(find.text('Sounds & Haptics'), findsOneWidget);
    expect(find.text('System Haptics'), findsOneWidget);
    expect(find.text('UI Sound Effects'), findsOneWidget);
    expect(find.text('VIBRATION INTENSITY'), findsOneWidget);
    
    // Test the SwitchListTile toggles
    final switches = find.byType(SwitchListTile);
    expect(switches, findsNWidgets(2)); // Haptics and Sounds toggles

    // Tap the Haptics toggle to turn it OFF
    await tester.tap(switches.first);
    await tester.pumpAndSettle();

    // When Haptics are off, the VIBRATION INTENSITY radio buttons should hide
    expect(find.text('VIBRATION INTENSITY'), findsNothing);
    
    // Tap the Sounds toggle to turn it OFF
    await tester.tap(switches.last);
    await tester.pumpAndSettle();
    
    // When Sounds are off, the UI VOLUME slider should hide
    expect(find.text('UI VOLUME'), findsNothing);
  });
}
