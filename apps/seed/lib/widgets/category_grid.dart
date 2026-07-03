// SPDX-License-Identifier: AGPL-3.0-only
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 分類グリッド(docs/04 HomeScreen)。自己完結型: /categories を自分で取得。
class CategoryGrid extends StatefulWidget {
  const CategoryGrid({super.key});

  @override
  State<CategoryGrid> createState() => _CategoryGridState();
}

class _CategoryGridState extends State<CategoryGrid> {
  List<Category>? _items; // null=読込中
  String? _error;

  static const _icons = <String, IconData>{
    'fruit-veg': Icons.spa,
    'leaf-veg': Icons.eco,
    'root-veg': Icons.south,
    'beans': Icons.grain,
    'grains': Icons.grass,
    'herbs': Icons.local_florist,
    'flowers': Icons.filter_vintage,
    'seedlings': Icons.park,
  };

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
      final items = await ApiClient.i.fetchCategories();
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
      return const Center(child: CircularProgressIndicator());
    }
    final wide = MediaQuery.of(context).size.width >= 600;
    return GridView.count(
      crossAxisCount: wide ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.6,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        for (final c in items)
          Card(
            color: SeedColors.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: const BorderSide(color: Color(0xFFE3DDCD)),
            ),
            child: InkWell(
              onTap: () => context.go('/c/${c.slug}'),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(
                    _icons[c.slug] ?? Icons.grass,
                    color: SeedColors.green,
                  ),
                  const SizedBox(width: 8),
                  Text(c.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
