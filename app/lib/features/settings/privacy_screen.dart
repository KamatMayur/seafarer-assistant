import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers.dart';
import '../../widgets/common.dart';

final _privacyProvider = FutureProvider.autoDispose<String>((ref) async {
  final j = await ref.read(apiClientProvider).get('/v1/legal/privacy', auth: false) as Map<String, dynamic>;
  return j['markdown'] as String;
});

/// Privacy notice and tester terms (served by the API so there is one source of truth).
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final md = ref.watch(_privacyProvider);
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/welcome')),
        title: const Text('Privacy notice and tester terms'),
        actions: [
          TextButton(
            onPressed: () => launchUrl(Uri.parse('${ref.read(apiClientProvider).baseUrl}/privacy')),
            child: const Text('Open in browser'),
          ),
        ],
      ),
      body: md.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.cloud_off,
          title: 'Could not load the privacy notice',
          message: '$e',
          action: OutlinedButton(onPressed: () => ref.invalidate(_privacyProvider), child: const Text('Try again')),
        ),
        data: (text) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: SelectionArea(child: MarkdownLite(text)),
          ),
        ),
      ),
    );
  }
}

/// Renders the small Markdown subset the notice uses: headings, paragraphs, bullet lists, tables, **bold**.
class MarkdownLite extends StatelessWidget {
  const MarkdownLite(this.text, {super.key});
  final String text;

  List<InlineSpan> _inline(String s, TextStyle? base) {
    final spans = <InlineSpan>[];
    final re = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*');
    var last = 0;
    for (final m in re.allMatches(s)) {
      if (m.start > last) spans.add(TextSpan(text: s.substring(last, m.start)));
      spans.add(m.group(1) != null
          ? TextSpan(text: m.group(1), style: const TextStyle(fontWeight: FontWeight.w700))
          : TextSpan(text: m.group(2), style: const TextStyle(fontStyle: FontStyle.italic)));
      last = m.end;
    }
    if (last < s.length) spans.add(TextSpan(text: s.substring(last)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final children = <Widget>[];
    final table = <List<String>>[];

    void flushTable() {
      if (table.isEmpty) return;
      children.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Table(
          border: TableBorder.all(color: Theme.of(context).dividerColor),
          columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(3)},
          children: [
            for (var i = 0; i < table.length; i++)
              TableRow(children: [
                for (final c in table[i])
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text.rich(TextSpan(
                        children: _inline(c, null),
                        style: i == 0 ? const TextStyle(fontWeight: FontWeight.w700) : null)),
                  ),
              ]),
          ],
        ),
      ));
      table.clear();
    }

    for (final line in text.split('\n')) {
      if (line.startsWith('|')) {
        final cells = line.split('|').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
        if (!cells.every((c) => RegExp(r'^[-:]+$').hasMatch(c))) table.add(cells);
        continue;
      }
      flushTable();
      if (line.startsWith('# ')) {
        children.add(Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(line.substring(2), style: t.headlineSmall)));
      } else if (line.startsWith('## ')) {
        children.add(Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 6), child: Text(line.substring(3), style: t.titleMedium)));
      } else if (line.startsWith('- ')) {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 4, left: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('•  '),
            Expanded(child: Text.rich(TextSpan(children: _inline(line.substring(2), null)))),
          ]),
        ));
      } else if (line.trim().isNotEmpty) {
        children.add(Padding(
            padding: const EdgeInsets.only(bottom: 8), child: Text.rich(TextSpan(children: _inline(line, null)))));
      }
    }
    flushTable();
    return ListView(padding: const EdgeInsets.all(24), children: children);
  }
}
