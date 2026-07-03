// SPDX-License-Identifier: AGPL-3.0-only
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 新着の横スクロール(docs/04 HomeScreen)。/listings?limit=10 を自分で取得。
class NewListingsStrip extends StatefulWidget {
  const NewListingsStrip({super.key});

  @override
  State<NewListingsStrip> createState() => _NewListingsStripState();
}

class _NewListingsStripState extends State<NewListingsStrip> {
  List<Listing>? _items; // null=読込中
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _items = null;
      _error = null;
    });
    try {
      final items = await ApiClient.i.fetchListings(limit: 10);
      if (mounted) setState(() => _items = items);
    } on ApiException {
      if (mounted) setState(() => _error = '読み込めませんでした');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: TextButton(onPressed: _load, child: Text('$_error(再試行)')),
      );
    }
    final items = _items;
    if (items == null) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('まだ出品がありません'),
      );
    }
    return SizedBox(
      height: 230,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => SizedBox(
          width: 160,
          child: ListingCard(
            listing: items[i],
            onTap: () => context.go('/l/${items[i].id}'),
          ),
        ),
      ),
    );
  }
}
