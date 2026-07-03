// SPDX-License-Identifier: AGPL-3.0-only
import 'package:flutter/material.dart';

import '../widgets/category_grid.dart';
import '../widgets/new_listings_strip.dart';

/// ホーム(docs/04): 分類グリッド+新着ストリップ。各部品が自分で取得する。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('種の交換')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: const [
          Text('分類からさがす',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          SizedBox(height: 8),
          CategoryGrid(),
          SizedBox(height: 16),
          Text('新着',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          SizedBox(height: 8),
          NewListingsStrip(),
        ],
      ),
    );
  }
}
