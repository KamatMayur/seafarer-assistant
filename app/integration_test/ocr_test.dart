/// Reads the FAKE certificate in fixtures/ (image and image-only PDF) with the real Windows OCR engine through the
/// runner's channel, then checks the fields the rules pull out. Run (cd app):
///   flutter test integration_test/ocr_test.dart -d windows
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:seafarer_assistant/core/ocr.dart';
import 'package:seafarer_assistant/domain/certificate_scan.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final name in ['fake_certificate.png', 'fake_certificate.pdf']) {
    testWidgets('Windows OCR reads $name', (t) async {
      final path = File('integration_test/fixtures/$name').absolute.path;
      final text = await t.runAsync(() => CertificateOcr().readText(path));
      // ignore: avoid_print
      print('--- OCR text of $name ---\n$text');
      final g = readCertificateText(text!);
      expect(g.type, 'stcw_advanced');
      expect(g.subtype, 'AFF');
      expect(g.number, 'AFF/FAKE/2024/0042');
      expect(g.issue, DateTime(2024, 3, 15));
      expect(g.expiry, DateTime(2029, 3, 14));
      expect(g.authority, 'FAKE Maritime Training Institute, Pune');
    });
  }
}
