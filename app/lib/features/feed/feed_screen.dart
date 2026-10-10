import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/background.dart';
import '../../core/providers.dart';
import '../../data/db.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../domain/feed_grouping.dart';
import '../../widgets/common.dart';
import '../document/document_screen.dart';

/// S4: alerts that match the profile, newest first, critical pinned. Two panes on wide windows.
class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key, this.selectedId});
  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final list = _FeedList(selectedId: selectedId, wide: wide);
    if (!wide) return list;
    return Row(children: [
      SizedBox(width: 420, child: list),
      const VerticalDivider(width: 1),
      Expanded(
        child: selectedId == null
            ? const EmptyState(icon: Icons.article_outlined, title: 'Select an alert to read it here')
            : DocumentView(key: ValueKey(selectedId), documentId: selectedId!),
      ),
    ]);
  }
}

class _FeedList extends ConsumerWidget {
  const _FeedList({required this.selectedId, required this.wide});
  final String? selectedId;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(feedItemsProvider);
    final last = ref.watch(lastSyncProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('For you'),
        actions: [
          if (last != null)
            Center(child: Text('Updated ${timeAgo(last)}', style: Theme.of(context).textTheme.bodySmall)),
          IconButton(
            tooltip: 'Check for new alerts',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(backgroundSyncProvider).runOnce(),
          ),
        ],
      ),
      body: Column(children: [
        const OfflineBanner(),
        Expanded(
          child: items.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => EmptyState(icon: Icons.error_outline, title: 'Could not read saved alerts', message: '$e'),
            data: (rows) {
              if (rows.isEmpty) {
                return EmptyState(
                  icon: Icons.notifications_none,
                  title: last == null ? 'Getting your alerts…' : 'Nothing for you in the last 30 days',
                  message: 'New circulars, exam notices and advisories that match your profile appear here. '
                      'The app checks every 30 minutes while it is open.',
                  action: OutlinedButton(
                    onPressed: () => ref.read(backgroundSyncProvider).runOnce(),
                    child: const Text('Check now'),
                  ),
                );
              }
              final byAlert = {for (final r in rows) r.alertId: r};
              final cards = groupFeed(rows.map(FeedRepository.toAlert).toList());
              return RefreshIndicator(
                onRefresh: () => ref.read(backgroundSyncProvider).runOnce(),
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: cards.length,
                  itemBuilder: (_, i) => FeedCardTile(
                    card: cards[i],
                    row: byAlert[cards[i].main.alertId]!,
                    selected: cards[i].main.documentId != null && cards[i].main.documentId == selectedId,
                    onOpen: () {
                      final c = cards[i];
                      ref.read(feedRepoProvider).markRead(c.all.where((a) => !a.read).map((a) => a.alertId));
                      if (c.main.documentId != null) {
                        context.go(wide ? '/feed/doc/${c.main.documentId}' : '/document/${c.main.documentId}');
                      } else if (c.main.certificateId != null) {
                        context.go('/wallet/${c.main.certificateId}');
                      }
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class FeedCardTile extends StatelessWidget {
  const FeedCardTile({super.key, required this.card, required this.row, required this.selected, required this.onOpen});
  final FeedCard card;
  final FeedItem row;
  final bool selected;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final doc = row.documentJson == null
        ? null
        : DocumentCard.fromJson(jsonDecode(row.documentJson!) as Map<String, dynamic>);
    final unread = card.unread;
    final title = doc?.title ?? (card.main.kind == 'cert_expiry' ? 'Certificate expiry reminder' : 'Notice');
    final impactReason = card.impacts.isNotEmpty ? card.impacts.first.reason : null;

    return Card(
      color: selected ? cs.secondaryContainer : null,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (unread)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(Icons.circle, size: 10, color: cs.primary, semanticLabel: 'Unread'),
                ),
              if (card.isCritical)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: PriorityBadge(label: 'CRITICAL', color: cs.error, onColor: cs.onError),
                ),
              if (card.isUpdate)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: PriorityBadge(label: 'UPDATED', color: cs.tertiary, onColor: cs.onTertiary),
                ),
              Expanded(
                child: Text(
                  [
                    if (doc != null) docTypeLabel(doc.docType),
                    if (doc?.circularNumber != null) doc!.circularNumber!,
                    if (doc?.publishedDate != null) fmtDate(doc!.publishedDate),
                  ].join(' · '),
                  style: t.labelMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
            const SizedBox(height: 4),
            Text(title,
                style: t.titleSmall?.copyWith(fontWeight: unread ? FontWeight.w700 : FontWeight.w500),
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
            if (card.main.kind == 'cert_expiry' && card.main.reason != null)
              Padding(padding: const EdgeInsets.only(top: 4), child: Text(card.main.reason!)),
            if (doc?.actionRequired == true)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [
                  Icon(Icons.assignment_late_outlined, size: 16, color: cs.error),
                  const SizedBox(width: 4),
                  Text(doc!.actionDeadline != null ? 'Action by ${fmtDate(doc.actionDeadline)}' : 'Action required',
                      style: t.labelMedium?.copyWith(color: cs.error)),
                ]),
              ),
            if (impactReason != null || card.main.kind == 'cert_impact')
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [
                  Icon(Icons.flag, size: 16, color: cs.tertiary),
                  const SizedBox(width: 4),
                  Expanded(child: Text('May affect your certificate', style: t.labelMedium)),
                ]),
              ),
            if (card.main.kind != 'cert_impact' && card.main.reason != null && card.main.kind != 'cert_expiry')
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Why: ${card.main.reason}', style: t.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
          ]),
        ),
      ),
    );
  }
}
