import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/models.dart';
import 'budget_service.dart';

/// Builds a printable trip brief to send to friends.
///
/// This is the app's real output: Sultan plans alone, then sends this PDF so
/// everyone has the same details without needing the app. So it is built to be
/// readable by someone who has never seen the app - dates spelled out, no
/// abbreviations, totals obvious, and nothing that only makes sense in-app.
class TripPdfBuilder {
  TripPdfBuilder({required this.trip});

  final Trip trip;

  static final _accent = PdfColor.fromHex('#F5A524');
  static final _ink = PdfColor.fromHex('#1A1A1A');
  static final _muted = PdfColor.fromHex('#6B7280');
  static final _line = PdfColor.fromHex('#D1D5DB');
  static final _warn = PdfColor.fromHex('#DC2626');
  static final _good = PdfColor.fromHex('#059669');

  // PdfColor has no alpha helper, so tints are explicit.
  static final _accentWash = PdfColor.fromHex('#FEF6E7');
  static final _accentLine = PdfColor.fromHex('#E8B84B');
  static final _orange = PdfColor.fromHex('#B45309');

  final _dateFmt = DateFormat('d MMM yyyy');

  Future<Uint8List> build({
    List<Flight> flights = const [],
    List<Hotel> hotels = const [],
    List<ItineraryDay> itinerary = const [],
    List<Expense> expenses = const [],
    List<PackingItem> packing = const [],
    BudgetBreakdown? budget,
    Map<String, double> allocations = const {},
    bool includeBudget = true,
    bool includeExpenses = true,
    bool includePacking = true,
    bool includeItinerary = true,
  }) async {
    final doc = pw.Document(
      title: '${trip.name} trip brief',
      author: 'Your Travel Buddy',
    );

    final pdfFont = pw.Font.helvetica();
    final pdfBold = pw.Font.helveticaBold();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 34, 32, 40),
        header: (ctx) => ctx.pageNumber == 1 ? pw.SizedBox() : _runningHeader(pdfFont),
        footer: (ctx) => _footer(ctx, pdfFont),
        build: (ctx) => [
          _titleBlock(pdfFont, pdfBold),
          pw.SizedBox(height: 16),
          _overviewGrid(pdfFont, pdfBold),
          if (flights.isNotEmpty) ...[
            _sectionTitle('Flights', pdfFont, pdfBold),
            ...flights.map((f) => _flightCard(f, pdfFont, pdfBold)),
          ],
          if (hotels.isNotEmpty) ...[
            _sectionTitle('Accommodation', pdfFont, pdfBold),
            ...hotels.map((h) => _hotelCard(h, pdfFont, pdfBold)),
          ],
          if (includeItinerary && itinerary.isNotEmpty)
            _section('Day by day', pdfFont, pdfBold, _itineraryTable(itinerary, pdfFont, pdfBold)),
          if (includeBudget && budget != null)
            _section('Budget', pdfFont, pdfBold, _budgetTable(budget, allocations, pdfFont, pdfBold)),
          if (includeExpenses && expenses.isNotEmpty) ...[
            _sectionTitle('Expenses', pdfFont, pdfBold),
            _expenseTable(expenses, pdfFont, pdfBold),
            if (budget != null) ...[
              pw.SizedBox(height: 8),
              _splitSummary(trip, expenses, budget, pdfFont, pdfBold),
            ],
          ],
          if (includePacking && packing.isNotEmpty) ...[
            _sectionTitle('Packing list', pdfFont, pdfBold),
            _packingList(packing, pdfFont, pdfBold),
          ],
          pw.SizedBox(height: 18),
          _confirmationFootnotes(flights, hotels, pdfFont),
        ],
      ),
    );

    return doc.save();
  }

  // ---------- header ----------

  pw.Widget _runningHeader(pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 6),
      margin: const pw.EdgeInsets.only(bottom: 10),
      decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _line))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(trip.name, style: pw.TextStyle(font: font, fontSize: 9, color: _muted)),
          pw.Text(
            '${_fmt(trip.departure)} - ${_fmt(trip.returnDate)}',
            style: pw.TextStyle(font: font, fontSize: 9, color: _muted),
          ),
        ],
      ),
    );
  }

  pw.Widget _footer(pw.Context ctx, pw.Font font) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 12),
      child: pw.Text(
        'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
        style: pw.TextStyle(font: font, fontSize: 8, color: _muted),
      ),
    );
  }

  pw.Widget _titleBlock(pw.Font font, pw.Font bold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'TRIP BRIEF',
          style: pw.TextStyle(font: bold, fontSize: 9, color: _accent, letterSpacing: 2),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          trip.name,
          style: pw.TextStyle(font: bold, fontSize: 26, color: _ink),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          '${_route()}   |   ${_fmt(trip.departure)} to ${_fmt(trip.returnDate)}'
          '   |   ${_nights()} nights   |   ${trip.travelers} ${trip.travelers == 1 ? 'traveller' : 'travellers'}',
          style: pw.TextStyle(font: font, fontSize: 10.5, color: _muted),
        ),
        if (trip.tripType.trim().isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Text(
            '${trip.tripType} trip',
            style: pw.TextStyle(font: font, fontSize: 10.5, color: _muted),
          ),
        ],
      ],
    );
  }

  pw.Widget _overviewGrid(pw.Font font, pw.Font bold) {
    final rows = <(String, String)>[
      ('Travelers', '${trip.travelers}'),
      ('Transport', trip.transportLabel),
      if ((trip.totalBudget) > 0) ('Budget', _money(trip.totalBudget)),
      if (trip.originCountry.trim().isNotEmpty) ('From', '${trip.originName}, ${trip.originCountry}'),
      if (trip.destCountry.trim().isNotEmpty) ('To', '${trip.destName}, ${trip.destCountry}'),
      ('Status', trip.status.isEmpty ? 'planning' : trip.status),
    ];

    return pw.Table(
      border: pw.TableBorder.symmetric(
        inside: pw.BorderSide(color: _line, width: 0.5),
        outside: pw.BorderSide(color: _line, width: 0.5),
      ),
      children: rows
          .map(
            (r) => pw.TableRow(
              children: [
                pw.Expanded(
                  flex: 2,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(7),
                    color: PdfColor.fromHex('#F9FAFB'),
                    child: pw.Text(r.$1, style: pw.TextStyle(font: bold, fontSize: 9, color: _muted)),
                  ),
                ),
                pw.Expanded(
                  flex: 3,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(7),
                    child: pw.Text(r.$2, style: pw.TextStyle(font: font, fontSize: 9.5)),
                  ),
                ),
              ],
            ),
          )
          .toList(),
    );
  }

  /// A heading plus its first row of content, glued together.
  ///
  /// Without this a page break can strand "Budget" at the bottom of a page
  /// with the table on the next one - it looked broken rather than paginated.
  pw.Widget _section(String text, pw.Font font, pw.Font bold, pw.Widget content) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [_sectionTitle(text, font, bold), content],
    );
  }

  pw.Widget _sectionTitle(String text, pw.Font font, pw.Font bold) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20, bottom: 8),
      child: pw.Row(
        children: [
          pw.Container(width: 3, height: 13, color: _accent),
          pw.SizedBox(width: 7),
          pw.Text(text, style: pw.TextStyle(font: bold, fontSize: 14, color: _ink)),
        ],
      ),
    );
  }

  // ---------- flights ----------

  pw.Widget _flightCard(Flight f, pw.Font font, pw.Font bold) {
    final booking = f.bookingReference ?? '';
    final conf = f.confirmationNumber ?? '';
    final ref = booking.trim().isNotEmpty ? booking : conf;
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _line, width: 0.5),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                [f.airline, f.flightNumber].where((s) => s.trim().isNotEmpty).join('  '),
                style: pw.TextStyle(font: bold, fontSize: 11),
              ),
              if (ref.trim().isNotEmpty)
                pw.Text('Ref: $ref', style: pw.TextStyle(font: bold, fontSize: 10, color: _accent)),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Row(
            children: [
              pw.Expanded(child: _timeCol(f.departure, f.fromCode.isNotEmpty ? f.fromCode : f.fromCity, font, bold)),
              pw.Container(
                alignment: pw.Alignment.center,
                child: pw.Text('->', style: pw.TextStyle(font: font, fontSize: 10, color: _muted)),
              ),
              pw.Expanded(child: _timeCol(f.arrival, f.toCode.isNotEmpty ? f.toCode : f.toCity, font, bold, alignRight: true)),
            ],
          ),
          if (f.seat.trim().isNotEmpty || (f.cost ?? 0) > 0 || f.status.trim().isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              [
                if (f.seat.trim().isNotEmpty) 'Seat ${f.seat}',
                if ((f.cost ?? 0) > 0) 'Cost ${_moneyWith(f.cost!, f.currency)}',
                if (f.status.trim().isNotEmpty) f.status.trim(),
              ].join('   |   '),
              style: pw.TextStyle(font: font, fontSize: 8.5, color: _muted),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _timeCol(DateTime when, String place, pw.Font font, pw.Font bold, {bool alignRight = false}) {
    return pw.Column(
      crossAxisAlignment: alignRight ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          when.hour == 0 && when.minute == 0 ? '—' : DateFormat('HH:mm').format(when),
          style: pw.TextStyle(font: bold, fontSize: 13),
        ),
        pw.Text(_fmt(when), style: pw.TextStyle(font: font, fontSize: 8.5, color: _muted)),
        if (place.trim().isNotEmpty)
          pw.Text(place, style: pw.TextStyle(font: font, fontSize: 9)),
      ],
    );
  }

  // ---------- hotels ----------

  pw.Widget _hotelCard(Hotel h, pw.Font font, pw.Font bold) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _line, width: 0.5),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(h.name, style: pw.TextStyle(font: bold, fontSize: 11)),
          if (h.address.trim().isNotEmpty)
            pw.Text(h.address, style: pw.TextStyle(font: font, fontSize: 8.5, color: _muted)),
          pw.SizedBox(height: 5),
          pw.Text(
            'Check-in ${_fmt(h.checkIn)}   |   Check-out ${_fmt(h.checkOut)}',
            style: pw.TextStyle(font: font, fontSize: 9),
          ),
          pw.Text(
            [
              if ((h.confirmationNumber ?? '').trim().isNotEmpty) 'Ref ${(h.confirmationNumber ?? '').trim()}',
              if ((h.phone ?? '').trim().isNotEmpty) (h.phone ?? '').trim(),
              if ((h.cost ?? 0) > 0) _moneyWith(h.cost!, h.currency),
            ].join('   |   '),
            style: pw.TextStyle(font: font, fontSize: 8.5, color: _muted),
          ),
        ],
      ),
    );
  }

  /// ItineraryDay has `theme` and `notes` - there is no title field.
  String _dayPlan(ItineraryDay d) {
    final theme = (d.theme ?? '').trim();
    final notes = d.notes.trim();
    if (theme.isEmpty && notes.isEmpty) return '—';
    if (theme.isEmpty) return notes;
    if (notes.isEmpty) return theme;
    return '$theme\n$notes';
  }

  // ---------- itinerary ----------

  pw.Widget _itineraryTable(List<ItineraryDay> days, pw.Font font, pw.Font bold) {
    final sorted = [...days]..sort((a, b) {
      final d = a.date.compareTo(b.date);
      return d != 0 ? d : a.dayNumber.compareTo(b.dayNumber);
    });

    return pw.Table(
      border: pw.TableBorder.symmetric(
        inside: pw.BorderSide(color: _line, width: 0.5),
        outside: pw.BorderSide(color: _line, width: 0.5),
      ),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F9FAFB')),
          children: [
            _cell('Day', bold, 1, header: true),
            _cell('Date', bold, 2, header: true),
            _cell('Plan', bold, 6, header: true),
          ],
        ),
        ...sorted.map(
          (d) => pw.TableRow(
            children: [
              _cell('${d.dayNumber}', font, 1),
              _cell(_fmt(d.date), font, 2),
              _cell(
                _dayPlan(d),
                font,
                6,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- budget ----------

  pw.Widget _budgetTable(BudgetBreakdown budget, Map<String, double> allocations, pw.Font font, pw.Font bold) {
    final rows = <String, double>{...allocations, ...budget.byCategory};
    final keys = rows.keys.toList()..sort((a, b) {
      final aa = allocations[a] ?? 0;
      final bb = allocations[b] ?? 0;
      if (aa != bb) return bb.compareTo(aa);
      return (budget.byCategory[b] ?? 0).compareTo(budget.byCategory[a] ?? 0);
    });

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (keys.isEmpty)
          pw.Text('No budget breakdown set.', style: pw.TextStyle(font: font, fontSize: 9.5, color: _muted))
        else
          pw.Table(
            border: pw.TableBorder.symmetric(
              inside: pw.BorderSide(color: _line, width: 0.5),
              outside: pw.BorderSide(color: _line, width: 0.5),
            ),
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F9FAFB')),
                children: [
                  _cell('Category', bold, 4, header: true),
                  _cell('Set aside', bold, 2, header: true, alignRight: true),
                  _cell('Spent', bold, 2, header: true, alignRight: true),
                  _cell('Left', bold, 2, header: true, alignRight: true),
                ],
              ),
              ...keys.map((k) {
                final alloc = allocations[k] ?? 0;
                final spent = budget.byCategory[k] ?? 0;
                final left = alloc - spent;
                final over = alloc > 0 && spent > alloc;
                return pw.TableRow(
                  children: [
                    _cell(_pretty(k), font, 4),
                    _cell(alloc > 0 ? _money(alloc) : 'not set', font, 2, alignRight: true,
                        color: alloc > 0 ? null : _orange),
                    _cell(_money(spent), font, 2, alignRight: true),
                    _cell(
                      alloc <= 0 ? 'not budgeted' : (left >= 0 ? _money(left) : 'OVER ${_money(left.abs())}'),
                      bold,
                      2,
                      alignRight: true,
                      color: alloc <= 0 ? _muted : (over ? _warn : _good),
                    ),
                  ],
                );
              }),
            ],
          ),
        pw.SizedBox(height: 8),
        _totalsRow(font, bold, budget, allocations),
      ],
    );
  }

  pw.Widget _totalsRow(pw.Font font, pw.Font bold, BudgetBreakdown budget, Map<String, double> allocations) {
    final allocated = allocations.values.fold<double>(0, (a, b) => a + b);
    final unassigned = budget.budget - allocated;
    final over = unassigned < 0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(9),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F9FAFB'),
        border: pw.Border.all(color: _line, width: 0.5),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        children: [
          _kv('Trip budget', budget.budget > 0 ? _money(budget.budget) : 'not set', font, bold, budget.budget > 0 ? null : _muted),
          _kv('Total spent', _money(budget.spent), font, bold, null),
          if (allocated > 0) _kv('Allocated across categories', _money(allocated), font, bold, null),
          if (budget.budget > 0 && allocated > 0)
            _kv(
              over ? 'Allocated over budget by' : 'Budget not yet allocated',
              _money(unassigned.abs()),
              font,
              bold,
              over ? _warn : _muted,
            ),
          if (budget.budget > 0)
            _kv(
              budget.isOverBudget ? 'Over budget by' : 'Remaining',
              _money(budget.remaining.abs()),
              font,
              bold,
              budget.isOverBudget ? _warn : _good,
            ),
          if ((trip.travelers) > 0 && budget.hasBudget)
            _kv('Per traveller (spent)', _money(budget.spent / trip.travelers), font, bold, null),
        ],
      ),
    );
  }

  pw.Widget _kv(String label, String value, pw.Font font, pw.Font bold, PdfColor? color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: 9, color: _muted)),
          pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 9.5, color: color ?? _ink)),
        ],
      ),
    );
  }

  // ---------- expenses ----------

  pw.Widget _expenseTable(List<Expense> expenses, pw.Font font, pw.Font bold) {
    final sorted = [...expenses]..sort((a, b) => a.date.compareTo(b.date));
    // No row cap - a trip with 300 expenses should show all 300. dart_pdf
    // paginates tables across pages on its own.
    final shown = sorted;

    return pw.Table(
      border: pw.TableBorder.symmetric(
        inside: pw.BorderSide(color: _line, width: 0.5),
        outside: pw.BorderSide(color: _line, width: 0.5),
      ),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F9FAFB')),
          children: [
            _cell('Date', bold, 2, header: true),
            _cell('Item', bold, 4, header: true),
            _cell('Category', bold, 2, header: true),
            _cell('Amount', bold, 2, header: true, alignRight: true),
          ],
        ),
        ...shown.map(
          (e) => pw.TableRow(
            children: [
              _cell(_fmt(e.date), font, 2),
              _cell(e.title, font, 4),
              _cell(_pretty(e.category), font, 2),
              _cell(_moneyWith(e.amount, e.currency), font, 2, alignRight: true),
            ],
          ),
        ),
      ],
    );
  }

  /// The part friends actually care about: what the trip cost, and their share.
  pw.Widget _splitSummary(Trip t, List<Expense> expenses, BudgetBreakdown budget, pw.Font font, pw.Font bold) {
    final per = t.travelers > 0 ? budget.spent / t.travelers : 0.0;
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.all(9),
      decoration: pw.BoxDecoration(
        color: _accentWash,
        border: pw.Border.all(color: _accentLine, width: 0.5),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('SHARED SO FAR', style: pw.TextStyle(font: bold, fontSize: 8, color: _accent, letterSpacing: 1.2)),
          pw.SizedBox(height: 4),
          pw.Text(
            '${_money(budget.spent)} across ${t.travelers} ${t.travelers == 1 ? 'traveller' : 'travellers'} '
            'is ${_money(per)} each, if split evenly.',
            style: pw.TextStyle(font: font, fontSize: 9.5),
          ),
        ],
      ),
    );
  }

  // ---------- packing ----------

  pw.Widget _packingList(List<PackingItem> items, pw.Font font, pw.Font bold) {
    final sorted = [...items]..sort((a, b) {
      // packed is a bool: unpacked first, packed after.
      if (a.packed != b.packed) return a.packed ? 1 : -1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: sorted
          .map(
            (i) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 8,
                    height: 8,
                    margin: const pw.EdgeInsets.only(top: 2.5, right: 6),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: i.packed ? _good : _line, width: 0.8),
                      color: i.packed ? _good : null,
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      i.name,
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 9.5,
                        color: i.packed ? _muted : _ink,
                        decoration: i.packed ? pw.TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                  if ((i.quantity) > 1)
                    pw.Text('x${i.quantity}', style: pw.TextStyle(font: font, fontSize: 8.5, color: _muted)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  /// Booking references gathered in one place - the thing people lose.
  pw.Widget _confirmationFootnotes(List<Flight> flights, List<Hotel> hotels, pw.Font font) {
    final lines = <String>[];
    for (final f in flights) {
      final booking = f.bookingReference ?? '';
    final conf = f.confirmationNumber ?? '';
    final ref = booking.trim().isNotEmpty ? booking : conf;
      if (ref.trim().isNotEmpty) {
        lines.add('${[f.airline, f.flightNumber].where((s) => s.trim().isNotEmpty).join(' ')} - reference $ref');
      }
    }
    for (final h in hotels) {
      if ((h.confirmationNumber ?? '').trim().isNotEmpty) {
        lines.add('${h.name} - reference ${h.confirmationNumber}');
      }
    }
    if (lines.isEmpty) return pw.SizedBox();

    return pw.Container(
      padding: const pw.EdgeInsets.all(9),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _line, width: 0.5),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('BOOKING REFERENCES', style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 8, color: _muted, letterSpacing: 1)),
          pw.SizedBox(height: 4),
          ...lines.map((l) => pw.Text(l, style: pw.TextStyle(font: font, fontSize: 8.5))),
        ],
      ),
    );
  }

  // ---------- helpers ----------

  pw.Widget _cell(String text, pw.Font font, int flex, {bool header = false, bool alignRight = false, PdfColor? color}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(5),
      alignment: alignRight ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
      child: pw.Text(
        text.isEmpty ? ' ' : text,
        style: pw.TextStyle(
          font: font,
          fontSize: header ? 8.5 : 8.5,
          color: color ?? (header ? _muted : _ink),
          fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  String _fmt(DateTime d) => _dateFmt.format(d);
  String _money(double v) => _moneyWith(v, trip.baseCurrency);
  String _moneyWith(double v, String? currency) {
    final raw = (currency ?? '').trim().isEmpty ? trip.baseCurrency : (currency ?? '').trim();
    final c = raw;
    return '$c ${NumberFormat('#,##0.00').format(v)}';
  }

  String _route() {
    final from = trip.originName.trim();
    final to = trip.destName.trim();
    if (from.isEmpty && to.isEmpty) return 'Route not set';
    if (from.isEmpty) return 'To $to';
    if (to.isEmpty) return 'From $from';
    return '$from to $to';
  }

  String _nights() => trip.returnDate.difference(trip.departure).inDays.toString();

  static String _pretty(String raw) => switch (raw.trim().toLowerCase()) {
        'transport' || 'transportation' => 'Transportation',
        'food' => 'Food',
        'accommodation' || 'hotel' => 'Accommodation',
        'activities' || 'activity' => 'Activities',
        'shopping' => 'Shopping',
        'groceries' => 'Groceries',
        '' => 'Other',
        _ => raw[0].toUpperCase() + raw.substring(1),
      };
}