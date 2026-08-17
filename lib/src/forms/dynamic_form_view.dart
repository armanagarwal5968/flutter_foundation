import 'package:flutter/material.dart';

import 'dynamic_form_definition.dart';

typedef DynamicFormSubmit = Future<void> Function(Map<String, Object?> values);

class DynamicFormView extends StatefulWidget {
  const DynamicFormView({
    required this.definition,
    required this.onSubmit,
    this.initialValues = const {},
    super.key,
  });

  final DynamicFormDefinition definition;
  final DynamicFormSubmit onSubmit;
  final Map<String, Object?> initialValues;

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

  String? _validateSection() {
    for (final field in _section.fields) {
      if (field.type == DynamicFieldType.info || !field.required) continue;
      final value = _valueFor(field);
      if (value == null || value == '') {
        return '${field.label} is required.';
      }
    }
    return null;
  }

  Object? _valueFor(DynamicFormField field) =>
      _usesController(field.type)
          ? _controllers[field.id]!.text.trim()
          : _values[field.id];

  void _continue() {
    final validationError = _validateSection();
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }
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
    final validationError = _validateSection();
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }
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
                onPressed: _submitting ? null : (isLast ? _submit : _continue),
                child: Text(
                  _submitting
                      ? 'Submitting...'
                      : isLast
                      ? widget.definition.submitLabel
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
            labelText: '${field.label}${field.required ? ' *' : ''}',
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
          title: Text('${field.label}${field.required ? ' *' : ''}'),
          subtitle: Text(value ?? field.placeholder ?? 'Select date'),
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
            Text('${field.label}${field.required ? ' *' : ''}'),
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${field.label}${field.required ? ' *' : ''}'),
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
      case DynamicFieldType.rating:
        final rating = _values[field.id] as int? ?? 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${field.label}${field.required ? ' *' : ''}'),
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
}
