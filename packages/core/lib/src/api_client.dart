// SPDX-License-Identifier: MIT
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';
import 'session.dart';

/// API 呼出しの失敗。ステータス 0 は接続不可(メンテナンス中表示に使う)。
class ApiException implements Exception {
  ApiException(this.status, this.message, {this.code});

  final int status;
  final String message;
  final String? code; // docs/03 のエラーコード(REGISTERED_VARIETY 等)

  @override
  String toString() => 'ApiException($status, $code, $message)';
}

/// backend(docs/03)への HTTP クライアント。
///
/// アプリ起動時に [ApiClient.init] で設定し、以後 [ApiClient.i] で使う。
/// 認証トークンは [Session.instance] から自動で付与する。
class ApiClient {
  ApiClient({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  static late ApiClient i;

  static void init(String baseUrl, {http.Client? client}) {
    i = ApiClient(baseUrl: baseUrl, client: client);
  }

  final String baseUrl;
  final http.Client _client;

  // --- 型付きメソッド(docs/03) ---

  Future<List<Category>> fetchCategories() async {
    final rows = await getJson('/categories') as List<dynamic>;
    return rows
        .map((r) => Category.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<Listing>> fetchListings({
    String? category,
    String? type,
    String? q,
    String? cursor,
    int limit = 20,
  }) async {
    final result = await getJson('/listings', query: {
      if (category != null) 'category': category,
      if (type != null) 'type': type,
      if (q != null) 'q': q,
      if (cursor != null) 'cursor': cursor,
      'limit': '$limit',
    }) as Map<String, dynamic>;
    return (result['items'] as List<dynamic>)
        .map((r) => Listing.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<Listing> fetchListing(String id) async {
    final json = await getJson('/listings/$id') as Map<String, dynamic>;
    return Listing.fromJson(json);
  }

  Future<Listing> createListing(Map<String, dynamic> body) async {
    final json = await postJson('/listings', body) as Map<String, dynamic>;
    return Listing.fromJson(json);
  }

  Future<List<Variety>> searchVarieties(String q, {int limit = 10}) async {
    final rows = await getJson('/varieties', query: {'q': q, 'limit': '$limit'})
        as List<dynamic>;
    return rows
        .map((r) => Variety.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  // --- 低レベル ---

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
      String message = res.body;
      String? code;
      try {
        final json = jsonDecode(utf8.decode(res.bodyBytes));
        if (json is Map<String, dynamic>) {
          message = (json['detail'] ?? message).toString();
          code = json['code'] as String?;
        }
      } on FormatException {
        // JSON でないエラー本文はそのまま使う
      }
      throw ApiException(res.statusCode, message, code: code);
    }
    if (res.body.isEmpty) return null;
    return jsonDecode(utf8.decode(res.bodyBytes));
  }
}
