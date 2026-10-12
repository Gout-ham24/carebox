import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CareRole { patient, primaryCaretaker, additionalCaretaker }
enum DoseStatus { acknowledged, appAcknowledged, missed, upcoming }
enum PageTab { home, schedule, history, circle, concerns, device, settings }

const boxOptions = <String>[
  'Box 1 Morning',
  'Box 2 Afternoon',
  'Box 3 Evening',
];

String roleLabel(CareRole role) => switch (role) {
  CareRole.patient => 'Patient',
  CareRole.primaryCaretaker => 'Primary caretaker',
  CareRole.additionalCaretaker => 'Additional caretaker',
};

String statusLabel(DoseStatus status) => switch (status) {
  DoseStatus.acknowledged => 'Dose acknowledged',
  DoseStatus.appAcknowledged => 'App acknowledgement recorded',
  DoseStatus.missed => 'Missed',
  DoseStatus.upcoming => 'Upcoming',
};

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
    : <Map<String, dynamic>>[];

class DoseSchedule {
  DoseSchedule({required this.id, required this.name, required this.box, required this.time, required this.days, this.enabled = true});
  final String id;
  String name;
  String box;
  TimeOfDay time;
  Set<int> days;
  bool enabled;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'box': box,
        'hour': time.hour,
        'minute': time.minute,
        'days': (days.toList()..sort()),
        'enabled': enabled,
      };

  static DoseSchedule? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final box = json['box'];
    final hour = json['hour'];
    final minute = json['minute'];
    if (id is! String || name is! String || box is! String || hour is! int || minute is! int) return null;
    final rawDays = json['days'];
    final days = rawDays is List
        ? rawDays.whereType<int>().where((d) => d >= 1 && d <= 7).toSet()
        : <int>{};
    return DoseSchedule(
      id: id,
      name: name,
      box: box,
      time: TimeOfDay(hour: hour.clamp(0, 23).toInt(), minute: minute.clamp(0, 59).toInt()),
      days: days.isEmpty ? {1, 2, 3, 4, 5, 6, 7} : days,
      enabled: json['enabled'] != false,
    );
  }
}

class DoseRecord {
  DoseRecord(this.name, this.when, this.status);
  final String name;
  final DateTime when;
  final DoseStatus status;

  Map<String, Object?> toJson() => {
        'name': name,
        'when': when.toIso8601String(),
        'status': status.name,
      };

  static DoseRecord? fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    final when = json['when'] is String ? DateTime.tryParse(json['when'] as String) : null;
    if (name is! String || when == null) return null;
    return DoseRecord(name, when, _enumByName(DoseStatus.values, json['status'], DoseStatus.missed));
  }
}

class CircleMember {
  CircleMember(this.name, this.email, this.role, this.invitation);
  String name;
  String email;
  CareRole role;
  String invitation;

  Map<String, Object?> toJson() => {
        'name': name,
        'email': email,
        'role': role.name,
        'invitation': invitation,
      };

  static CircleMember? fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    if (name is! String || name.isEmpty) return null;
    return CircleMember(
      name,
      json['email'] is String ? json['email'] as String : '',
      _enumByName(CareRole.values, json['role'], CareRole.additionalCaretaker),
      json['invitation'] is String ? json['invitation'] as String : 'Active',
    );
  }
}

class CareConcern {
  CareConcern(this.title, this.detail, this.raisedBy, this.createdAt, {this.status = 'Open', this.response = ''});
  final String title;
  final String detail;
  final String raisedBy;
  final DateTime createdAt;
  String status;
  String response;

  Map<String, Object?> toJson() => {
        'title': title,
        'detail': detail,
        'raisedBy': raisedBy,
        'createdAt': createdAt.toIso8601String(),
        'status': status,
        'response': response,
      };

  static CareConcern? fromJson(Map<String, dynamic> json) {
    final title = json['title'];
    final detail = json['detail'];
    final raisedBy = json['raisedBy'];
    final createdAt = json['createdAt'] is String ? DateTime.tryParse(json['createdAt'] as String) : null;
    if (title is! String || detail is! String || raisedBy is! String || createdAt == null) return null;
    return CareConcern(
      title,
      detail,
      raisedBy,
      createdAt,
      status: json['status'] is String ? json['status'] as String : 'Open',
      response: json['response'] is String ? json['response'] as String : '',
    );
  }
}

class CareBoxState extends ChangeNotifier {
  /// Pre-filled sample data. Kept so the existing automated tests keep working;
  /// the real app starts from [CareBoxState.load], which begins empty.
  CareBoxState() {
    _seedSampleData();
    _startClock();
  }

  /// A clean state with no sample people, schedules or history.
  CareBoxState.empty() {
    userName = '';
    notificationCenter.add(_welcomeNotice);
    _startClock();
  }

  static const _storageKey = 'carebox_state_v1';
  static const _welcomeNotice = 'Welcome to CareBox. Add a medicine and a time in Schedule to get started.';

  /// Loads saved data from this device (or starts empty on first launch).
  static Future<CareBoxState> load() async {
    final state = CareBoxState.empty();
    try {
      final prefs = await SharedPreferences.getInstance();
      state._prefs = prefs;
      final raw = prefs.getString(_storageKey);
      if (raw != null) state._restore(raw);
    } catch (_) {
      // Storage unavailable: continue with an empty, unsaved session.
    }
    return state;
  }

  SharedPreferences? _prefs;

  CareRole role = CareRole.patient;
  String userName = 'Margaret';
  bool signedIn = false;
  bool offline = false;
  bool ledOn = false;
  bool buzzerOn = false;
  bool alertsEnabled = true;
  bool doseRemindersEnabled = true;
  int responseWindowMinutes = 15;
  int? remainingSeconds;
  String _lastScheduledMinute = '';
  String? activeDose;
  DateTime? reminderStarted;
  PageTab tab = PageTab.home;
  String notice = '';
  final List<String> notificationCenter = [];
  final List<DoseSchedule> schedules = [];
  final List<DoseRecord> history = [];
  final List<CircleMember> members = [];
  final List<CareConcern> concerns = [];
  Timer? _clock;

  void _startClock() {
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _seedSampleData() {
    notificationCenter.add('CareBox demo is ready. Sample care circle loaded locally.');
    schedules.addAll([
      DoseSchedule(id: 's1', name: 'Morning vitamins', box: 'Box 1 Morning', time: const TimeOfDay(hour: 8, minute: 0), days: {1, 2, 3, 4, 5, 6, 7}),
      DoseSchedule(id: 's2', name: 'Afternoon medication', box: 'Box 2 Afternoon', time: const TimeOfDay(hour: 13, minute: 0), days: {1, 2, 3, 4, 5, 6, 7}),
      DoseSchedule(id: 's3', name: 'Evening medication', box: 'Box 3 Evening', time: const TimeOfDay(hour: 20, minute: 0), days: {1, 2, 3, 4, 5, 6, 7}),
    ]);
    history.addAll([
      DoseRecord('Morning vitamins', DateTime.now().subtract(const Duration(hours: 2)), DoseStatus.acknowledged),
      DoseRecord('Evening medication', DateTime.now().subtract(const Duration(days: 1, hours: 12)), DoseStatus.acknowledged),
      DoseRecord('Morning vitamins', DateTime.now().subtract(const Duration(days: 1, hours: 2)), DoseStatus.missed),
      DoseRecord('Evening medication', DateTime.now().subtract(const Duration(days: 2, hours: 12)), DoseStatus.acknowledged),
    ]);
    members.addAll([
      CircleMember('Margaret Ellis', 'margaret@example.com', CareRole.patient, 'Active'),
      CircleMember('Daniel Ellis', 'daniel@example.com', CareRole.primaryCaretaker, 'Active'),
      CircleMember('Sophie Ellis', 'sophie@example.com', CareRole.additionalCaretaker, 'Active'),
    ]);
  }

  // ---------------------------------------------------------------- storage

  Map<String, Object?> _toJson() => {
        'userName': userName,
        'role': role.name,
        'signedIn': signedIn,
        'alertsEnabled': alertsEnabled,
        'doseRemindersEnabled': doseRemindersEnabled,
        'responseWindowMinutes': responseWindowMinutes,
        'schedules': schedules.map((s) => s.toJson()).toList(),
        'history': history.take(500).map((r) => r.toJson()).toList(),
        'members': members.map((m) => m.toJson()).toList(),
        'concerns': concerns.map((c) => c.toJson()).toList(),
        'notifications': notificationCenter.take(50).toList(),
      };

  void _restore(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return;
    final data = Map<String, dynamic>.from(decoded);
    userName = data['userName'] is String ? data['userName'] as String : userName;
    role = _enumByName(CareRole.values, data['role'], CareRole.patient);
    signedIn = data['signedIn'] == true && userName.isNotEmpty;
    alertsEnabled = data['alertsEnabled'] != false;
    doseRemindersEnabled = data['doseRemindersEnabled'] != false;
    final window = data['responseWindowMinutes'];
    responseWindowMinutes = window is num ? window.toInt().clamp(5, 30).toInt() : 15;

    schedules
      ..clear()
      ..addAll(_maps(data['schedules']).map(DoseSchedule.fromJson).whereType<DoseSchedule>());
    history
      ..clear()
      ..addAll(_maps(data['history']).map(DoseRecord.fromJson).whereType<DoseRecord>());
    members
      ..clear()
      ..addAll(_maps(data['members']).map(CircleMember.fromJson).whereType<CircleMember>());
    concerns
      ..clear()
      ..addAll(_maps(data['concerns']).map(CareConcern.fromJson).whereType<CareConcern>());

    final notes = data['notifications'];
    if (notes is List) {
      notificationCenter
        ..clear()
        ..addAll(notes.whereType<String>());
    }
    if (notificationCenter.isEmpty) notificationCenter.add(_welcomeNotice);
  }

  void _save() {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      unawaited(prefs.setString(_storageKey, jsonEncode(_toJson())).catchError((_) => false));
    } catch (_) {
      // Saving is best-effort; the app keeps working in memory.
    }
  }

  void _changed() {
    _save();
    notifyListeners();
  }

  /// Erases everything saved on this device and returns to first-run state.
  Future<void> resetAll() async {
    activeDose = null;
    reminderStarted = null;
    remainingSeconds = null;
    ledOn = false;
    buzzerOn = false;
    schedules.clear();
    history.clear();
    members.clear();
    concerns.clear();
    notificationCenter
      ..clear()
      ..add(_welcomeNotice);
    userName = '';
    role = CareRole.patient;
    signedIn = false;
    tab = PageTab.home;
    alertsEnabled = true;
    doseRemindersEnabled = true;
    responseWindowMinutes = 15;
    notice = '';
    try {
      await _prefs?.remove(_storageKey);
    } catch (_) {}
    notifyListeners();
  }

  // --------------------------------------------------------------- derived

  int get missedLastTwoDays => history.where((d) => d.status == DoseStatus.missed && DateTime.now().difference(d.when) <= const Duration(days: 2)).length;
  int get acknowledgedToday => history.where((d) => (d.status == DoseStatus.acknowledged || d.status == DoseStatus.appAcknowledged) && d.when.year == DateTime.now().year && d.when.month == DateTime.now().month && d.when.day == DateTime.now().day).length;
  int get enabledToday => schedules.where((s) => s.enabled && s.days.contains(DateTime.now().weekday)).length;
  double get todayProgress => enabledToday == 0 ? 0 : (acknowledgedToday / enabledToday).clamp(0.0, 1.0).toDouble();
  bool get canManageSchedules => role != CareRole.additionalCaretaker;

  /// The primary caretaker manages the circle. Until one exists, the patient
  /// who set up the app on this phone can add people.
  bool get canManageCircle =>
      role == CareRole.primaryCaretaker ||
      (role == CareRole.patient && !members.any((m) => m.role == CareRole.primaryCaretaker));

  String get countdownText {
    final s = remainingSeconds ?? 0;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  /// The enabled schedule whose reminder time comes up soonest.
  DoseSchedule? get nextDoseSchedule {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DoseSchedule? best;
    DateTime? bestTime;
    for (final schedule in schedules.where((s) => s.enabled)) {
      for (var offset = 0; offset < 8; offset++) {
        final day = today.add(Duration(days: offset));
        if (!schedule.days.contains(day.weekday)) continue;
        final at = DateTime(day.year, day.month, day.day, schedule.time.hour, schedule.time.minute);
        if (at.isAfter(now)) {
          if (bestTime == null || at.isBefore(bestTime)) {
            best = schedule;
            bestTime = at;
          }
          break;
        }
      }
    }
    return best;
  }

  // --------------------------------------------------------------- actions

  void signIn({required String name, required CareRole selectedRole, String email = ''}) {
    userName = name.trim().isEmpty ? 'CareBox member' : name.trim();
    role = selectedRole;
    signedIn = true;
    final known = members.any((m) => m.name.toLowerCase() == userName.toLowerCase());
    if (!known) members.add(CircleMember(userName, email.trim(), selectedRole, 'Active'));
    _changed();
  }

  void signOut() {
    signedIn = false;
    tab = PageTab.home;
    _changed();
  }

  void selectTab(PageTab value) {
    tab = value;
    notifyListeners();
  }

  void setResponseWindow(int value) {
    responseWindowMinutes = value.clamp(5, 30).toInt();
    _changed();
  }

  void setRole(CareRole value) {
    role = value;
    _changed();
  }

  void setDoseReminders(bool value) {
    doseRemindersEnabled = value;
    _changed();
  }

  void setAlerts(bool value) {
    alertsEnabled = value;
    _changed();
  }

  void addNotice(String message) {
    notice = message;
    notificationCenter.insert(0, message);
    if (notificationCenter.length > 50) {
      notificationCenter.removeRange(50, notificationCenter.length);
    }
    _changed();
  }

  String? scheduleConflict(TimeOfDay time, Set<int> days, {String? excludingId}) {
    final candidate = time.hour * 60 + time.minute;
    for (final item in schedules.where((schedule) =>
        schedule.enabled &&
        schedule.id != excludingId &&
        schedule.days.intersection(days).isNotEmpty)) {
      final existing = item.time.hour * 60 + item.time.minute;
      if (candidate == existing) {
        return 'Two medicines are scheduled at the same time. Please choose different times.';
      }
    }
    return null;
  }

  String? saveSchedule({String? id, required String name, required String box, required TimeOfDay time, required Set<int> days, required bool enabled}) {
    if (name.trim().isEmpty || days.isEmpty) return 'Add a name and select at least one day.';
    if (!boxOptions.contains(box)) return 'Choose one of the three CareBox compartments.';
    if (enabled) {
      final conflict = scheduleConflict(time, days, excludingId: id);
      if (conflict != null) return conflict;
    }
    final boxAlreadyAssigned = schedules.any(
      (schedule) => schedule.id != id && schedule.box == box,
    );
    if (boxAlreadyAssigned) {
      return 'This box already has a medicine. Edit its schedule instead.';
    }
    if (id == null) {
      schedules.add(DoseSchedule(id: DateTime.now().microsecondsSinceEpoch.toString(), name: name.trim(), box: box, time: time, days: Set.of(days), enabled: enabled));
    } else {
      final item = schedules.firstWhere((s) => s.id == id);
      item.name = name.trim(); item.box = box; item.time = time; item.days = Set.of(days); item.enabled = enabled;
    }
    addNotice('Schedule saved for $name.');
    return null;
  }

  void removeSchedule(String id) {
    schedules.removeWhere((s) => s.id == id);
    _changed();
  }

  void toggleSchedule(DoseSchedule s, bool value) {
    if (value) {
      final conflict = scheduleConflict(s.time, s.days, excludingId: s.id);
      if (conflict != null) {
        addNotice(conflict);
        return;
      }
    }
    s.enabled = value;
    _changed();
  }

  void startReminder({String? name}) {
    if (activeDose != null) return;
    if (name == null && schedules.isEmpty) {
      addNotice('Add a medicine in Schedule before testing a reminder.');
      return;
    }
    activeDose = name ?? schedules.firstWhere((s) => s.enabled, orElse: () => schedules.first).name;
    reminderStarted = DateTime.now();
    remainingSeconds = responseWindowMinutes * 60;
    ledOn = true; buzzerOn = true;
    addNotice('Reminder started for $activeDose. The device LED and buzzer are active.');
  }

  void acknowledgeDose() {
    if (activeDose == null) return;
    history.insert(0, DoseRecord(activeDose!, DateTime.now(), DoseStatus.appAcknowledged));
    addNotice('App acknowledgement recorded. This does not confirm medication was taken.');
    _clearReminder();
  }

  void simulatePhysicalButtonPress() {
    if (activeDose == null) return;
    history.insert(0, DoseRecord(activeDose!, DateTime.now(), DoseStatus.acknowledged));
    addNotice('Dose acknowledged. Simulated physical button press; ingestion is not confirmed.');
    _clearReminder();
  }

  void markMissed() {
    if (activeDose == null) return;
    history.insert(0, DoseRecord(activeDose!, DateTime.now(), DoseStatus.missed));
    addNotice('The response window ended without an acknowledgement.');
    _clearReminder();
  }

  void _clearReminder() {
    activeDose = null;
    reminderStarted = null;
    remainingSeconds = null;
    ledOn = false;
    buzzerOn = false;
    notifyListeners();
  }

  void _tick() {
    final now = DateTime.now();
    if (activeDose == null) {
      if (!doseRemindersEnabled) return;
      final due = schedules.where((s) => s.enabled && s.days.contains(now.weekday) && s.time.hour == now.hour && s.time.minute == now.minute).toList();
      final minuteKey = '${now.year}-${now.month}-${now.day}-${now.hour}-${now.minute}';
      if (due.isNotEmpty && minuteKey != _lastScheduledMinute) {
        _lastScheduledMinute = minuteKey;
        startReminder(name: due.first.name);
      }
      return;
    }
    if (remainingSeconds == null) return;
    remainingSeconds = remainingSeconds! - 1;
    if (remainingSeconds! <= 0) {
      markMissed();
      return;
    }
    notifyListeners();
  }

  bool confirmRepeatedMissesAndRaiseConcern() {
    if (missedLastTwoDays <= 3) return false;
    concerns.insert(0, CareConcern('Several missed reminders', '$missedLastTwoDays missed reminders were recorded in the last 2 days. Please check in with the care circle.', userName, DateTime.now()));
    addNotice('A care concern was shared with the circle.');
    return true;
  }

  void addMember(String name, String email, CareRole memberRole) {
    members.add(CircleMember(name.trim(), email.trim(), memberRole, 'Added on this phone'));
    addNotice('${name.trim()} was added to the care circle on this phone. No invitation was sent to ${email.trim()}.');
  }

  void removeMember(CircleMember member) {
    if (!canManageCircle || member.role == CareRole.primaryCaretaker) return;
    members.remove(member);
    addNotice('${member.name} was removed from the care circle.');
  }

  void raiseConcern(String title, String detail) {
    concerns.insert(0, CareConcern(title, detail, userName, DateTime.now()));
    addNotice('Concern shared with the care circle.');
  }

  void respondToConcern(CareConcern concern, String response) {
    concern.response = response;
    concern.status = 'Responded';
    _changed();
  }

  void resolveConcern(CareConcern concern) {
    concern.status = 'Resolved';
    _changed();
  }

  void withdrawConcern(CareConcern concern) {
    if (concern.raisedBy == userName) {
      concern.status = 'Withdrawn';
      _changed();
    }
  }

  void testDevice() {
    ledOn = true;
    buzzerOn = true;
    addNotice('Device test simulated: LED and buzzer were activated locally.');
    Future.delayed(const Duration(seconds: 2), () {
      ledOn = false;
      buzzerOn = false;
      notifyListeners();
    });
  }

  void reconnect() {
    offline = false;
    addNotice('Simulated connection restored locally.');
  }

  void toggleOffline(bool value) {
    offline = value;
    addNotice(value ? 'Device is offline. Reminders remain visible in the app.' : 'Device connection restored.');
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }
}
