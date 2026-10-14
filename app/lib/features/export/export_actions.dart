import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../domain/expiry.dart';
import '../../widgets/common.dart';
import 'pdf_export.dart';

/// Asks where to save, then writes the PDF there. Nothing leaves the device unless the user moves the file.
Future<void> _save(BuildContext context, Future<Uint8List> Function() build, String fileName) async {
  try {
    final bytes = await build();
    final saved = await FilePicker.saveFile(
      dialogTitle: 'Save PDF',
      fileName: fileName,
      bytes: bytes,
      mimeType: 'application/pdf',
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (saved != null && context.mounted) showSnack(context, 'Saved to ${saved.toFilePath()}');
  } catch (e) {
    if (context.mounted) showSnack(context, 'Could not create the PDF: $e');
  }
}

String _stamp(DateTime d) => formatDay(d);

Future<void> exportSeaServicePdf(BuildContext context, WidgetRef ref) async {
  final today = todayIst();
  final entries = await ref.read(seaServiceProvider.future);
  final profile = await ref.read(profileProvider.future);
  final labels = ref.read(metaProvider).value?.shipTypes ?? const {};
  if (!context.mounted) return;
  await _save(
    context,
    () => seaServicePdf(entries: entries, today: today, holderName: profile?.name, shipTypeLabels: labels),
    'sea-service-${_stamp(today)}.pdf',
  );
}

/// Image scans (JPG/PNG) are decrypted in memory only and placed in the PDF; PDF scans stay in the app.
Future<void> exportCertificatesPdf(BuildContext context, WidgetRef ref) async {
  final today = todayIst();
  final certs = await ref.read(certificatesProvider.future);
  final profile = await ref.read(profileProvider.future);
  final labels = ref.read(metaProvider).value?.certTypes ?? const {};
  final vault = ref.read(fileVaultProvider);
  if (!context.mounted) return;
  await _save(context, () async {
    final images = <String, Uint8List>{};
    for (final c in certs) {
      final name = (c.fileName ?? '').toLowerCase();
      if (c.filePath == null || !(name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.png'))) continue;
      images[c.id] = Uint8List.fromList(await vault.read(c.filePath!));
    }
    return certificatesPdf(
      certificates: certs,
      today: today,
      holderName: profile?.name,
      certTypeLabels: labels,
      images: images,
    );
  }, 'certificates-${_stamp(today)}.pdf');
}
