import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runcoach_ai/models/shareable_run.dart';
import 'package:runcoach_ai/utils/duration_format.dart';
import 'package:runcoach_ai/widgets/shareable_run_card.dart';

void main() {
  test('formats durations as minutes and seconds, including hours', () {
    expect(formatRunDuration(360), '6:00');
    expect(formatRunDuration(1865), '31:05');
    expect(formatRunDuration(3665), '1:01:05');
  });

  test('converts entered duration minutes to API seconds', () {
    expect(durationMinutesToSeconds(10), 600);
    expect(durationMinutesToSeconds(31), 1860);
    expect(durationMinutesToSeconds(10.5), 630);
  });

  final run = ShareableRun(
    distanceKm: 5,
    pace: '6:00',
    timeSeconds: 1800,
    coachComment: 'Strong effort. Recover well before your next run.',
    date: DateTime(2026, 9, 30),
  );

  test('estimates calories from distance', () {
    expect(run.estimatedCalories, 300);
  });

  testWidgets('renders the complete share card and export action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ShareableRunCard(run: run),
          ),
        ),
      ),
    );

    expect(find.text('5.00'), findsOneWidget);
    expect(find.text('6:00 /km'), findsOneWidget);
    expect(find.text('30:00'), findsOneWidget);
    expect(find.text('300 kcal*'), findsOneWidget);
    expect(
      find.text('Strong effort. Recover well before your next run.'),
      findsOneWidget,
    );
    expect(find.text('Share run card'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('share-card-route-graphic')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
