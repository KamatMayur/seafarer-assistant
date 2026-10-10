import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:uuid/uuid.dart';

import '../../core/api_client.dart';
import '../../core/background.dart';
import '../../core/providers.dart';
import '../../data/db.dart';
import '../../domain/expiry.dart';
import '../../widgets/common.dart';

/// S8: add or edit a certificate. Saved locally first (works offline), then synced.
class CertificateFormScreen extends ConsumerStatefulWidget {
  const CertificateFormScreen({super.key, this.certificateId});
  final String? certificateId;

  @override
  ConsumerState<CertificateFormScreen> createState() => _CertificateFormScreenState();
}

class _CertificateFormScreenState extends ConsumerState<CertificateFormScreen> {
  final _form = GlobalKey<FormState>();
  final _subtype = TextEditingController();
  final _number = TextEditingController();
  final _authority = TextEditingController();
  String _type = 'coc';
  DateTime? _issue, _expiry;
  bool _noExpiry = false;
  String? _filePath, _fileName;
  File? _newFile;
  Certificate? _existing;
  bool _loading = true, _saving = false;
  List<Map<String, dynamic>> _linked = [];

  bool get _isNew => widget.certificateId == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_isNew) {
      final c = await ref.read(certRepoProvider).byId(widget.certificateId!);
      if (c != null) {
        _existing = c;
        _type = c.type;
        _subtype.text = c.subtype ?? '';
        _number.text = c.number ?? '';
        _authority.text = c.issuingAuthority ?? '';
        _issue = parseDay(c.issueDate);
        _expiry = parseDay(c.expiryDate);
        _noExpiry = c.expiryDate == null;
        _filePath = c.filePath;
        _fileName = c.fileName;
        _loadLinked();
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadLinked() async {
    try {
      final r = await ref.read(apiClientProvider).get('/v1/certificates/${widget.certificateId}/linked-documents');
      if (mounted) setState(() => _linked = (r as List).cast<Map<String, dynamic>>());
    } on ApiException catch (_) {
      // offline or not synced yet
    }
  }

  Future<void> _pickDate(bool issue) async {
    final initial = (issue ? _issue : _expiry) ?? DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => issue ? _issue = d : _expiry = d);
  }

  Future<void> _pickFile() async {
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png']);
    final path = files.isEmpty ? null : files.single.path;
    if (path != null) {
      setState(() {
        _newFile = File(path);
        _fileName = files.single.name;
      });
    }
  }

  Future<void> _viewFile() async {
    if (_newFile != null) {
      await OpenFilex.open(_newFile!.path);
      return;
    }
    if (_filePath == null) return;
    final tmp = await ref.read(fileVaultProvider).decryptToTemp(_filePath!, _fileName ?? 'certificate');
    await OpenFilex.open(tmp.path);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (!_noExpiry && _expiry == null) {
      showSnack(context, 'Choose an expiry date, or tick "No expiry date".');
      return;
    }
    if (_issue != null && _expiry != null && !_noExpiry && _expiry!.isBefore(_issue!)) {
      showSnack(context, 'The expiry date is before the issue date.');
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(certRepoProvider);
    final id = widget.certificateId ?? const Uuid().v4();
    String? vaultPath = _filePath;
    if (_newFile != null) {
      await ref.read(fileVaultProvider).remove(_filePath);
      vaultPath = await ref.read(fileVaultProvider).store(_newFile!, id);
    }
    await repo.save(
      id: id, // new certificates get their UUID here, so the encrypted file is named after it
      type: _type,
      subtype: _subtype.text.trim(),
      number: _number.text.trim(),
      issuingAuthority: _authority.text.trim(),
      issueDate: _issue == null ? null : formatDay(_issue!),
      expiryDate: _noExpiry || _expiry == null ? null : formatDay(_expiry!),
      filePath: vaultPath,
      fileName: _fileName,
    );
    unawaited(ref.read(backgroundSyncProvider).runOnce());
    if (mounted) {
      showSnack(context, 'Saved');
      context.go('/wallet');
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this certificate?'),
        content: const Text('It is removed from this device and from your account. The scanned file is deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(fileVaultProvider).remove(_filePath);
    await ref.read(certRepoProvider).softDelete(widget.certificateId!);
    unawaited(ref.read(backgroundSyncProvider).runOnce());
    if (mounted) context.go('/wallet');
  }

  Future<void> _resolve(bool keepMine) async {
    await ref.read(certRepoProvider).resolveConflict(widget.certificateId!, keepMine: keepMine);
    await ref.read(backgroundSyncProvider).runOnce();
    if (mounted) context.go('/wallet');
  }

  @override
  Widget build(BuildContext context) {
    final types = ref.watch(metaProvider).value?.certTypes ??
        const {'coc': 'CoC', 'cop': 'CoP', 'cdc': 'CDC', 'passport': 'Passport', 'medical': 'Medical', 'other': 'Other'};
    final today = todayIst();
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/wallet')),
        title: Text(_isNew ? 'Add certificate' : 'Certificate'),
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
                    if (_expiry != null && !_noExpiry)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(describeExpiry(formatDay(_expiry!), today),
                            style: Theme.of(context).textTheme.titleMedium),
                      ),
                    DropdownButtonFormField<String>(
                      initialValue: types.containsKey(_type) ? _type : null,
                      items: [for (final e in types.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                      onChanged: (v) => setState(() => _type = v ?? 'other'),
                      decoration: const InputDecoration(labelText: 'Type *'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _subtype,
                      maxLength: 40,
                      decoration: const InputDecoration(
                          labelText: 'Grade / course', hintText: 'e.g. MEO Class II, AFF, PSCRB, GMDSS GOC'),
                    ),
                    TextFormField(
                      controller: _number,
                      maxLength: 80,
                      decoration: const InputDecoration(labelText: 'Certificate number'),
                    ),
                    TextFormField(
                      controller: _authority,
                      maxLength: 200,
                      decoration: const InputDecoration(labelText: 'Issued by', hintText: 'e.g. MMD Mumbai, DGMA'),
                    ),
                    const SizedBox(height: 8),
                    Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.event),
                        label: Text(_issue == null ? 'Issue date' : 'Issued ${fmtDate(_issue)}'),
                        onPressed: () => _pickDate(true),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.event_busy),
                        label: Text(_noExpiry ? 'No expiry' : (_expiry == null ? 'Expiry date *' : 'Expires ${fmtDate(_expiry)}')),
                        onPressed: _noExpiry ? null : () => _pickDate(false),
                      ),
                      FilterChip(
                        label: const Text('No expiry date'),
                        selected: _noExpiry,
                        onSelected: (v) => setState(() => _noExpiry = v),
                      ),
                    ]),
                    const SizedBox(height: 20),
                    Text('Scan or photo (optional)', style: Theme.of(context).textTheme.titleSmall),
                    const Text('Stored only on this device, encrypted. Never uploaded.'),
                    const SizedBox(height: 8),
                    Wrap(spacing: 12, children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.attach_file),
                        label: Text(_fileName == null ? 'Attach file' : 'Replace file'),
                        onPressed: _pickFile,
                      ),
                      if (_fileName != null)
                        TextButton.icon(icon: const Icon(Icons.visibility), label: Text(_fileName!), onPressed: _viewFile),
                    ]),
                    if (_linked.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text('Circulars that may affect this certificate', style: Theme.of(context).textTheme.titleSmall),
                      for (final l in _linked)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.flag_outlined),
                          title: Text('${l['title']}', maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${l['reason']}', maxLines: 3, overflow: TextOverflow.ellipsis),
                          onTap: () => context.push('/document/${l['document_id']}'),
                        ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: const Padding(padding: EdgeInsets.all(12), child: Text('Save')),
                    ),
                  ]),
                ),
              ),
            ),
    );
  }

  Widget _conflict(Map server) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('This certificate was changed on another device while you edited it here.',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Other device: number ${server['number'] ?? '–'}, expiry ${server['expiry_date'] ?? 'none'}'
              '${server['deleted_at'] != null ? ' (deleted there)' : ''}'),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            FilledButton(onPressed: () => _resolve(true), child: const Text('Keep this device\'s version')),
            OutlinedButton(onPressed: () => _resolve(false), child: const Text('Use the other version')),
          ]),
        ]),
      ),
    );
  }
}
