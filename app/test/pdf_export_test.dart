import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:seafarer_assistant/data/db.dart';
import 'package:seafarer_assistant/features/export/pdf_export.dart';

// 1x1 PNG, used as a FAKE certificate scan.
final _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

int _pages(List<int> pdf) => RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(pdf)).length;

SeaService _sea(String id, String vessel, String on, String? off, {String? rank}) => SeaService(
      id: id,
      vesselName: vessel,
      rank: rank,
      signOn: on,
      signOff: off,
      shipType: 'tanker',
      version: 1,
      updatedAt: DateTime(2026),
      dirty: false,
    );

Certificate _cert(String id, String type, String? expiry, {String? file}) => Certificate(
      id: id,
      type: type,
      number: 'FAKE-$id',
      expiryDate: expiry,
      version: 1,
      updatedAt: DateTime(2026),
      dirty: false,
      filePath: file == null ? null : 'vault/$id',
      fileName: file,
    );

void main() {
  test('pdfSafe keeps Latin-1, turns typographic punctuation into ASCII, replaces other scripts', () {
    expect(pdfSafe('MV Sagar – “Ratna” …'), 'MV Sagar - "Ratna" ...');
    expect(pdfSafe('Café'), 'Café');
    expect(pdfSafe('सागर'), '????');
    expect(pdfSafe(null), '');
  });

  test('sea service summary builds, including a non-Latin vessel name', () async {
    final pdf = await seaServicePdf(
      entries: [
        _sea('1', 'FAKE MV Example', '2025-01-01', '2025-06-30', rank: 'Third Officer'),
        _sea('2', 'FAKE सागर', '2025-08-01', null, rank: 'Second Officer'),
      ],
      today: DateTime.utc(2026, 10, 14),
      holderName: 'FAKE Seafarer',
      shipTypeLabels: {'tanker': 'Tanker'},
      compress: false,
    );
    expect(latin1.decode(pdf.sublist(0, 5)), '%PDF-');
    expect(_pages(pdf), 1);
  });

  test('certificates pack adds one page per image scan, PDF scans stay in the app', () async {
    final pdf = await certificatesPdf(
      certificates: [
        _cert('a', 'medical', '2026-12-01', file: 'medical.png'),
        _cert('b', 'coc', '2030-01-01', file: 'coc.pdf'),
        _cert('c', 'cdc', null),
      ],
      today: DateTime.utc(2026, 10, 14),
      certTypeLabels: {'medical': 'Medical fitness', 'coc': 'CoC', 'cdc': 'CDC'},
      images: {'a': _png},
      compress: false,
    );
    expect(_pages(pdf), 2); // the table page + the medical scan
  });
}
