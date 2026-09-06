import 'package:flutter/material.dart';

import 'dynamic_form_definition.dart';
import 'dynamic_form_preview.dart';
import 'dynamic_form_repository.dart';

class DynamicFormEditorPage extends StatefulWidget {
  const DynamicFormEditorPage({
    required this.form,
    required this.repository,
    super.key,
  });

  final DynamicFormDefinition form;
  final DynamicFormRepository repository;

  @override
  State<DynamicFormEditorPage> createState() => _DynamicFormEditorPageState();
}

class _DynamicFormEditorPageState extends State<DynamicFormEditorPage> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _submitLabel;
  late List<DynamicFormSection> _sections;
  late bool _published;
  late bool _catalogVisible;
  late bool _confirmBeforeSubmit;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.form.title);
    _description = TextEditingController(text: widget.form.description);
    _submitLabel = TextEditingController(text: widget.form.submitLabel);
    _sections = List.of(widget.form.sections);
    _published = widget.form.published;
    _catalogVisible = widget.form.catalogVisible;
    _confirmBeforeSubmit = widget.form.confirmBeforeSubmit;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _submitLabel.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.repository.saveForm(
        _currentDefinition(version: widget.form.version + 1),
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  DynamicFormDefinition _currentDefinition({required int version}) =>
      DynamicFormDefinition(
        id: widget.form.id,
        title: _title.text.trim(),
        description:
            _description.text.trim().isEmpty ? null : _description.text.trim(),
        submitLabel: _submitLabel.text.trim(),
        version: version,
        published: _published,
        catalogVisible: _catalogVisible,
        confirmBeforeSubmit: _confirmBeforeSubmit,
        sections: _sections,
      );

  void _preview() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => DynamicFormPreviewPage(
              definition: _currentDefinition(version: widget.form.version),
            ),
      ),
    );
  }

  Future<void> _addSection() async {
    final section = await _sectionDialog();
    if (section != null) setState(() => _sections.add(section));
  }

  Future<DynamicFormSection?> _sectionDialog([
    DynamicFormSection? existing,
  ]) async {
    final title = TextEditingController(text: existing?.title);
    final description = TextEditingController(text: existing?.description);
    final result = await showDialog<DynamicFormSection>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(existing == null ? 'Add section' : 'Edit section'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                TextField(
                  controller: description,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed:
                    () => Navigator.pop(
                      context,
                      DynamicFormSection(
                        id:
                            existing?.id ??
                            'section_${DateTime.now().microsecondsSinceEpoch}',
                        title: title.text.trim(),
                        description:
                            description.text.trim().isEmpty
                                ? null
                                : description.text.trim(),
                        fields: existing?.fields ?? const [],
                      ),
                    ),
                child: const Text('Save'),
              ),
            ],
          ),
    );
    title.dispose();
    description.dispose();
    return result;
  }

  Future<DynamicFormField?> _fieldDialog([DynamicFormField? existing]) async {
    final label = TextEditingController(text: existing?.label);
    final description = TextEditingController(text: existing?.description);
    final placeholder = TextEditingController(text: existing?.placeholder);
    final optionRows = <_EditableOptionRow>[];
    final allOptionRows = <_EditableOptionRow>[];
    for (final option in existing?.options ?? const <DynamicFieldOption>[]) {
      final row = _EditableOptionRow.fromOption(option);
      optionRows.add(row);
      allOptionRows.add(row);
    }
    var type = existing?.type ?? DynamicFieldType.text;
    var required = existing?.required ?? false;
    var includeInSummary = existing?.includeInSummary ?? false;
    final result = await showDialog<DynamicFormField>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text(existing == null ? 'Add field' : 'Edit field'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: label,
                          decoration: const InputDecoration(labelText: 'Label'),
                        ),
                        DropdownButtonFormField<DynamicFieldType>(
                          value: type,
                          decoration: const InputDecoration(labelText: 'Type'),
                          items: [
                            for (final value in DynamicFieldType.values)
                              DropdownMenuItem(
                                value: value,
                                child: Text(value.name),
                              ),
                          ],
                          onChanged:
                              (value) => setDialogState(() => type = value!),
                        ),
                        TextField(
                          controller: description,
                          decoration: const InputDecoration(
                            labelText: 'Description/help',
                          ),
                        ),
                        TextField(
                          controller: placeholder,
                          decoration: const InputDecoration(
                            labelText: 'Placeholder',
                          ),
                        ),
                        if (type == DynamicFieldType.singleChoice ||
                            type == DynamicFieldType.multiChoice) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Options',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          for (
                            var optionIndex = 0;
                            optionIndex < optionRows.length;
                            optionIndex++
                          )
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller:
                                                optionRows[optionIndex].label,
                                            decoration: const InputDecoration(
                                              labelText: 'Option label',
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Delete option',
                                          onPressed:
                                              () => setDialogState(
                                                () => optionRows.removeAt(
                                                  optionIndex,
                                                ),
                                              ),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                        ),
                                      ],
                                    ),
                                    TextField(
                                      controller:
                                          optionRows[optionIndex].description,
                                      decoration: const InputDecoration(
                                        labelText: 'Description (optional)',
                                      ),
                                    ),
                                    CheckboxListTile(
                                      contentPadding: EdgeInsets.zero,
                                      value:
                                          optionRows[optionIndex]
                                              .includeInSummary,
                                      onChanged:
                                          (value) => setDialogState(
                                            () =>
                                                optionRows[optionIndex]
                                                        .includeInSummary =
                                                    value ?? false,
                                          ),
                                      title: const Text(
                                        'Part of session summary',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          OutlinedButton.icon(
                            onPressed: () {
                              final row = _EditableOptionRow.empty();
                              allOptionRows.add(row);
                              setDialogState(() => optionRows.add(row));
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add option'),
                          ),
                        ],
                        if (type != DynamicFieldType.info &&
                            type != DynamicFieldType.singleChoice &&
                            type != DynamicFieldType.multiChoice)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: includeInSummary,
                            onChanged:
                                (value) => setDialogState(
                                  () => includeInSummary = value ?? false,
                                ),
                            title: Text(
                              type == DynamicFieldType.yesNo
                                  ? 'Add Yes to session summary'
                                  : 'Include answer in session summary',
                            ),
                          ),
                        SwitchListTile(
                          value: required,
                          onChanged:
                              (value) => setDialogState(() => required = value),
                          title: const Text('Required'),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed:
                          () => Navigator.pop(
                            context,
                            DynamicFormField(
                              id:
                                  existing?.id ??
                                  'field_${DateTime.now().microsecondsSinceEpoch}',
                              label: label.text.trim(),
                              type: type,
                              description:
                                  description.text.trim().isEmpty
                                      ? null
                                      : description.text.trim(),
                              placeholder:
                                  placeholder.text.trim().isEmpty
                                      ? null
                                      : placeholder.text.trim(),
                              required: required,
                              minimum:
                                  type == DynamicFieldType.rating ? 1 : null,
                              maximum:
                                  type == DynamicFieldType.rating ? 5 : null,
                              includeInSummary: includeInSummary,
                              options: optionRows
                                  .where(
                                    (row) => row.label.text.trim().isNotEmpty,
                                  )
                                  .map((row) => row.toOption())
                                  .toList(growable: false),
                            ),
                          ),
                      child: const Text('Save'),
                    ),
                  ],
                ),
          ),
    );
    label.dispose();
    description.dispose();
    placeholder.dispose();
    for (final row in allOptionRows) {
      row.dispose();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit form'),
        actions: [
          IconButton(
            tooltip: 'Preview as user',
            onPressed: _preview,
            icon: const Icon(Icons.visibility_outlined),
          ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving...' : 'Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Form title'),
          ),
          TextField(
            controller: _description,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          TextField(
            controller: _submitLabel,
            decoration: const InputDecoration(labelText: 'Submit button'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _published,
            onChanged: (value) => setState(() => _published = value),
            title: const Text('Published'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _catalogVisible,
            onChanged: (value) => setState(() => _catalogVisible = value),
            title: const Text('Show in form catalog'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _confirmBeforeSubmit,
            onChanged: (value) => setState(() => _confirmBeforeSubmit = value),
            title: const Text('Review answers before submitting'),
          ),
          const Divider(),
          for (
            var sectionIndex = 0;
            sectionIndex < _sections.length;
            sectionIndex++
          )
            Card(
              child: ExpansionTile(
                title: Text(_sections[sectionIndex].title),
                subtitle: Text(
                  '${_sections[sectionIndex].fields.length} fields',
                ),
                trailing: IconButton(
                  tooltip: 'Delete section',
                  onPressed:
                      () => setState(() => _sections.removeAt(sectionIndex)),
                  icon: const Icon(Icons.delete_outline),
                ),
                children: [
                  for (
                    var fieldIndex = 0;
                    fieldIndex < _sections[sectionIndex].fields.length;
                    fieldIndex++
                  )
                    ListTile(
                      title: Text(
                        _sections[sectionIndex].fields[fieldIndex].label,
                      ),
                      subtitle: Text(
                        _sections[sectionIndex].fields[fieldIndex].type.name,
                      ),
                      onTap: () async {
                        final updated = await _fieldDialog(
                          _sections[sectionIndex].fields[fieldIndex],
                        );
                        if (updated == null) return;
                        final fields = List<DynamicFormField>.of(
                          _sections[sectionIndex].fields,
                        )..[fieldIndex] = updated;
                        setState(
                          () =>
                              _sections[sectionIndex] = DynamicFormSection(
                                id: _sections[sectionIndex].id,
                                title: _sections[sectionIndex].title,
                                description:
                                    _sections[sectionIndex].description,
                                fields: fields,
                              ),
                        );
                      },
                      trailing: IconButton(
                        onPressed: () {
                          final fields = List<DynamicFormField>.of(
                            _sections[sectionIndex].fields,
                          )..removeAt(fieldIndex);
                          setState(
                            () =>
                                _sections[sectionIndex] = DynamicFormSection(
                                  id: _sections[sectionIndex].id,
                                  title: _sections[sectionIndex].title,
                                  description:
                                      _sections[sectionIndex].description,
                                  fields: fields,
                                ),
                          );
                        },
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('Add field'),
                    onTap: () async {
                      final field = await _fieldDialog();
                      if (field == null) return;
                      setState(
                        () =>
                            _sections[sectionIndex] = DynamicFormSection(
                              id: _sections[sectionIndex].id,
                              title: _sections[sectionIndex].title,
                              description: _sections[sectionIndex].description,
                              fields: [
                                ..._sections[sectionIndex].fields,
                                field,
                              ],
                            ),
                      );
                    },
                  ),
                ],
              ),
            ),
          OutlinedButton.icon(
            onPressed: _addSection,
            icon: const Icon(Icons.add),
            label: const Text('Add section'),
          ),
        ],
      ),
    );
  }
}

class _EditableOptionRow {
  _EditableOptionRow({
    required this.value,
    required this.label,
    required this.description,
    required this.includeInSummary,
  });

  factory _EditableOptionRow.fromOption(DynamicFieldOption option) =>
      _EditableOptionRow(
        value: option.value,
        label: TextEditingController(text: option.label),
        description: TextEditingController(text: option.description),
        includeInSummary: option.includeInSummary,
      );

  factory _EditableOptionRow.empty() => _EditableOptionRow(
    value: null,
    label: TextEditingController(),
    description: TextEditingController(),
    includeInSummary: false,
  );

  final String? value;
  final TextEditingController label;
  final TextEditingController description;
  bool includeInSummary;

  DynamicFieldOption toOption() {
    final optionLabel = label.text.trim();
    return DynamicFieldOption(
      value:
          value ??
          optionLabel.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_'),
      label: optionLabel,
      description:
          description.text.trim().isEmpty ? null : description.text.trim(),
      includeInSummary: includeInSummary,
    );
  }

  void dispose() {
    label.dispose();
    description.dispose();
  }
}
