import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../core/database_helper.dart';
import '../services/soft_delete.dart';

/// Passports and visas in one place. Replaces the read-only list that
/// previously existed in the More tab.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  List<Passport> _passports = [];
  Map<int, List<Visa>> _visasByPassport = {};
  List<Visa> _standaloneVisas = [];
  bool _isLoading = true;

  /// Passport numbers are masked until explicitly revealed.
  final Set<int> _revealed = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await DatabaseHelper().database;
    final passportRows = await db.query('passports', where: 'deleted_at IS NULL', orderBy: 'expiry_date ASC');
    final visasByPassport = <int, List<Visa>>{};
    for (final row in passportRows) {
      final pid = row['id'] as int;
      final visaRows = await db.query('visas', where: 'passport_id = ? AND deleted_at IS NULL', whereArgs: [pid], orderBy: 'expiry_date ASC');
      visasByPassport[pid] = visaRows.map(Visa.fromMap).toList();
    }
    final loose = (await db.query('visas', where: 'passport_id IS NULL AND deleted_at IS NULL', orderBy: 'expiry_date ASC')).map(Visa.fromMap).toList();

    if (!mounted) return;
    setState(() {
      _passports = passportRows.map(Passport.fromMap).toList();
      _visasByPassport = visasByPassport;
      _standaloneVisas = loose;
      _isLoading = false;
    });
  }

  // ---------- masking ----------

  String _maskedNumber(String value) {
    final clean = value.trim();
    if (clean.length <= 4) return '••••';
    return '${clean.substring(0, 2)}${'•' * (clean.length - 4)}${clean.substring(clean.length - 2)}';
  }

  String _displayNumber(Passport p) {
    if (_revealed.contains(p.id)) return p.passportNumber;
    return _maskedNumber(p.passportNumber);
  }

  // ---------- validity ----------

  /// Status string + colour for a passport or visa expiry date.
  ({String label, Color color, IconData icon}) _expiryState(DateTime? expiry) {
    if (expiry == null) {
      return (label: 'No expiry date', color: Colors.grey, icon: Icons.help_outline);
    }
    final now = DateTime.now();
    final days = expiry.difference(now).inDays;
    if (expiry.isBefore(now)) {
      return (label: 'Expired ${_ago(expiry)} ago', color: Colors.red, icon: Icons.error);
    }
    if (days <= 30) {
      return (label: 'Expires in $days days', color: Colors.red, icon: Icons.warning);
    }
    if (days <= 90) {
      return (label: 'Expires in ${(days / 30).round()} months', color: Colors.orange, icon: Icons.warning_amber);
    }
    if (days <= 365) {
      return (label: 'Expires in ${(days / 30).round()} months', color: Colors.orange.shade700, icon: Icons.schedule);
    }
    final years = (days / 365).floor();
    return (label: 'Valid for $years more year${years == 1 ? '' : 's'}', color: Colors.green, icon: Icons.check_circle);
  }

  String _ago(DateTime d) {
    final days = DateTime.now().difference(d).inDays;
    if (days < 31) return '$days days';
    final months = (days / 30).floor();
    if (months < 12) return '$months months';
    return '${(months / 12).floor()} years';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Documents', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.add),
            onSelected: (v) {
              if (v == 'passport') _showPassportForm();
              if (v == 'visa') _showVisaForm();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'passport', child: Text('Add passport')),
              PopupMenuItem(value: 'visa', child: Text('Add visa')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  _sectionLabel('Passports', Icons.badge_outlined, cs, _passports.length),
                  const SizedBox(height: 10),
                  if (_passports.isEmpty)
                    _emptyBox('No passports added yet', 'Add one to get expiry alerts.', cs)
                  else
                    ..._passports.map(_passportCard),
                  const SizedBox(height: 24),
                  _sectionLabel('Visas', Icons.approval_outlined, cs,
                      _standaloneVisas.length + _visasByPassport.values.fold(0, (a, b) => a + b.length)),
                  const SizedBox(height: 10),
                  if (_standaloneVisas.isEmpty &&
                      _visasByPassport.values.every((v) => v.isEmpty))
                    _emptyBox('No visas added yet', 'Add a visa to track entry rules and expiry.', cs)
                  else ...[
                    for (final p in _passports)
                      ...(_visasByPassport[p.id] ?? []).map((v) => _visaCard(v, passport: p)),
                    ..._standaloneVisas.map((v) => _visaCard(v)),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _sectionLabel(String text, IconData icon, ColorScheme cs, int count) {
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 8),
        Text(text, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
        const Spacer(),
        Text('$count', style: GoogleFonts.inter(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5))),
      ],
    );
  }

  Widget _emptyBox(String title, String subtitle, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Icon(Icons.badge_outlined, size: 32, color: cs.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: 10),
          Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(subtitle, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.55))),
        ],
      ),
    );
  }

  Widget _passportCard(Passport p) {
    final cs = Theme.of(context).colorScheme;
    final state = _expiryState(p.expiryDate);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: state.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.badge, color: state.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.country, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () => setState(() {
                          if (!_revealed.add(p.id!)) _revealed.remove(p.id);
                        }),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _displayNumber(p),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                letterSpacing: 1.1,
                                color: cs.onSurface.withValues(alpha: 0.75),
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              _revealed.contains(p.id) ? Icons.visibility_off : Icons.visibility,
                              size: 14,
                              color: cs.onSurface.withValues(alpha: 0.45),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') _showPassportForm(p);
                    if (v == 'delete') _deletePassport(p);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(state.icon, size: 14, color: state.color),
                const SizedBox(width: 6),
                Text(state.label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: state.color)),
                const SizedBox(width: 10),
                Text('Expires ${DateFormat('MMM y').format(p.expiryDate)}', style: GoogleFonts.inter(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5))),
              ],
            ),
            if (p.holderName.isNotEmpty || p.nationality != null) ...[
              const SizedBox(height: 6),
              Text(
                [
                  if (p.holderName.isNotEmpty) p.holderName,
                  if (p.nationality != null) p.nationality!,
                ].join(' • '),
                style: GoogleFonts.inter(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5)),
              ),
            ],
            if ((_visasByPassport[p.id] ?? []).isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final v in _visasByPassport[p.id]!)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
                      child: Text('${v.country} — ${_visaLabel(v.visaType)}', style: GoogleFonts.inter(fontSize: 10, color: cs.primary)),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _visaCard(Visa v, {Passport? passport}) {
    final cs = Theme.of(context).colorScheme;
    final state = _expiryState(v.expiryDate);
    final statusColor = switch (v.status) {
      'approved' => Colors.green,
      'applied' || 'pending' => Colors.orange,
      'rejected' || 'refused' => Colors.red,
      'expired' => Colors.red,
      'not_required' => Colors.teal,
      _ => Colors.grey,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.approval, color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${v.country} — ${_visaLabel(v.visaType)}', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
                      if (passport != null)
                        Text('Via ${passport.country}', style: GoogleFonts.inter(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5))),
                    ],
                  ),
                ),
                _statusChip(v.status, statusColor),
                PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'edit') _showVisaForm(existing: v, passport: passport);
                    if (val == 'delete') _deleteVisa(v);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _meta(Icons.schedule, state.label, state.color),
                if (v.maxStayDays != null) _meta(Icons.timelapse, 'Max ${v.maxStayDays} days', cs.onSurface.withValues(alpha: 0.7)),
                if (v.entryRules != null) _meta(Icons.repeat, v.entryRules!, cs.onSurface.withValues(alpha: 0.7)),
                if (v.cost != null && v.cost! > 0)
                  _meta(Icons.payments, '\$${v.cost!.toStringAsFixed(0)}${v.costCurrency != null ? ' ${v.costCurrency}' : ''}', cs.onSurface.withValues(alpha: 0.7)),
              ],
            ),
            if (v.conditions != null && v.conditions!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(v.conditions!, style: GoogleFonts.inter(fontSize: 12, height: 1.35, color: cs.onSurface.withValues(alpha: 0.7))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(text, style: GoogleFonts.inter(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _statusChip(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
      child: Text(status.replaceAll('_', ' '), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  String _visaLabel(String type) => switch (type) {
        'tourist' => 'Tourist',
        'business' => 'Business',
        'transit' => 'Transit',
        'student' => 'Student',
        'work' => 'Work',
        'resident' => 'Resident',
        _ => type,
      };

  // ---------- passport form ----------

  void _showPassportForm([Passport? existing]) {
    final numberCtrl = TextEditingController(text: existing?.passportNumber ?? '');
    final holderCtrl = TextEditingController(text: existing?.holderName ?? '');
    final authorityCtrl = TextEditingController(text: existing?.issuingAuthority ?? '');
    final nationalityCtrl = TextEditingController(text: existing?.nationality ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    String country = existing?.country ?? '';
    String countryCode = existing?.countryCode ?? '';
    DateTime expiry = existing?.expiryDate ?? DateTime.now().add(const Duration(days: 365 * 5));
    DateTime issued = existing?.issuedDate ?? DateTime.now().subtract(const Duration(days: 365));
    int alertMonths = existing?.expiryAlertMonths ?? 6;
    String? error;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 16, left: 16, right: 16, top: 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(existing == null ? 'Add Passport' : 'Edit Passport', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                TextField(
                  controller: numberCtrl,
                  decoration: const InputDecoration(labelText: 'Passport number *', border: OutlineInputBorder()),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: holderCtrl,
                  decoration: const InputDecoration(labelText: 'Holder name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(text: country)
                          ..selection = TextSelection.collapsed(offset: country.length),
                        onChanged: (v) => setSheet(() => country = v),
                        decoration: const InputDecoration(labelText: 'Country *', hintText: 'UAE', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 110,
                      child: TextField(
                        controller: TextEditingController(text: countryCode)
                          ..selection = TextSelection.collapsed(offset: countryCode.length),
                        onChanged: (v) => setSheet(() => countryCode = v.toUpperCase()),
                        decoration: const InputDecoration(labelText: 'Code', hintText: 'AE', border: OutlineInputBorder()),
                        textCapitalization: TextCapitalization.characters,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _dateField('Issued', issued, (d) => setSheet(() => issued = d))),
                    const SizedBox(width: 10),
                    Expanded(child: _dateField('Expires *', expiry, (d) => setSheet(() => expiry = d))),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nationalityCtrl,
                  decoration: const InputDecoration(labelText: 'Nationality', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: authorityCtrl,
                  decoration: const InputDecoration(labelText: 'Issuing authority', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                Text('Warn me ${alertMonths == 1 ? '1 month' : '$alertMonths months'} before expiry', style: GoogleFonts.inter(fontSize: 13)),
                Slider(
                  value: alertMonths.toDouble().clamp(1, 24),
                  min: 1,
                  max: 24,
                  divisions: 23,
                  label: '${alertMonths}m',
                  onChanged: (v) => setSheet(() => alertMonths = v.round()),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: GoogleFonts.inter(fontSize: 13, color: Colors.red)),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final number = numberCtrl.text.trim();
                      final countryName = country.trim();
                      if (number.isEmpty || countryName.isEmpty) {
                        setSheet(() => error = 'Passport number and country are required.');
                        return;
                      }
                      final db = await DatabaseHelper().database;
                      final now = DateTime.now().toIso8601String();
                      final isExpired = expiry.isBefore(DateTime.now());
                      final expired = isExpired ? 1 : 0;
                      final soon =
                          !isExpired && expiry.difference(DateTime.now()).inDays <= alertMonths * 30 ? 1 : 0;
                      final row = {
                        'passport_number': number,
                        'country': countryName,
                        'country_code': countryCode.trim().isEmpty ? countryName.substring(0, countryName.length >= 2 ? 2 : 1).toUpperCase() : countryCode.trim(),
                        'issued_date': issued.toIso8601String(),
                        'expiry_date': expiry.toIso8601String(),
                        'issuing_authority': authorityCtrl.text.trim(),
                        'holder_name': holderCtrl.text.trim(),
                        'nationality': nationalityCtrl.text.trim().isEmpty ? null : nationalityCtrl.text.trim(),
                        'place_of_birth': existing != null ? null : null,
                        'date_of_birth': null,
                        'tax_id': null,
                        'photo_path': '',
                        'notes': notesCtrl.text.trim(),
                        'expiry_alert_months': alertMonths,
                        'expired': expired,
                        'expiring_soon': soon,
                        'created_at': existing?.createdAt.toIso8601String() ?? now,
                        'updated_at': now,
                        'sync_enabled': 1,
                        'sync_status': 0,
                      };
                      if (existing?.id == null) {
                        await db.insert('passports', row);
                      } else {
                        await db.update('passports', row, where: 'id = ?', whereArgs: [existing!.id]);
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      await _load();
                    },
                    child: Text(existing == null ? 'Save passport' : 'Update'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateField(String label, DateTime value, ValueChanged<DateTime> onPick) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(1990),
          lastDate: DateTime.now().add(const Duration(days: 365 * 20)),
        );
        if (d != null) onPick(d);
      },
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        child: Text(DateFormat('MMM d, y').format(value), style: GoogleFonts.inter(fontSize: 14)),
      ),
    );
  }

  // ---------- visa form ----------

  void _showVisaForm({Visa? existing, Passport? passport}) {
    final conditionsCtrl = TextEditingController(text: existing?.conditions ?? '');
    final rulesCtrl = TextEditingController(text: existing?.entryRules ?? '');
    final refCtrl = TextEditingController(text: existing?.applicationRef ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    final costCtrl = TextEditingController(text: existing?.cost != null ? existing!.cost!.toStringAsFixed(0) : '');
    String country = existing?.country ?? '';
    String countryCode = existing?.countryCode ?? '';
    String visaType = existing?.visaType ?? 'tourist';
    String status = existing?.status ?? 'approved';
    int? linkedPassportId = existing?.passportId ?? passport?.id;
    DateTime? expiry = existing?.expiryDate;
    int? maxStay = existing?.maxStayDays;
    String? error;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 16, left: 16, right: 16, top: 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(existing == null ? 'Add Visa' : 'Edit Visa', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(text: country)
                          ..selection = TextSelection.collapsed(offset: country.length),
                        onChanged: (v) => setSheet(() => country = v),
                        decoration: const InputDecoration(labelText: 'Country *', hintText: 'UZ', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 110,
                      child: TextField(
                        controller: TextEditingController(text: countryCode)
                          ..selection = TextSelection.collapsed(offset: countryCode.length),
                        onChanged: (v) => setSheet(() => countryCode = v.toUpperCase()),
                        decoration: const InputDecoration(labelText: 'Code', border: OutlineInputBorder()),
                        textCapitalization: TextCapitalization.characters,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: visaType,
                  decoration: const InputDecoration(labelText: 'Visa type', border: OutlineInputBorder()),
                  items: const ['tourist', 'business', 'transit', 'student', 'work', 'resident', 'other']
                      .map((t) => DropdownMenuItem(value: t, child: Text(_visaLabel(t))))
                      .toList(),
                  onChanged: (v) => setSheet(() => visaType = v ?? visaType),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                  items: const [
                    ('approved', 'Approved / granted'),
                    ('applied', 'Applied / pending'),
                    ('not_required', 'Not required'),
                    ('rejected', 'Rejected / refused'),
                  ]
                      .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)))
                      .toList(),
                  onChanged: (v) => setSheet(() => status = v ?? status),
                ),
                const SizedBox(height: 12),
                if (_passports.isNotEmpty)
                  DropdownButtonFormField<int?>(
                    initialValue: linkedPassportId,
                    decoration: const InputDecoration(labelText: 'Linked passport', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('None')),
                      ..._passports.map((p) => DropdownMenuItem(value: p.id, child: Text(p.country))),
                    ],
                    onChanged: (v) => setSheet(() => linkedPassportId = v),
                  ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: expiry ?? DateTime.now().add(const Duration(days: 365)),
                      firstDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 15)),
                    );
                    if (d != null) setSheet(() => expiry = d);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Expiry date', border: OutlineInputBorder()),
                    child: Text(expiry == null ? 'tap to set' : DateFormat('MMM d, y').format(expiry!), style: GoogleFonts.inter(fontSize: 14)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: rulesCtrl,
                  decoration: const InputDecoration(labelText: 'Entry rules', hintText: 'Single entry', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: TextEditingController(text: maxStay?.toString() ?? '')
                    ..selection = TextSelection.collapsed(offset: maxStay?.toString().length ?? 0),
                  onChanged: (v) => maxStay = int.tryParse(v),
                  decoration: const InputDecoration(labelText: 'Max stay (days)', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: costCtrl,
                  decoration: const InputDecoration(labelText: 'Cost', border: OutlineInputBorder()),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: refCtrl,
                  decoration: const InputDecoration(labelText: 'Application reference', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: conditionsCtrl,
                  decoration: const InputDecoration(labelText: 'Conditions / notes', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: GoogleFonts.inter(fontSize: 13, color: Colors.red)),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final countryName = country.trim();
                      if (countryName.isEmpty) {
                        setSheet(() => error = 'Country is required.');
                        return;
                      }
                      final db = await DatabaseHelper().database;
                      final now = DateTime.now().toIso8601String();
                      final row = {
                        'passport_id': linkedPassportId,
                        'country': countryName,
                        'country_code': countryCode.trim().isEmpty ? countryName.substring(0, countryName.length >= 2 ? 2 : 1).toUpperCase() : countryCode.trim(),
                        'visa_type': visaType,
                        'status': status,
                        'issued_date': existing?.issuedDate?.toIso8601String(),
                        'expiry_date': expiry?.toIso8601String(),
                        'entry_date': existing?.entryDate?.toIso8601String(),
                        'exit_date': existing?.exitDate?.toIso8601String(),
                        'max_stay_days': maxStay,
                        'entry_rules': rulesCtrl.text.trim().isEmpty ? null : rulesCtrl.text.trim(),
                        'conditions': conditionsCtrl.text.trim().isEmpty ? null : conditionsCtrl.text.trim(),
                        'cost': double.tryParse(costCtrl.text.trim()),
                        'cost_currency': null,
                        'application_ref': refCtrl.text.trim().isEmpty ? null : refCtrl.text.trim(),
                        'notes': notesCtrl.text.trim(),
                        'photo_path': '',
                        'created_at': existing?.createdAt.toIso8601String() ?? now,
                        'updated_at': now,
                        'sync_enabled': 1,
                        'sync_status': 0,
                      };
                      if (existing?.id == null) {
                        await db.insert('visas', row);
                      } else {
                        await db.update('visas', row, where: 'id = ?', whereArgs: [existing!.id]);
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      await _load();
                    },
                    child: Text(existing == null ? 'Save visa' : 'Update'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- delete ----------

  Future<void> _deletePassport(Passport p) async {
    final ok = await _confirm('Delete ${p.country} passport?');
    if (!ok || p.id == null) return;
    final db = await DatabaseHelper().database;
    // Soft delete so a restore never resurrects a passport the user removed.
    await softDelete(db, 'visas', p.id!);
    final visaRows = await db.query('visas', where: 'passport_id = ?', whereArgs: [p.id]);
    for (final v in visaRows) {
      if (v['id'] is int) await softDelete(db, 'visas', v['id'] as int);
    }
    await softDelete(db, 'passports', p.id!);
    await _load();
  }

  Future<void> _deleteVisa(Visa v) async {
    final ok = await _confirm('Delete ${v.country} visa?');
    if (!ok || v.id == null) return;
    final db = await DatabaseHelper().database;
    await softDelete(db, 'visas', v.id!);
    await _load();
  }

  Future<bool> _confirm(String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Are you sure?'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    return result == true;
  }
}
