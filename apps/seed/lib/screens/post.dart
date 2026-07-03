// SPDX-License-Identifier: AGPL-3.0-only
import 'package:flutter/material.dart';

/// 出品(docs/04 PostListingScreen・認証必須)。Phase 0 は空画面。
class PostListingScreen extends StatefulWidget {
  const PostListingScreen({super.key});

  @override
  State<PostListingScreen> createState() => _PostListingScreenState();
}

class _PostListingScreenState extends State<PostListingScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('出品')),
      body: const Center(child: Text('出品(準備中)')),
    );
  }
}
