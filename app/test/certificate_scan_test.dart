// Certificate text below is FAKE (invented names and numbers), shaped like Windows OCR output: one line per text
// line, labels and values sometimes split across lines or columns.
import 'package:flutter_test/flutter_test.dart';
import 'package:seafarer_assistant/domain/certificate_scan.dart';

void main() {
  test('dates: Indian day-first, month names, ISO, impossible dates rejected', () {
    List<DateTime> d(String s) => findDates(s.toLowerCase()).map((f) => f.date).toList();
    expect(d('03/04/2025'), [DateTime(2025, 4, 3)]);
    expect(d('03-04-25'), [DateTime(2025, 4, 3)]);
    expect(d('12/31/2025'), [DateTime(2025, 12, 31)]); // only possible US-style
    expect(d('31/02/2025'), isEmpty);
    expect(d('5th March 2026'), [DateTime(2026, 3, 5)]);
    expect(d('05-MAR-2026 and Mar 6, 2026'), [DateTime(2026, 3, 5), DateTime(2026, 3, 6)]);
    expect(d('2027-01-09'), [DateTime(2027, 1, 9)]);
  });

  test('CoC: grade, number, MMD, labelled dates on the same line', () {
    final g = readCertificateText('''
FAKE SAMPLE
CERTIFICATE OF COMPETENCY
Marine Engineer Officer Class II
Certificate No: FAKE/MEO/II/12345
Issued by Mercantile Marine Department, Mumbai
Date of Issue: 14/02/2022    Date of Expiry: 13/02/2027
Date of Birth: 01/01/1990
''');
    expect(g.type, 'coc');
    expect(g.subtype, 'MEO Class II');
    expect(g.number, 'FAKE/MEO/II/12345');
    expect(g.authority, 'MMD Mumbai');
    expect(g.issue, DateTime(2022, 2, 14));
    expect(g.expiry, DateTime(2027, 2, 13));
  });

  test('two-column table: labels on one line, values on the next', () {
    final g = readCertificateText('''
Certificate of Proficiency
Advanced Fire Fighting
FAKE Maritime Training Institute, Pune
Cert. No. AFF-0099-FAKE
Date of Issue Valid Until
10 Jan 2024 09 Jan 2029
''');
    expect(g.type, 'stcw_advanced');
    expect(g.subtype, 'AFF');
    expect(g.authority, 'FAKE Maritime Training Institute, Pune');
    expect(g.number, 'AFF-0099-FAKE');
    expect(g.issue, DateTime(2024, 1, 10));
    expect(g.expiry, DateTime(2029, 1, 9));
  });

  test('label with the value on the next line; birth dates ignored; basic course', () {
    final g = readCertificateText('''
Personal Survival Techniques
Date of birth
02/03/1995
Date of issue
11/11/2023
Certificate number
PST 778899
''');
    expect(g.type, 'stcw_basic');
    expect(g.subtype, 'PST');
    expect(g.issue, DateTime(2023, 11, 11));
    expect(g.expiry, isNull);
    expect(g.number, 'PST 778899');
  });

  test('medical, CDC and passport types', () {
    expect(readCertificateText('Medical Fitness Certificate\nFit for sea service').type, 'medical');
    expect(readCertificateText('CONTINUOUS DISCHARGE CERTIFICATE\nCDC No. MUM 000000').type, 'cdc');
    final p = readCertificateText(
      'REPUBLIC OF INDIA\nPASSPORT\nNationality INDIAN\nZ0000000\nDate of Expiry 01/06/2030',
    );
    expect(p.type, 'passport');
    expect(p.number, 'Z0000000');
    expect(p.expiry, DateTime(2030, 6, 1));
  });

  test('no labels: earliest and latest dates; expiry before issue is dropped', () {
    final g = readCertificateText('FAKE certificate\n01/05/2021\n30/04/2026');
    expect(g.issue, DateTime(2021, 5, 1));
    expect(g.expiry, DateTime(2026, 4, 30));
    final bad = readCertificateText('Date of issue 01/01/2025\nValid till 01/01/2020');
    expect(bad.issue, DateTime(2025, 1, 1));
    expect(bad.expiry, isNull);
  });

  test('unreadable text gives nothing rather than a guess', () {
    expect(readCertificateText('').isEmpty, isTrue);
    expect(readCertificateText('~~ ## random noise 12 ab').isEmpty, isTrue);
    expect(readCertificateText('Certificate No. November').number, isNull);
  });
}
