import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models.dart';
import '../../widgets/common.dart';

/// The quote with the matched words in bold. Offsets come from the server and are clamped, never trusted blindly.
List<TextSpan> quoteSpans(String quote, List<(int, int)> marks, TextStyle? bold) {
  final spans = <TextSpan>[];
  var pos = 0;
  for (final (start, end) in [...marks]..sort((a, b) => a.$1.compareTo(b.$1))) {
    final s = start.clamp(pos, quote.length), e = end.clamp(s, quote.length);
    if (s > pos) spans.add(TextSpan(text: quote.substring(pos, s)));
    if (e > s) spans.add(TextSpan(text: quote.substring(s, e), style: bold));
    pos = e;
  }
  if (pos < quote.length) spans.add(TextSpan(text: quote.substring(pos)));
  return spans;
}

/// One cited-search hit: which circular and page, the verbatim quote, and links to the summary and official PDF.
class PassageTile extends StatelessWidget {
  const PassageTile({super.key, required this.passage, required this.onOpenDocument});
  final Passage passage;
  final VoidCallback onOpenDocument;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final d = passage.document;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            [
              docTypeLabel(d.docType),
              if (d.circularNumber != null) d.circularNumber!,
              if (d.publishedDate != null) fmtDate(d.publishedDate),
              'page ${passage.page}',
            ].join(' · '),
            style: t.labelMedium,
          ),
          const SizedBox(height: 2),
          Text(d.title, style: t.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.only(left: 10),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: Theme.of(context).colorScheme.outlineVariant, width: 3)),
            ),
            child: Text.rich(
              TextSpan(
                style: t.bodyMedium,
                children: [
                  const TextSpan(text: '“'),
                  ...quoteSpans(passage.quote, passage.marks, const TextStyle(fontWeight: FontWeight.w700)),
                  const TextSpan(text: '”'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(spacing: 8, children: [
            TextButton.icon(
              onPressed: onOpenDocument,
              icon: const Icon(Icons.article_outlined, size: 18),
              label: const Text('Summary'),
            ),
            TextButton.icon(
              onPressed: () => launchUrl(Uri.parse(passage.pdfUrl), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text('Official PDF, page ${passage.page}'),
            ),
          ]),
        ]),
      ),
    );
  }
}
