// SPDX-License-Identifier: MIT
import 'package:flutter/foundation.dart';

/// 認証状態のシングルトン。グローバル状態はこれ1つ(方針)。
///
/// PocketBase のトークンとユーザーIDのみを保持する。
/// 画面側は [Session.instance] を参照し、変更を監視したい場合は
/// [Listenable] として listen する。
final class Session extends ChangeNotifier {
  Session._();

  static final Session instance = Session._();

  String? _token;
  String? _userId;

  String? get token => _token;
  String? get userId => _userId;
  bool get isLoggedIn => _token != null;

  void signIn({required String token, required String userId}) {
    _token = token;
    _userId = userId;
    notifyListeners();
  }

  void signOut() {
    _token = null;
    _userId = null;
    notifyListeners();
  }
}
