import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/background.dart';
import '../../core/config.dart';
import '../../core/desktop.dart';
import '../../core/providers.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';

/// S9 + S10: profile, topics, quiet hours, data saver, privacy (export / delete), sign out.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    final saver = ref.watch(dataSaverProvider).value ?? false;
    final t = Theme.of(context).textTheme;

    Widget header(String s) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
          child: Text(s.toUpperCase(), style: t.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary)),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        header('Alerts'),
        ListTile(
          leading: const Icon(Icons.badge_outlined),
          title: const Text('Your profile'),
          subtitle: Text(_profileLine(profile)),
          onTap: () => context.go('/settings/profile'),
        ),
        ListTile(
          leading: const Icon(Icons.topic_outlined),
          title: const Text('Topics to follow or mute'),
          subtitle: const Text('e.g. get CoC dispatch lists, mute training circulars'),
          onTap: () => showDialog(context: context, builder: (_) => const _TopicsDialog()),
        ),
        ListTile(
          leading: const Icon(Icons.bedtime_outlined),
          title: const Text('Quiet hours (IST)'),
          subtitle: Text(profile?.quietStart == null
              ? 'Off. Critical safety advisories always come through.'
              : '${profile!.quietStart} – ${profile.quietEnd}. Email alerts wait until the end; critical ones do not.'),
          onTap: () => _editQuietHours(context, ref, profile),
        ),
        const ListTile(
          leading: Icon(Icons.alarm),
          title: Text('Certificate reminders'),
          subtitle: Text('6 months, 3 months, 1 month, 1 week before expiry, on the day, and when expired. '
              'Shown as Windows notifications while the app is running, also from the tray.'),
        ),
        if (desktopShell != null) ...[header('This computer'), const _DesktopSettings()],
        header('Connection'),
        SwitchListTile(
          secondary: const Icon(Icons.data_saver_on),
          title: const Text('Data saver'),
          subtitle: const Text('Check every 2 hours instead of every 30 minutes. For slow or paid ship internet.'),
          value: saver,
          onChanged: (v) async {
            await ref.read(databaseProvider).setValue('data_saver', '$v');
            ref.read(backgroundSyncProvider).start();
          },
        ),
        ListTile(
          leading: const Icon(Icons.dns_outlined),
          title: const Text('Server address'),
          subtitle: Text(ref.read(apiClientProvider).baseUrl),
          onTap: () => _editServer(context, ref),
        ),
        header('Help'),
        ListTile(
          leading: const Icon(Icons.bug_report_outlined),
          title: const Text('Report a problem or suggest something'),
          subtitle: const Text('Goes straight to the people running this test'),
          onTap: () => showDialog(context: context, builder: (_) => const _ReportDialog()),
        ),
        header('Privacy'),
        ListTile(
          leading: const Icon(Icons.policy_outlined),
          title: const Text('Privacy notice and tester terms'),
          onTap: () => context.push('/privacy'),
        ),
        ListTile(
          leading: const Icon(Icons.download_outlined),
          title: const Text('Download my data'),
          subtitle: const Text('Everything the server holds about you, as a ZIP of JSON files'),
          onTap: () => _export(context, ref),
        ),
        ListTile(
          leading: Icon(Icons.delete_forever_outlined, color: Theme.of(context).colorScheme.error),
          title: const Text('Delete my account'),
          subtitle: const Text('Removes your account, profile, certificates and alerts from the server and this device'),
          onTap: () => _deleteAccount(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Sign out'),
          subtitle: const Text('Removes your data and certificate files from this device'),
          onTap: () => _signOut(context, ref),
        ),
        header('About'),
        FutureBuilder(
          future: PackageInfo.fromPlatform(),
          builder: (_, snap) => ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text('${AppConfig.appName} ${snap.data?.version ?? ''}'),
            subtitle: const Text(AppConfig.unofficialNotice),
          ),
        ),
        const Padding(padding: EdgeInsets.all(16), child: DisclaimerBox()),
      ]),
    );
  }

  String _profileLine(Profile? p) {
    if (p == null) return 'Not loaded';
    return [p.rank, p.department, p.level, if (p.homeMmd != null) 'MMD ${p.homeMmd}']
        .whereType<String>()
        .map((s) => s.replaceAll('_', ' '))
        .join(' · ');
  }

  Future<void> _editQuietHours(BuildContext context, WidgetRef ref, Profile? p) async {
    if (p == null) return;
    TimeOfDay parse(String? s, int h) =>
        s == null ? TimeOfDay(hour: h, minute: 0) : TimeOfDay(hour: int.parse(s.split(':')[0]), minute: int.parse(s.split(':')[1]));
    String fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final off = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Quiet hours'),
        content: const Text('Choose a start and end time (India time). Critical advisories always come through.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Turn off')),
          FilledButton(onPressed: () => Navigator.pop(c, false), child: const Text('Set times')),
        ],
      ),
    );
    if (off == null || !context.mounted) return;
    Profile updated;
    if (off) {
      updated = p.copyWith(clearQuiet: true);
    } else {
      final start = await showTimePicker(context: context, initialTime: parse(p.quietStart, 22), helpText: 'Quiet from');
      if (start == null || !context.mounted) return;
      final end = await showTimePicker(context: context, initialTime: parse(p.quietEnd, 7), helpText: 'Quiet until');
      if (end == null) return;
      updated = p.copyWith(quietStart: fmt(start), quietEnd: fmt(end));
    }
    try {
      await ref.read(profileRepoProvider).update(updated);
      ref.invalidate(profileProvider);
    } on ApiException catch (e) {
      if (context.mounted) showSnack(context, e.message);
    }
  }

  Future<void> _editServer(BuildContext context, WidgetRef ref) async {
    final c = TextEditingController(text: ref.read(apiClientProvider).baseUrl);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Server address'),
        content: TextField(controller: c, decoration: const InputDecoration(hintText: 'https://...')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (v == null || Uri.tryParse(v)?.hasScheme != true) return;
    ref.read(apiClientProvider).baseUrl = v;
    await ref.read(databaseProvider).setValue('api_base', v);
    if (context.mounted) showSnack(context, 'Server address saved');
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    try {
      final bytes = await ref.read(authRepoProvider).exportData();
      final saved = await FilePicker.saveFile(
        dialogTitle: 'Save my data',
        fileName: 'my-seafarer-data.zip',
        bytes: Uint8List.fromList(bytes),
        mimeType: 'application/zip',
      );
      if (saved == null) return;
      if (context.mounted) showSnack(context, 'Saved to ${saved.toFilePath()}');
    } on ApiException catch (e) {
      if (context.mounted) showSnack(context, e.message);
    }
  }

  Future<bool> _confirm(BuildContext context, String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(action)),
          ],
        ),
      ) ??
      false;

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    if (!await _confirm(context, 'Delete your account?',
        'This cannot be undone. Your profile, certificates, alerts and consents are deleted from the server, and '
            'all data and certificate files are removed from this device.',
        'Delete everything')) {
      return;
    }
    try {
      await ref.read(authRepoProvider).deleteAccount();
      await ref.read(fileVaultProvider).wipe();
      ref.read(sessionProvider.notifier).signedOut();
    } on ApiException catch (e) {
      if (context.mounted) showSnack(context, '${e.message} Nothing was deleted.');
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    if (await _confirm(context, 'Sign out?',
        'Certificates that are not synced yet and the certificate files on this device will be removed.',
        'Sign out')) {
      await ref.read(sessionProvider.notifier).signOut();
    }
  }
}

class _TopicsDialog extends ConsumerStatefulWidget {
  const _TopicsDialog();

  @override
  ConsumerState<_TopicsDialog> createState() => _TopicsDialogState();
}

class _TopicsDialogState extends ConsumerState<_TopicsDialog> {
  Map<String, String>? _modes;
  String? _error;

  @override
  void initState() {
    super.initState();
    ref.read(profileRepoProvider).topics().then((m) => setState(() => _modes = m)).catchError((Object e) {
      setState(() => _error = '$e');
    });
  }

  @override
  Widget build(BuildContext context) {
    final topics = ref.watch(metaProvider).value?.topics ?? {};
    return AlertDialog(
      title: const Text('Topics'),
      content: SizedBox(
        width: 520,
        child: _error != null
            ? Text(_error!)
            : _modes == null
                ? const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))
                : ListView(shrinkWrap: true, children: [
                    const Text('Follow: get these even when they are not specific to your rank. '
                        'Mute: never get them (critical advisories still come through).'),
                    const SizedBox(height: 8),
                    for (final e in topics.entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(children: [
                          Expanded(child: Text(e.value)),
                          SegmentedButton<String>(
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment(value: 'mute', label: Text('Mute')),
                              ButtonSegment(value: 'default', label: Text('Auto')),
                              ButtonSegment(value: 'follow', label: Text('Follow')),
                            ],
                            selected: {_modes![e.key] ?? 'default'},
                            onSelectionChanged: (s) => setState(() {
                              s.first == 'default' ? _modes!.remove(e.key) : _modes![e.key] = s.first;
                            }),
                          ),
                        ]),
                      ),
                  ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _modes == null
              ? null
              : () async {
                  try {
                    await ref.read(profileRepoProvider).saveTopics(_modes!);
                    if (context.mounted) Navigator.pop(context);
                  } on ApiException catch (e) {
                    if (mounted) setState(() => _error = e.message);
                  }
                },
          child: const Text('Save'),
        ),
      ],
    );
  }
}


/// Tray and start-with-Windows switches (Windows only).
class _DesktopSettings extends StatefulWidget {
  const _DesktopSettings();

  @override
  State<_DesktopSettings> createState() => _DesktopSettingsState();
}

class _DesktopSettingsState extends State<_DesktopSettings> {
  bool? _startup;

  @override
  void initState() {
    super.initState();
    StartupService.isEnabled().then((v) {
      if (mounted) setState(() => _startup = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final shell = desktopShell!;
    return Column(children: [
      SwitchListTile(
        secondary: const Icon(Icons.vertical_align_bottom),
        title: const Text('Keep running in the system tray when closed'),
        subtitle: const Text('New alerts and expiry reminders keep arriving. Quit from the tray icon menu.'),
        value: shell.keepInTray,
        onChanged: (v) async {
          await shell.setKeepInTray(v);
          setState(() {});
        },
      ),
      if (StartupService.isPackaged)
        ListTile(
          leading: const Icon(Icons.power_settings_new),
          title: const Text('Start with Windows'),
          subtitle: const Text('On by default. Change it in Windows Settings > Apps > Startup.'),
          onTap: () => launchUrl(Uri.parse('ms-settings:startupapps')),
        )
      else
        SwitchListTile(
          secondary: const Icon(Icons.power_settings_new),
          title: const Text('Start with Windows'),
          subtitle: const Text('Opens in the system tray when you sign in to Windows.'),
          value: _startup ?? false,
          onChanged: _startup == null
              ? null
              : (v) async {
                  await StartupService.setEnabled(v);
                  final now = await StartupService.isEnabled();
                  if (mounted) setState(() => _startup = now);
                },
        ),
    ]);
  }
}


class _ReportDialog extends ConsumerStatefulWidget {
  const _ReportDialog();

  @override
  ConsumerState<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends ConsumerState<_ReportDialog> {
  final _text = TextEditingController();
  String _kind = 'problem';
  bool _sending = false;

  Future<void> _send() async {
    if (_text.text.trim().isEmpty) return;
    setState(() => _sending = true);
    final sent = await ref.read(feedbackProvider).report(
      kind: _kind,
      message: _text.text.trim(),
      context: {'screen': 'settings'},
    );
    if (!mounted) return;
    Navigator.pop(context);
    showSnack(context, sent ? 'Thank you, your report was sent.' : 'Saved. It will be sent when you are online.');
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Report a problem'),
        content: SizedBox(
          width: 520,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'problem', label: Text('Problem')),
                ButtonSegment(value: 'idea', label: Text('Suggestion')),
              ],
              selected: {_kind},
              onSelectionChanged: (v) => setState(() => _kind = v.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              autofocus: true,
              minLines: 4,
              maxLines: 10,
              maxLength: 4000,
              decoration: const InputDecoration(
                hintText: 'What happened, and what did you expect? Which circular or screen?',
              ),
            ),
            const Text('The app version is attached. Do not include passwords or certificate numbers.'),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: _sending ? null : _send, child: const Text('Send')),
        ],
      );
}
