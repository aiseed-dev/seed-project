// SPDX-License-Identifier: MIT
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'session.dart';

/// API 呼出しの失敗。ステータス 0 は接続不可(メンテナンス中表示に使う)。
class ApiException implements Exception {
  ApiException(this.status, this.message);

  final int status;
  final String message;

  @override
  String toString() => 'ApiException($status, $message)';
}

/// backend(docs/03)への薄い HTTP クライアント。
///
/// 認証トークンは [Session.instance] から自動で付与する。
/// レスポンスは JSON を decode して返すのみで、モデルへの変換は
/// 呼び出し側(または models)で行う。
class ApiClient {
  ApiClient({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Map<String, String> _headers() {
    final token = Session.instance.token;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> getJson(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    return _send(() => _client.get(uri, headers: _headers()));
  }

  Future<dynamic> postJson(String path, Object? body) async {
    final uri = Uri.parse('$baseUrl$path');
    return _send(
      () => _client.post(uri, headers: _headers(), body: jsonEncode(body)),
    );
  }

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    http.Response res;
    try {
      res = await request();
    } on http.ClientException catch (e) {
      throw ApiException(0, e.message);
    }
    if (res.statusCode >= 400) {
      throw ApiException(res.statusCode, res.body);
    }
    if (res.body.isEmpty) return null;
    return jsonDecode(res.body);
  }
}
