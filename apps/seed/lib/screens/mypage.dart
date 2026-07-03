// SPDX-License-Identifier: AGPL-3.0-only
import 'package:flutter/material.dart';

/// マイページ(docs/04 MyPageScreen・認証必須)。Phase 0 は空画面。
/// 申込み一覧はここから辿る(docs/04)。
class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('マイページ')),
      body: const Center(child: Text('マイページ(準備中)')),
    );
  }
}
