/// Pulls useful fields out of a booking confirmation's text.
///
/// IMPORTANT: every value here is a *suggestion*. Airline and hotel PDFs vary
/// enormously between providers, so these heuristics will sometimes be wrong
/// and sometimes find nothing. A wrong booking reference is worse than a
/// missing one - you would trust it at the check-in desk - so nothing from
/// this class is ever written to the database without the user accepting it.
library;

/// What we managed to read, plus what was found so the user can judge it.
class ExtractedConfirmation {
  /// Booking reference / PNR / record locator.
  final String? reference;

  /// Flight number such as FZ1234 or EY 456.
  final String? flightNumber;

  /// Airline name as printed.
  final String? airline;

  /// Origin and destination, usually IATA codes or city names.
  final String? from;
  final String? to;

  /// Dates found, in document order.
  final List<DateTime> dates;

  /// Seat / booking / cabin hints.
  final String? seat;

  /// Hotel name, when this looks like a hotel confirmation.
  final String? hotelName;

  /// Total charged, if present.
  final String? total;

  /// True when the source text was too thin to be a real confirmation.
  final bool scanned;

  /// Human-readable list of what was found, for the review sheet.
  List<String> get summary => [
        if (reference != null) 'Booking reference: $reference',
        if (airline != null) 'Airline: $airline',
        if (flightNumber != null) 'Flight: $flightNumber',
        if (from != null && to != null) 'Route: $from → $to',
        if (dates.isNotEmpty) 'Date${dates.length == 1 ? '' : 's'}: ${dates.map(_shortDate).join(', ')}',
        if (seat != null) 'Seat: $seat',
        if (hotelName != null) 'Hotel: $hotelName',
        if (total != null) 'Total: $total',
      ];

  const ExtractedConfirmation({
    this.reference,
    this.flightNumber,
    this.airline,
    this.from,
    this.to,
    this.dates = const [],
    this.seat,
    this.hotelName,
    this.total,
    this.scanned = false,
  });

  bool get foundAnything =>
      reference != null || flightNumber != null || hotelName != null || dates.isNotEmpty;
}

String _shortDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class ConfirmationParser {
  const ConfirmationParser();

  ExtractedConfirmation parse(String text, {bool scanned = false}) {
    if (text.trim().isEmpty || scanned) {
      return const ExtractedConfirmation(scanned: true);
    }
    final upper = text.toUpperCase();

    return ExtractedConfirmation(
      reference: _reference(text, upper),
      flightNumber: _flightNumber(text, upper),
      airline: _airline(text, upper),
      from: _from(text, upper),
      to: _to(text, upper),
      dates: _dates(text),
      seat: _seat(text, upper),
      hotelName: _hotelName(text),
      total: _total(text, upper),
    );
  }

  // ---- individual fields ----

  /// Prefers an explicitly labelled reference, then falls back to a standalone
  /// 6-character alphanumeric code (the usual PNR shape).
  String? _reference(String text, String upper) {
    // The separator is REQUIRED. Without it a document headed
    // "Booking Confirmation" on one line and "Airline:" on the next would
    // capture AIRLINE as the booking reference.
    final labelled = RegExp(
      r'(?:PNR|RECORD\s*LOCATOR|BOOKING\s*(?:REF(?:ERENCE)?|NUMBER|CODE)|CONFIRMATION(?:\s*(?:CODE|NUMBER|REF))?|RESERVATION(?:\s*(?:CODE|NUMBER))?)'
      r'\s*[:#\-]\s*([A-Z0-9]{5,8})\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (labelled != null) {
      final value = labelled.group(1)!.toUpperCase();
      // Reject things like "CONFIRMATION DATE".
      if (!_isLabelWord(value)) return value;
    }

    // Standalone 6-char code on its own line - classic PNR placement.
    final standalone = RegExp(r'^\s*([A-Z0-9]{6})\s*$', multiLine: true).firstMatch(upper);
    if (standalone != null) {
      final value = standalone.group(1)!;
      if (!_isLabelWord(value) && _hasDigitAndLetter(value)) return value;
    }
    return null;
  }

  bool _isLabelWord(String value) {
    const words = {
      'NUMBER', 'CODE', 'DATE', 'TOTAL', 'PRICE', 'REF', 'REFERENCE',
      'TOTALPRICE', 'AIRLINE', 'FLIGHT', 'TICKET', 'BOOKING', 'SEAT',
      'PASSENGER', 'AMOUNT', 'HOTEL', 'CHECKIN', 'CHECKOUT', 'TERMS',
    };
    return words.contains(value) || words.contains(value.replaceAll(RegExp('[^A-Z]'), ''));
  }

  bool _hasDigitAndLetter(String v) => RegExp(r'\d').hasMatch(v) && RegExp(r'[A-Z]').hasMatch(v);

  /// FZ1234, EY 456, 9W-231 style.
  String? _flightNumber(String text, String upper) {
    final m = RegExp(r'\b([A-Z]{2})\s?-?\s?(\d{2,4})\b')
        .firstMatch(upper.replaceAll(RegExp(r'[^\w\s-]'), ' '));
    if (m == null) return null;
    final code = m.group(1)!;
    if (_isLabelWord(code) || const {'NO', 'ID', 'ON', 'IN', 'AT', 'TO', 'IS'}.contains(code)) return null;
    return '${code}${m.group(2)}';
  }

  String? _airline(String text, String upper) {
    // caseSensitive: false - confirmations print "Airline:", not "AIRLINE:".
    // Stop at the next field label so "Airline: FLYDUBAI  Flight: FZ1234"
    // yields FLYDUBAI rather than swallowing "Flight" too.
    final m = RegExp(
      r'(?:AIRLINE|CARRIER|OPERATED BY)\s*[:#\-]\s*([A-Za-z][A-Za-z.&]{1,20})'
      r'(?:\s+[A-Z][A-Za-z.&]{1,20})*',
      caseSensitive: false,
    ).firstMatch(text);
    if (m == null) return null;

    final value = (m.group(1) ?? '').trim();
    if (value.isEmpty) return null;
    const stopWords = {'FLIGHT', 'FLT', 'NUMBER', 'NO', 'CODE', 'CLASS', 'DATE'};
    final words = value.split(RegExp(r'\s+'));
    final kept = <String>[];
    for (final w in words) {
      if (stopWords.contains(w.toUpperCase())) break;
      kept.add(w);
    }
    final out = kept.join(' ').trim();
    return out.isEmpty ? null : out;
  }

  String? _from(String text, String upper) {
    final labelled = RegExp(r'(?:FROM|ORIGIN|DEPART(?:URE)?\s*FROM|DEPARTING\s*FROM)\s*[:#\-]?\s*([A-Za-z ()]{3,40})',
            caseSensitive: false).firstMatch(text);
    if (labelled != null) {
      final v = labelled.group(1)!.trim();
      if (_looksLikePlace(v)) return v;
    }
    // "Abu Dhabi (AUH) to Tashkent (TAS)"
    final arrow = RegExp(r'([A-Za-z][A-Za-z .]{2,30})\s*\(\s*([A-Z]{3})\s*\)\s*(?:to|->|→|-|–)\s*',
            caseSensitive: false).firstMatch(text);
    if (arrow != null) return '${arrow.group(1)!.trim()} (${arrow.group(2)})';
    return null;
  }

  String? _to(String text, String upper) {
    final labelled = RegExp(r'(?:TO|DESTINATION|ARRIV(?:E|AL)(?:ING)?(?:\s*AT)?)\s*[:#\-]\s*([A-Za-z ()]{3,40})',
            caseSensitive: false).firstMatch(text);
    if (labelled != null) {
      final v = labelled.group(1)!.trim();
      if (_looksLikePlace(v)) return v;
    }
    final arrow = RegExp(r'(?:to|->|→|-|–)\s*([A-Za-z][A-Za-z .]{2,30})\s*\(\s*([A-Z]{3})\s*\)',
            caseSensitive: false).firstMatch(text);
    if (arrow != null) return '${arrow.group(1)!.trim()} (${arrow.group(2)})';
    return null;
  }

  bool _looksLikePlace(String v) {
    const bad = ['DATE', 'TIME', 'TOTAL', 'CONFIRMATION', 'THE', 'AND', 'IS'];
    final u = v.toUpperCase();
    if (bad.any(u.startsWith)) return false;
    return RegExp(r'[A-Za-z]').hasMatch(v);
  }

  /// Dates in the shapes confirmations actually use.
  List<DateTime> _dates(String text) {
    final found = <DateTime>[];
    final months = {
      'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4, 'MAY': 5, 'JUN': 6,
      'JUL': 7, 'AUG': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12,
    };

    // 15 Nov 2026 / 15 NOV 2026
    for (final m in RegExp(r'\b(\d{1,2})[ \-]([A-Za-z]{3})[ \-](\d{4})\b').allMatches(text)) {
      final month = months[m.group(2)!.toUpperCase().substring(0, 3)];
      if (month != null) found.add(_date(int.parse(m.group(1)!), month, int.parse(m.group(3)!)));
    }
    // 2026-11-15
    for (final m in RegExp(r'\b(\d{4})-(\d{2})-(\d{2})\b').allMatches(text)) {
      found.add(_date(int.parse(m.group(3)!), int.parse(m.group(2)!), int.parse(m.group(1)!)));
    }
    // 15/11/2026 (day first is the common international form)
    for (final m in RegExp(r'\b(\d{1,2})/(\d{1,2})/(\d{4})\b').allMatches(text)) {
      final d = int.parse(m.group(1)!);
      final mo = int.parse(m.group(2)!);
      if (d <= 31 && mo <= 12) found.add(_date(d, mo, int.parse(m.group(3)!)));
    }

    // Deduplicate, keep document order.
    final seen = <String>{};
    return found.where((d) => seen.add('${d.year}-${d.month}-${d.day}')).toList();
  }

  DateTime _date(int day, int month, int year) => DateTime(year, month, day);

  String? _seat(String text, String upper) {
    final m = RegExp(r'\bSEAT\s*[:#\-]?\s*([0-9]{1,2}[A-K](?:\s*[-/]\s*[0-9]{1,2}[A-K])?)\b',
            caseSensitive: false).firstMatch(text);
    return m?.group(1)?.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String? _hotelName(String text) {
    final upper = text.toUpperCase();
    if (!upper.contains('HOTEL') && !upper.contains('ACCOMMODATION') && !upper.contains('CHECK-IN')) {
      return null;
    }
    final m = RegExp(
      r"(?:HOTEL|PROPERTY|ACCOMMODATION)\s*[:#\-]\s*\n?\s*([A-Z][A-Za-z0-9 &'\-.]{3,40})",
      caseSensitive: false,
    ).firstMatch(text);
    final v = m?.group(1)?.trim();
    if (v == null || v.isEmpty) return null;
    const noise = ['NAME', 'CONFIRMATION', 'BOOKING', 'REFERENCE', 'CHECK', 'ADDRESS', 'RESERVATION'];
    if (noise.any(v.toUpperCase().startsWith)) return null;
    return v;
  }

  String? _total(String text, String upper) {
    final m = RegExp(
      r'(?:TOTAL|GRAND TOTAL|AMOUNT(?: PAID)?|PRICE)\s*[:#\-]?\s*([A-Z]{3})\s*([\d,]+(?:\.\d{2})?)',
    ).firstMatch(upper);
    if (m != null) return '${m.group(2)} ${m.group(1)}';
    final plain = RegExp(r'(?:TOTAL|GRAND TOTAL)\s*[:#\-]?\s*([\d,]+(?:\.\d{2})?)\s*(AED|USD|EUR|GBP|SAR|INR|UZS)?')
        .firstMatch(upper);
    if (plain == null) return null;
    final amount = plain.group(1)!;
    final cur = plain.group(2);
    return cur == null ? amount : '$amount $cur';
  }
}
