import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';

/// S1: what the app is, the unofficial notice, and consent (DPDP Act 2023: explicit, per purpose).
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _core = false;
  bool _email = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(padding: const EdgeInsets.all(24), shrinkWrap: true, children: [
            Icon(Icons.sailing, size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(AppConfig.appName, style: t.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'New DGMA circulars, exam notices and advisories that concern you, plus a wallet that reminds you '
              'before your certificates expire.',
              style: t.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  const Icon(Icons.gpp_maybe_outlined),
                  const SizedBox(width: 8),
                  Expanded(child: Text(AppConfig.unofficialNotice, style: t.bodyMedium)),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _core,
              onChanged: (v) => setState(() => _core = v ?? false),
              title: const Text('I agree to the privacy policy (required)'),
              subtitle: const Text(
                'We store your email, profile (rank, department, MMD) and certificate details (type, number, '
                'dates) to send you relevant alerts. Certificate images stay on this device, encrypted. '
                'You can export or delete everything at any time in Settings.',
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => context.push('/privacy'),
                child: const Text('Read the privacy notice and tester terms'),
              ),
            ),
            CheckboxListTile(
              value: _email,
              onChanged: (v) => setState(() => _email = v ?? false),
              title: const Text('Also send important alerts by email (optional)'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _core ? () => context.go('/sign-in', extra: _email) : null,
              child: const Padding(padding: EdgeInsets.all(12), child: Text('Continue')),
            ),
          ]),
        ),
      ),
    );
  }
}
