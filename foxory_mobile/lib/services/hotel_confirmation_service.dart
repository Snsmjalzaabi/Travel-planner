
/// Find a trip whose destination matches [city] (case-insensitive substring /
/// token match) and whose date range overlaps [checkIn]–[checkOut].
///
/// Returns the trip id if a match is found; otherwise null.
Future<int?> findMatchingTrip({
  required String city,
  required DateTime checkIn,
  required DateTime checkOut,
  required Future<List<Map<String, dynamic>>> Function() tripQuery,
}) async {
  final trips = await tripQuery();
  int? bestId;
  for (final t in trips) {
    final destName = (t['dest_name'] as String?) ?? '';
    final destCountry = (t['dest_country'] as String?) ?? '';
    final combined = '$destName $destCountry'.toLowerCase();
    final cityLower = city.toLowerCase();
    if (!_tokenMatch(cityLower, combined)) continue;
    final depText = (t['departure'] as String?) ?? '';
    final retText = (t['return_date'] as String?) ?? '';
    final dep = DateTime.tryParse(depText);
    final ret = DateTime.tryParse(retText);
    if (dep == null || ret == null) continue;
    final tripStart = dep.subtract(const Duration(days: 1));
    final tripEnd = ret.add(const Duration(days: 1));
    if (checkIn.isBefore(tripEnd) && checkOut.isAfter(tripStart)) {
      bestId = t['id'] as int?;
      break;
    }
  }
  return bestId;
}

bool _tokenMatch(String query, String target) {
  final q = query.toLowerCase();
  final t = target.toLowerCase();
  if (t.contains(q)) return true;
  final qTokens = q.split(RegExp(r'[\s\-]+')).where((s) => s.length >= 3).toSet();
  final tTokens = t.split(RegExp(r'[\s\-]+')).map((s) => s.toLowerCase()).toSet();
  for (final qt in qTokens) {
    if (tTokens.any((tt) => tt.contains(qt) || qt.contains(tt))) return true;
  }
  return false;
}
