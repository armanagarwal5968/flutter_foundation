import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'dynamic_form_definition.dart';
import 'dynamic_form_file_upload.dart';
import 'dynamic_form_summary.dart';
import '../formatting/friendly_date.dart';
import '../widgets/blocking_progress_overlay.dart';

typedef DynamicFormSubmit = Future<void> Function(Map<String, Object?> values);

class DynamicFormView extends StatefulWidget {
  const DynamicFormView({
    required this.definition,
    required this.onSubmit,
    this.onSubmitted,
    this.initialValues = const {},
    this.fileUploader,
    this.showSectionHeader = true,
    this.sectionHeaderDecoration,
    super.key,
  });

  final DynamicFormDefinition definition;
  final DynamicFormSubmit onSubmit;
  final Future<void> Function()? onSubmitted;
  final Map<String, Object?> initialValues;
  final DynamicFormFileUploader? fileUploader;
  final bool showSectionHeader;
  final BoxDecoration? sectionHeaderDecoration;

  @override
  State<DynamicFormView> createState() => _DynamicFormViewState();
}

class _DynamicFormViewState extends State<DynamicFormView> {
  final _values = <String, Object?>{};
  final _controllers = <String, TextEditingController>{};
  final _scrollController = ScrollController();
  int _sectionIndex = 0;
  bool _submitting = false;
  bool _uploading = false;
  String? _error;
  final _requiredErrors = <String>{};

  DynamicFormSection get _section => widget.definition.sections[_sectionIndex];

  @override
  void initState() {
    super.initState();
    _values.addAll(widget.initialValues);
    for (final section in widget.definition.sections) {
      for (final field in section.fields) {
        if (_usesController(field.type)) {
          _controllers[field.id] = TextEditingController(
            text: widget.initialValues[field.id]?.toString() ?? '',
          );
        }
        if (_hasOtherOption(field)) {
          final detailsKey = _otherDetailsKey(field);
          _controllers[detailsKey] = TextEditingController(
            text: widget.initialValues[detailsKey]?.toString() ?? '',
          );
        }
      }
    }
    _removeHiddenValues();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _usesController(DynamicFieldType type) => {
    DynamicFieldType.text,
    DynamicFieldType.multiline,
    DynamicFieldType.phone,
    DynamicFieldType.number,
  }.contains(type);

  void _continue() {
    _syncControllerValues();
    if (!_validateRequiredFields([_section])) return;
    _showSection(_sectionIndex + 1);
  }

  void _showSection(int index) {
    setState(() {
      _error = null;
      _sectionIndex = index;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  Future<void> _submit() async {
    _syncControllerValues();
    if (!_validateRequiredFields(widget.definition.sections)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    var submitted = false;
    try {
      await widget.onSubmit(Map.unmodifiable(_values));
      submitted = true;
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
    if (submitted && mounted) await widget.onSubmitted?.call();
  }

  Future<void> _reviewAndSubmit() async {
    _syncControllerValues();
    if (!_validateRequiredFields(widget.definition.sections)) return;
    final confirmed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder:
            (_) => DynamicFormConfirmationPage(
              definition: widget.definition,
              values: Map.unmodifiable(_values),
            ),
      ),
    );
    if (confirmed == true) await _submit();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.definition.sections.isEmpty) {
      return const Center(child: Text('This form has no sections.'));
    }
    final isLast = _sectionIndex == widget.definition.sections.length - 1;
    final visibleFields = _section.fields.where(_isVisible).toList();
    final questionOffset =
        widget.definition.sections
            .take(_sectionIndex)
            .expand((section) => section.fields)
            .where(_isVisible)
            .where((field) => field.type != DynamicFieldType.info)
            .length;
    var questionIndex = questionOffset;
    return BlockingProgressOverlay(
      visible: _submitting || _uploading,
      message: _uploading ? 'Uploading file…' : 'Submitting form…',
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(20),
        children: [
          if (widget.definition.sections.length > 1) ...[
            LinearProgressIndicator(
              value: (_sectionIndex + 1) / widget.definition.sections.length,
            ),
            const SizedBox(height: 12),
            Text(
              'Step ${_sectionIndex + 1} of ${widget.definition.sections.length}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
          if (widget.showSectionHeader) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding:
                  widget.sectionHeaderDecoration == null
                      ? EdgeInsets.zero
                      : const EdgeInsets.all(12),
              decoration: widget.sectionHeaderDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _section.title,
                    softWrap: true,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (_section.description case final description?) ...[
                    const SizedBox(height: 8),
                    Text(description),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          for (final field in visibleFields) ...[
            _buildQuestion(
              context,
              field,
              field.type == DynamicFieldType.info ? null : ++questionIndex,
            ),
            const SizedBox(height: 16),
          ],
          if (_error case final error?) ...[
            Text(
              error,
              key: const Key('dynamic-form-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              if (_sectionIndex > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        (_submitting || _uploading)
                            ? null
                            : () => _showSection(_sectionIndex - 1),
                    child: const Text('Back'),
                  ),
                ),
              if (_sectionIndex > 0) const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed:
                      (_submitting || _uploading)
                          ? null
                          : isLast
                          ? (widget.definition.confirmBeforeSubmit
                              ? _reviewAndSubmit
                              : _submit)
                          : _continue,
                  child: Text(
                    _submitting
                        ? 'Submitting...'
                        : isLast
                        ? (widget.definition.confirmBeforeSubmit
                            ? 'Review answers'
                            : widget.definition.submitLabel)
                        : 'Continue',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isVisible(DynamicFormField field) =>
      field.visibleWhen?.matches(_values) ?? true;

  void _syncControllerValues() {
    for (final section in widget.definition.sections) {
      for (final field in section.fields.where(
        (field) => _usesController(field.type),
      )) {
        if (_isVisible(field)) {
          _values[field.id] = _controllers[field.id]!.text.trim();
        } else {
          _values.remove(field.id);
        }
      }
    }
    for (final section in widget.definition.sections) {
      for (final field in section.fields.where(_hasOtherOption)) {
        final detailsKey = _otherDetailsKey(field);
        if (_isVisible(field) && _hasSelectedOtherOption(field)) {
          _values[detailsKey] = _controllers[detailsKey]!.text.trim();
        } else {
          _values.remove(detailsKey);
        }
      }
    }
    _removeHiddenValues();
  }

  void _setValue(String fieldId, Object? value) {
    setState(() {
      _values[fieldId] = value;
      _requiredErrors.remove(fieldId);
      _removeHiddenValues();
    });
  }

  bool _validateRequiredFields(Iterable<DynamicFormSection> sections) {
    if (!widget.definition.enforceRequiredFields) return true;
    final missing = <String>{};
    for (final field in sections.expand((section) => section.fields)) {
      if (!field.required || field.type == DynamicFieldType.info) continue;
      if (!_isVisible(field)) continue;
      if (_isEmptyAnswer(_values[field.id])) missing.add(field.id);
    }
    setState(() {
      _requiredErrors
        ..clear()
        ..addAll(missing);
      _error = missing.isEmpty ? null : 'Complete all required fields.';
    });
    if (missing.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
    return missing.isEmpty;
  }

  bool _isEmptyAnswer(Object? value) {
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    if (value is Iterable) return value.isEmpty;
    if (value is Map) return value.isEmpty;
    return false;
  }

  void _removeHiddenValues() {
    final fields = widget.definition.sections
        .expand((section) => section.fields)
        .toList(growable: false);
    for (var pass = 0; pass < fields.length; pass++) {
      var removedAnswer = false;
      for (final field in fields) {
        if (_isVisible(field)) continue;
        removedAnswer = _values.remove(field.id) != null || removedAnswer;
        final controller = _controllers[field.id];
        if (controller != null && controller.text.isNotEmpty) {
          controller.clear();
          removedAnswer = true;
        }
      }
      if (!removedAnswer) break;
    }
    for (final field in fields.where(_hasOtherOption)) {
      if (_isVisible(field) && _hasSelectedOtherOption(field)) continue;
      final detailsKey = _otherDetailsKey(field);
      _values.remove(detailsKey);
      _controllers[detailsKey]?.clear();
    }
  }

  bool _hasOtherOption(DynamicFormField field) =>
      (field.type == DynamicFieldType.singleChoice ||
          field.type == DynamicFieldType.multiChoice) &&
      field.options.any(_optionNeedsDetails);

  bool _optionNeedsDetails(DynamicFieldOption option) {
    final label = option.label.toLowerCase();
    final value = option.value.toLowerCase().replaceAll('_', ' ');
    final other = RegExp(r'\bother\b');
    return other.hasMatch(label) ||
        other.hasMatch(value) ||
        label.contains('something else');
  }

  String _otherDetailsKey(DynamicFormField field) =>
      '${field.id}_other_details';

  bool _hasSelectedOtherOption(DynamicFormField field) {
    final selected = _values[field.id];
    if (selected is String) {
      return field.options.any(
        (option) => option.value == selected && _optionNeedsDetails(option),
      );
    }
    if (selected is Iterable) {
      final selectedValues = selected.whereType<String>().toSet();
      return field.options.any(
        (option) =>
            selectedValues.contains(option.value) &&
            _optionNeedsDetails(option),
      );
    }
    return false;
  }

  List<Widget> _otherDetailsInput(DynamicFormField field) {
    if (!_hasSelectedOtherOption(field)) return const [];
    final detailsKey = _otherDetailsKey(field);
    return [
      const SizedBox(height: 8),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Please specify'),
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey('other-details-${field.id}'),
            controller: _controllers[detailsKey],
            onChanged: (value) => _setValue(detailsKey, value.trim()),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ],
      ),
    ];
  }

  Widget _labelledInput({
    required BuildContext context,
    required DynamicFormField field,
    required Widget input,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _fieldLabel(
        context,
        field,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      if (field.description case final description?) ...[
        const SizedBox(height: 4),
        Text(description),
      ],
      const SizedBox(height: 8),
      input,
    ],
  );

  Widget _fieldLabel(
    BuildContext context,
    DynamicFormField field, {
    TextStyle? style,
  }) => Text.rich(
    key: ValueKey('question-label-${field.id}'),
    TextSpan(
      children: [
        TextSpan(text: field.label),
        if (field.required)
          TextSpan(
            text: ' *',
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    ),
    style: style ?? Theme.of(context).textTheme.titleMedium,
  );

  Widget _buildQuestion(
    BuildContext context,
    DynamicFormField field,
    int? questionNumber,
  ) {
    final indicator = widget.definition.questionIndicator;
    if (questionNumber == null || indicator == DynamicQuestionIndicator.none) {
      return _withRequiredState(context, field, _buildField(context, field));
    }
    final marker = switch (indicator) {
      DynamicQuestionIndicator.none => '',
      DynamicQuestionIndicator.numbered => '$questionNumber.',
      DynamicQuestionIndicator.bullet => '•',
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 32,
          child: Text(
            marker,
            key: ValueKey('question-indicator-${field.id}'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: _withRequiredState(
            context,
            field,
            _buildField(context, field),
          ),
        ),
      ],
    );
  }

  Widget _withRequiredState(
    BuildContext context,
    DynamicFormField field,
    Widget child,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      child,
      if (_requiredErrors.contains(field.id)) ...[
        const SizedBox(height: 6),
        Text(
          'This field is required.',
          key: ValueKey('required-error-${field.id}'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.error,
          ),
        ),
      ],
    ],
  );

  Widget _buildField(BuildContext context, DynamicFormField field) {
    final helper = field.description;
    switch (field.type) {
      case DynamicFieldType.info:
        return Card(
          key: ValueKey('dynamic-form-info-${field.id}'),
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  field.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (helper != null) ...[
                  const SizedBox(height: 4),
                  Text(helper),
                ],
                if (field.linkLabel != null && field.linkUrl != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    key: ValueKey('dynamic-form-link-${field.id}'),
                    onPressed:
                        () => launchUrl(
                          Uri.parse(field.linkUrl!),
                          mode: LaunchMode.externalApplication,
                        ),
                    icon: const Icon(Icons.open_in_new),
                    label: Text(field.linkLabel!),
                  ),
                ],
              ],
            ),
          ),
        );
      case DynamicFieldType.text:
      case DynamicFieldType.multiline:
      case DynamicFieldType.phone:
      case DynamicFieldType.number:
        return _labelledInput(
          context: context,
          field: field,
          input: TextFormField(
            controller: _controllers[field.id],
            onChanged: (value) => _setValue(field.id, value.trim()),
            maxLines: field.type == DynamicFieldType.multiline ? 4 : 1,
            keyboardType: switch (field.type) {
              DynamicFieldType.phone => TextInputType.phone,
              DynamicFieldType.number => TextInputType.number,
              _ => TextInputType.text,
            },
            decoration: InputDecoration(
              hintText: field.placeholder,
              border: const OutlineInputBorder(),
            ),
          ),
        );
      case DynamicFieldType.date:
        final value = _values[field.id] as String?;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(4),
          ),
          title: _fieldLabel(context, field),
          subtitle: Text(
            value == null
                ? field.placeholder ?? 'Select date'
                : formatFriendlyDateValue(value),
          ),
          trailing: const Icon(Icons.calendar_today),
          onTap: () async {
            final selected = await showDatePicker(
              context: context,
              firstDate: DateTime(1900),
              lastDate: DateTime.now().add(const Duration(days: 730)),
              initialDate: DateTime.tryParse(value ?? '') ?? DateTime.now(),
            );
            if (selected != null) {
              _setValue(field.id, selected.toIso8601String());
            }
          },
        );
      case DynamicFieldType.yesNo:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldLabel(context, field),
            if (helper != null) Text(helper),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Yes')),
                ButtonSegment(value: false, label: Text('No')),
              ],
              emptySelectionAllowed: true,
              selected:
                  _values.containsKey(field.id)
                      ? {_values[field.id]! as bool}
                      : const {},
              onSelectionChanged:
                  (selection) => _setValue(field.id, selection.first),
            ),
          ],
        );
      case DynamicFieldType.singleChoice:
        if (field.options.length > 10) {
          final selected = _values[field.id] as String?;
          final selectedDescription =
              field.options
                  .where((option) => option.value == selected)
                  .firstOrNull
                  ?.description;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _labelledInput(
                context: context,
                field: field,
                input: DropdownButtonFormField<String>(
                  key: ValueKey('single-choice-dropdown-${field.id}'),
                  value: selected,
                  isExpanded: true,
                  decoration: InputDecoration(
                    hintText: field.placeholder ?? 'Select an option',
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final option in field.options)
                      DropdownMenuItem<String>(
                        value: option.value,
                        child: Text(
                          option.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => _setValue(field.id, value),
                ),
              ),
              if (selectedDescription != null) ...[
                const SizedBox(height: 6),
                Text(selectedDescription),
              ],
              ..._otherDetailsInput(field),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldLabel(context, field),
            if (helper != null) Text(helper),
            for (final option in field.options)
              RadioListTile<String>(
                value: option.value,
                groupValue: _values[field.id] as String?,
                title: Text(option.label),
                subtitle:
                    option.description == null
                        ? null
                        : Text(option.description!),
                onChanged: (value) => _setValue(field.id, value),
              ),
            ..._otherDetailsInput(field),
          ],
        );
      case DynamicFieldType.multiChoice:
        final selected = Set<String>.from(
          (_values[field.id] as Iterable?)?.whereType<String>() ?? const [],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldLabel(context, field),
            if (helper != null) Text(helper),
            for (final option in field.options)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: selected.contains(option.value),
                title: Text(option.label),
                subtitle:
                    option.description == null
                        ? null
                        : Text(option.description!),
                onChanged: (checked) {
                  final updated = Set<String>.from(
                    (_values[field.id] as Iterable?)?.whereType<String>() ??
                        const [],
                  );
                  if (checked ?? false) {
                    updated.add(option.value);
                  } else {
                    updated.remove(option.value);
                  }
                  _setValue(field.id, updated.toList(growable: false));
                },
              ),
            ..._otherDetailsInput(field),
          ],
        );
      case DynamicFieldType.fileUpload:
        final uploads =
            (_values[field.id] as Iterable?)
                ?.whereType<Map>()
                .map((item) => Map<String, Object?>.from(item))
                .toList(growable: false) ??
            const <Map<String, Object?>>[];
        final categories =
            field.options.isEmpty
                ? const <DynamicFieldOption>[
                  DynamicFieldOption(value: 'file', label: 'File'),
                ]
                : field.options;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldLabel(context, field),
            if (helper != null) Text(helper),
            const SizedBox(height: 8),
            for (final category in categories)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton.icon(
                  onPressed:
                      (_submitting || _uploading)
                          ? null
                          : () => _uploadFile(field, category),
                  icon: const Icon(Icons.upload_file),
                  label: Text('Upload ${category.label}'),
                ),
              ),
            for (final upload in uploads)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.attach_file),
                title: Text('${upload['fileName'] ?? 'Uploaded file'}'),
                subtitle:
                    upload['category'] == null
                        ? null
                        : Text('${upload['category']}'),
              ),
          ],
        );
      case DynamicFieldType.rating:
        final rating = _values[field.id] as int? ?? 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldLabel(context, field),
            Row(
              children: [
                for (var index = 1; index <= (field.maximum ?? 5); index++)
                  IconButton(
                    onPressed: () => _setValue(field.id, index),
                    icon: Icon(
                      index <= rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                  ),
              ],
            ),
          ],
        );
    }
  }

  Future<void> _uploadFile(
    DynamicFormField field,
    DynamicFieldOption category,
  ) async {
    final uploader =
        widget.fileUploader ?? FirebaseDynamicFormFileUploader().upload;
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final upload = await uploader(
        formId: widget.definition.id,
        fieldId: field.id,
        category: category.label,
      );
      if (upload == null || !mounted) return;
      final existing =
          (_values[field.id] as Iterable?)
              ?.whereType<Map>()
              .map((item) => Map<String, Object?>.from(item))
              .where((item) => item['category'] != category.label)
              .toList() ??
          <Map<String, Object?>>[];
      _setValue(field.id, [...existing, upload]);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }
}

class DynamicFormConfirmationPage extends StatelessWidget {
  const DynamicFormConfirmationPage({
    required this.definition,
    required this.values,
    super.key,
  });

  final DynamicFormDefinition definition;
  final Map<String, Object?> values;

  @override
  Widget build(BuildContext context) {
    final fields = {
      for (final section in definition.sections)
        for (final field in section.fields) field.id: field,
    };
    final summary = buildDynamicFormSummary(definition, values);
    return Scaffold(
      appBar: AppBar(title: const Text('Review before submitting')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(definition.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          if (summary.isNotEmpty) ...[
            Text(
              'Session summary preview',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [for (final item in summary) Text('• $item')],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text('Answers', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final entry in values.entries)
            if (_hasReviewValue(entry.value))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_reviewLabel(fields, entry.key)),
                subtitle: Text(_reviewValue(fields[entry.key], entry.value)),
              ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const Key('confirm-form-submit'),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check),
            label: Text(definition.submitLabel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Go back and edit'),
          ),
        ],
      ),
    );
  }
}

String _reviewLabel(Map<String, DynamicFormField> fields, String key) {
  final field = fields[key];
  if (field != null) return field.label;
  const suffix = '_other_details';
  if (key.endsWith(suffix)) {
    final source = fields[key.substring(0, key.length - suffix.length)];
    if (source != null) return '${source.label} — Other details';
  }
  return key;
}

bool _hasReviewValue(Object? value) =>
    value != null && value != '' && !(value is Iterable && value.isEmpty);

String _reviewValue(DynamicFormField? field, Object? value) {
  if (value is bool) return value ? 'Yes' : 'No';
  if (field?.type == DynamicFieldType.date) {
    return formatFriendlyDateValue(value);
  }
  if (field != null && value is String) {
    final option = field.options.where((option) => option.value == value);
    if (option.isNotEmpty) return option.first.label;
  }
  if (field != null && value is Iterable) {
    if (field.type == DynamicFieldType.fileUpload) {
      return value
          .whereType<Map>()
          .map(
            (item) =>
                '${item['category'] ?? 'File'}: ${item['fileName'] ?? 'Uploaded'}',
          )
          .join(', ');
    }
    final selected = value.whereType<String>().toSet();
    return field.options
        .where((option) => selected.contains(option.value))
        .map((option) => option.label)
        .join(', ');
  }
  return '$value';
}
