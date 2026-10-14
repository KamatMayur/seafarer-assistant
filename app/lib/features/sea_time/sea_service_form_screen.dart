import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/background.dart';
import '../../core/providers.dart';
import '../../data/db.dart';
import '../../domain/expiry.dart';
import '../../widgets/common.dart';

/// Add or edit one ship (S15). Saved locally first (works offline), then synced.
class SeaServiceFormScreen extends ConsumerStatefulWidget {
  const SeaServiceFormScreen({super.key, this.entryId});
  final String? entryId;

  @override
  ConsumerState<SeaServiceFormScreen> createState() => _SeaServiceFormScreenState();
}

class _SeaServiceFormScreenState extends ConsumerState<SeaServiceFormScreen> {
  final _form = GlobalKey<FormState>();
  final _vessel = TextEditingController();
  final _imo = TextEditingController();
  final _flag = TextEditingController();
  String _rank = '';
  String? _shipType;
  DateTime? _signOn, _signOff;
  bool _onBoard = false;
  SeaService? _existing;
  bool _loading = true;

  bool get _isNew => widget.entryId == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_isNew) {
      final s = await ref.read(seaRepoProvider).byId(widget.entryId!);
      if (s != null) {
        _existing = s;
        _vessel.text = s.vesselName;
        _imo.text = s.imo ?? '';
        _flag.text = s.flag ?? '';
        _rank = s.rank ?? '';
        _shipType = s.shipType;
        _signOn = parseDay(s.signOn);
        _signOff = parseDay(s.signOff);
        _onBoard = s.signOff == null;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickDate(bool signOn) async {
    final d = await showDatePicker(
      context: context,
      initialDate: (signOn ? _signOn : _signOff) ?? DateTime.now(),
      firstDate: DateTime(1960),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d != null) setState(() => signOn ? _signOn = d : _signOff = d);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_signOn == null) {
      showSnack(context, 'Choose the sign-on date from your CDC.');
      return;
    }
    if (!_onBoard && _signOff == null) {
      showSnack(context, 'Choose the sign-off date, or tick "Still on board".');
      return;
    }
    if (!_onBoard && _signOff!.isBefore(_signOn!)) {
      showSnack(context, 'The sign-off date is before the sign-on date.');
      return;
    }
    String? opt(String v) => v.trim().isEmpty ? null : v.trim();
    await ref.read(seaRepoProvider).save(
          id: widget.entryId,
          vesselName: _vessel.text.trim(),
          imo: opt(_imo.text),
          rank: opt(_rank),
          signOn: formatDay(_signOn!),
          signOff: _onBoard ? null : formatDay(_signOff!),
          shipType: _shipType,
          flag: opt(_flag.text),
        );
    unawaited(ref.read(backgroundSyncProvider).runOnce());
    if (mounted) {
      showSnack(context, 'Saved');
      context.go('/sea');
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: const Text('It is removed from this device and from your account.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(seaRepoProvider).softDelete(widget.entryId!);
    unawaited(ref.read(backgroundSyncProvider).runOnce());
    if (mounted) context.go('/sea');
  }

  Future<void> _resolve(bool keepMine) async {
    await ref.read(seaRepoProvider).resolveConflict(widget.entryId!, keepMine: keepMine);
    await ref.read(backgroundSyncProvider).runOnce();
    if (mounted) context.go('/sea');
  }

  @override
  Widget build(BuildContext context) {
    final meta = ref.watch(metaProvider).value;
    final ranks = <String>{for (final l in meta?.ranks.values ?? const <List<String>>[]) ...l}.toList();
    final shipTypes = meta?.shipTypes ?? const <String, String>{};
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/sea')),
        title: Text(_isNew ? 'Add sea service' : 'Sea service'),
        actions: [
          if (!_isNew) IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Form(
                  key: _form,
                  child: ListView(padding: const EdgeInsets.all(24), children: [
                    if (_existing?.conflictJson != null) _conflict(jsonDecode(_existing!.conflictJson!) as Map),
                    TextFormField(
                      controller: _vessel,
                      maxLength: 200,
                      decoration: const InputDecoration(labelText: 'Vessel name *'),
                      validator: (v) => (v ?? '').trim().isEmpty ? 'Enter the vessel name' : null,
                    ),
                    TextFormField(
                      controller: _imo,
                      maxLength: 7,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'IMO number', hintText: '7 digits'),
                      validator: (v) {
                        final s = (v ?? '').trim();
                        return s.isEmpty || RegExp(r'^\d{7}$').hasMatch(s) ? null : 'An IMO number has 7 digits';
                      },
                    ),
                    Autocomplete<String>(
                      initialValue: TextEditingValue(text: _rank),
                      optionsBuilder: (v) => ranks.where((r) => r.toLowerCase().contains(v.text.toLowerCase())),
                      onSelected: (v) => _rank = v,
                      fieldViewBuilder: (context, controller, focus, onSubmit) => TextFormField(
                        controller: controller,
                        focusNode: focus,
                        maxLength: 40,
                        onChanged: (v) => _rank = v,
                        decoration: const InputDecoration(labelText: 'Rank', hintText: 'e.g. Third Officer'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      initialValue: shipTypes.containsKey(_shipType) ? _shipType : null,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Not given')),
                        for (final e in shipTypes.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                      ],
                      onChanged: (v) => setState(() => _shipType = v),
                      decoration: const InputDecoration(labelText: 'Ship type'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _flag,
                      maxLength: 60,
                      decoration: const InputDecoration(labelText: 'Flag', hintText: 'e.g. India, Liberia'),
                    ),
                    const SizedBox(height: 8),
                    Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.login),
                        label: Text(_signOn == null ? 'Sign-on date *' : 'Signed on ${fmtDate(_signOn)}'),
                        onPressed: () => _pickDate(true),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.logout),
                        label: Text(_onBoard
                            ? 'On board'
                            : (_signOff == null ? 'Sign-off date *' : 'Signed off ${fmtDate(_signOff)}')),
                        onPressed: _onBoard ? null : () => _pickDate(false),
                      ),
                      FilterChip(
                        label: const Text('Still on board'),
                        selected: _onBoard,
                        onSelected: (v) => setState(() => _onBoard = v),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text('Use the dates entered in your CDC.', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _save,
                      child: const Padding(padding: EdgeInsets.all(12), child: Text('Save')),
                    ),
                  ]),
                ),
              ),
            ),
    );
  }

  Widget _conflict(Map server) => Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('This entry was changed on another device while you edited it here.'),
            Text('Other device: ${server['vessel_name']}, ${server['sign_on']} – ${server['sign_off'] ?? 'on board'}'),
            Wrap(spacing: 8, children: [
              TextButton(onPressed: () => _resolve(false), child: const Text('Keep the other version')),
              FilledButton(onPressed: () => _resolve(true), child: const Text('Keep mine')),
            ]),
          ]),
        ),
      );
}
