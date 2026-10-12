import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reads the text of a certificate scan or PDF on the device (decisions.md R12). Windows uses its built-in OCR
/// engine through the runner's "seafarer/ocr" channel (windows/runner/ocr_channel.cpp). Mobile (Phase 5) will use
/// Google ML Kit's on-device text recognition behind the same interface. The file never leaves the device and the
/// text is not stored.
class CertificateOcr {
  static const _channel = MethodChannel('seafarer/ocr');

  bool get available => Platform.isWindows;

  /// Returns the recognised text (empty if none). Throws [PlatformException] if the file cannot be read.
  Future<String> readText(String path) async => await _channel.invokeMethod<String>('readText', {'path': path}) ?? '';
}

final ocrProvider = Provider<CertificateOcr>((_) => CertificateOcr());
