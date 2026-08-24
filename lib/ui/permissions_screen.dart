import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/theme.dart';
import 'home_screen.dart';

/// The app's initial route. Checks permission status on launch (no prompts)
/// and, if the microphone is already granted, silently advances straight to
/// [HomeScreen] — a returning user with permissions intact never sees this
/// linger. Otherwise stays up: microphone gates proceeding (the app can't
/// record without it); notification and battery-exemption are shown as
/// recommended but skippable, matching how step 3 treated them.
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _checking = true;
  bool _micGranted = false;
  bool _notificationGranted = false;
  bool _batteryExempt = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final micGranted = await Permission.microphone.status.then((s) => s.isGranted);
    final notificationGranted = await FlutterForegroundTask.checkNotificationPermission().then(
      (p) => p == NotificationPermission.granted,
    );
    final batteryExempt = await FlutterForegroundTask.isIgnoringBatteryOptimizations;

    if (!mounted) return;
    setState(() {
      _micGranted = micGranted;
      _notificationGranted = notificationGranted;
      _batteryExempt = batteryExempt;
      _checking = false;
    });

    if (micGranted) _proceed();
  }

  void _proceed() {
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  Future<void> _requestMic() async {
    final granted = await Permission.microphone.request().then((s) => s.isGranted);
    if (!mounted) return;
    setState(() => _micGranted = granted);
    if (granted) _proceed();
  }

  Future<void> _requestNotification() async {
    if (await FlutterForegroundTask.checkNotificationPermission() != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    final granted = await FlutterForegroundTask.checkNotificationPermission().then(
      (p) => p == NotificationPermission.granted,
    );
    if (!mounted) return;
    setState(() => _notificationGranted = granted);
  }

  Future<void> _requestBatteryExemption() async {
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
    final exempt = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    if (!mounted) return;
    setState(() => _batteryExempt = exempt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NightTalker')),
      body: _checking
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'NightTalker records while you sleep, so it needs a few permissions up front.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                _PermissionRow(
                  icon: Icons.mic,
                  title: 'Microphone',
                  description: 'Required — the app can\'t record without it.',
                  granted: _micGranted,
                  onGrant: _requestMic,
                ),
                _PermissionRow(
                  icon: Icons.notifications_active,
                  title: 'Notifications',
                  description: 'Recommended — shows the ongoing recording status while listening.',
                  granted: _notificationGranted,
                  onGrant: _requestNotification,
                ),
                _PermissionRow(
                  icon: Icons.battery_charging_full,
                  title: 'Ignore battery optimization',
                  description: 'Recommended — some phones kill overnight recordings without this.',
                  granted: _batteryExempt,
                  onGrant: _requestBatteryExemption,
                ),
              ],
            ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.granted,
    required this.onGrant,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool granted;
  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(description),
        trailing: granted
            ? const Icon(Icons.check_circle, color: AppColors.moonlight)
            : OutlinedButton(onPressed: onGrant, child: const Text('Grant')),
      ),
    );
  }
}
