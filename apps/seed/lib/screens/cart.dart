// SPDX-License-Identifier: AGPL-3.0-only
import 'package:flutter/material.dart';

/// カート(docs/04 CartScreen・認証必須)。Phase 0 は空画面。
/// Phase 3 で提供者ごとのグループ表示を実装する。
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('カート')),
      body: const Center(child: Text('カート(準備中)')),
    );
  }
}
