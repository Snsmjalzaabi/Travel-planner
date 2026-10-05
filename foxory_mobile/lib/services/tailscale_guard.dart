import 'dart:async';

import 'package:http/http.dart' as http;

/// Why a sync was or was not allowed to happen.
enum TailscaleState {
  /// The configured host is a Tailscale address and answered.
  connected,

  /// Address is a Tailscale one but nothing answered - tunnel down.
  unreachable,

  /// Address is not in the Tailscale range at all.
  notTailscaleAddress,

  /// Nothing configured yet.
  notConfigured,
}

class TailscaleCheck {
  final TailscaleState state;

  /// Populated when the host answered, so the UI can prove it is live.
  final String? detail;

  const TailscaleCheck(this.state, [this.detail]);

  /// Sync and any off-device transfer are allowed only in this state.
  bool get allowed => state == TailscaleState.connected;

  String get message => switch (state) {
        TailscaleState.connected => detail ?? 'Connected over Tailscale',
        TailscaleState.unreachable =>
          'Pi is not answering over Tailscale. Your data stays on this phone until it does.',
        TailscaleState.notTailscaleAddress =>
          'That address is not a Tailscale address. Sync is disabled so trip data cannot leave the phone over the local network.',
        TailscaleState.notConfigured => 'No Pi address set. Everything stays on this phone.',
      };
}

/// Decides whether data is allowed to leave the phone.
///
/// The rule is strict and one-directional: trip data stays on the phone, and
/// only travels when the Pi is genuinely reachable over Tailscale. A LAN
/// address is refused outright rather than trusted, because the same Pi is
/// also reachable at a plain 192.168.x.x address on the home WiFi - and that
/// is exactly the path this is meant to avoid.
class TailscaleGuard {
  const TailscaleGuard();

  /// Tailscale hands out addresses in 100.64.0.0/10 (RFC 6598 CGNAT space).
  static bool isTailscaleAddress(String host) {
    final h = host.trim();
    if (h.isEmpty) return false;

    // Hostname: not a bare Tailscale IP, so we cannot vouch for it.
    final looksNumeric = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(h);
    if (!looksNumeric) return false;

    final parts = h.split('.').map((p) => int.tryParse(p) ?? -1).toList();
    if (parts.any((p) => p < 0 || p > 255)) return false;

    return parts[0] == 100 && parts[1] >= 64 && parts[1] <= 127;
  }

  /// Confirms the address is Tailscale *and* that something actually answers.
  ///
  /// The range check alone is not enough: the address could be correct while
  /// the tunnel is down, and a failed request must not be reported as success.
  Future<TailscaleCheck> probe(String host, int port, {Duration timeout = const Duration(seconds: 6)}) async {
    if (host.trim().isEmpty) {
      return const TailscaleCheck(TailscaleState.notConfigured);
    }
    if (!isTailscaleAddress(host)) {
      return const TailscaleCheck(TailscaleState.notTailscaleAddress);
    }

    try {
      final response = await http
          .get(Uri.parse('http://$host:$port/health'))
          .timeout(timeout);
      if (response.statusCode == 200) {
        return TailscaleCheck(TailscaleState.connected, 'Connected over Tailscale · $host');
      }
      return TailscaleCheck(
        TailscaleState.unreachable,
        'Pi answered but not correctly (HTTP ${response.statusCode})',
      );
    } on TimeoutException {
      return const TailscaleCheck(TailscaleState.unreachable, 'Timed out waiting for the Pi');
    } catch (_) {
      // Tailscale down, or the device is offline.
      return const TailscaleCheck(TailscaleState.unreachable, 'Tailscale tunnel is not up');
    }
  }
}