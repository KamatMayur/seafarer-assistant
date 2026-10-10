import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';

/// S3: who you are, so alerts can be filtered. Also used from Settings to edit the profile ([editing]).
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key, this.editing = false});
  final bool editing;

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _name = TextEditingController();
  String? _department, _level, _rank, _mmd;
  String _lang = 'en';
  final _ships = <String>{};
  final _grades = <String>{};
  bool _loaded = false, _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    ref.read(profileRepoProvider).cached().then((p) {
      if (p != null && mounted) {
        setState(() {
          _name.text = p.name ?? '';
          _department = p.department;
          _level = p.level;
          _rank = p.rank;
          _mmd = p.homeMmd;
          _lang = p.preferredLanguage;
          _ships.addAll(p.shipTypes);
          _grades.addAll(p.examGrades);
        });
      }
      if (mounted) setState(() => _loaded = true);
    });
  }

  Future<void> _save() async {
    if (_department == null || _level == null) {
      setState(() => _error = 'Please choose your department and level.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = ref.read(profileRepoProvider);
    final current = await repo.cached() ?? Profile();
    try {
      await repo.update(current.copyWith(
        name: _name.text.trim(),
        department: _department,
        level: _level,
        rank: _rank,
        homeMmd: _mmd,
        preferredLanguage: _lang,
        shipTypes: _ships.toList(),
        examGrades: _grades.toList(),
      ));
      ref.invalidate(profileProvider);
      if (!mounted) return;
      if (widget.editing) {
        showSnack(context, 'Profile saved. New alerts will use it.');
        context.pop();
      } else {
        ref.read(sessionProvider.notifier).profileSaved();
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _section(String title, String? help, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (help != null) Text(help, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          child,
        ]),
      );

  Widget _chips(Map<String, String> options, Set<String> selected) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final e in options.entries)
            FilterChip(
              label: Text(e.value),
              selected: selected.contains(e.key),
              onSelected: (on) => setState(() => on ? selected.add(e.key) : selected.remove(e.key)),
            ),
        ],
      );

  Widget _choice(Map<String, String> options, String? value, void Function(String) onPick) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final e in options.entries)
            ChoiceChip(label: Text(e.value), selected: value == e.key, onSelected: (_) => setState(() => onPick(e.key))),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final meta = ref.watch(metaProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editing ? 'Your profile' : 'Tell us about you'),
        automaticallyImplyLeading: widget.editing,
      ),
      body: meta.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.cloud_off,
          title: 'Could not load the form',
          message: '$e',
          action: OutlinedButton(onPressed: () => ref.invalidate(metaProvider), child: const Text('Try again')),
        ),
        data: (m) => !_loaded
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(padding: const EdgeInsets.all(24), children: [
                    if (!widget.editing)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 20),
                        child: Text('This decides which circulars and exam notices reach you. You can change it '
                            'any time in Settings.'),
                      ),
                    _section('Name (optional)', null,
                        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name'))),
                    _section('Department *', null, _choice(m.departments, _department, (v) {
                      _department = v;
                      _rank = null;
                    })),
                    _section('Level *', null, _choice(m.levels, _level, (v) => _level = v)),
                    if (_department != null)
                      _section(
                        'Rank',
                        null,
                        DropdownButtonFormField<String>(
                          initialValue: (m.ranks[_department] ?? []).contains(_rank) ? _rank : null,
                          items: [
                            for (final r in m.ranks[_department] ?? <String>[])
                              DropdownMenuItem(value: r, child: Text(r)),
                          ],
                          onChanged: (v) => setState(() => _rank = v),
                          decoration: const InputDecoration(labelText: 'Rank'),
                        ),
                      ),
                    _section(
                      'Home MMD',
                      'Exam notices for other MMDs are hidden unless they are for a grade you chose below.',
                      DropdownButtonFormField<String>(
                        initialValue: _mmd,
                        items: [for (final e in m.mmds.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                        onChanged: (v) => setState(() => _mmd = v),
                        decoration: const InputDecoration(labelText: 'MMD'),
                      ),
                    ),
                    _section('Ship types you sail on', 'Leave empty to get notices for all ship types.',
                        _chips(m.shipTypes, _ships)),
                    _section('Exams you are preparing for', 'You get seat-booking, timetable and result notices.',
                        _chips(m.examGrades, _grades)),
                    _section(
                      'Language',
                      'Summaries in Indian languages are coming. Until then they are shown in English.',
                      DropdownButtonFormField<String>(
                        initialValue: _lang,
                        items: [
                          for (final e in m.languages.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                        ],
                        onChanged: (v) => setState(() => _lang = v ?? 'en'),
                        decoration: const InputDecoration(labelText: 'Language'),
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(widget.editing ? 'Save' : 'Start'),
                      ),
                    ),
                  ]),
                ),
              ),
      ),
    );
  }
}
