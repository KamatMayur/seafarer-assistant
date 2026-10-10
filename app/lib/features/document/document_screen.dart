import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';

final _detailProvider = FutureProvider.autoDispose.family<({DocumentDetail detail, bool fromCache}), String>(
  (ref, id) async {
    final lang = (await ref.read(profileRepoProvider).cached())?.preferredLanguage ?? 'en';
    return ref.read(documentRepoProvider).detail(id, lang: lang);
  },
);

/// S5 full screen (narrow windows, links from search and toasts).
class DocumentScreen extends StatelessWidget {
  const DocumentScreen({super.key, required this.documentId});
  final String documentId;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/feed')),
          title: const Text('Document'),
        ),
        body: DocumentView(documentId: documentId),
      );
}

class DocumentView extends ConsumerWidget {
  const DocumentView({super.key, required this.documentId});
  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(_detailProvider(documentId));
    return detail.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: e is ApiException && e.offline ? Icons.cloud_off : Icons.error_outline,
        title: 'Could not open this document',
        message: '$e',
        action: OutlinedButton(
          onPressed: () => ref.invalidate(_detailProvider(documentId)),
          child: const Text('Try again'),
        ),
      ),
      data: (r) => _DocumentBody(detail: r.detail, fromCache: r.fromCache),
    );
  }
}

class _DocumentBody extends ConsumerWidget {
  const _DocumentBody({required this.detail, required this.fromCache});
  final DocumentDetail detail;
  final bool fromCache;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final card = detail.card;
    final s = detail.summary;
    final meta = ref.watch(metaProvider).value;

    String label(String kind, String code) {
      if (meta == null) return code.replaceAll('_', ' ');
      final m = switch (kind) {
        'departments' => meta.departments,
        'levels' => meta.levels,
        'ship_types' => meta.shipTypes,
        'mmds' => meta.mmds,
        'cert_types' => meta.certTypes,
        'exam_grades' => meta.examGrades,
        _ => const <String, String>{},
      };
      return meta.label(m, code);
    }

    final groups = s?.affectedGroups ?? {};
    final who = [for (final e in groups.entries) ...e.value.map((v) => label(e.key, v))];

    Widget section(String title, Widget child) => Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.titleSmall?.copyWith(color: cs.primary)),
            const SizedBox(height: 6),
            child,
          ]),
        );

    final uncertain = s?.uncertainFields ?? const [];
    return SelectionArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(24, 16, 24, 32), children: [
        if (fromCache)
          _Banner(icon: Icons.cloud_off, text: 'Offline: showing the copy saved on this device.', color: cs.tertiaryContainer),
        if (s?.languageFallback == true)
          _Banner(
            icon: Icons.translate,
            text: 'This summary is not yet available in your language, so it is shown in English.',
            color: cs.surfaceContainerHighest,
          ),
        if (uncertain.contains('text_quality'))
          _Banner(
            icon: Icons.warning_amber,
            text: 'The PDF is a poor-quality scan. The extract below may contain errors; read the official PDF.',
            color: cs.errorContainer,
          ),
        Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          if (card.isCritical) PriorityBadge(label: 'CRITICAL', color: cs.error, onColor: cs.onError),
          Text(
            [
              docTypeLabel(card.docType),
              if (card.circularNumber != null) 'No. ${card.circularNumber}',
              fmtDate(card.publishedDate),
              if (card.issuingBranch != null) card.issuingBranch!,
            ].join(' · '),
            style: t.labelLarge,
          ),
        ]),
        const SizedBox(height: 8),
        Text(card.title, style: t.headlineSmall),
        const SizedBox(height: 12),
        const DisclaimerBox(),
        if (s != null) ...[
          section('In short', Text(s.summaryShort, style: t.bodyLarge)),
          section('Who is affected', Text(who.isEmpty ? 'All seafarers (no specific group named)' : who.join(', '))),
          section(
            'What you must do',
            Text(
              s.actionRequired
                  ? 'This document asks readers to act. See the key points and the official PDF.'
                  : 'No action for individual seafarers was found in the text.',
            ),
          ),
          section(
            'Deadline',
            Text(
              s.actionDeadline != null ? fmtDate(s.actionDeadline) : 'Not stated in circular',
              style: s.actionDeadline != null ? t.bodyLarge?.copyWith(fontWeight: FontWeight.w700) : null,
            ),
          ),
          if (s.keyPoints.isNotEmpty)
            section(
              'Key points (quoted from the document)',
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final p in s.keyPoints)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('•  '),
                      Expanded(child: Text(p)),
                    ]),
                  ),
              ]),
            ),
          if (s.summaryDetailed != null)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('More text from the document'),
              children: [Text(s.summaryDetailed!)],
            ),
        ] else
          section('Summary', const Text('No summary for this document. Please read the official PDF.')),
        if (detail.impacts.isNotEmpty)
          section(
            'Your certificates',
            Column(children: [
              for (final i in detail.impacts)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.flag, color: cs.tertiary),
                  title: Text(i.reason),
                  trailing: TextButton(
                    onPressed: () => context.go('/wallet/${i.certificateId}'),
                    child: const Text('Open'),
                  ),
                ),
            ]),
          ),
        if (detail.related.isNotEmpty)
          section(
            'Related',
            Column(children: [
              for (final r in detail.related)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.link),
                  title: Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${r.relation}${r.circularNumber == null ? '' : ' · No. ${r.circularNumber}'}'),
                  onTap: () => context.push('/document/${r.documentId}'),
                ),
            ]),
          ),
        const SizedBox(height: 20),
        Wrap(spacing: 12, runSpacing: 8, children: [
          FilledButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open official PDF'),
            onPressed: () => launchUrl(Uri.parse(detail.pdfUrl), mode: LaunchMode.externalApplication),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copy link'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: detail.pdfUrl));
              showSnack(context, 'Link copied');
            },
          ),
        ]),
        const SizedBox(height: 16),
        if (s != null)
          Text(
            '${s.method == 'human' || s.verifiedByHuman ? 'Checked by an editor' : 'Automatic extract, not yet checked by an editor'}'
            ' · ${s.modelVersion}',
            style: t.bodySmall,
          ),
      ]),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
        child: Row(children: [Icon(icon, size: 18), const SizedBox(width: 8), Expanded(child: Text(text))]),
      );
}
