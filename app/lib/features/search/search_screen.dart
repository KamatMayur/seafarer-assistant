import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';

/// S6: search all circulars and notices (server full-text search; saved documents only when offline).
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _q = TextEditingController();
  String? _type, _dept;
  List<DocumentCard> _items = [];
  int _total = 0, _page = 1;
  bool _loading = false, _offline = false;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _search({bool more = false}) async {
    setState(() {
      _loading = true;
      _error = null;
      if (!more) _page = 1;
    });
    try {
      final r = await ref.read(documentRepoProvider).search(
            q: _q.text.trim().isEmpty ? null : _q.text.trim(),
            docType: _type,
            department: _dept,
            page: _page,
          );
      if (!mounted) return; // the user left the Archive tab while this search was loading
      setState(() {
        _items = more ? [..._items, ...r.items] : r.items;
        _total = r.total;
        _offline = r.offline;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onTyped(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _search);
  }

  @override
  Widget build(BuildContext context) {
    final meta = ref.watch(metaProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Archive')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            controller: _q,
            onChanged: _onTyped,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search circulars, e.g. "CoC revalidation" or "53 of 2026"',
              suffixIcon: _q.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _q.clear();
                        _search();
                      },
                    ),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(children: [
            for (final e in docTypeLabels.entries.where((e) => e.key != 'unknown'))
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(e.value),
                  selected: _type == e.key,
                  onSelected: (on) {
                    setState(() => _type = on ? e.key : null);
                    _search();
                  },
                ),
              ),
            const SizedBox(width: 12),
            if (meta != null)
              DropdownButton<String?>(
                value: _dept,
                hint: const Text('Any department'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Any department')),
                  for (final e in meta.departments.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) {
                  setState(() => _dept = v);
                  _search();
                },
              ),
          ]),
        ),
        if (_offline)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Offline: searching only documents saved on this device.'),
          ),
        if (_error != null)
          Padding(padding: const EdgeInsets.all(16), child: Text(_error!)),
        Expanded(
          child: _items.isEmpty && !_loading
              ? const EmptyState(icon: Icons.search_off, title: 'No documents found')
              : ListView.builder(
                  itemCount: _items.length + 1,
                  itemBuilder: (_, i) {
                    if (i == _items.length) {
                      if (_loading) {
                        return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                      }
                      if (!_offline && _items.length < _total) {
                        return Center(
                          child: TextButton(
                            onPressed: () {
                              _page++;
                              _search(more: true);
                            },
                            child: Text('Show more (${_total - _items.length} left)'),
                          ),
                        );
                      }
                      return const SizedBox(height: 24);
                    }
                    final d = _items[i];
                    return ListTile(
                      title: Text(d.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text([
                        docTypeLabel(d.docType),
                        if (d.circularNumber != null) d.circularNumber!,
                        fmtDate(d.publishedDate),
                        if (d.status == 'archived') 'archive (no summary)',
                      ].join(' · ')),
                      leading: Icon(d.isCritical ? Icons.warning_amber : Icons.description_outlined,
                          color: d.isCritical ? Theme.of(context).colorScheme.error : null),
                      onTap: () => context.push('/document/${d.id}'),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
