// SPDX-License-Identifier: AGPL-3.0-only
import 'package:flutter/material.dart';

/// 検索(docs/04 SearchResultScreen)。Phase 0 は空画面。
class SearchResultScreen extends StatefulWidget {
  const SearchResultScreen({super.key});

  @override
  State<SearchResultScreen> createState() => _SearchResultScreenState();
}

class _SearchResultScreenState extends State<SearchResultScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('検索')),
      body: const Center(child: Text('検索(準備中)')),
    );
  }
}
