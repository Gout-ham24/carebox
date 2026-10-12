import 'package:flutter_test/flutter_test.dart';

import '../lib/services/device_service.dart';

void main() {
  group('DeviceEvent parsing', () {
    test('parses a valid acknowledgement payload', () {
      final event = DeviceEvent.fromJson(<String, Object?>{
        'deviceId': 'carebox-001',
        'patientId': 'patient-01',
        'scheduleId': 'schedule-morning',
        'box': 1,
        'event': 'ACKNOWLEDGED',
        'occurredAt': '2025-03-08T08:30:00Z',
      });

      expect(event.deviceId, 'carebox-001');
      expect(event.event, 'ACKNOWLEDGED');
      expect(event.box, 1);
      expect(event.occurredAt.isUtc, isTrue);
    });

    test('rejects unknown event names and invalid boxes', () {
      expect(
        () => DeviceEvent.fromJson(<String, Object?>{
          'deviceId': 'carebox-001',
          'patientId': 'patient-01',
          'scheduleId': 'schedule-morning',
          'box': 4,
          'event': 'DOSE_TAKEN',
          'occurredAt': '2025-03-08T08:30:00Z',
        }),
        throwsFormatException,
      );
    });

    test('rejects malformed timestamps', () {
      expect(
        () => DeviceEvent.fromJson(<String, Object?>{
          'deviceId': 'carebox-001',
          'patientId': 'patient-01',
          'scheduleId': 'schedule-morning',
          'box': 1,
          'event': 'REMINDER_STARTED',
          'occurredAt': 'not-a-date',
        }),
        throwsFormatException,
      );
    });
  });
}
