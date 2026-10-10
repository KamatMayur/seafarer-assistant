import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

import '../data/db.dart';
import 'api_client.dart';

/// 'Report a problem' and automatic crash reports. Reports are queued on this device and sent when online and
/// signed in, so nothing is lost on a ship with no connection. Crash reports contain the error and app version only.
class FeedbackService {
  FeedbackService(this.api, this.db);
  final ApiClient api;
  final AppDatabase db;
  static const _queueKey = 'pending_feedback';
  static const maxCrashesPerSession = 5;
  final _seenCrashes = <int>{};
  int _crashesThisSession = 0;

  Future<List<Map<String, dynamic>>> _queue() async {
    final raw = await db.getValue(_queueKey);
    return raw == null ? [] : (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }

  Future<void> _save(List<Map<String, dynamic>> q) => db.setValue(_queueKey, jsonEncode(q));

  Future<Map<String, dynamic>> _base() async {
    String version = '';
    try {
      version = (await PackageInfo.fromPlatform()).version;
    } catch (_) {}
    return {'app_version': version, 'platform': Platform.operatingSystem};
  }

  /// Queues the report and tries to send it now. Returns true if it reached the server.
  Future<bool> report({required String kind, required String message, Map<String, String> context = const {}}) async {
    final q = await _queue()
      ..add({...await _base(), 'kind': kind, 'message': message, 'context': context});
    await _save(q.length > 50 ? q.sublist(q.length - 50) : q); // bounded on disk
    return flush();
  }

  /// Called from FlutterError.onError / PlatformDispatcher.onError. Never throws.
  void reportCrash(Object error, StackTrace? stack) {
    final key = '${error.runtimeType}:$error'.hashCode;
    if (_crashesThisSession >= maxCrashesPerSession || !_seenCrashes.add(key)) return;
    _crashesThisSession++;
    final text = '$error\n\n${stack ?? ''}';
    unawaited(report(
      kind: 'crash',
      message: text.length > 7000 ? text.substring(0, 7000) : text,
      context: {'error_type': '${error.runtimeType}'},
    ).catchError((_) => false));
  }

  /// Sends queued reports. Keeps them if offline or signed out.
  Future<bool> flush() async {
    if (await api.tokens.refreshToken() == null) return false;
    final q = await _queue();
    while (q.isNotEmpty) {
      try {
        await api.post('/v1/feedback', body: q.first);
      } on ApiException catch (e) {
        if (e.offline || e.unauthorized || e.status == 429) {
          await _save(q);
          return false;
        }
        // 4xx: malformed report, drop it rather than block the queue
      }
      q.removeAt(0);
      await _save(q);
    }
    return true;
  }
}
