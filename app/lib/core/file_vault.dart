import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Certificate scans are stored only on this device, encrypted with AES-256-GCM (decisions.md D5).
/// The key is generated on first use and kept in the OS credential store, so a copied file is unreadable
/// elsewhere. File layout: 12-byte nonce | ciphertext | 16-byte MAC.
class FileVault {
  FileVault({FlutterSecureStorage? storage, Future<Directory> Function()? baseDir})
      : _storage = storage ?? const FlutterSecureStorage(),
        _baseDir = baseDir ?? getApplicationSupportDirectory;

  final FlutterSecureStorage _storage;
  final Future<Directory> Function() _baseDir;
  final _algo = AesGcm.with256bits();
  static const _keyName = 'sa_file_vault_key';
  SecretKey? _key;

  Future<SecretKey> _secretKey() async {
    if (_key != null) return _key!;
    var b64 = await _storage.read(key: _keyName);
    if (b64 == null) {
      final rnd = Random.secure();
      b64 = base64Encode(List<int>.generate(32, (_) => rnd.nextInt(256)));
      await _storage.write(key: _keyName, value: b64);
    }
    return _key = SecretKey(base64Decode(b64));
  }

  Future<Directory> _dir() async {
    final d = Directory(p.join((await _baseDir()).path, 'vault'));
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  /// Encrypts [source] into the vault and returns the vault file path.
  Future<String> store(File source, String id) async {
    final box = await _algo.encrypt(await source.readAsBytes(), secretKey: await _secretKey());
    final out = File(p.join((await _dir()).path, '$id.bin'));
    await out.writeAsBytes(box.concatenation(), flush: true);
    return out.path;
  }

  Future<List<int>> read(String vaultPath) async {
    final bytes = await File(vaultPath).readAsBytes();
    final box = SecretBox.fromConcatenation(bytes, nonceLength: 12, macLength: 16);
    return _algo.decrypt(box, secretKey: await _secretKey());
  }

  /// Decrypts to a temporary file for viewing; the caller opens it with the system viewer.
  Future<File> decryptToTemp(String vaultPath, String fileName) async {
    final tmp = Directory(p.join(Directory.systemTemp.path, 'seafarer_assistant_view'));
    if (!tmp.existsSync()) tmp.createSync(recursive: true);
    final out = File(p.join(tmp.path, fileName));
    await out.writeAsBytes(await read(vaultPath), flush: true);
    return out;
  }

  Future<void> remove(String? vaultPath) async {
    if (vaultPath != null && File(vaultPath).existsSync()) await File(vaultPath).delete();
  }

  /// Sign-out / account deletion.
  Future<void> wipe() async {
    final d = await _dir();
    if (d.existsSync()) await d.delete(recursive: true);
    await _storage.delete(key: _keyName);
    _key = null;
  }
}
