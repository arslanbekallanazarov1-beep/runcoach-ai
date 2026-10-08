import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runcoach_ai/screens/gear_tracker_screen.dart';
import 'package:runcoach_ai/services/gear_tracker_service.dart';

void main() {
  test('persists shoes and records distance against the selected pair',
      () async {
    final storage = MemoryGearStorage();
    final tracker = GearTrackerService(storage: storage);
    await tracker.load();

    await tracker.addShoe(name: 'Daily trainers', startingKilometers: 695);
    final shoeId = tracker.selectedShoeId!;
    await tracker.recordRunDistance(5);

    expect(tracker.shoes.single.totalKilometers, 700);
    expect(tracker.selectedShoe?.name, 'Daily trainers');

    final restored = GearTrackerService(storage: storage);
    await restored.load();
    expect(restored.shoes.single.totalKilometers, 700);
    expect(restored.selectedShoeId, shoeId);
    tracker.dispose();
    restored.dispose();
  });

  test('does not assign run distance when no shoe is selected', () async {
    final tracker = GearTrackerService(storage: MemoryGearStorage());
    await tracker.load();
    await tracker.addShoe(name: 'Tempo shoes');
    await tracker.selectShoe(null);

    expect(await tracker.recordRunDistance(8), isNull);
    expect(tracker.shoes.single.totalKilometers, 0);
    tracker.dispose();
  });

  testWidgets('shows replacement alert after 700 km', (tester) async {
    final tracker = GearTrackerService(storage: MemoryGearStorage());
    await tracker.load();
    await tracker.addShoe(name: 'Daily trainers', startingKilometers: 700);

    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: GearTrackerScreen(gearTracker: tracker),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Daily trainers'), findsOneWidget);
    expect(find.text('Time to replace shoes'), findsNothing);
    await tracker.recordRunDistance(0.1);
    await tester.pumpAndSettle();
    expect(find.text('Time to replace shoes'), findsOneWidget);
    expect(tester.takeException(), isNull);
    tracker.dispose();
  });
}
