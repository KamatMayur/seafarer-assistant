import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../data/db.dart';
import '../../domain/expiry.dart';
import '../../domain/sea_time.dart';
import '../../widgets/common.dart';
import '../export/export_actions.dart';

SeaSpell spellOf(SeaService s) =>
    SeaSpell(signOn: parseDay(s.signOn)!, signOff: parseDay(s.signOff), rank: s.rank, shipType: s.shipType);

/// S15: sea service log, totals, and NRI days per Indian financial year. Works offline; informational only.
class SeaTimeScreen extends ConsumerWidget {
  const SeaTimeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(seaServiceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Sea time'), actions: [
        if (entries.value?.isNotEmpty == true)
          IconButton(
            tooltip: 'Export PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => exportSeaServicePdf(context, ref),
          ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/sea/new'),
        icon: const Icon(Icons.add),
        label: const Text('Add sea service'),
      ),
      body: entries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(icon: Icons.error_outline, title: 'Could not read your sea service', message: '$e'),
        data: (list) => list.isEmpty
            ? const EmptyState(
                icon: Icons.sailing_outlined,
                title: 'No sea service yet',
                message: 'Add each ship with the sign-on and sign-off dates from your CDC. The app adds up your sea '
                    'time by rank and ship type, and counts days on board per financial year (useful for NRI status).',
              )
            : SeaTimeBody(entries: list, today: todayIst()),
      ),
    );
  }
}

class SeaTimeBody extends ConsumerWidget {
  const SeaTimeBody({super.key, required this.entries, required this.today});
  final List<SeaService> entries;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final meta = ref.watch(metaProvider).value;
    final rules = ref.watch(nriRulesProvider).value;
    final spells = entries.map(spellOf).toList();
    final totals = seaTotals(spells, today);
    String shipLabel(String k) => k.isEmpty ? 'Ship type not given' : (meta?.shipTypes[k] ?? k);

    return ListView(padding: const EdgeInsets.fromLTRB(8, 8, 8, 96), children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Total sea time', style: t.labelLarge),
            Text(describeDays(totals.totalDays), style: t.headlineSmall),
            Text('${totals.totalDays} days, counting sign-on and sign-off days', style: t.bodySmall),
            const SizedBox(height: 12),
            _Breakdown(title: 'By rank', rows: {
              for (final e in totals.byRank.entries) (e.key.isEmpty ? 'Rank not given' : e.key): e.value,
            }),
            _Breakdown(title: 'By ship type', rows: {for (final e in totals.byShipType.entries) shipLabel(e.key): e.value}),
            const SizedBox(height: 8),
            Text('For DG Shipping and MMD purposes the dates in your CDC and the sea service testimonials count, not '
                'this total.', style: t.bodySmall),
          ]),
        ),
      ),
      if (rules != null) NriCard(rows: nriByFinancialYear(spells, rules, today), notes: rules.notes),
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 4),
        child: Text('SHIPS (${entries.length})', style: t.labelLarge),
      ),
      for (final s in entries) _EntryTile(entry: s, today: today, shipLabel: shipLabel),
    ]);
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.title, required this.rows});
  final String title;
  final Map<String, int> rows;

  @override
  Widget build(BuildContext context) {
    final sorted = rows.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        for (final e in sorted)
          Row(children: [
            Expanded(child: Text(e.key)),
            Text(describeDays(e.value)),
          ]),
      ]),
    );
  }
}

/// NRI days per financial year: days on board vs days possibly in India, against the configured threshold.
class NriCard extends StatelessWidget {
  const NriCard({super.key, required this.rows, required this.notes});
  final List<FyNri> rows;
  final List<String> notes;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final unverified = rows.any((r) => r.regime != null && !r.regime!.verifiedByOwner);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('NRI days (informational)', style: t.titleMedium),
          const SizedBox(height: 4),
          Text('Indian financial year, 1 April – 31 March.', style: t.bodySmall),
          if (unverified)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline, size: 18, color: cs.tertiary),
                const SizedBox(width: 6),
                const Expanded(
                    child: Text('The tax rule sources behind these numbers have not been checked by the app owner '
                        'yet. Treat them as a rough guide.')),
              ]),
            ),
          for (final r in rows) _FyRow(row: r),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('How this is counted and its limits'),
            children: [
              for (final n in notes)
                Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('• $n', style: t.bodySmall)),
              for (final reg in {for (final r in rows) ?r.regime})
                for (final s in reg.sources)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('Source (${reg.law}): $s', style: t.bodySmall),
                  ),
            ],
          ),
        ]),
      ),
    );
  }
}

class _FyRow extends StatelessWidget {
  const _FyRow({required this.row});
  final FyNri row;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final threshold = row.regime?.thresholdDays;
    final (String verdict, Color color) = switch (row.status) {
      NriStatus.atOrAbove => ('$threshold days or more possibly in India: likely resident', cs.error),
      NriStatus.below => ('Fewer than $threshold days possibly in India', cs.primary),
      NriStatus.belowSoFar => (
          'Fewer than $threshold so far. Up to ${row.daysLeftBelowThreshold} more days in India this year stays below '
              '$threshold.',
          cs.primary
        ),
      NriStatus.noRule => ('No rule configured for this year', cs.outline),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('FY ${fyLabel(row.fy)}${row.complete ? '' : ' (so far)'}', style: t.titleSmall),
        Text('On board ${row.daysOnBoard} days · possibly in India ${row.daysPossiblyInIndia} of ${row.daysCounted} days'),
        Text(verdict, style: t.bodyMedium?.copyWith(color: color)),
      ]),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.today, required this.shipLabel});
  final SeaService entry;
  final DateTime today;
  final String Function(String) shipLabel;

  @override
  Widget build(BuildContext context) {
    final range = spellRange(spellOf(entry), today);
    final days = range == null ? 0 : rangeDays(range);
    return Card(
      child: ListTile(
        leading: Icon(entry.signOff == null ? Icons.directions_boat : Icons.directions_boat_outlined),
        title: Text(entry.vesselName),
        subtitle: Text([
          if (entry.rank?.isNotEmpty == true) entry.rank!,
          if (entry.shipType != null) shipLabel(entry.shipType!),
          '${fmtDate(parseDay(entry.signOn))} – ${entry.signOff == null ? 'on board' : fmtDate(parseDay(entry.signOff))}',
          if (entry.conflictJson != null) 'sync conflict – tap to resolve',
          if (entry.conflictJson == null && entry.dirty) 'not synced yet',
        ].join(' · ')),
        trailing: Text('$days days'),
        onTap: () => context.go('/sea/${entry.id}'),
      ),
    );
  }
}
