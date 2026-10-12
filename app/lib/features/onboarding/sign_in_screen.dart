import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';

/// How the sign-in screen was opened: from the welcome screen's consent form (new account) or from
/// "I already have an account" (no consents sent, so an existing user's earlier choices stay as they were).
class SignInArgs {
  const SignInArgs({required this.newAccount, this.emailAlerts = false});
  final bool newAccount;
  final bool emailAlerts;
}

/// S2: email -> 6-digit code. Consent from the welcome screen is sent with the first sign-in.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;
  bool _noAccount = false;

  SignInArgs get _args {
    final extra = GoRouterState.of(context).extra;
    return extra is SignInArgs ? extra : const SignInArgs(newAccount: false);
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _noAccount = false;
    });
    try {
      await action();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.status == 400 && !_args.newAccount) {
        setState(() {
          _noAccount = true;
          _error = 'There is no account for this email yet.';
        });
      } else {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() => _run(() async {
        await ref.read(authRepoProvider).startEmailLogin(_email.text.trim());
        if (mounted) setState(() => _codeSent = true);
      });

  Future<void> _verify() => _run(() async {
        final auth = ref.read(authRepoProvider);
        final args = _args;
        await auth.verify(_email.text.trim(), _code.text.trim(),
            consentCore: args.newAccount, consentEmail: args.emailAlerts);
        try {
          await auth.registerDevice((await PackageInfo.fromPlatform()).version);
        } catch (_) {}
        final profile = await ref.read(profileRepoProvider).fetch();
        ref.read(sessionProvider.notifier).signedIn(profileComplete: profile.isComplete);
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_args.newAccount ? 'Create your account' : 'Sign in'),
        leading: BackButton(onPressed: () => context.go('/welcome')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(padding: const EdgeInsets.all(24), shrinkWrap: true, children: [
            Text(
              _codeSent
                  ? 'We sent a 6-digit code to ${_email.text.trim()}. It is valid for 15 minutes.'
                  : 'Enter your email. We will send you a sign-in code; no password needed.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _email,
              enabled: !_codeSent && !_busy,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email'),
              onSubmitted: (_) => _sendCode(),
            ),
            if (_codeSent) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _code,
                enabled: !_busy,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofillHints: const [AutofillHints.oneTimeCode],
                decoration: const InputDecoration(labelText: 'Code'),
                onSubmitted: (_) => _verify(),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            if (_noAccount)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => context.go('/welcome'),
                  child: const Text('Create an account (accept the privacy policy first)'),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : (_codeSent ? _verify : _sendCode),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _busy
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_codeSent ? 'Sign in' : 'Send code'),
              ),
            ),
            if (_codeSent)
              TextButton(
                onPressed: _busy ? null : () => setState(() => _codeSent = false),
                child: const Text('Use a different email'),
              ),
          ]),
        ),
      ),
    );
  }
}
