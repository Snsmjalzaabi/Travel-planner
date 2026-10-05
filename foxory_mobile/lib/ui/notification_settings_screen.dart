import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/notification_service.dart';

/// Notification settings: shows whether the OS will actually let the app post
/// alerts, and offers a way to fix it if not.
///
/// This exists because the app used to request permission before the first
/// frame and swallow the outcome, so alerts could be silently off with no
/// visible sign and no way to recover.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  NotificationPermissionState _state = NotificationPermissionState.unknown;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final state = await AlertService.instance?.permissionState() ??
        NotificationPermissionState.unknown;
    if (!mounted) return;
    setState(() {
      _state = state;
      _loading = false;
    });
  }

  Future<void> _request() async {
    final alerts = AlertService.instance;
    if (alerts == null) return;
    await alerts.requestPermission();
    await _refresh();
  }

  Future<void> _openSettings() async {
    await AlertService.instance?.openAppSettings();
    // The user may change it in Settings; re-check when they come back.
    await _refresh();
  }

  Future<void> _sendTest() async {
    final alerts = AlertService.instance;
    if (alerts == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final count = await alerts.fireAlertsNow();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          count == 0
              ? 'No alerts due right now. Add a passport, visa or upcoming trip to test.'
              : 'Sent $count notification${count == 1 ? '' : 's'}. Check your notification shade.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _statusBanner(cs),
                const SizedBox(height: 20),
                if (_state.needsSettings)
                  _button(
                    'Open phone settings',
                    Icons.settings,
                    cs.primary,
                    _openSettings,
                    subtitle: 'Android has blocked further requests. Enable notifications for Your Travel Buddy here.',
                  )
                else if (!_state.canNotify)
                  _button(
                    'Allow notifications',
                    Icons.notifications_active_outlined,
                    cs.primary,
                    _request,
                    subtitle: _state == NotificationPermissionState.notAsked
                        ? 'You will get one system prompt.'
                        : 'Tap to ask again.',
                  ),
                const SizedBox(height: 12),
                _button(
                  'Send a test now',
                  Icons.send_outlined,
                  cs.primary,
                  _sendTest,
                  subtitle: 'Fires any passport, visa or trip alerts immediately.',
                ),
                const SizedBox(height: 24),
                _infoBox('Daily check',
                    'The app also runs a daily check at 08:00 and notifies you about anything expiring soon.'),
                const SizedBox(height: 12),
                _infoBox('What triggers an alert',
                    'Passports expiring or expired, approved visas expiring within 45 days, and trips departing within 3 days.'),
              ],
            ),
    );
  }

  Widget _statusBanner(ColorScheme cs) {
    final granted = _state.canNotify;
    final color = granted ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(granted ? Icons.notifications_active : Icons.notifications_off_outlined, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _state.label,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  granted
                      ? 'Expiry warnings will arrive on this device.'
                      : 'Expiry warnings are switched off, so you will not be warned about a passport or visa expiring.',
                  style: GoogleFonts.inter(fontSize: 12, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _button(String title, IconData icon, Color color, VoidCallback onTap, {String? subtitle}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        subtitle: subtitle == null ? null : Text(subtitle, style: GoogleFonts.inter(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: onTap,
      ),
    );
  }

  Widget _infoBox(String title, String body) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 4),
          Text(body, style: GoogleFonts.inter(fontSize: 12, height: 1.4, color: cs.onSurface.withValues(alpha: 0.7))),
        ],
      ),
    );
  }
}