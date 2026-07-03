// SPDX-License-Identifier: MIT
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// 認証状態のシングルトン。グローバル状態はこれ1つ(方針)。
///
/// PocketBase でログインしてトークンとユーザーIDのみを保持する
/// (業務データは持たない)。変更を監視したい画面は [Listenable] として
/// listen する。
final class Session extends ChangeNotifier {
  Session._();

  static final Session instance = Session._();

  /// PocketBase の URL。アプリ起動時に設定する。
  static String pocketbaseUrl = '';

  String? _token;
  String? _userId;

  String? get token => _token;
  String? get userId => _userId;
  bool get isLoggedIn => _token != null;

  /// PocketBase にログインしてトークンを保持する。
  Future<void> login(
    String email,
    String password, {
    http.Client? client,
  }) async {
    final c = client ?? http.Client();
    final res = await c.post(
      Uri.parse('$pocketbaseUrl/api/collections/users/auth-with-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'identity': email, 'password': password}),
    );
    if (res.statusCode != 200) {
      throw SessionException('メールアドレスまたはパスワードが違います');
    }
    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    _token = json['token'] as String?;
    _userId = (json['record'] as Map<String, dynamic>?)?['id'] as String?;
    if (_token == null || _userId == null) {
      throw SessionException('ログインに失敗しました');
    }
    notifyListeners();
  }

  /// PocketBase にユーザーを作成し、確認メールを送る。
  Future<void> register(
    String email,
    String password, {
    String? name,
    http.Client? client,
  }) async {
    final c = client ?? http.Client();
    final res = await c.post(
      Uri.parse('$pocketbaseUrl/api/collections/users/records'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'passwordConfirm': password,
        if (name != null && name.isNotEmpty) 'name': name,
      }),
    );
    if (res.statusCode >= 400) {
      throw SessionException('登録に失敗しました(既に登録済みの可能性があります)');
    }
    // メール確認(PocketBase が確認メールを送信する)
    await c.post(
      Uri.parse(
        '$pocketbaseUrl/api/collections/users/request-verification',
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
  }

  void logout() {
    _token = null;
    _userId = null;
    notifyListeners();
  }

  /// テスト用: 直接トークンを設定する。
  @visibleForTesting
  void setForTest({required String token, required String userId}) {
    _token = token;
    _userId = userId;
    notifyListeners();
  }
}

class SessionException implements Exception {
  SessionException(this.message);

  final String message;

  @override
  String toString() => message;
}
