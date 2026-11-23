import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'dynamic_form_definition.dart';
import 'dynamic_form_file_upload.dart';
import 'dynamic_form_view.dart';

/// Identifies one in-progress form: who is filling it, which form, and for
/// which patient and session.
@immutable
class DynamicFormDraftKey {
  const DynamicFormDraftKey({
    required this.ownerId,
    required this.formId,
    this.patientId,
    this.sessionId,
  });

  final String ownerId;
  final String formId;
  final String? patientId;
  final String? sessionId;

  /// Firestore document ID. Starts with the owner's uid so security rules can
  /// allow reading a draft that does not exist yet.
  String get documentId => [
    ownerId,
    formId,
    patientId ?? '-',
    sessionId ?? '-',
  ].map((part) => part.replaceAll(RegExp('[^A-Za-z0-9_-]'), '_')).join('__');

  @override
  bool operator ==(Object other) =>
      other is DynamicFormDraftKey && other.documentId == documentId;

  @override
  int get hashCode => documentId.hashCode;
}

@immutable
class DynamicFormDraft {
  const DynamicFormDraft({
    required this.values,
    required this.pageIndex,
    required this.formVersion,
    this.updatedAt,
  });

  final Map<String, Object?> values;
  final int pageIndex;
  final int formVersion;
  final DateTime? updatedAt;

  bool get isEmpty => values.isEmpty;
}

abstract interface class DynamicFormDraftStore {
  Future<DynamicFormDraft?> load(DynamicFormDraftKey key);

  Future<void> save(DynamicFormDraftKey key, DynamicFormDraft draft);

  Future<void> delete(DynamicFormDraftKey key);
}

/// Drafts in the top-level `form_drafts` collection, one document per
/// [DynamicFormDraftKey], readable only by the expert who owns it.
class FirestoreDynamicFormDraftStore implements DynamicFormDraftStore {
  FirestoreDynamicFormDraftStore({FirebaseFirestore? firestore})
    : _injected = firestore;

  final FirebaseFirestore? _injected;

  // Resolved on first use so building a form never requires Firebase.
  FirebaseFirestore get _firestore => _injected ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _document(DynamicFormDraftKey key) =>
      _firestore.collection('form_drafts').doc(key.documentId);

  @override
  Future<DynamicFormDraft?> load(DynamicFormDraftKey key) async {
    final snapshot = await _document(key).get();
    final data = snapshot.data();
    if (data == null) return null;
    final updatedAt = data['updatedAt'];
    return DynamicFormDraft(
      values: Map<String, Object?>.from(data['values'] as Map? ?? const {}),
      pageIndex: (data['pageIndex'] as num?)?.toInt() ?? 0,
      formVersion: (data['formVersion'] as num?)?.toInt() ?? 0,
      updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : null,
    );
  }

  @override
  Future<void> save(DynamicFormDraftKey key, DynamicFormDraft draft) =>
      _document(key).set({
        'ownerId': key.ownerId,
        'formId': key.formId,
        'formVersion': draft.formVersion,
        'patientId': key.patientId,
        'sessionId': key.sessionId,
        'values': draft.values,
        'pageIndex': draft.pageIndex,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> delete(DynamicFormDraftKey key) => _document(key).delete();
}

/// Keeps only answers that belong to [definition], so a draft saved against
/// an older form version cannot submit removed questions.
@visibleForTesting
Map<String, Object?> draftValuesForDefinition(
  DynamicFormDefinition definition,
  Map<String, Object?> values,
) {
  final allowed = <String>{};
  for (final section in definition.sections) {
    for (final field in section.fields) {
      allowed
        ..add(field.id)
        ..add('${field.id}_other_details');
    }
  }
  return {
    for (final entry in values.entries)
      if (allowed.contains(entry.key)) entry.key: entry.value,
  };
}

/// A [DynamicFormView] that saves the answers as a draft while they are being
/// filled in, restores them (and the page) when the form is opened again, and
/// deletes the draft once the form is submitted.
class DraftableDynamicFormView extends StatefulWidget {
  const DraftableDynamicFormView({
    required this.definition,
    required this.draftKey,
    required this.draftStore,
    required this.onSubmit,
    this.onSubmitted,
    this.fileUploader,
    this.showSectionHeader = true,
    this.sectionHeaderDecoration,
    this.saveDelay = const Duration(milliseconds: 800),
    super.key,
  });

  final DynamicFormDefinition definition;
  final DynamicFormDraftKey draftKey;
  final DynamicFormDraftStore draftStore;
  final DynamicFormSubmit onSubmit;
  final Future<void> Function()? onSubmitted;
  final DynamicFormFileUploader? fileUploader;
  final bool showSectionHeader;
  final BoxDecoration? sectionHeaderDecoration;

  /// How long typing must pause before the draft is saved.
  final Duration saveDelay;

  @override
  State<DraftableDynamicFormView> createState() =>
      _DraftableDynamicFormViewState();
}

enum _DraftStatus { none, restored, saving, saved, failed }

class _DraftableDynamicFormViewState extends State<DraftableDynamicFormView> {
  late Future<DynamicFormDraft?> _loading;
  DynamicFormDraft? _restored;
  var _generation = 0;
  var _status = _DraftStatus.none;
  DateTime? _savedAt;
  Timer? _saveTimer;
  Map<String, Object?>? _pendingValues;
  var _pendingPage = 0;
  var _submitted = false;
  var _disposed = false;

  bool get _canUpdate => mounted && !_disposed;

  @override
  void initState() {
    super.initState();
    _loading = _load();
  }

  Future<DynamicFormDraft?> _load() async {
    try {
      final draft = await widget.draftStore.load(widget.draftKey);
      if (draft == null) return null;
      final values = draftValuesForDefinition(widget.definition, draft.values);
      if (values.isEmpty) return null;
      final restored = DynamicFormDraft(
        values: values,
        pageIndex: draft.pageIndex,
        formVersion: draft.formVersion,
        updatedAt: draft.updatedAt,
      );
      _restored = restored;
      _status = _DraftStatus.restored;
      _savedAt = draft.updatedAt;
      return restored;
    } on Object catch (error) {
      debugPrint('Form draft could not be loaded: $error');
      return null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    // Leaving the page mid-pause still keeps the latest answers.
    if (_saveTimer?.isActive ?? false) {
      _saveTimer!.cancel();
      unawaited(_flush());
    }
    super.dispose();
  }

  void _onChanged(Map<String, Object?> values, int pageIndex) {
    if (_submitted) return;
    _pendingValues = values;
    _pendingPage = pageIndex;
    _saveTimer?.cancel();
    _saveTimer = Timer(widget.saveDelay, () => unawaited(_flush()));
  }

  Future<void> _flush() async {
    final values = _pendingValues;
    if (values == null || _submitted) return;
    _pendingValues = null;
    if (_canUpdate) setState(() => _status = _DraftStatus.saving);
    try {
      if (values.isEmpty) {
        await widget.draftStore.delete(widget.draftKey);
      } else {
        await widget.draftStore.save(
          widget.draftKey,
          DynamicFormDraft(
            values: values,
            pageIndex: _pendingPage,
            formVersion: widget.definition.version,
          ),
        );
      }
      if (_canUpdate && !_submitted) {
        setState(() {
          _status = values.isEmpty ? _DraftStatus.none : _DraftStatus.saved;
          _savedAt = DateTime.now();
        });
      }
    } on Object catch (error) {
      debugPrint('Form draft could not be saved: $error');
      if (_canUpdate) setState(() => _status = _DraftStatus.failed);
    }
  }

  Future<void> _submit(Map<String, Object?> values) async {
    await widget.onSubmit(values);
    _submitted = true;
    _saveTimer?.cancel();
    _pendingValues = null;
    try {
      await widget.draftStore.delete(widget.draftKey);
    } on Object catch (error) {
      debugPrint('Submitted form draft could not be deleted: $error');
    }
  }

  Future<void> _discard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Discard draft?'),
            content: const Text(
              'Your saved answers for this form will be cleared and the form '
              'will start again from the beginning.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep draft'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Discard'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    _saveTimer?.cancel();
    _pendingValues = null;
    try {
      await widget.draftStore.delete(widget.draftKey);
    } on Object catch (error) {
      debugPrint('Form draft could not be discarded: $error');
    }
    if (!mounted) return;
    setState(() {
      _restored = null;
      _status = _DraftStatus.none;
      _savedAt = null;
      _generation++;
    });
  }

  String _statusText() {
    final time =
        _savedAt == null
            ? ''
            : ' · ${TimeOfDay.fromDateTime(_savedAt!.toLocal()).format(context)}';
    return switch (_status) {
      _DraftStatus.restored => 'Continuing your saved draft$time',
      _DraftStatus.saving => 'Saving draft…',
      _DraftStatus.saved => 'Draft saved$time',
      _DraftStatus.failed => 'Draft could not be saved. Check your connection.',
      _DraftStatus.none => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DynamicFormDraft?>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final restored = _restored;
        final theme = Theme.of(context);
        return Column(
          children: [
            if (_status != _DraftStatus.none)
              Material(
                color:
                    _status == _DraftStatus.failed
                        ? theme.colorScheme.errorContainer
                        : theme.colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                  child: Row(
                    children: [
                      Icon(
                        _status == _DraftStatus.failed
                            ? Icons.cloud_off_outlined
                            : Icons.edit_note,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusText(),
                          key: const ValueKey('form-draft-status'),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      TextButton(
                        onPressed: _discard,
                        child: const Text('Discard draft'),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: DynamicFormView(
                key: ValueKey('draft-form-$_generation'),
                definition: widget.definition,
                initialValues: restored?.values ?? const {},
                initialPageIndex: restored?.pageIndex ?? 0,
                onChanged: _onChanged,
                onSubmit: _submit,
                onSubmitted: widget.onSubmitted,
                fileUploader: widget.fileUploader,
                showSectionHeader: widget.showSectionHeader,
                sectionHeaderDecoration: widget.sectionHeaderDecoration,
              ),
            ),
          ],
        );
      },
    );
  }
}
