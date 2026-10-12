import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/main.dart';

void main() {
  group('CareBox core reminder rules', () {
    late CareBoxState state;
    setUp(() => state = CareBoxState());
    tearDown(() => state.dispose());

    test('rejects an exact same-time schedule with the requested message', () {
      final result = state.saveSchedule(
        name: 'New dose',
        box: 'Box 2 Afternoon',
        time: const TimeOfDay(hour: 8, minute: 0),
        days: {1, 2, 3, 4, 5, 6, 7},
        enabled: true,
      );
      expect(
        result,
        'Two medicines are scheduled at the same time. Please choose different times.',
      );
    });

    test('starts one reminder and records acknowledgement without claiming ingestion', () {
      state.startReminder(name: 'Morning vitamins');
      expect(state.activeDose, 'Morning vitamins');
      expect(state.ledOn, isTrue);
      state.acknowledgeDose();
      expect(state.activeDose, isNull);
      expect(state.history.first.status, DoseStatus.appAcknowledged);
      expect(
        state.notificationCenter.first,
        'App acknowledgement recorded. This does not confirm medication was taken.',
      );
      expect(statusLabel(state.history.first.status), 'App acknowledgement recorded');
      expect(state.notificationCenter.first.toLowerCase(), isNot(contains('ingested')));
    });

    test('simulated physical button event records a device acknowledgement', () {
      state.startReminder(name: 'Morning vitamins');
      state.simulatePhysicalButtonPress();
      expect(state.history.first.status, DoseStatus.acknowledged);
      expect(state.notificationCenter.first, contains('Dose acknowledged.'));
      expect(state.activeDose, isNull);
    });

    test('only three named CareBox boxes are available', () {
      expect(boxOptions, [
        'Box 1 Morning',
        'Box 2 Afternoon',
        'Box 3 Evening',
      ]);
      expect(
        state.schedules.map((schedule) => schedule.box).toSet(),
        boxOptions.toSet(),
      );
    });

    test('a box can only have one medicine schedule', () {
      final result = state.saveSchedule(
        name: 'Second morning medicine',
        box: 'Box 1 Morning',
        time: const TimeOfDay(hour: 9, minute: 0),
        days: {1, 2, 3, 4, 5, 6, 7},
        enabled: true,
      );
      expect(
        result,
        'This box already has a medicine. Edit its schedule instead.',
      );
    });

    test('response window can be configured within supported bounds', () {
      state.setResponseWindow(20);
      expect(state.responseWindowMinutes, 20);
      state.setResponseWindow(60);
      expect(state.responseWindowMinutes, 30);
      state.setResponseWindow(2);
      expect(state.responseWindowMinutes, 5);
    });

    test('active reminder expires as missed and turns device indicators off', () {
      state.startReminder(name: 'Evening medication');
      state.markMissed();
      expect(state.history.first.status, DoseStatus.missed);
      expect(state.ledOn, isFalse);
      expect(state.buzzerOn, isFalse);
      expect(state.activeDose, isNull);
    });

    test('requires more than three misses in a rolling two-day window', () {
      expect(state.missedLastTwoDays, 1);
      expect(state.confirmRepeatedMissesAndRaiseConcern(), isFalse);
      state.history.addAll(List.generate(3, (i) => DoseRecord('Dose $i', DateTime.now().subtract(Duration(hours: i + 1)), DoseStatus.missed)));
      expect(state.missedLastTwoDays, 4);
      expect(state.confirmRepeatedMissesAndRaiseConcern(), isTrue);
      expect(state.concerns.first.title, 'Several missed reminders');
    });

    test('only a primary caretaker can remove non-primary members', () {
      final member = state.members.last;
      state.setRole(CareRole.additionalCaretaker);
      state.removeMember(member);
      expect(state.members, contains(member));
      state.setRole(CareRole.primaryCaretaker);
      state.removeMember(member);
      expect(state.members, isNot(contains(member)));
    });
  });
}
