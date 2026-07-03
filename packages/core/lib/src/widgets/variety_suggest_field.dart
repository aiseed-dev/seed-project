// SPDX-License-Identifier: MIT
import 'dart:async';

import 'package:flutter/material.dart';

import '../api_client.dart';
import '../constants.dart';
import '../models.dart';

/// 品種名のサジェスト入力(docs/04 PostListingScreen)。
///
/// 入力のたび GET /varieties?q= を debounce(300ms)で呼び、候補を表示する。
/// 候補外の名前のまま確定すると自由入力扱い(呼び出し側で variety_id なし)。
class VarietySuggestField extends StatefulWidget {
  const VarietySuggestField({
    super.key,
    required this.onChanged,
    this.client,
  });

  /// (入力中の名前, 確定した品種 or null) を親へ通知する。
  final void Function(String name, Variety? selected) onChanged;

  final ApiClient? client;

  @override
  State<VarietySuggestField> createState() => _VarietySuggestFieldState();
}

class _VarietySuggestFieldState extends State<VarietySuggestField> {
  final _controller = TextEditingController();
  List<Variety> _suggests = [];
  Variety? _selected;
  Timer? _debounce;

  ApiClient get _api => widget.client ?? ApiClient.i;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onText(String text) {
    _selected = null;
    widget.onChanged(text, null);
    _debounce?.cancel();
    if (text.trim().isEmpty) {
      setState(() => _suggests = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final rows = await _api.searchVarieties(text.trim());
        if (mounted) setState(() => _suggests = rows);
      } on ApiException {
        if (mounted) setState(() => _suggests = []);
      }
    });
  }

  void _select(Variety variety) {
    _controller.text = variety.name;
    setState(() {
      _selected = variety;
      _suggests = [];
    });
    widget.onChanged(variety.name, variety);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          onChanged: _onText,
          decoration: const InputDecoration(
            labelText: '品種名',
            hintText: '例: みやま小かぶ',
            border: OutlineInputBorder(),
          ),
        ),
        for (final variety in _suggests)
          ListTile(
            dense: true,
            title: Text(variety.name),
            subtitle:
                variety.summary != null ? Text(variety.summary!) : null,
            onTap: () => _select(variety),
          ),
        if (_selected == null && _controller.text.trim().isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'この名前で出品します(品種マスタへの提案が自動で作られます)',
              style: TextStyle(fontSize: 11, color: SeedColors.disabled),
            ),
          ),
      ],
    );
  }
}
