// Guards the notification-permission recovery path. The app previously
// requested permission before the first frame inside a timeout that swallowed
// the result, so alerts could be silently off with no way to see or fix that.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foxory_mobile/services/notification_service.dart';

void main() {
  test('only granted counts as "can notify"', () {
    expect(NotificationPermissionState.granted.canNotify, isTrue);
    expect(NotificationPermissionState.denied.canNotify, isFalse);
    expect(NotificationPermissionState.notAsked.canNotify, isFalse);
    expect(NotificationPermissionState.blockedNeedsSettings.canNotify, isFalse);
    expect(NotificationPermissionState.unknown.canNotify, isFalse);
  });

  test('only a permanent block routes the user to phone settings', () {
    expect(NotificationPermissionState.blockedNeedsSettings.needsSettings, isTrue);
    expect(NotificationPermissionState.denied.needsSettings, isFalse);
    expect(NotificationPermissionState.notAsked.needsSettings, isFalse);
    expect(NotificationPermissionState.granted.needsSettings, isFalse);
  });

  test('no state reads as healthy by accident', () {
    // Every non-granted state must say something, so the UI never shows a
    // green "you're fine" banner when notifications are actually blocked.
    for (final s in NotificationPermissionState.values) {
      expect(s.label.trim(), isNotEmpty, reason: '${s.name} needs a label');
      if (s != NotificationPermissionState.granted) {
        expect(s.canNotify, isFalse, reason: '${s.name} must not claim it can notify');
      }
    }
  });

  test('the permanently-blocked label tells the user where to go', () {
    final label = NotificationPermissionState.blockedNeedsSettings.label.toLowerCase();
    expect(label, contains('settings'));
  });

  test('main() no longer requests permission before the first frame', () {
    // Regression guard: calling requestPermission() in main() popped a system
    // dialog during startup and the timeout discarded the answer.
    final main = File('lib/main.dart').readAsStringSync();
    expect(main.contains('requestPermission'), isFalse);
    expect(main.contains('runApp'), isTrue, reason: 'runApp must still be called');
    // Scheduling the daily check is fine; asking the user is not.
    expect(main.contains('scheduleDailyCheck'), isTrue);
  });

  test('a notification settings screen is reachable from the More menu', () {
    final more = File('lib/ui/more_screen.dart').readAsStringSync();
    expect(more.contains('NotificationSettingsScreen'), isTrue);
    expect(more.contains('Notifications'), isTrue);
  });
}
