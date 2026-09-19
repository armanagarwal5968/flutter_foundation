import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'dynamic_form_definition.dart';
import 'dynamic_form_file_upload.dart';
import 'dynamic_form_summary.dart';
import '../formatting/friendly_date.dart';

typedef DynamicFormSubmit = Future<void> Function(Map<String, Object?> values);

class DynamicFormView extends StatefulWidget {
  const DynamicFormView({
    required this.definition,
    required this.onSubmit,
    this.initialValues = const {},
    this.fileUploader,
    super.key,
  });

  final DynamicFormDefinition definition;
  final DynamicFormSubmit onSubmit;
  final Map<String, Object?> initialValues;
  final DynamicFormFileUploader? fileUploader;

  @override
  State<DynamicFormView> createState() => _DynamicFormViewState();
}

class _DynamicFormViewState extends State<DynamicFormView> {
  final _values = <String, Object?>{};
  final _controllers = <String, TextEditingController>{};
  int _sectionIndex = 0;
  bool _submitting = false;
  String? _error;

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
      }
    }
  }

  @override
  void dispose() {
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
    for (final field in _section.fields.where(
      (field) => _usesController(field.type),
    )) {
      _values[field.id] = _controllers[field.id]!.text.trim();
    }
    setState(() {
      _error = null;
      _sectionIndex++;
    });
  }

  Future<void> _submit() async {
    for (final controller in _controllers.entries) {
      _values[controller.key] = controller.value.text.trim();
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onSubmit(Map.unmodifiable(_values));
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _reviewAndSubmit() async {
    for (final controller in _controllers.entries) {
      _values[controller.key] = controller.value.text.trim();
    }
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
    return ListView(
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
        const SizedBox(height: 12),
        Text(_section.title, style: Theme.of(context).textTheme.headlineSmall),
        if (_section.description case final description?) ...[
          const SizedBox(height: 8),
          Text(description),
        ],
        const SizedBox(height: 20),
        for (final field in _section.fields) ...[
          _buildField(context, field),
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
                      _submitting
                          ? null
                          : () => setState(() => _sectionIndex--),
                  child: const Text('Back'),
                ),
              ),
            if (_sectionIndex > 0) const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed:
                    _submitting
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
    );
  }

  Widget _buildField(BuildContext context, DynamicFormField field) {
    final helper = field.description;
    switch (field.type) {
      case DynamicFieldType.info:
        return Card(
          color: Theme.of(context).colorScheme.primaryContainer,
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
        return TextFormField(
          controller: _controllers[field.id],
          maxLines: field.type == DynamicFieldType.multiline ? 4 : 1,
          keyboardType: switch (field.type) {
            DynamicFieldType.phone => TextInputType.phone,
            DynamicFieldType.number => TextInputType.number,
            _ => TextInputType.text,
          },
          decoration: InputDecoration(
            labelText: field.label,
            hintText: field.placeholder,
            helperText: helper,
            border: const OutlineInputBorder(),
            alignLabelWithHint: field.type == DynamicFieldType.multiline,
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
          title: Text(field.label),
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
              setState(() => _values[field.id] = selected.toIso8601String());
            }
          },
        );
      case DynamicFieldType.yesNo:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(field.label),
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
                  (selection) =>
                      setState(() => _values[field.id] = selection.first),
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
              DropdownButtonFormField<String>(
                key: ValueKey('single-choice-dropdown-${field.id}'),
                value: selected,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: field.label,
                  helperText: helper,
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
                onChanged: (value) => setState(() => _values[field.id] = value),
              ),
              if (selectedDescription != null) ...[
                const SizedBox(height: 6),
                Text(selectedDescription),
              ],
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(field.label),
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
                onChanged: (value) => setState(() => _values[field.id] = value),
              ),
          ],
        );
      case DynamicFieldType.multiChoice:
        final selected = Set<String>.from(
          (_values[field.id] as Iterable?)?.whereType<String>() ?? const [],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(field.label),
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
                  setState(
                    () => _values[field.id] = updated.toList(growable: false),
                  );
                },
              ),
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
            Text(field.label),
            if (helper != null) Text(helper),
            const SizedBox(height: 8),
            for (final category in categories)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton.icon(
                  onPressed:
                      _submitting ? null : () => _uploadFile(field, category),
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
            Text(field.label),
            Row(
              children: [
                for (var index = 1; index <= (field.maximum ?? 5); index++)
                  IconButton(
                    onPressed: () => setState(() => _values[field.id] = index),
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
      _submitting = true;
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
      setState(() => _values[field.id] = [...existing, upload]);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
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
                title: Text(fields[entry.key]?.label ?? entry.key),
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
