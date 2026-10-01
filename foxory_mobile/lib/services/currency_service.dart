import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Free, no-key currency conversion using the ECB Frankfurter API.
///
/// Converts any amount between any supported currency pair.
/// On network failure, returns 1:1 (graceful degradation).
///
/// Usage:
///   final service = CurrencyService();
///   final inUSD = await service.convert(100, 'AED', 'USD');
class CurrencyService {
  static const _apiBase = 'https://api.frankfurter.app';
  static const _cacheTtlHours = 24;

  final http.Client _client;
  SharedPreferences? _prefsCache;

  CurrencyService({http.Client? client}) : _client = client ?? http.Client();

  Future<SharedPreferences> _getPrefs() async {
    if (_prefsCache != null) return _prefsCache!;
    _prefsCache = await SharedPreferences.getInstance();
    return _prefsCache!;
  }

  /// Convert [amount] from [from] currency to [to] currency.
  Future<double> convert(double amount, String from, String to) async {
    final normalizedFrom = _normalize(from);
    final normalizedTo = _normalize(to);
    if (normalizedFrom == normalizedTo) return amount;
    final rate = await getRate(normalizedFrom, normalizedTo);
    return amount * rate;
  }

  Future<double> getRate(String from, String to) async {
    final normalizedFrom = _normalize(from);
    final normalizedTo = _normalize(to);
    if (normalizedFrom == normalizedTo) return 1.0;

    final prefs = await _getPrefs();
    final cacheKey = 'fx_${normalizedFrom}_$normalizedTo';
    final cached = prefs.getString(cacheKey);

    if (cached != null) {
      try {
        final decoded = jsonDecode(cached) as Map<String, dynamic>;
        final ts = decoded['ts'] as int?;
        if (ts != null) {
          final ageHours = DateTime.now()
              .difference(DateTime.fromMillisecondsSinceEpoch(ts))
              .inHours;
          if (ageHours < _cacheTtlHours) {
            return (decoded['rate'] as num?)?.toDouble() ?? 1.0;
          }
        }
      } catch (_) {
        // corrupt cache — ignore
      }
    }

    try {
      final url = Uri.parse('$_apiBase/latest?from=$normalizedFrom&to=$normalizedTo');
      final resp = await _client.get(url).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final rates = data['rates'] as Map<String, dynamic>?;
        final raw = rates?[normalizedTo];
        if (raw != null) {
          final rate = (raw as num).toDouble();
          if (rate > 0) {
            final entry = jsonEncode({
              'rate': rate,
              'ts': DateTime.now().millisecondsSinceEpoch,
            });
            await prefs.setString(cacheKey, entry);
            return rate;
          }
        }
      }
    } catch (_) {
      // Network or parse failure — fall through to 1:1
    }

    return 1.0;
  }

  String _normalize(String currency) => currency.trim().toUpperCase();
}
