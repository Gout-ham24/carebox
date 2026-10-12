import 'package:flutter/material.dart';
import 'care_state.dart';
import 'services/device_service.dart';
import 'services/wifi_connection_screen.dart';

// Cloud accounts, push notifications and the physical box are not connected yet,
// so the device screen stays a clearly labelled simulation.
const bool demoMode = true;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = await CareBoxState.load();
  runApp(CareBoxApp(state: state));
}

const ink = Color(0xFF203047);
const blue = Color(0xFF6C9CE8);
const cyan = Color(0xFF8CC9D7);
const canvas = Color(0xFFF1F6FA);

class CareBoxApp extends StatefulWidget {
  const CareBoxApp({super.key, this.state});
  final CareBoxState? state;
  @override
  State<CareBoxApp> createState() => _CareBoxAppState();
}

class _CareBoxAppState extends State<CareBoxApp> {
  late final CareBoxState state = widget.state ?? CareBoxState();
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: state,
    builder: (context, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CareBox',
      theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: canvas, colorScheme: ColorScheme.fromSeed(seedColor: blue, primary: ink, surface: canvas), fontFamily: 'Roboto', appBarTheme: const AppBarTheme(backgroundColor: canvas, foregroundColor: ink, elevation: 0)),
      home: state.signedIn ? CareShell(state: state) : LoginScreen(state: state),
    ),
  );
}

class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(18)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: padding, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .76), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white, width: 1.4), boxShadow: [BoxShadow(color: ink.withValues(alpha: .045), blurRadius: 22, offset: const Offset(0, 9))]), child: child);
}

class CareShell extends StatelessWidget {
  const CareShell({super.key, required this.state});

  final CareBoxState state;

  @override
  Widget build(BuildContext context) {
    final pages = <PageTab, Widget>{
      PageTab.home: DashboardScreen(state: state),
      PageTab.schedule: ScheduleScreen(state: state),
      PageTab.history: HistoryScreen(state: state),
      PageTab.circle: CircleScreen(state: state),
      PageTab.concerns: ConcernScreen(state: state),
      PageTab.device: DeviceScreen(state: state),
      PageTab.settings: SettingsScreen(state: state),
    };
    const destinations = <NavigationDestination>[
      NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
      NavigationDestination(icon: Icon(Icons.schedule), label: 'Schedule'),
      NavigationDestination(icon: Icon(Icons.history), label: 'History'),
      NavigationDestination(icon: Icon(Icons.people_outline), label: 'Circle'),
      NavigationDestination(icon: Icon(Icons.favorite_border), label: 'Concerns'),
      NavigationDestination(icon: Icon(Icons.memory), label: 'Device'),
      NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
    ];
    const railDestinations = <NavigationRailDestination>[
      NavigationRailDestination(icon: Icon(Icons.home_outlined), label: Text('Home')),
      NavigationRailDestination(icon: Icon(Icons.schedule), label: Text('Schedule')),
      NavigationRailDestination(icon: Icon(Icons.history), label: Text('History')),
      NavigationRailDestination(icon: Icon(Icons.people_outline), label: Text('Circle')),
      NavigationRailDestination(icon: Icon(Icons.favorite_border), label: Text('Concerns')),
      NavigationRailDestination(icon: Icon(Icons.memory), label: Text('Device')),
      NavigationRailDestination(icon: Icon(Icons.settings_outlined), label: Text('Settings')),
    ];

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wideLayout = constraints.maxWidth >= 720;
            final currentPage = pages[state.tab]!;
            final pageContent = Column(
              children: [
                if (state.offline)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    color: const Color(0xFFFFE8C2),
                    child: const Text(
                      'Device offline (simulated) · app reminders remain available',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: ink, fontWeight: FontWeight.w600),
                    ),
                  ),
                Expanded(child: currentPage),
              ],
            );

            if (wideLayout) {
              return Row(
                children: [
                  NavigationRail(
                    selectedIndex: state.tab.index,
                    onDestinationSelected: (index) =>
                        state.selectTab(PageTab.values[index]),
                    labelType: NavigationRailLabelType.all,
                    destinations: railDestinations,
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: pageContent,
                      ),
                    ),
                  ),
                ],
              );
            }

            return Column(
              children: [
                Expanded(child: pageContent),
                NavigationBar(
                  selectedIndex: state.tab.index,
                  onDestinationSelected: (index) =>
                      state.selectTab(PageTab.values[index]),
                  destinations: destinations,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.state});
  final CareBoxState state;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  CareRole role = CareRole.patient;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    super.dispose();
  }

  void _continue() {
    final name = nameController.text.trim();
    if (name.isEmpty) {
      _message(context, 'Please enter your name.');
      return;
    }
    widget.state.signIn(name: name, selectedRole: role, email: emailController.text);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 28),
                    Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        color: blue.withValues(alpha: .15),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(
                        Icons.medication_liquid,
                        color: ink,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'CareBox',
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'A calmer way to stay in sync with care.',
                      style: TextStyle(fontSize: 17, color: Color(0xFF52647B)),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Your schedules and history are saved on this phone only. There is no account, cloud sync or push notification service connected yet.',
                      style: TextStyle(color: Color(0xFF617287), fontSize: 13),
                    ),
                    const SizedBox(height: 22),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Set up CareBox',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: ink,
                            ),
                          ),
                          const SizedBox(height: 18),
                          TextField(
                            controller: nameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Your name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email (optional)',
                              prefixIcon: Icon(Icons.mail_outline),
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<CareRole>(
                            value: role,
                            decoration: const InputDecoration(
                              labelText: 'I am using CareBox as',
                            ),
                            items: CareRole.values
                                .map(
                                  (option) => DropdownMenuItem(
                                    value: option,
                                    child: Text(roleLabel(option)),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() => role = value ?? role);
                            },
                          ),
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: _continue,
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('Continue'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              backgroundColor: ink,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.state});

  final CareBoxState state;

  @override
  Widget build(BuildContext context) {
    final nextSchedule = state.nextDoseSchedule;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your care, at a glance',
                    style: TextStyle(color: Color(0xFF64758A), fontSize: 14),
                  ),
                  Text(
                    'Hello, ${state.userName}',
                    style: const TextStyle(
                      color: ink,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _showNotifications(context, state),
              icon: const Icon(Icons.notifications_none, color: ink),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GlassCard(
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: cyan.withValues(alpha: .28),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.check_circle_outline, color: ink),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Today’s progress',
                      style: TextStyle(
                        color: ink,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      '${state.acknowledgedToday} of ${state.enabledToday} reminders acknowledged today',
                      style: const TextStyle(color: Color(0xFF617287)),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 52,
                height: 52,
                child: CircularProgressIndicator(
                  value: state.todayProgress,
                  strokeWidth: 6,
                  backgroundColor: canvas,
                  color: blue,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (state.activeDose != null)
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.notifications_active, color: blue),
                    const SizedBox(width: 8),
                    const Text(
                      'Reminder active',
                      style: TextStyle(
                        color: ink,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      state.countdownText,
                      style: const TextStyle(
                        color: ink,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  state.activeDose!,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'An app acknowledgement is not a device button press or confirmation that medication was taken.',
                  style: TextStyle(color: Color(0xFF5D6E82)),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: state.acknowledgeDose,
                  style: FilledButton.styleFrom(
                    backgroundColor: ink,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Record app acknowledgement'),
                ),
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: () => state.selectTab(PageTab.device),
                  icon: const Icon(Icons.memory),
                  label: const Text('Open device screen'),
                ),
              ],
            ),
          ),
        if (state.activeDose != null) const SizedBox(height: 14),
        GlassCard(
          child: Row(
            children: [
              const Icon(Icons.access_time, color: blue, size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Next dose',
                      style: TextStyle(color: Color(0xFF617287)),
                    ),
                    Text(
                      nextSchedule?.name ?? 'No scheduled medicines',
                      style: const TextStyle(
                        color: ink,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      nextSchedule == null
                          ? 'Add a reminder in Schedule'
                          : '${_formatTime(nextSchedule.time)} · ${nextSchedule.box}',
                      style: const TextStyle(color: Color(0xFF617287)),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => state.selectTab(PageTab.schedule),
                child: Text(nextSchedule == null ? 'Add' : 'View'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (state.missedLastTwoDays > 3)
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'A gentle check-in may help',
                  style: TextStyle(
                    color: ink,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${state.missedLastTwoDays} reminders were missed in the last 2 days. Review before sharing a concern.',
                  style: const TextStyle(color: Color(0xFF617287)),
                ),
                TextButton.icon(
                  onPressed: () => _confirmConcern(context, state),
                  icon: const Icon(Icons.favorite_border),
                  label: const Text('Review and raise concern'),
                ),
              ],
            ),
          ),
        const SizedBox(height: 14),
        const Text(
          'Quick actions',
          style: TextStyle(color: ink, fontSize: 19, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            ActionChip(
              avatar: const Icon(Icons.notifications_active_outlined),
              label: const Text('Test a reminder'),
              onPressed: state.startReminder,
            ),
            ActionChip(
              avatar: const Icon(Icons.warning_amber_outlined),
              label: const Text('Raise a concern'),
              onPressed: () => state.selectTab(PageTab.concerns),
            ),
            ActionChip(
              avatar: const Icon(Icons.devices_outlined),
              label: const Text('Device'),
              onPressed: () => state.selectTab(PageTab.device),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Recent activity',
          style: TextStyle(color: ink, fontSize: 19, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 9),
        if (state.history.isEmpty)
          const GlassCard(
            child: Text(
              'No activity yet. Reminders and acknowledgements will appear here.',
              style: TextStyle(color: Color(0xFF617287)),
            ),
          ),
        ...state.history.take(3).map(
          (record) => Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: GlassCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    record.status == DoseStatus.acknowledged ||
                            record.status == DoseStatus.appAcknowledged
                        ? Icons.check_circle_outline
                        : Icons.info_outline,
                    color: record.status == DoseStatus.acknowledged ||
                            record.status == DoseStatus.appAcknowledged
                        ? const Color(0xFF39836D)
                        : const Color(0xFFB77B31),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      '${record.name} · ${statusLabel(record.status)}',
                      style: const TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    _timeLabel(record.when),
                    style: const TextStyle(
                      color: Color(0xFF718197),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key, required this.state});

  final CareBoxState state;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Schedules',
            style: TextStyle(color: ink, fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const Text(
            'Set one medicine and reminder time for each of the three boxes.',
            style: TextStyle(color: Color(0xFF617287)),
          ),
          const SizedBox(height: 18),
          if (state.schedules.isEmpty)
            const GlassCard(
              child: Text(
                'No schedules are set. Add a medicine and time to a CareBox.',
                style: TextStyle(color: Color(0xFF617287)),
              ),
            ),
          ...state.schedules.map(
            (schedule) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            schedule.name,
                            style: const TextStyle(
                              color: ink,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Switch(
                          value: schedule.enabled,
                          onChanged: state.canManageSchedules
                              ? (value) => state.toggleSchedule(schedule, value)
                              : null,
                        ),
                      ],
                    ),
                    Text(
                      '${_formatTime(schedule.time)} · ${schedule.box}',
                      style: const TextStyle(color: Color(0xFF617287)),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _days(schedule.days),
                      style: const TextStyle(color: Color(0xFF617287)),
                    ),
                    if (state.canManageSchedules)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => _scheduleDialog(
                              context,
                              state,
                              schedule: schedule,
                            ),
                            child: const Text('Edit'),
                          ),
                          TextButton(
                            onPressed: () => _confirmRemoveSchedule(
                              context,
                              state,
                              schedule,
                            ),
                            child: const Text('Remove'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (!state.canManageSchedules)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Schedule changes are managed by the primary caretaker.',
                style: TextStyle(color: Color(0xFF617287)),
              ),
            ),
          if (state.canManageSchedules)
            FilledButton.icon(
              onPressed: () => _scheduleDialog(context, state),
              icon: const Icon(Icons.add),
              label: const Text('Add schedule'),
              style: FilledButton.styleFrom(
                backgroundColor: ink,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: state.startReminder,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Test a reminder'),
          ),
          const SizedBox(height: 10),
          const Text(
            'Reminders appear while CareBox is open. Alerts when the app is closed need a notification service that is not set up yet.',
            style: TextStyle(color: Color(0xFF617287), fontSize: 12),
          ),
        ],
      );
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.state});

  final CareBoxState state;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String period = 'Today';

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final filtered = widget.state.history.where((record) {
      if (period == 'Today') {
        return record.when.year == now.year &&
            record.when.month == now.month &&
            record.when.day == now.day;
      }
      if (period == 'This week') {
        return now.difference(record.when).inDays < 7;
      }
      return now.difference(record.when).inDays < 31;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Dose history',
          style: TextStyle(color: ink, fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const Text(
          'A record of reminders and the acknowledgement method.',
          style: TextStyle(color: Color(0xFF617287)),
        ),
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'Today', label: Text('Today')),
            ButtonSegment(value: 'This week', label: Text('Week')),
            ButtonSegment(value: 'This month', label: Text('Month')),
          ],
          selected: {period},
          onSelectionChanged: (selection) {
            setState(() => period = selection.first);
          },
        ),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          const GlassCard(
            child: Text(
              'No dose events in this period yet.',
              style: TextStyle(color: ink),
            ),
          )
        else
          ...filtered.map(
            (record) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                padding: const EdgeInsets.all(15),
                child: Row(
                  children: [
                    Icon(
                      record.status == DoseStatus.missed
                          ? Icons.error_outline
                          : Icons.check_circle_outline,
                      color: record.status == DoseStatus.missed
                          ? const Color(0xFFB77B31)
                          : const Color(0xFF39836D),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.name,
                            style: const TextStyle(
                              color: ink,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            statusLabel(record.status),
                            style: const TextStyle(color: Color(0xFF617287)),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${record.when.month}/${record.when.day} · ${_timeLabel(record.when)}',
                      style: const TextStyle(
                        color: Color(0xFF617287),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        const Text(
          '“Dose acknowledged” identifies a device-button event. In-app acknowledgements are labeled separately. Neither confirms medication was taken.',
          style: TextStyle(color: Color(0xFF617287), fontSize: 13),
        ),
      ],
    );
  }
}

class CircleScreen extends StatelessWidget {
  const CircleScreen({super.key, required this.state});

  final CareBoxState state;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Care circle',
            style: TextStyle(color: ink, fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const Text(
            'Support, with clear roles and respectful communication.',
            style: TextStyle(color: Color(0xFF617287)),
          ),
          const SizedBox(height: 18),
          ...state.members.map(
            (member) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                padding: const EdgeInsets.all(15),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: cyan.withValues(alpha: .35),
                      child: Text(
                        member.name.isEmpty ? '?' : member.name[0],
                        style: const TextStyle(
                          color: ink,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.name,
                            style: const TextStyle(
                              color: ink,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${roleLabel(member.role)} · ${member.invitation}',
                            style: const TextStyle(
                              color: Color(0xFF617287),
                              fontSize: 13,
                            ),
                          ),
                          if (member.email.isNotEmpty)
                            Text(
                              member.email,
                              style: const TextStyle(
                                color: Color(0xFF617287),
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (state.canManageCircle &&
                        member.role != CareRole.primaryCaretaker &&
                        member.name != state.userName)
                      IconButton(
                        onPressed: () =>
                            _confirmRemoveMember(context, state, member),
                        icon: const Icon(
                          Icons.person_remove_outlined,
                          color: Color(0xFF8A5460),
                        ),
                        tooltip: 'Remove member',
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (state.canManageCircle)
            FilledButton.icon(
              onPressed: () => _memberDialog(context, state),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add a caretaker'),
              style: FilledButton.styleFrom(
                backgroundColor: ink,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          if (!state.canManageCircle)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Only the primary caretaker can change care-circle membership.',
                style: TextStyle(color: Color(0xFF617287)),
              ),
            ),
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              'People you add are saved on this phone. Invitations are not sent and other phones do not see this circle yet.',
              style: TextStyle(color: Color(0xFF617287), fontSize: 12),
            ),
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: () => state.selectTab(PageTab.concerns),
            icon: const Icon(Icons.favorite_border),
            label: const Text('View shared concerns'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      );
}

class ConcernScreen extends StatelessWidget {
  const ConcernScreen({super.key, required this.state});

  final CareBoxState state;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Shared concerns',
            style: TextStyle(color: ink, fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Use this space for respectful check-ins and shared responses.',
            style: TextStyle(color: Color(0xFF617287)),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _raiseConcernDialog(context, state),
            icon: const Icon(Icons.add),
            label: const Text('Raise a concern'),
            style: FilledButton.styleFrom(
              backgroundColor: ink,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 14),
          if (state.concerns.isEmpty)
            const GlassCard(
              child: Text(
                'No concerns have been raised. You can start a respectful check-in at any time.',
                style: TextStyle(color: Color(0xFF617287)),
              ),
            )
          else
            ...state.concerns.map(
              (concern) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ConcernCard(state: state, concern: concern),
              ),
            ),
        ],
      );
}

class ConcernCard extends StatelessWidget {
  const ConcernCard({super.key, required this.state, required this.concern});

  final CareBoxState state;
  final CareConcern concern;

  @override
  Widget build(BuildContext context) => GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    concern.title,
                    style: const TextStyle(
                      color: ink,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(
                  label: Text(concern.status),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            Text(
              'Raised by ${concern.raisedBy} · ${_timeLabel(concern.createdAt)}',
              style: const TextStyle(color: Color(0xFF617287), fontSize: 12),
            ),
            const SizedBox(height: 7),
            Text(concern.detail, style: const TextStyle(color: ink)),
            if (concern.response.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Response: ${concern.response}',
                  style: const TextStyle(color: Color(0xFF52647B)),
                ),
              ),
            Wrap(
              children: [
                if (state.role != CareRole.patient &&
                    concern.status != 'Resolved' &&
                    concern.status != 'Withdrawn')
                  TextButton(
                    onPressed: () => _respondDialog(context, state, concern),
                    child: const Text('Respond'),
                  ),
                if (state.role != CareRole.patient &&
                    concern.status != 'Resolved' &&
                    concern.status != 'Withdrawn')
                  TextButton(
                    onPressed: () => state.resolveConcern(concern),
                    child: const Text('Resolve'),
                  ),
                if (concern.raisedBy == state.userName &&
                    concern.status != 'Withdrawn' &&
                    concern.status != 'Resolved')
                  TextButton(
                    onPressed: () => state.withdrawConcern(concern),
                    child: const Text('Withdraw'),
                  ),
              ],
            ),
          ],
        ),
      );
}

class DemoDeviceScreen extends StatelessWidget {
  const DemoDeviceScreen({super.key, required this.state});

  final CareBoxState state;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'CareBox device',
            style: TextStyle(color: ink, fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const Text(
            'Simulated device · no physical CareBox is connected. Use the Wi-Fi option above for real hardware.',
            style: TextStyle(color: Color(0xFF617287)),
          ),
          const SizedBox(height: 18),
          GlassCard(
            child: Column(
              children: [
                _deviceRow(Icons.memory, 'CareBox One', 'Simulated device · not STM32 telemetry'),
                const Divider(height: 24),
                _deviceRow(
                  Icons.wifi,
                  state.offline ? 'Offline simulation' : 'Connected simulation',
                  state.offline ? 'Simulated offline state' : 'Simulated session only',
                ),
                const Divider(height: 24),
                _deviceRow(
                  Icons.lightbulb_outline,
                  'LED indicator',
                  state.ledOn ? 'Simulated active' : 'Standby',
                ),
                const Divider(height: 24),
                _deviceRow(
                  Icons.volume_up_outlined,
                  'Buzzer',
                  state.buzzerOn ? 'Simulated active' : 'Standby',
                ),
                const Divider(height: 24),
                _deviceRow(
                  Icons.timer_outlined,
                  'Response window',
                  '${state.responseWindowMinutes} minutes',
                ),
                const Divider(height: 24),
                _deviceRow(
                  Icons.display_settings_outlined,
                  'LCD status simulation',
                  state.activeDose == null
                      ? 'CareBox ready'
                      : '${state.activeDose} · ${state.countdownText}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: state.testDevice,
            icon: const Icon(Icons.tune),
            label: const Text('Run simulated LED and buzzer test'),
            style: FilledButton.styleFrom(
              backgroundColor: ink,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
            ),
          ),
          if (state.activeDose != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: state.simulatePhysicalButtonPress,
              icon: const Icon(Icons.touch_app_outlined),
              label: const Text('Simulate physical device button press'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Simulated event only · records “Dose acknowledged”; it does not confirm medication was taken.',
                style: TextStyle(color: Color(0xFF617287), fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 9),
          OutlinedButton.icon(
            onPressed: state.reconnect,
            icon: const Icon(Icons.refresh),
            label: const Text('Reset simulated connection'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
          SwitchListTile(
            title: const Text('Simulate device offline'),
            subtitle: const Text('Simulation only · reminders stay in the app'),
            value: state.offline,
            onChanged: state.toggleOffline,
          ),
          const GlassCard(
            child: Text(
              'LED, buzzer, display, connection and button events on this screen are simulated. There is no live STM32 implementation, authenticated device backend, or physical hardware connection here.',
              style: TextStyle(color: Color(0xFF52647B)),
            ),
          ),
        ],
      );
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.state});

  final CareBoxState state;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Settings',
            style: TextStyle(color: ink, fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const Text(
            'Tune reminders and how CareBox works on this phone.',
            style: TextStyle(color: Color(0xFF617287)),
          ),
          const SizedBox(height: 16),
          GlassCard(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Dose reminders'),
                  subtitle: const Text('In-app reminders for scheduled doses'),
                  value: state.doseRemindersEnabled,
                  onChanged: state.setDoseReminders,
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Care-circle updates'),
                  subtitle: const Text('Shared concerns and circle changes'),
                  value: state.alertsEnabled,
                  onChanged: state.setAlerts,
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.timer_outlined, color: blue),
                  title: const Text('Response window'),
                  subtitle: Text(
                    '${state.responseWindowMinutes} minutes after reminder begins',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _responseWindowDialog(context, state),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your role on this phone',
                  style: TextStyle(color: ink, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<CareRole>(
                  value: state.role,
                  items: CareRole.values
                      .map(
                        (role) => DropdownMenuItem(
                          value: role,
                          child: Text(roleLabel(role)),
                        ),
                      )
                      .toList(),
                  onChanged: (role) {
                    if (role != null) state.setRole(role);
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Role',
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'This decides what you can change on this phone. It is not a login or an account permission.',
                  style: TextStyle(color: Color(0xFF617287), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ListTile(
            leading: const Icon(Icons.notifications_none, color: blue),
            title: const Text('Notification center'),
            subtitle: Text('${state.notificationCenter.length} updates'),
            onTap: () => _showNotifications(context, state),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline, color: blue),
            title: const Text('About CareBox'),
            subtitle: const Text('Version 1.0 · Saved on this device'),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'CareBox',
              applicationVersion: '1.0',
              children: const [
                Text(
                  'CareBox helps people and their care circle coordinate medication reminders. An acknowledgement records an app action or a device button event, not medication ingestion.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: state.signOut,
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF8A5460),
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => _confirmReset(context, state),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Erase all data on this phone'),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFB42318)),
          ),
        ],
      );
}

Widget _deviceRow(IconData icon, String title, String detail) => Row(children: [Icon(icon, color: blue), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: ink, fontWeight: FontWeight.bold)), Text(detail, style: const TextStyle(color: Color(0xFF617287), fontSize: 13))]))]);
String _formatTime(TimeOfDay t) => '${t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod}:${t.minute.toString().padLeft(2, '0')} ${t.period == DayPeriod.am ? 'AM' : 'PM'}';
String _timeLabel(DateTime d) => _formatTime(TimeOfDay.fromDateTime(d));
String _days(Set<int> days) => days.length == 7 ? 'Every day' : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].asMap().entries.where((e) => days.contains(e.key + 1)).map((e) => e.value).join(' · ');
void _message(BuildContext context, String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

Future<void> _confirmReset(BuildContext context, CareBoxState state) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Erase all data?'),
      content: const Text(
        'This deletes your schedules, history, care circle and concerns from this phone and returns CareBox to its first-run screen. This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Erase everything'),
        ),
      ],
    ),
  );
  if (confirmed == true) await state.resetAll();
}

Future<void> _scheduleDialog(
  BuildContext context,
  CareBoxState state, {
  DoseSchedule? schedule,
}) async {
  final nameController = TextEditingController(text: schedule?.name ?? '');
  var time = schedule?.time ?? TimeOfDay.now();
  var box = schedule?.box ?? boxOptions.first;
  var days = Set<int>.of(schedule?.days ?? {1, 2, 3, 4, 5, 6, 7});
  var enabled = schedule?.enabled ?? true;
  var errorMessage = '';

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setLocalState) => AlertDialog(
        title: Text(schedule == null ? 'Add schedule' : 'Edit schedule'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Medication or reminder',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: box,
                decoration: const InputDecoration(labelText: 'CareBox box'),
                items: boxOptions
                    .map(
                      (option) => DropdownMenuItem(
                        value: option,
                        child: Text(option),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setLocalState(() => box = value ?? box);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Reminder time'),
                subtitle: Text(_formatTime(time)),
                trailing: const Icon(Icons.access_time),
                onTap: () async {
                  final pickedTime = await showTimePicker(
                    context: dialogContext,
                    initialTime: time,
                  );
                  if (pickedTime != null) {
                    setLocalState(() => time = pickedTime);
                  }
                },
              ),
              Wrap(
                spacing: 2,
                children: List.generate(
                  7,
                  (index) => FilterChip(
                    label: Text(['M', 'T', 'W', 'T', 'F', 'S', 'S'][index]),
                    selected: days.contains(index + 1),
                    onSelected: (selected) {
                      setLocalState(() {
                        if (selected) {
                          days.add(index + 1);
                        } else {
                          days.remove(index + 1);
                        }
                      });
                    },
                  ),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enabled'),
                value: enabled,
                onChanged: (value) {
                  setLocalState(() => enabled = value);
                },
              ),
              if (errorMessage.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    errorMessage,
                    style: const TextStyle(color: Color(0xFFB42318)),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final issue = state.saveSchedule(
                id: schedule?.id,
                name: nameController.text,
                box: box,
                time: time,
                days: days,
                enabled: enabled,
              );
              if (issue != null) {
                setLocalState(() => errorMessage = issue);
              } else {
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  nameController.dispose();
}

Future<void> _confirmRemoveSchedule(
  BuildContext context,
  CareBoxState state,
  DoseSchedule schedule,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Remove schedule?'),
      content: Text('Remove ${schedule.name} from ${schedule.box}?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Keep schedule'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Remove'),
        ),
      ],
    ),
  );
  if (confirmed == true) state.removeSchedule(schedule.id);
}

Future<void> _confirmRemoveMember(
  BuildContext context,
  CareBoxState state,
  CircleMember member,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Remove care-circle member?'),
      content: Text('Remove ${member.name} from this care circle?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Remove member'),
        ),
      ],
    ),
  );
  if (confirmed == true) state.removeMember(member);
}

Future<void> _memberDialog(BuildContext context, CareBoxState state) async {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  var memberRole = CareRole.additionalCaretaker;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setLocalState) => AlertDialog(
        title: const Text('Add to care circle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            DropdownButtonFormField<CareRole>(
              value: memberRole,
              items: CareRole.values
                  .where((role) => role != CareRole.primaryCaretaker || state.role == CareRole.primaryCaretaker)
                  .map(
                    (role) => DropdownMenuItem(
                      value: role,
                      child: Text(roleLabel(role)),
                    ),
                  )
                  .toList(),
              onChanged: (role) {
                setLocalState(() {
                  memberRole = role ?? memberRole;
                });
              },
              decoration: const InputDecoration(labelText: 'Role'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              final email = emailController.text.trim();
              if (name.isEmpty || !email.contains('@')) return;
              state.addMember(name, email, memberRole);
              Navigator.pop(dialogContext);
            },
            child: const Text('Add to circle'),
          ),
        ],
      ),
    ),
  );
  nameController.dispose();
  emailController.dispose();
}

Future<void> _raiseConcernDialog(
  BuildContext context,
  CareBoxState state,
) async {
  final titleController = TextEditingController();
  final detailController = TextEditingController();

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Start a respectful check-in'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: titleController,
            decoration: const InputDecoration(labelText: 'Topic'),
          ),
          TextField(
            controller: detailController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'What would you like the circle to know?',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final title = titleController.text.trim();
            final detail = detailController.text.trim();
            if (title.isEmpty || detail.isEmpty) return;
            state.raiseConcern(title, detail);
            Navigator.pop(dialogContext);
          },
          child: const Text('Share concern'),
        ),
      ],
    ),
  );
  titleController.dispose();
  detailController.dispose();
}

Future<void> _confirmConcern(
  BuildContext context,
  CareBoxState state,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Review missed reminders'),
      content: Text(
        '${state.missedLastTwoDays} reminders were missed in the last 2 days. Would you like to share a gentle check-in with the care circle?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Confirm and share'),
        ),
      ],
    ),
  );
  if (confirmed == true) state.confirmRepeatedMissesAndRaiseConcern();
}

Future<void> _respondDialog(
  BuildContext context,
  CareBoxState state,
  CareConcern concern,
) async {
  final responseController = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Respond with care'),
      content: TextField(
        controller: responseController,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'Your response'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final response = responseController.text.trim();
            if (response.isEmpty) return;
            state.respondToConcern(concern, response);
            Navigator.pop(dialogContext);
          },
          child: const Text('Send response'),
        ),
      ],
    ),
  );
  responseController.dispose();
}

Future<void> _responseWindowDialog(
  BuildContext context,
  CareBoxState state,
) async {
  var minutes = state.responseWindowMinutes.toDouble();

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setLocalState) => AlertDialog(
        title: const Text('Response window'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${minutes.round()} minutes'),
            Slider(
              value: minutes,
              min: 5,
              max: 30,
              divisions: 5,
              label: '${minutes.round()} min',
              onChanged: (value) {
                setLocalState(() => minutes = value);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              state.setResponseWindow(minutes.round());
              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

void _showNotifications(BuildContext context, CareBoxState state) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        shrinkWrap: true,
        children: [
          const Text(
            'Notification center',
            style: TextStyle(color: ink, fontSize: 21, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ...state.notificationCenter.map(
            (notice) => ListTile(
              leading: const Icon(Icons.notifications_none, color: blue),
              title: Text(notice, style: const TextStyle(color: ink)),
            ),
          ),
        ],
      ),
    ),
  );
}

class DeviceScreen extends StatelessWidget {
  const DeviceScreen({super.key, required this.state});

  final CareBoxState state;

  void _recordDeviceEvent(DeviceEvent event) {
    if (event.event != 'ACKNOWLEDGED' && event.event != 'MISSED') return;
    DoseSchedule? matchedSchedule;
    for (final DoseSchedule schedule in state.schedules) {
      if (schedule.id == event.scheduleId) {
        matchedSchedule = schedule;
        break;
      }
    }
    if (matchedSchedule == null) return;
    state.history.insert(
      0,
      DoseRecord(
        matchedSchedule.name,
        event.occurredAt,
        event.event == 'ACKNOWLEDGED'
            ? DoseStatus.acknowledged
            : DoseStatus.missed,
      ),
    );
    state.addNotice(
      event.event == 'ACKNOWLEDGED'
          ? 'Dose acknowledged. Physical button event received; ingestion is not confirmed.'
          : 'Dose missed. Device event received.',
    );
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.wifi_tethering),
                label: const Text('Connect ESP8266 Wi-Fi prototype'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => WifiConnectionScreen(
                      onEvent: _recordDeviceEvent,
                      initialSchedules: state.schedules
                          .map((schedule) => <String, Object?>{
                                'scheduleId': schedule.id,
                                'patientId': 'patient-demo',
                                'box': int.parse(schedule.box.split(' ')[1]),
                                'hour': schedule.time.hour,
                                'minute': schedule.time.minute,
                                'enabled': schedule.enabled,
                                'repeatDays': schedule.days.toList(),
                              })
                          .toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: DemoDeviceScreen(state: state)),
        ],
      );
}
