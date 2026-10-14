import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../data/db.dart';
import '../../domain/expiry.dart';
import '../../domain/sea_time.dart';
import '../../widgets/common.dart' show fmtDate;

/// S16: PDF export of the sea service summary and the certificates pack, built on the device (nothing is uploaded).
/// Every page says it is prepared by the seafarer with an independent app and is not an official record.

const _footer = 'Prepared by the seafarer with Seafarer Assistant, an independent app not affiliated with DGMA, '
    'DG Shipping or the Government of India. Not an official record.';

/// The built-in PDF font (Helvetica) only covers Latin-1: typographic punctuation becomes its ASCII form, and
/// anything else (e.g. a vessel name typed in Devanagari) becomes '?' instead of breaking the document.
@visibleForTesting
String pdfSafe(String? s) {
  if (s == null) return '';
  const ascii = {0x2013: '-', 0x2014: '-', 0x2018: "'", 0x2019: "'", 0x201C: '"', 0x201D: '"', 0x2022: '-', 0x2026: '...'};
  return s.runes.map((r) => r < 256 ? String.fromCharCode(r) : (ascii[r] ?? '?')).join();
}

pw.Widget _header(String title, String? holder, DateTime today) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(pdfSafe(title), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        if (holder != null && holder.trim().isNotEmpty) pw.Text(pdfSafe(holder.trim())),
        pw.Text('Generated ${fmtDate(today)}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.SizedBox(height: 12),
      ],
    );

pw.Widget _pageFooter(pw.Context c) => pw.Column(children: [
      pw.Divider(color: PdfColors.grey400),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(child: pw.Text(_footer, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700))),
        pw.SizedBox(width: 12),
        pw.Text('Page ${c.pageNumber} of ${c.pagesCount}', style: const pw.TextStyle(fontSize: 7)),
      ]),
    ]);

pw.Widget _table(List<String> headers, List<List<String>> rows) => pw.TableHelper.fromTextArray(
      headers: headers,
      data: [for (final r in rows) r.map(pdfSafe).toList()],
      headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 8),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellAlignment: pw.Alignment.centerLeft,
    );

Future<Uint8List> seaServicePdf({
  required List<SeaService> entries,
  required DateTime today,
  String? holderName,
  Map<String, String> shipTypeLabels = const {},
  bool compress = true,
}) {
  final sorted = [...entries]..sort((a, b) => a.signOn.compareTo(b.signOn));
  final spells = [
    for (final s in sorted)
      SeaSpell(signOn: parseDay(s.signOn)!, signOff: parseDay(s.signOff), rank: s.rank, shipType: s.shipType),
  ];
  final totals = seaTotals(spells, today);
  String ship(String? k) => k == null || k.isEmpty ? '' : (shipTypeLabels[k] ?? k);
  List<List<String>> breakdown(Map<String, int> m, String Function(String) label) => [
        for (final e in m.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
          [label(e.key), '${e.value}', describeDays(e.value)],
      ];

  final doc = pw.Document(compress: compress, title: 'Sea service summary', creator: 'Seafarer Assistant');
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    margin: const pw.EdgeInsets.all(28),
    footer: _pageFooter,
    build: (_) => [
      _header('Sea service summary', holderName, today),
      _table(
        ['Vessel', 'IMO', 'Rank', 'Ship type', 'Flag', 'Signed on', 'Signed off', 'Days'],
        [
          for (var i = 0; i < sorted.length; i++)
            [
              sorted[i].vesselName,
              sorted[i].imo ?? '',
              sorted[i].rank ?? '',
              ship(sorted[i].shipType),
              sorted[i].flag ?? '',
              fmtDate(parseDay(sorted[i].signOn)),
              sorted[i].signOff == null ? 'on board' : fmtDate(parseDay(sorted[i].signOff)),
              '${switch (spellRange(spells[i], today)) { final r? => rangeDays(r), null => 0 }}',
            ],
        ],
      ),
      pw.SizedBox(height: 14),
      pw.Text('Total sea time: ${describeDays(totals.totalDays)} (${totals.totalDays} days)',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      pw.Text('Sign-on and sign-off days both count; overlapping entries are counted once in the total.',
          style: const pw.TextStyle(fontSize: 8)),
      pw.SizedBox(height: 10),
      _table(['Rank', 'Days', 'About'], breakdown(totals.byRank, (k) => k.isEmpty ? 'Not given' : k)),
      pw.SizedBox(height: 8),
      _table(['Ship type', 'Days', 'About'], breakdown(totals.byShipType, (k) => k.isEmpty ? 'Not given' : ship(k))),
      pw.SizedBox(height: 10),
      pw.Text('The dates in your CDC and your sea service testimonials are the official record.',
          style: const pw.TextStyle(fontSize: 8)),
    ],
  ));
  return doc.save();
}

/// [images] maps a certificate id to the decrypted bytes of its JPG/PNG scan; those get a page each.
Future<Uint8List> certificatesPdf({
  required List<Certificate> certificates,
  required DateTime today,
  String? holderName,
  Map<String, String> certTypeLabels = const {},
  Map<String, Uint8List> images = const {},
  bool compress = true,
}) {
  final sorted = [...certificates]..sort((a, b) => (a.expiryDate ?? '9999').compareTo(b.expiryDate ?? '9999'));
  String title(Certificate c) {
    final base = certTypeLabels[c.type] ?? c.type.toUpperCase();
    return c.subtype?.isNotEmpty == true ? '$base – ${c.subtype}' : base;
  }

  final doc = pw.Document(compress: compress, title: 'Certificates', creator: 'Seafarer Assistant');
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    margin: const pw.EdgeInsets.all(28),
    footer: _pageFooter,
    build: (_) => [
      _header('Certificates', holderName, today),
      _table(
        ['Certificate', 'Number', 'Issued by', 'Issued', 'Expires', 'Status', 'Scan'],
        [
          for (final c in sorted)
            [
              title(c),
              c.number ?? '',
              c.issuingAuthority ?? '',
              fmtDate(parseDay(c.issueDate)),
              c.expiryDate == null ? 'no expiry' : fmtDate(parseDay(c.expiryDate)),
              describeExpiry(c.expiryDate, today),
              images.containsKey(c.id) ? 'attached' : (c.filePath != null ? 'kept in the app (PDF)' : ''),
            ],
        ],
      ),
      pw.SizedBox(height: 10),
      pw.Text('Copies for reference only. Show the original certificates when asked.',
          style: const pw.TextStyle(fontSize: 8)),
    ],
  ));
  for (final c in sorted.where((c) => images.containsKey(c.id))) {
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(pdfSafe('${title(c)}${c.number?.isNotEmpty == true ? ' · ${c.number}' : ''}'),
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Expanded(child: pw.Center(child: pw.Image(pw.MemoryImage(images[c.id]!), fit: pw.BoxFit.contain))),
        _pageFooter(ctx),
      ]),
    ));
  }
  return doc.save();
}
