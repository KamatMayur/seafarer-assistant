import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/config.dart';
import '../core/providers.dart';

final _day = DateFormat('d MMM yyyy');
String fmtDate(DateTime? d) => d == null ? '–' : _day.format(d);

String timeAgo(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays < 7) return '${diff.inDays} d ago';
  return fmtDate(t);
}

const docTypeLabels = {
  'circular': 'Circular',
  'order': 'Order',
  'notice': 'Notice',
  'exam_schedule': 'Exam notice',
  'result': 'Result',
  'advisory': 'Advisory',
  'rules': 'Rules',
  'unknown': 'Document',
};

String docTypeLabel(String t) => docTypeLabels[t] ?? t;

/// Shown on every summary: it is an automatic extract, not advice.
class DisclaimerBox extends StatelessWidget {
  const DisclaimerBox({super.key, this.text});
  final String? text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Icon(Icons.info_outline, color: cs.onSecondaryContainer),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text ?? AppConfig.disclaimer, style: TextStyle(color: cs.onSecondaryContainer)),
        ),
      ]),
    );
  }
}

/// "You are offline" strip with the time of the last successful sync.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(offlineProvider)) return const SizedBox.shrink();
    final last = ref.watch(lastSyncProvider).value;
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          Icon(Icons.cloud_off, size: 18, color: cs.onTertiaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Offline. Showing saved data${last == null ? '' : ' from ${timeAgo(last)}'}. '
              'Changes are kept and sent when you reconnect.',
              style: TextStyle(color: cs.onTertiaryContainer),
            ),
          ),
        ]),
      ),
    );
  }
}

class PriorityBadge extends StatelessWidget {
  const PriorityBadge({super.key, required this.label, required this.color, required this.onColor});
  final String label;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
        child: Text(label, style: TextStyle(color: onColor, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 4),
              Text(message!, textAlign: TextAlign.center),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ]),
        ),
      );
}

void showSnack(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
