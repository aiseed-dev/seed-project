// SPDX-License-Identifier: AGPL-3.0-only
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 承認待ちキュー(docs/04 RevisionQueueScreen・editor 以上のみ)。
class RevisionQueueScreen extends StatefulWidget {
  const RevisionQueueScreen({super.key});

  @override
  State<RevisionQueueScreen> createState() => _RevisionQueueScreenState();
}

class _RevisionQueueScreenState extends State<RevisionQueueScreen> {
  List<RevisionQueueEntry>? _entries; // null=読込中
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _entries = null;
      _error = null;
    });
    try {
      final entries = await ApiClient.i.fetchEditorQueue();
      if (mounted) setState(() => _entries = entries);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e.status == 403 ? 'editor 権限が必要です' : 'メンテナンス中です');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    return Scaffold(
      appBar: AppBar(title: const Text('編集提案の承認')),
      body: _error != null
          ? Center(child: Text(_error!))
          : entries == null
              ? const Center(child: CircularProgressIndicator())
              : entries.isEmpty
                  ? const Center(child: Text('承認待ちはありません'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        itemCount: entries.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final entry = entries[i];
                          return ListTile(
                            title: Text(entry.varietyName),
                            subtitle: Text(
                              '${entry.authorName}・${entry.revision.editSummary ?? "(概要なし)"}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => context.go(
                                '/editor/revisions/${entry.revision.id}'),
                          );
                        },
                      ),
                    ),
    );
  }
}
