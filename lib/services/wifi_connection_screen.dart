import 'dart:convert';

import 'package:flutter/material.dart';

import 'device_service.dart';

class WifiConnectionScreen extends StatefulWidget {
  const WifiConnectionScreen({
    super.key,
    this.onEvent,
    this.initialSchedules = const <Map<String, Object?>>[],
  });

  final ValueChanged<DeviceEvent>? onEvent;
  final List<Map<String, Object?>> initialSchedules;

  @override
  State<WifiConnectionScreen> createState() => _WifiConnectionScreenState();
}

class _WifiConnectionScreenState extends State<WifiConnectionScreen> {
  static const _background = Color(0xFFF1F6FA);
  static const _ink = Color(0xFF203047);
  static const _blue = Color(0xFF6C9CE8);
  static const _cyan = Color(0xFF8CC9D7);

  final _urlController = TextEditingController();
  final _tokenController = TextEditingController();
  final _schedulesController = TextEditingController();
  final List<DeviceEvent> _events = <DeviceEvent>[];
  WifiDeviceService? _service;
  DeviceStatus? _status;
  String? _error;
  String? _message;
  bool _busy = false;

  bool get _isOnline => _status?.online == true;

  Future<void> _connect() async {
    final service = _service;
    if (_busy || service != null) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    WifiDeviceService? candidate;
    try {
      candidate = WifiDeviceService(
        baseUrl: _urlController.text,
        pairingToken: _tokenController.text,
      );
      final status = await candidate.getStatus();
      if (!mounted) {
        candidate.dispose();
        return;
      }
      _service = candidate;
      _status = status;
      _message = status.online
          ? 'Live status received from ${status.deviceId}. Hardware behavior is not verified.'
          : 'Status received; the device reports offline.';
      final activeService = candidate;
      activeService.startPolling(
        onEvents: _receiveEvents,
        onError: (error) => _showPollingError(activeService, error),
      );
      await _pollNow(activeService);
    } catch (error) {
      candidate?.dispose();
      if (mounted) {
        setState(() {
          _service = null;
          _status = null;
          _message = 'Disconnected after a connection failure.';
          _error = '$error';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pollNow(WifiDeviceService service) async {
    try {
      _receiveEvents(await service.pollEvents());
    } catch (error) {
      _showPollingError(service, error);
    }
  }

  void _receiveEvents(List<DeviceEvent> received) {
    if (!mounted || received.isEmpty) return;
    setState(() {
      _events.insertAll(0, received.reversed);
      _message = 'Received ${received.length} event${received.length == 1 ? '' : 's'} from the device.';
    });
    for (final event in received) {
      widget.onEvent?.call(event);
    }
  }

  void _showPollingError(WifiDeviceService service, Object error) {
    if (!mounted || !identical(_service, service)) return;
    service.dispose();
    setState(() {
      _service = null;
      _status = null;
      _message = 'Disconnected after a device polling failure.';
      _error = '$error';
    });
  }

  void _disconnect() {
    _service?.dispose();
    setState(() {
      _service = null;
      _status = null;
      _message = 'Disconnected. The Wi-Fi polling connection has been disposed.';
      _error = null;
    });
  }


  Future<void> _runAction(
    String successMessage,
    Future<void> Function(WifiDeviceService service) action,
  ) async {
    final service = _service;
    if (service == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await action(service);
      if (mounted) setState(() => _message = successMessage);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _sectionCard({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xE0FFFFFF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x778CC9D7)),
        ),
        child: child,
      );

  Widget _field({
    required String label,
    required TextEditingController controller,
    String? hint,
    bool obscure = false,
    int lines = 1,
  }) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: _ink, fontWeight: FontWeight.w600)),
          const SizedBox(height: 7),
          TextField(
            controller: controller,
            obscureText: obscure,
            minLines: lines,
            maxLines: obscure ? 1 : lines,
            style: const TextStyle(color: _ink),
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: _background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ],
      );

  @override
  void initState() {
    super.initState();
    _schedulesController.text = jsonEncode(widget.initialSchedules);
  }

  @override
  void dispose() {
    _service?.dispose();
    _urlController.dispose();
    _tokenController.dispose();
    _schedulesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          title: const Text('ESP8266 Wi-Fi prototype', style: TextStyle(color: _ink)),
          backgroundColor: _background,
          foregroundColor: _ink,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            children: [
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.wifi_tethering, color: _blue),
                      SizedBox(width: 10),
                      Expanded(child: Text('Opt-in hardware prototype', style: TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w700))),
                    ]),
                    const SizedBox(height: 8),
                    const Text('Local demo remains separate. Connect only to matching ESP8266 firmware on your LAN.', style: TextStyle(color: _ink)),
                    const SizedBox(height: 16),
                    _field(label: 'Device base URL', controller: _urlController, hint: 'http://192.168.1.50/'),
                    const SizedBox(height: 14),
                    _field(label: 'Pairing token', controller: _tokenController, hint: 'Enter the device pairing token', obscure: true),
                    const SizedBox(height: 14),
                    Wrap(spacing: 10, runSpacing: 10, children: [
                      FilledButton.icon(
                        onPressed: _busy || _service != null ? null : _connect,
                        icon: const Icon(Icons.link),
                        label: Text(_busy && _service == null ? 'Connecting…' : 'Connect'),
                        style: FilledButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white),
                      ),
                      OutlinedButton.icon(
                        onPressed: _service == null ? null : _disconnect,
                        icon: const Icon(Icons.link_off),
                        label: const Text('Disconnect'),
                        style: OutlinedButton.styleFrom(foregroundColor: _ink),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Icon(_isOnline ? Icons.check_circle : Icons.circle_outlined, color: _isOnline ? Colors.green.shade700 : Colors.blueGrey),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        _service == null ? 'Not connected' : _isOnline ? 'Live / online · ${_status!.deviceId} · ${_status!.firmware}' : 'Connected endpoint reports offline · ${_status!.deviceId}',
                        style: const TextStyle(color: _ink, fontWeight: FontWeight.w600),
                      )),
                    ]),
                    const SizedBox(height: 8),
                    const Text('A successful HTTP response is not proof that a physical LED, buzzer, medication action, or STM32 was activated.', style: TextStyle(color: _ink, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Device commands', style: TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    _field(label: 'Schedule JSON array', controller: _schedulesController, lines: 4),
                    const SizedBox(height: 12),
                    Wrap(spacing: 9, runSpacing: 9, children: [
                      FilledButton(onPressed: _service == null || _busy ? null : () => _runAction('Schedule request accepted by the adapter; physical behavior is not verified.', (service) async => service.sendSchedules(_decodeSchedules())), child: const Text('Send schedules')),
                      OutlinedButton.icon(onPressed: _service == null || _busy ? null : () => _runAction('LED test request accepted; physical LED behavior is not verified.', (service) => service.testLed()), icon: const Icon(Icons.light_mode_outlined), label: const Text('Test LED')),
                      OutlinedButton.icon(onPressed: _service == null || _busy ? null : () => _runAction('Buzzer test request accepted; physical buzzer behavior is not verified.', (service) => service.testBuzzer()), icon: const Icon(Icons.notifications_active_outlined), label: const Text('Test buzzer')),
                      OutlinedButton.icon(onPressed: _service == null || _busy ? null : () => _runAction('Reconnect request accepted by the adapter; physical reconnection is not verified.', (service) => service.reconnect()), icon: const Icon(Icons.refresh), label: const Text('Reconnect')),
                    ]),
                    if (_message != null) ...[
                      const SizedBox(height: 12),
                      Text(_message!, style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w600)),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text('Request failed: $_error', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Expanded(child: Text('Received device events', style: TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w700))),
                      Text('${_events.length}', style: const TextStyle(color: _ink, fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 10),
                    if (_events.isEmpty)
                      const Text('No events received from the device yet.', style: TextStyle(color: _ink))
                    else
                      ..._events.map((event) => Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: _background, borderRadius: BorderRadius.circular(13)),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(event.event == 'ACKNOWLEDGED' ? 'Dose acknowledged' : event.event, style: const TextStyle(color: _ink, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text('Schedule ${event.scheduleId} · Box ${event.box} · ${event.occurredAt.toLocal()}', style: const TextStyle(color: _ink, fontSize: 12)),
                              const Text('Device event only; this does not confirm medication ingestion.', style: TextStyle(color: _ink, fontSize: 12)),
                            ]),
                          )),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  List<Map<String, Object?>> _decodeSchedules() {
    final raw = jsonDecode(_schedulesController.text);
    if (raw is! List) throw const FormatException('Schedules must be a JSON array.');
    return raw.map((entry) {
      if (entry is! Map) throw const FormatException('Each schedule must be a JSON object.');
      return Map<String, Object?>.from(entry);
    }).toList();
  }
}
