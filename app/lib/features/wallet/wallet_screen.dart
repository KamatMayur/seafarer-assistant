import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../data/db.dart';
import '../../domain/expiry.dart';
import '../../widgets/common.dart';
import '../export/export_actions.dart';

String certTitle(Certificate c, Map<String, String>? labels) {
  final base = labels?[c.type] ?? c.type.toUpperCase();
  return c.subtype?.isNotEmpty == true ? '$base – ${c.subtype}' : base;
}

/// S7: certificates grouped by status. Works fully offline; changes sync when online.
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final certs = ref.watch(certificatesProvider);
    final labels = ref.watch(metaProvider).value?.certTypes;
    final today = todayIst();
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet'), actions: [
        if (certs.value?.isNotEmpty == true)
          IconButton(
            tooltip: 'Export PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => exportCertificatesPdf(context, ref),
          ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/wallet/new'),
        icon: const Icon(Icons.add),
        label: const Text('Add certificate'),
      ),
      body: Column(children: [
        const OfflineBanner(),
        Expanded(
          child: certs.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => EmptyState(icon: Icons.error_outline, title: 'Could not read the wallet', message: '$e'),
            data: (list) {
              if (list.isEmpty) {
                return const EmptyState(
                  icon: Icons.wallet_outlined,
                  title: 'No certificates yet',
                  message: 'Add your CoC, CDC, passport, medical and STCW courses. You get reminders 6 months, '
                      '3 months, 1 month and 1 week before they expire.',
                );
              }
              final groups = <ExpiryStatus, List<Certificate>>{};
              for (final c in list) {
                groups.putIfAbsent(statusOf(c.expiryDate, today), () => []).add(c);
              }
              const order = [ExpiryStatus.expired, ExpiryStatus.expiringSoon, ExpiryStatus.valid, ExpiryStatus.noExpiry];
              const names = {
                ExpiryStatus.expired: 'Expired',
                ExpiryStatus.expiringSoon: 'Expiring within 90 days',
                ExpiryStatus.valid: 'Valid',
                ExpiryStatus.noExpiry: 'No expiry date',
              };
              return ListView(padding: const EdgeInsets.only(bottom: 96), children: [
                for (final s in order)
                  if (groups[s] != null) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text('${names[s]!.toUpperCase()} (${groups[s]!.length})',
                          style: Theme.of(context).textTheme.labelLarge),
                    ),
                    for (final c in groups[s]!) _CertTile(cert: c, status: s, today: today, labels: labels),
                  ],
              ]);
            },
          ),
        ),
      ]),
    );
  }
}

class _CertTile extends StatelessWidget {
  const _CertTile({required this.cert, required this.status, required this.today, required this.labels});
  final Certificate cert;
  final ExpiryStatus status;
  final DateTime today;
  final Map<String, String>? labels;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = switch (status) {
      ExpiryStatus.expired => cs.error,
      ExpiryStatus.expiringSoon => Colors.orange.shade700,
      _ => cs.primary,
    };
    final expiry = parseDay(cert.expiryDate);
    return Card(
      child: ListTile(
        leading: Container(width: 6, height: 40, color: color),
        title: Text(certTitle(cert, labels)),
        subtitle: Text([
          if (cert.number?.isNotEmpty == true) cert.number!,
          if (expiry != null) 'exp ${fmtDate(expiry)}',
          if (cert.conflictJson != null) 'sync conflict – tap to resolve',
          if (cert.conflictJson == null && cert.dirty) 'not synced yet',
        ].join(' · ')),
        trailing: Text(describeExpiry(cert.expiryDate, today), style: TextStyle(color: color)),
        onTap: () => context.go('/wallet/${cert.id}'),
      ),
    );
  }
}
