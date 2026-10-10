import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'token_store.dart';

/// Thrown for any non-2xx answer. [offline] is true when the server could not be reached at all.
class ApiException implements Exception {
  ApiException(this.message, {this.status, this.offline = false});
  final String message;
  final int? status;
  final bool offline;

  bool get unauthorized => status == 401;

  @override
  String toString() => message;
}

/// Small JSON client for the /v1 API. Refreshes the access token once on 401 and retries.
class ApiClient {
  ApiClient({required this.baseUrl, required this.tokens, http.Client? client}) : _http = client ?? http.Client();

  String baseUrl;
  final TokenStore tokens;
  final http.Client _http;
  Future<bool>? _refreshing;

  /// Called when the refresh token is rejected: the user has to sign in again.
  void Function()? onSignedOut;

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final q = query?.map((k, v) => MapEntry(k, v is List ? v.map((e) => '$e').toList() : '$v'))
      ?..removeWhere((_, v) => v == 'null' || v == '');
    return Uri.parse(baseUrl.replaceAll(RegExp(r'/+$'), '') + path).replace(queryParameters: q);
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query, bool auth = true}) =>
      _send('GET', path, query: query, auth: auth);

  Future<dynamic> post(String path, {Object? body, bool auth = true}) => _send('POST', path, body: body, auth: auth);

  Future<dynamic> patch(String path, {Object? body}) => _send('PATCH', path, body: body);

  Future<dynamic> put(String path, {Object? body}) => _send('PUT', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  /// Raw bytes (data export ZIP).
  Future<List<int>> getBytes(String path) async {
    final resp = await _raw('GET', path, auth: true);
    return resp.bodyBytes;
  }

  Future<dynamic> _send(String method, String path,
      {Map<String, dynamic>? query, Object? body, bool auth = true}) async {
    final resp = await _raw(method, path, query: query, body: body, auth: auth);
    if (resp.body.isEmpty) return null;
    return jsonDecode(utf8.decode(resp.bodyBytes));
  }

  Future<http.Response> _raw(String method, String path,
      {Map<String, dynamic>? query, Object? body, bool auth = true, bool retried = false}) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (auth) {
      final access = await tokens.accessToken();
      if (access != null) headers['Authorization'] = 'Bearer $access';
    }
    final req = http.Request(method, _uri(path, query))..headers.addAll(headers);
    if (body != null) req.body = jsonEncode(body);

    http.Response resp;
    try {
      resp = await http.Response.fromStream(await _http.send(req).timeout(const Duration(seconds: 30)));
    } on SocketException {
      throw ApiException('No connection to the server.', offline: true);
    } on TimeoutException {
      throw ApiException('The server took too long to answer.', offline: true);
    } on http.ClientException {
      throw ApiException('No connection to the server.', offline: true);
    }

    if (resp.statusCode == 401 && auth && !retried && await _refresh()) {
      return _raw(method, path, query: query, body: body, auth: auth, retried: true);
    }
    if (resp.statusCode >= 400) {
      throw ApiException(_detail(resp), status: resp.statusCode);
    }
    return resp;
  }

  String _detail(http.Response resp) {
    try {
      final d = jsonDecode(utf8.decode(resp.bodyBytes))['detail'];
      if (d is String) return d;
      if (d is List && d.isNotEmpty) return '${d.first['msg']}';
    } catch (_) {}
    return 'Server error (${resp.statusCode}).';
  }

  /// One refresh at a time; concurrent 401s wait for the same attempt.
  Future<bool> _refresh() {
    return _refreshing ??= () async {
      try {
        final refresh = await tokens.refreshToken();
        if (refresh == null) return false;
        final resp = await _http.post(_uri('/v1/auth/refresh'),
            headers: {'Content-Type': 'application/json'}, body: jsonEncode({'refresh_token': refresh}));
        if (resp.statusCode != 200) {
          await tokens.clear();
          onSignedOut?.call();
          return false;
        }
        final j = jsonDecode(resp.body) as Map<String, dynamic>;
        await tokens.save(j['access_token'] as String, j['refresh_token'] as String);
        return true;
      } catch (_) {
        return false;
      } finally {
        _refreshing = null;
      }
    }();
  }
}
