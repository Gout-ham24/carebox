import 'dart:async';
import 'dart:convert';
import 'dart:io';

abstract class DeviceService {
  Future<DeviceStatus> getStatus();
  Future<List<DeviceEvent>> pollEvents();
  Future<void> sendSchedules(List<Map<String, Object?>> schedules);
  Future<void> testLed();
  Future<void> testBuzzer();
  Future<void> reconnect();
  void startPolling({
    required void Function(List<DeviceEvent> events) onEvents,
    required void Function(Object error) onError,
  });
  void stopPolling();
  void dispose();
}

class DeviceServiceException implements Exception {
  const DeviceServiceException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => statusCode == null
      ? 'DeviceServiceException: $message'
      : 'DeviceServiceException (HTTP $statusCode): $message';
}

class DeviceStatus {
  const DeviceStatus({
    required this.deviceId,
    required this.online,
    required this.firmware,
  });

  final String deviceId;
  final bool online;
  final String firmware;

  factory DeviceStatus.fromJson(Map<String, Object?> json) {
    final deviceId = json['deviceId'];
    final online = json['online'];
    final firmware = json['firmware'];
    if (deviceId is! String || deviceId.isEmpty || online is! bool || firmware is! String) {
      throw const FormatException(
        'Status must contain deviceId (string), online (boolean), and firmware (string).',
      );
    }
    return DeviceStatus(deviceId: deviceId, online: online, firmware: firmware);
  }
}

class DeviceEvent {
  const DeviceEvent({
    required this.deviceId,
    required this.patientId,
    required this.scheduleId,
    required this.box,
    required this.event,
    required this.occurredAt,
  });

  static const eventNames = <String>{
    'REMINDER_STARTED',
    'ACKNOWLEDGED',
    'MISSED',
    'DEVICE_ONLINE',
    'DEVICE_OFFLINE',
  };

  final String deviceId;
  final String patientId;
  final String scheduleId;
  final int box;
  final String event;
  final DateTime occurredAt;

  String get deduplicationKey =>
      '$deviceId|$patientId|$scheduleId|$box|$event|${occurredAt.toUtc().toIso8601String()}';

  factory DeviceEvent.fromJson(Map<String, Object?> json) {
    final deviceId = json['deviceId'];
    final patientId = json['patientId'];
    final scheduleId = json['scheduleId'];
    final box = json['box'];
    final event = json['event'];
    final occurredAt = json['occurredAt'];
    if (deviceId is! String || deviceId.isEmpty ||
        patientId is! String || scheduleId is! String ||
        box is! int || box < 1 || box > 3 ||
        event is! String || !eventNames.contains(event) ||
        occurredAt is! String) {
      throw const FormatException('Invalid CareBox event payload.');
    }
    final parsedDate = DateTime.tryParse(occurredAt);
    if (parsedDate == null) {
      throw const FormatException('Event occurredAt must be an ISO-8601 timestamp.');
    }
    return DeviceEvent(
      deviceId: deviceId,
      patientId: patientId,
      scheduleId: scheduleId,
      box: box,
      event: event,
      occurredAt: parsedDate,
    );
  }
}

class WifiDeviceService implements DeviceService {
  WifiDeviceService({
    required String baseUrl,
    required String pairingToken,
    HttpClient? httpClient,
    this.requestTimeout = const Duration(seconds: 4),
  })  : _baseUri = _validatedBaseUri(baseUrl),
        _pairingToken = pairingToken.trim(),
        _client = httpClient ?? HttpClient() {
    if (_pairingToken.isEmpty) {
      throw ArgumentError.value(pairingToken, 'pairingToken', 'Cannot be empty.');
    }
    _client.connectionTimeout = requestTimeout;
  }

  final Uri _baseUri;
  final String _pairingToken;
  final HttpClient _client;
  final Duration requestTimeout;
  final Set<String> _seenEventKeys = <String>{};
  DateTime? _cursor;
  bool _disposed = false;
  bool _pollInProgress = false;
  Timer? _pollTimer;

  static Uri _validatedBaseUri(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw ArgumentError.value(value, 'baseUrl', 'Enter a full http:// or https:// LAN URL.');
    }
    return uri.replace(path: uri.path.endsWith('/') ? uri.path : '${uri.path}/');
  }

  Future<Map<String, Object?>> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    if (_disposed) {
      throw const DeviceServiceException('This device connection has been disposed.');
    }
    final uri = _baseUri.resolve(path).replace(queryParameters: query);
    try {
      final request = await _client.openUrl(method, uri).timeout(requestTimeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set('X-Pairing-Token', _pairingToken);
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response = await request.close().timeout(requestTimeout);
      final responseText = await utf8.decoder.bind(response).join().timeout(requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw DeviceServiceException(
          'The CareBox returned HTTP ${response.statusCode}${responseText.isEmpty ? '.' : ': $responseText'}',
          statusCode: response.statusCode,
        );
      }
      if (responseText.trim().isEmpty) return <String, Object?>{};
      final decoded = jsonDecode(responseText);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a JSON object from the CareBox.');
      }
      return decoded.cast<String, Object?>();
    } on DeviceServiceException {
      rethrow;
    } on TimeoutException {
      throw const DeviceServiceException('The CareBox request timed out. Check the LAN connection.');
    } on FormatException catch (error) {
      throw DeviceServiceException('Invalid response from the CareBox: ${error.message}');
    } on SocketException catch (error) {
      throw DeviceServiceException('Could not reach the CareBox: ${error.message}');
    } on HttpException catch (error) {
      throw DeviceServiceException('HTTP connection failed: ${error.message}');
    }
  }

  @override
  Future<DeviceStatus> getStatus() async => DeviceStatus.fromJson(
        await _request('GET', 'api/status'),
      );

  @override
  Future<List<DeviceEvent>> pollEvents() async {
    final cursor = _cursor?.toUtc().toIso8601String() ?? '';
    final response = await _request(
      'GET',
      'api/events',
      query: <String, String>{if (cursor.isNotEmpty) 'after': cursor},
    );
    final rawEvents = response['events'];
    if (rawEvents is! List) {
      throw const DeviceServiceException('Events response must contain an events array.');
    }
    final newEvents = <DeviceEvent>[];
    for (final rawEvent in rawEvents) {
      if (rawEvent is! Map<String, dynamic>) {
        throw const DeviceServiceException('Events array contains an invalid event object.');
      }
      final event = DeviceEvent.fromJson(rawEvent.cast<String, Object?>());
      if (_seenEventKeys.add(event.deduplicationKey)) newEvents.add(event);
      if (_cursor == null || event.occurredAt.isAfter(_cursor!)) _cursor = event.occurredAt;
    }
    return newEvents;
  }

  @override
  Future<void> sendSchedules(List<Map<String, Object?>> schedules) async {
    await _request('POST', 'api/schedules', body: <String, Object?>{'schedules': schedules});
  }

  @override
  Future<void> testLed() async {
    await _request('POST', 'api/test/led', body: <String, Object?>{'action': 'test'});
  }

  @override
  Future<void> testBuzzer() async {
    await _request('POST', 'api/test/buzzer', body: <String, Object?>{'action': 'test'});
  }

  @override
  Future<void> reconnect() async {
    await _request('POST', 'api/reconnect', body: <String, Object?>{'action': 'reconnect'});
  }

  @override
  void startPolling({
    required void Function(List<DeviceEvent> events) onEvents,
    required void Function(Object error) onError,
  }) {
    if (_disposed) throw const DeviceServiceException('This device connection has been disposed.');
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_pollInProgress || _disposed) return;
      _pollInProgress = true;
      try {
        final events = await pollEvents();
        if (!_disposed && events.isNotEmpty) onEvents(events);
      } catch (error) {
        if (!_disposed) onError(error);
      } finally {
        _pollInProgress = false;
      }
    });
  }

  @override
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void dispose() {
    if (_disposed) return;
    stopPolling();
    _disposed = true;
    _client.close(force: true);
    _seenEventKeys.clear();
  }
}
