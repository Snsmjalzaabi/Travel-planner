// Data must stay on the phone unless the Pi is genuinely reachable over
// Tailscale. These tests pin the refusal rules, because a wrong result here
// means trip data leaving the phone over the open local network.
import 'package:flutter_test/flutter_test.dart';
import 'package:foxory_mobile/services/tailscale_guard.dart';

void main() {
  const guard = TailscaleGuard();

  group('address recognition', () {
    test('accepts real Tailscale addresses', () {
      expect(TailscaleGuard.isTailscaleAddress('100.82.155.42'), isTrue);
      expect(TailscaleGuard.isTailscaleAddress('100.64.0.1'), isTrue);
      expect(TailscaleGuard.isTailscaleAddress('100.127.255.255'), isTrue);
    });

    test('refuses LAN addresses', () {
      expect(TailscaleGuard.isTailscaleAddress('192.168.1.21'), isFalse);
      expect(TailscaleGuard.isTailscaleAddress('192.168.0.1'), isFalse);
      expect(TailscaleGuard.isTailscaleAddress('10.0.0.5'), isFalse);
      expect(TailscaleGuard.isTailscaleAddress('172.16.4.4'), isFalse);
    });

    test('refuses public addresses', () {
      expect(TailscaleGuard.isTailscaleAddress('8.8.8.8'), isFalse);
      expect(TailscaleGuard.isTailscaleAddress('1.1.1.1'), isFalse);
    });

    test('refuses addresses just outside the CGNAT range', () {
      // 100.63.x and 100.128.x sit outside 100.64.0.0/10.
      expect(TailscaleGuard.isTailscaleAddress('100.63.255.255'), isFalse);
      expect(TailscaleGuard.isTailscaleAddress('100.128.0.1'), isFalse);
      expect(TailscaleGuard.isTailscaleAddress('99.255.255.255'), isFalse);
      expect(TailscaleGuard.isTailscaleAddress('101.0.0.1'), isFalse);
    });

    test('refuses hostnames - cannot vouch for where they resolve', () {
      expect(TailscaleGuard.isTailscaleAddress('foxpi'), isFalse);
      expect(TailscaleGuard.isTailscaleAddress('foxpi.tailnet.ts.net'), isFalse);
      expect(TailscaleGuard.isTailscaleAddress('localhost'), isFalse);
    });

    test('refuses empty and malformed input', () {
      expect(TailscaleGuard.isTailscaleAddress(''), isFalse);
      expect(TailscaleGuard.isTailscaleAddress('   '), isFalse);
      expect(TailscaleGuard.isTailscaleAddress('100.82.155'), isFalse);
      expect(TailscaleGuard.isTailscaleAddress('100.82.155.999'), isFalse);
      expect(TailscaleGuard.isTailscaleAddress('not.an.ip'), isFalse);
    });

    test('tolerates surrounding whitespace', () {
      expect(TailscaleGuard.isTailscaleAddress('  100.82.155.42  '), isTrue);
    });
  });

  group('gate decisions', () {
    test('a LAN address is refused without touching the network', () async {
      // Nothing is listening on 127.0.0.1:1, so if this passed it would be a
      // false positive.
      final check = await guard.probe('192.168.1.21', 9101);
      expect(check.state, TailscaleState.notTailscaleAddress);
      expect(check.allowed, isFalse);
      expect(check.message, contains('Tailscale'));
    });

    test('an unconfigured address is refused', () async {
      final check = await guard.probe('', 9101);
      expect(check.state, TailscaleState.notConfigured);
      expect(check.allowed, isFalse);
    });

    test('a correct address with nothing listening is unreachable, not connected', () async {
      final check = await guard.probe('100.82.155.42', 1, timeout: const Duration(seconds: 3));
      expect(check.state, TailscaleState.unreachable);
      expect(check.allowed, isFalse);
    });

    test('only the connected state permits a transfer', () {
      expect(const TailscaleCheck(TailscaleState.connected).allowed, isTrue);
      expect(const TailscaleCheck(TailscaleState.unreachable).allowed, isFalse);
      expect(const TailscaleCheck(TailscaleState.notTailscaleAddress).allowed, isFalse);
      expect(const TailscaleCheck(TailscaleState.notConfigured).allowed, isFalse);
    });

    test('a blocked message tells the user their data is safe', () {
      for (final state in [
        TailscaleState.unreachable,
        TailscaleState.notTailscaleAddress,
        TailscaleState.notConfigured,
      ]) {
        final message = TailscaleCheck(state).message.toLowerCase();
        expect(message, anyOf(contains('stays on this phone'), contains('disabled')),
            reason: '$state must reassure the user');
      }
    });
  });
}