// SPDX-License-Identifier: AGPL-3.0-only
import 'package:flutter/material.dart';

/// ホーム(docs/04)。Phase 0 は空画面。
/// Phase 2 で CategoryGrid / NewListingsStrip を実装する。
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
      body: const Center(child: Text('ホーム(準備中)')),
    );
  }
}
