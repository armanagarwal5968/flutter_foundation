import 'package:flutter/material.dart';

import 'dynamic_form_definition.dart';
import 'dynamic_form_preview.dart';
import 'dynamic_form_repository.dart';

enum _EditorItemAction { moveUp, moveDown, edit, delete }

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
  late DynamicQuestionIndicator _questionIndicator;
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
    _questionIndicator = widget.form.questionIndicator;
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
        questionIndicator: _questionIndicator,
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

  Future<void> _editSection(int sectionIndex) async {
    final section = await _sectionDialog(_sections[sectionIndex]);
    if (section != null) {
      setState(() => _sections[sectionIndex] = section);
    }
  }

  void _moveSection(int sectionIndex, int offset) {
    final destination = sectionIndex + offset;
    if (destination < 0 || destination >= _sections.length) return;
    setState(() {
      final section = _sections.removeAt(sectionIndex);
      _sections.insert(destination, section);
    });
  }

  void _moveField(int sectionIndex, int fieldIndex, int offset) {
    final fields = List<DynamicFormField>.of(_sections[sectionIndex].fields);
    final destination = fieldIndex + offset;
    if (destination < 0 || destination >= fields.length) return;
    final field = fields.removeAt(fieldIndex);
    fields.insert(destination, field);
    _replaceSectionFields(sectionIndex, fields);
  }

  void _replaceSectionFields(int sectionIndex, List<DynamicFormField> fields) {
    final section = _sections[sectionIndex];
    setState(
      () =>
          _sections[sectionIndex] = DynamicFormSection(
            id: section.id,
            title: section.title,
            description: section.description,
            fields: fields,
          ),
    );
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
                  key: const Key('section-title-editor'),
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
    await Future<void>.delayed(kThemeAnimationDuration);
    title.dispose();
    description.dispose();
    return result;
  }

  Future<DynamicFormField?> _fieldDialog([DynamicFormField? existing]) async {
    final label = TextEditingController(text: existing?.label);
    final description = TextEditingController(text: existing?.description);
    final linkLabel = TextEditingController(text: existing?.linkLabel);
    final linkUrl = TextEditingController(text: existing?.linkUrl);
    final placeholder = TextEditingController(text: existing?.placeholder);
    final orderedFields = _sections
        .expand((section) => section.fields)
        .toList(growable: false);
    final existingIndex =
        existing == null
            ? orderedFields.length
            : orderedFields.indexWhere((field) => field.id == existing.id);
    final conditionCandidates = orderedFields
        .take(existingIndex < 0 ? orderedFields.length : existingIndex)
        .toList(growable: false);
    var conditionEnabled = existing?.visibleWhen != null;
    var conditionFieldId = existing?.visibleWhen?.fieldId;
    var conditionOperator =
        existing?.visibleWhen?.operator ?? DynamicConditionOperator.equals;
    Object? conditionValue = existing?.visibleWhen?.value;
    final conditionValueText = TextEditingController(
      text: conditionValue?.toString() ?? '',
    );
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
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: conditionEnabled,
                          onChanged:
                              conditionCandidates.isEmpty
                                  ? null
                                  : (value) => setDialogState(
                                    () => conditionEnabled = value,
                                  ),
                          title: const Text('Show conditionally'),
                          subtitle: const Text(
                            'Display this field only when another answer matches.',
                          ),
                        ),
                        if (conditionEnabled) ...[
                          DropdownButtonFormField<String>(
                            value:
                                conditionCandidates.any(
                                      (field) => field.id == conditionFieldId,
                                    )
                                    ? conditionFieldId
                                    : null,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Depends on question',
                            ),
                            items: [
                              for (final candidate in conditionCandidates)
                                DropdownMenuItem(
                                  value: candidate.id,
                                  child: Text(
                                    candidate.label,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (value) {
                              final source = conditionCandidates.firstWhere(
                                (field) => field.id == value,
                              );
                              setDialogState(() {
                                conditionFieldId = value;
                                conditionOperator =
                                    source.type == DynamicFieldType.multiChoice
                                        ? DynamicConditionOperator.contains
                                        : DynamicConditionOperator.equals;
                                conditionValue =
                                    source.type == DynamicFieldType.yesNo
                                        ? true
                                        : source.options.isNotEmpty
                                        ? source.options.first.value
                                        : '';
                                conditionValueText.text =
                                    conditionValue?.toString() ?? '';
                              });
                            },
                          ),
                          DropdownButtonFormField<DynamicConditionOperator>(
                            value: conditionOperator,
                            decoration: const InputDecoration(
                              labelText: 'Condition',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: DynamicConditionOperator.equals,
                                child: Text('Equals'),
                              ),
                              DropdownMenuItem(
                                value: DynamicConditionOperator.notEquals,
                                child: Text('Does not equal'),
                              ),
                              DropdownMenuItem(
                                value: DynamicConditionOperator.contains,
                                child: Text('Contains'),
                              ),
                            ],
                            onChanged:
                                (value) => setDialogState(
                                  () =>
                                      conditionOperator =
                                          value ??
                                          DynamicConditionOperator.equals,
                                ),
                          ),
                          if (_fieldWithId(
                                conditionCandidates,
                                conditionFieldId,
                              )
                              case final source?)
                            if (source.type == DynamicFieldType.yesNo)
                              DropdownButtonFormField<bool>(
                                value:
                                    conditionValue is bool
                                        ? conditionValue as bool
                                        : null,
                                decoration: const InputDecoration(
                                  labelText: 'Expected answer',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: true,
                                    child: Text('Yes'),
                                  ),
                                  DropdownMenuItem(
                                    value: false,
                                    child: Text('No'),
                                  ),
                                ],
                                onChanged:
                                    (value) => setDialogState(
                                      () => conditionValue = value,
                                    ),
                              )
                            else if (source.options.isNotEmpty)
                              DropdownButtonFormField<String>(
                                value:
                                    source.options.any(
                                          (option) =>
                                              option.value == conditionValue,
                                        )
                                        ? conditionValue as String?
                                        : null,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Expected answer',
                                ),
                                items: [
                                  for (final option in source.options)
                                    DropdownMenuItem(
                                      value: option.value,
                                      child: Text(
                                        option.label,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged:
                                    (value) => setDialogState(
                                      () => conditionValue = value,
                                    ),
                              )
                            else
                              TextField(
                                controller: conditionValueText,
                                decoration: const InputDecoration(
                                  labelText: 'Expected value',
                                ),
                                onChanged:
                                    (value) => setDialogState(
                                      () => conditionValue = value,
                                    ),
                              ),
                        ],
                        if (type == DynamicFieldType.info) ...[
                          TextField(
                            controller: linkLabel,
                            decoration: const InputDecoration(
                              labelText: 'Link label (optional)',
                            ),
                          ),
                          TextField(
                            controller: linkUrl,
                            keyboardType: TextInputType.url,
                            decoration: const InputDecoration(
                              labelText: 'Link URL (optional)',
                            ),
                          ),
                        ],
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
                              linkLabel:
                                  type != DynamicFieldType.info ||
                                          linkLabel.text.trim().isEmpty
                                      ? null
                                      : linkLabel.text.trim(),
                              linkUrl:
                                  type != DynamicFieldType.info ||
                                          linkUrl.text.trim().isEmpty
                                      ? null
                                      : linkUrl.text.trim(),
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
                              visibleWhen:
                                  conditionEnabled &&
                                          conditionFieldId != null &&
                                          conditionValue != null
                                      ? DynamicFieldCondition(
                                        fieldId: conditionFieldId!,
                                        operator: conditionOperator,
                                        value: conditionValue,
                                      )
                                      : null,
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
    await Future<void>.delayed(kThemeAnimationDuration);
    label.dispose();
    description.dispose();
    linkLabel.dispose();
    linkUrl.dispose();
    placeholder.dispose();
    conditionValueText.dispose();
    for (final row in allOptionRows) {
      row.dispose();
    }
    return result;
  }

  DynamicFormField? _fieldWithId(List<DynamicFormField> fields, String? id) {
    for (final field in fields) {
      if (field.id == id) return field;
    }
    return null;
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
          DropdownButtonFormField<DynamicQuestionIndicator>(
            value: _questionIndicator,
            decoration: const InputDecoration(labelText: 'Question markers'),
            items: const [
              DropdownMenuItem(
                value: DynamicQuestionIndicator.numbered,
                child: Text('Numbered (1, 2, 3...)'),
              ),
              DropdownMenuItem(
                value: DynamicQuestionIndicator.bullet,
                child: Text('Bullets'),
              ),
              DropdownMenuItem(
                value: DynamicQuestionIndicator.none,
                child: Text('None'),
              ),
            ],
            onChanged:
                (value) => setState(
                  () =>
                      _questionIndicator =
                          value ?? DynamicQuestionIndicator.numbered,
                ),
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
                trailing: PopupMenuButton<_EditorItemAction>(
                  key: ValueKey('section-menu-${_sections[sectionIndex].id}'),
                  tooltip: 'Section actions',
                  onSelected: (action) {
                    switch (action) {
                      case _EditorItemAction.moveUp:
                        _moveSection(sectionIndex, -1);
                      case _EditorItemAction.moveDown:
                        _moveSection(sectionIndex, 1);
                      case _EditorItemAction.edit:
                        _editSection(sectionIndex);
                      case _EditorItemAction.delete:
                        setState(() => _sections.removeAt(sectionIndex));
                    }
                  },
                  itemBuilder:
                      (context) => [
                        PopupMenuItem(
                          value: _EditorItemAction.moveUp,
                          enabled: sectionIndex > 0,
                          child: const Text('Move section up'),
                        ),
                        PopupMenuItem(
                          value: _EditorItemAction.moveDown,
                          enabled: sectionIndex < _sections.length - 1,
                          child: const Text('Move section down'),
                        ),
                        const PopupMenuItem(
                          value: _EditorItemAction.edit,
                          child: Text('Edit section title'),
                        ),
                        const PopupMenuItem(
                          value: _EditorItemAction.delete,
                          child: Text('Delete section'),
                        ),
                      ],
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
                        '${_sections[sectionIndex].fields[fieldIndex].type.name}'
                        '${_sections[sectionIndex].fields[fieldIndex].visibleWhen == null ? '' : ' • conditional'}',
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
                      trailing: PopupMenuButton<_EditorItemAction>(
                        key: ValueKey(
                          'field-menu-${_sections[sectionIndex].id}-${_sections[sectionIndex].fields[fieldIndex].id}',
                        ),
                        tooltip: 'Field actions',
                        onSelected: (action) async {
                          switch (action) {
                            case _EditorItemAction.moveUp:
                              _moveField(sectionIndex, fieldIndex, -1);
                            case _EditorItemAction.moveDown:
                              _moveField(sectionIndex, fieldIndex, 1);
                            case _EditorItemAction.edit:
                              final updated = await _fieldDialog(
                                _sections[sectionIndex].fields[fieldIndex],
                              );
                              if (updated == null) return;
                              final fields = List<DynamicFormField>.of(
                                _sections[sectionIndex].fields,
                              )..[fieldIndex] = updated;
                              _replaceSectionFields(sectionIndex, fields);
                            case _EditorItemAction.delete:
                              final fields = List<DynamicFormField>.of(
                                _sections[sectionIndex].fields,
                              )..removeAt(fieldIndex);
                              _replaceSectionFields(sectionIndex, fields);
                          }
                        },
                        itemBuilder:
                            (context) => [
                              PopupMenuItem(
                                value: _EditorItemAction.moveUp,
                                enabled: fieldIndex > 0,
                                child: const Text('Move field up'),
                              ),
                              PopupMenuItem(
                                value: _EditorItemAction.moveDown,
                                enabled:
                                    fieldIndex <
                                    _sections[sectionIndex].fields.length - 1,
                                child: const Text('Move field down'),
                              ),
                              const PopupMenuItem(
                                value: _EditorItemAction.edit,
                                child: Text('Edit field'),
                              ),
                              const PopupMenuItem(
                                value: _EditorItemAction.delete,
                                child: Text('Delete field'),
                              ),
                            ],
                      ),
                    ),
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('Add field'),
                    onTap: () async {
                      final field = await _fieldDialog();
                      if (field == null) return;
                      _replaceSectionFields(sectionIndex, [
                        ..._sections[sectionIndex].fields,
                        field,
                      ]);
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
