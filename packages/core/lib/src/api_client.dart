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

  Future<List<CartGroup>> fetchCart() async {
    final rows = await getJson('/cart') as List<dynamic>;
    return rows
        .map((r) => CartGroup.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> putCartItem(String listingId, int quantity) =>
      putJson('/cart/items/$listingId', {'quantity': quantity});

  Future<void> deleteCartItem(String listingId) =>
      deleteJson('/cart/items/$listingId');

  Future<TradeRequest> createRequest({
    required String providerKind,
    required String providerId,
    String? note,
  }) async {
    final json = await postJson('/requests', {
      'provider_kind': providerKind,
      'provider_id': providerId,
      if (note != null && note.isNotEmpty) 'note': note,
    }) as Map<String, dynamic>;
    return TradeRequest.fromJson(json);
  }

  Future<List<TradeRequestEntry>> fetchRequests() async {
    final rows = await getJson('/requests') as List<dynamic>;
    return rows
        .map((r) => TradeRequestEntry.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<TradeRequest> fetchRequest(String id) async {
    final json = await getJson('/requests/$id') as Map<String, dynamic>;
    return TradeRequest.fromJson(json);
  }

  Future<TradeRequest> patchRequest(String id, String status) async {
    final json =
        await patchJson('/requests/$id', {'status': status})
            as Map<String, dynamic>;
    return TradeRequest.fromJson(json);
  }

  Future<List<Message>> fetchMessages(String requestId) async {
    final rows = await getJson('/requests/$requestId/messages') as List<dynamic>;
    return rows
        .map((r) => Message.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<Message> postMessage(String requestId, String body) async {
    final json = await postJson('/requests/$requestId/messages', {'body': body})
        as Map<String, dynamic>;
    return Message.fromJson(json);
  }

  Future<void> postReview(String requestId, int score, String? comment) =>
      postJson('/requests/$requestId/reviews', {
        'score': score,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      });

  Future<Article> fetchArticle(String varietyId) async {
    final json = await getJson('/articles/$varietyId') as Map<String, dynamic>;
    return Article.fromJson(json);
  }

  Future<void> postRevision(
    String varietyId,
    Map<String, String> content,
    String? editSummary,
  ) =>
      postJson('/articles/$varietyId/revisions', {
        'content': content,
        if (editSummary != null && editSummary.isNotEmpty)
          'edit_summary': editSummary,
      });

  Future<List<RevisionSummary>> fetchMyRevisions() async {
    final rows = await getJson('/me/revisions') as List<dynamic>;
    return rows
        .map((r) => RevisionSummary.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<RevisionQueueEntry>> fetchEditorQueue() async {
    final rows = await getJson('/editor/revisions') as List<dynamic>;
    return rows
        .map((r) => RevisionQueueEntry.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<RevisionDetail> fetchEditorRevision(String id) async {
    final json = await getJson('/editor/revisions/$id') as Map<String, dynamic>;
    return RevisionDetail.fromJson(json);
  }

  Future<void> reviewRevision(String id, String action, String? note) =>
      patchJson('/editor/revisions/$id', {
        'action': action,
        if (note != null && note.isNotEmpty) 'review_note': note,
      });

  Future<Me> fetchMe() async {
    final json = await getJson('/me') as Map<String, dynamic>;
    return Me.fromJson(json);
  }

  Future<void> postReport({
    required String targetType,
    required String targetId,
    required String reason,
    String? detail,
  }) =>
      postJson('/reports', {
        'target_type': targetType,
        'target_id': targetId,
        'reason': reason,
        if (detail != null && detail.isNotEmpty) 'detail': detail,
      });

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

  Future<dynamic> putJson(String path, Object? body) async {
    final uri = Uri.parse('$baseUrl$path');
    return _send(
      () => _client.put(uri, headers: _headers(), body: jsonEncode(body)),
    );
  }

  Future<dynamic> patchJson(String path, Object? body) async {
    final uri = Uri.parse('$baseUrl$path');
    return _send(
      () => _client.patch(uri, headers: _headers(), body: jsonEncode(body)),
    );
  }

  Future<dynamic> deleteJson(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    return _send(() => _client.delete(uri, headers: _headers()));
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
