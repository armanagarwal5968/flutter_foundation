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
  late List<DynamicFormPage> _pages;
  late List<DynamicFormSection> _sections;
  late bool _published;
  late bool _catalogVisible;
  late bool _confirmBeforeSubmit;
  late bool _enforceRequiredFields;
  late DynamicQuestionIndicator _questionIndicator;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.form.title);
    _description = TextEditingController(text: widget.form.description);
    _submitLabel = TextEditingController(text: widget.form.submitLabel);
    if (widget.form.pages.isEmpty) {
      _pages = [
        for (final section in widget.form.sections)
          DynamicFormPage(
            id: 'page_${section.id}',
            title: section.title,
            description: section.description,
          ),
      ];
      _sections = [
        for (final section in widget.form.sections)
          DynamicFormSection(
            id: section.id,
            title: section.title,
            description: section.description,
            pageId: 'page_${section.id}',
            fields: section.fields,
          ),
      ];
    } else {
      _pages = List.of(widget.form.pages);
      _sections = List.of(widget.form.sections);
    }
    _published = widget.form.published;
    _catalogVisible = widget.form.catalogVisible;
    _confirmBeforeSubmit = widget.form.confirmBeforeSubmit;
    _enforceRequiredFields = widget.form.enforceRequiredFields;
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
        enforceRequiredFields: _enforceRequiredFields,
        questionIndicator: _questionIndicator,
        pages: _pages,
        sections: _sections,
      );

  Future<void> _addPage() async {
    final page = await _pageDialog();
    if (page != null) setState(() => _pages.add(page));
  }

  Future<void> _editPage(int pageIndex) async {
    final page = await _pageDialog(_pages[pageIndex]);
    if (page != null) setState(() => _pages[pageIndex] = page);
  }

  void _movePage(int pageIndex, int offset) {
    final destination = pageIndex + offset;
    if (destination < 0 || destination >= _pages.length) return;
    setState(() {
      final page = _pages.removeAt(pageIndex);
      _pages.insert(destination, page);
    });
  }

  void _deletePage(int pageIndex) {
    if (_pages.length <= 1) return;
    final pageId = _pages[pageIndex].id;
    final destinationId = _pages.firstWhere((page) => page.id != pageId).id;
    setState(() {
      _pages.removeAt(pageIndex);
      _sections = [
        for (final section in _sections)
          DynamicFormSection(
            id: section.id,
            title: section.title,
            description: section.description,
            pageId: section.pageId == pageId ? destinationId : section.pageId,
            fields: [
              for (final field in section.fields)
                _copyField(
                  field,
                  pageId: field.pageId == pageId ? destinationId : field.pageId,
                ),
            ],
          ),
      ];
    });
  }

  Future<DynamicFormPage?> _pageDialog([DynamicFormPage? existing]) async {
    final title = TextEditingController(text: existing?.title);
    final description = TextEditingController(text: existing?.description);
    final result = await showDialog<DynamicFormPage>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(existing == null ? 'Add page' : 'Edit page'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Page title'),
                ),
                TextField(
                  controller: description,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (title.text.trim().isEmpty) return;
                  Navigator.pop(
                    context,
                    DynamicFormPage(
                      id:
                          existing?.id ??
                          'page_${DateTime.now().microsecondsSinceEpoch}',
                      title: title.text.trim(),
                      description:
                          description.text.trim().isEmpty
                              ? null
                              : description.text.trim(),
                    ),
                  );
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
    title.dispose();
    description.dispose();
    return result;
  }

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

  Future<void> _addSection(String pageId) async {
    final section = await _sectionDialog(initialPageId: pageId);
    if (section != null) setState(() => _sections.add(section));
  }

  Future<void> _editSection(int sectionIndex) async {
    final section = await _sectionDialog(existing: _sections[sectionIndex]);
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
            pageId: section.pageId,
            fields: fields,
          ),
    );
  }

  Future<DynamicFormSection?> _sectionDialog({
    DynamicFormSection? existing,
    String? initialPageId,
  }) async {
    final title = TextEditingController(text: existing?.title);
    final description = TextEditingController(text: existing?.description);
    var pageId = existing == null ? initialPageId : existing.pageId;
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
                if (_pages.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: pageId ?? '__unassigned__',
                    decoration: const InputDecoration(labelText: 'Page'),
                    items: [
                      const DropdownMenuItem(
                        value: '__unassigned__',
                        child: Text('Unassigned (legacy page)'),
                      ),
                      for (final page in _pages)
                        DropdownMenuItem(
                          value: page.id,
                          child: Text(page.title),
                        ),
                    ],
                    onChanged:
                        (value) =>
                            pageId = value == '__unassigned__' ? null : value,
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
                        pageId: pageId,
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

  Future<DynamicFormField?> _fieldDialog({
    DynamicFormField? existing,
    String? initialPageId,
  }) async {
    final label = TextEditingController(text: existing?.label);
    final description = TextEditingController(text: existing?.description);
    final linkLabel = TextEditingController(text: existing?.linkLabel);
    final linkUrl = TextEditingController(text: existing?.linkUrl);
    final secondaryLinkLabel = TextEditingController(
      text: existing?.secondaryLinkLabel,
    );
    final secondaryLinkUrl = TextEditingController(
      text: existing?.secondaryLinkUrl,
    );
    final confirmationText = TextEditingController(
      text: existing?.confirmationText,
    );
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
    var pageId = existing == null ? initialPageId : existing.pageId;
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
                        if (_pages.isNotEmpty)
                          DropdownButtonFormField<String>(
                            value: pageId ?? '__section__',
                            decoration: const InputDecoration(
                              labelText: 'Page placement',
                              helperText:
                                  'Choose another page to split this section.',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: '__section__',
                                child: Text('Use section page'),
                              ),
                              for (final page in _pages)
                                DropdownMenuItem(
                                  value: page.id,
                                  child: Text(page.title),
                                ),
                            ],
                            onChanged:
                                (value) => setDialogState(
                                  () =>
                                      pageId =
                                          value == '__section__' ? null : value,
                                ),
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
                        if (type == DynamicFieldType.info ||
                            type == DynamicFieldType.privacy) ...[
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
                        if (type == DynamicFieldType.privacy) ...[
                          TextField(
                            controller: secondaryLinkLabel,
                            decoration: const InputDecoration(
                              labelText: 'Second link label',
                            ),
                          ),
                          TextField(
                            controller: secondaryLinkUrl,
                            keyboardType: TextInputType.url,
                            decoration: const InputDecoration(
                              labelText: 'Second link URL',
                            ),
                          ),
                          TextField(
                            controller: confirmationText,
                            decoration: const InputDecoration(
                              labelText: 'Confirmation text',
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
                                  (type != DynamicFieldType.info &&
                                              type !=
                                                  DynamicFieldType.privacy) ||
                                          linkLabel.text.trim().isEmpty
                                      ? null
                                      : linkLabel.text.trim(),
                              linkUrl:
                                  (type != DynamicFieldType.info &&
                                              type !=
                                                  DynamicFieldType.privacy) ||
                                          linkUrl.text.trim().isEmpty
                                      ? null
                                      : linkUrl.text.trim(),
                              secondaryLinkLabel:
                                  type != DynamicFieldType.privacy ||
                                          secondaryLinkLabel.text.trim().isEmpty
                                      ? null
                                      : secondaryLinkLabel.text.trim(),
                              secondaryLinkUrl:
                                  type != DynamicFieldType.privacy ||
                                          secondaryLinkUrl.text.trim().isEmpty
                                      ? null
                                      : secondaryLinkUrl.text.trim(),
                              confirmationText:
                                  type != DynamicFieldType.privacy ||
                                          confirmationText.text.trim().isEmpty
                                      ? null
                                      : confirmationText.text.trim(),
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
                              pageId: pageId,
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
    secondaryLinkLabel.dispose();
    secondaryLinkUrl.dispose();
    confirmationText.dispose();
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

  DynamicFormField _copyField(
    DynamicFormField field, {
    required String? pageId,
  }) => DynamicFormField(
    id: field.id,
    label: field.label,
    type: field.type,
    description: field.description,
    linkLabel: field.linkLabel,
    linkUrl: field.linkUrl,
    secondaryLinkLabel: field.secondaryLinkLabel,
    secondaryLinkUrl: field.secondaryLinkUrl,
    confirmationText: field.confirmationText,
    placeholder: field.placeholder,
    required: field.required,
    options: field.options,
    minimum: field.minimum,
    maximum: field.maximum,
    includeInSummary: field.includeInSummary,
    visibleWhen: field.visibleWhen,
    pageId: pageId,
  );

  Widget _sectionCardForPage({
    required DynamicFormPage page,
    required int sectionIndex,
  }) {
    final section = _sections[sectionIndex];
    final fieldIndexes = <int>[
      for (var index = 0; index < section.fields.length; index++)
        if ((section.fields[index].pageId ?? section.pageId) == page.id) index,
    ];
    final isDefaultPage = section.pageId == page.id;
    if (!isDefaultPage && fieldIndexes.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: ExpansionTile(
        title: Text(section.title),
        subtitle: Text(
          '${fieldIndexes.length} question${fieldIndexes.length == 1 ? '' : 's'}'
          '${isDefaultPage ? '' : ' • split from another page'}',
        ),
        trailing: PopupMenuButton<_EditorItemAction>(
          key: ValueKey(
            isDefaultPage
                ? 'section-menu-${section.id}'
                : 'section-menu-${section.id}-${page.id}',
          ),
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
                  child: Text('Edit or move section'),
                ),
                const PopupMenuItem(
                  value: _EditorItemAction.delete,
                  child: Text('Delete section'),
                ),
              ],
        ),
        children: [
          for (final fieldIndex in fieldIndexes)
            ListTile(
              title: Text(section.fields[fieldIndex].label),
              subtitle: Text(
                '${section.fields[fieldIndex].type.name}'
                '${section.fields[fieldIndex].visibleWhen == null ? '' : ' • conditional'}'
                '${section.fields[fieldIndex].pageId == null ? '' : ' • page override'}',
              ),
              onTap: () async {
                final updated = await _fieldDialog(
                  existing: section.fields[fieldIndex],
                );
                if (updated == null) return;
                final fields = List<DynamicFormField>.of(section.fields)
                  ..[fieldIndex] = updated;
                _replaceSectionFields(sectionIndex, fields);
              },
              trailing: PopupMenuButton<_EditorItemAction>(
                key: ValueKey(
                  'field-menu-${section.id}-${section.fields[fieldIndex].id}',
                ),
                tooltip: 'Question actions',
                onSelected: (action) async {
                  switch (action) {
                    case _EditorItemAction.moveUp:
                      _moveField(sectionIndex, fieldIndex, -1);
                    case _EditorItemAction.moveDown:
                      _moveField(sectionIndex, fieldIndex, 1);
                    case _EditorItemAction.edit:
                      final updated = await _fieldDialog(
                        existing: section.fields[fieldIndex],
                      );
                      if (updated == null) return;
                      final fields = List<DynamicFormField>.of(section.fields)
                        ..[fieldIndex] = updated;
                      _replaceSectionFields(sectionIndex, fields);
                    case _EditorItemAction.delete:
                      final fields = List<DynamicFormField>.of(section.fields)
                        ..removeAt(fieldIndex);
                      _replaceSectionFields(sectionIndex, fields);
                  }
                },
                itemBuilder:
                    (context) => [
                      PopupMenuItem(
                        value: _EditorItemAction.moveUp,
                        enabled: fieldIndex > 0,
                        child: const Text('Move question up'),
                      ),
                      PopupMenuItem(
                        value: _EditorItemAction.moveDown,
                        enabled: fieldIndex < section.fields.length - 1,
                        child: const Text('Move question down'),
                      ),
                      const PopupMenuItem(
                        value: _EditorItemAction.edit,
                        child: Text('Edit or move question'),
                      ),
                      const PopupMenuItem(
                        value: _EditorItemAction.delete,
                        child: Text('Delete question'),
                      ),
                    ],
              ),
            ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Add question to this section'),
            onTap: () async {
              final field = await _fieldDialog(
                initialPageId: isDefaultPage ? null : page.id,
              );
              if (field == null) return;
              _replaceSectionFields(sectionIndex, [...section.fields, field]);
            },
          ),
        ],
      ),
    );
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
        cacheExtent: 1200,
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
          SwitchListTile(
            key: const Key('enforce-required-fields-switch'),
            contentPadding: EdgeInsets.zero,
            value: _enforceRequiredFields,
            onChanged:
                (value) => setState(() => _enforceRequiredFields = value),
            title: const Text('Enforce required fields'),
            subtitle: const Text(
              'Prevent continuing or submitting until visible required questions are answered.',
            ),
          ),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Pages',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _addPage,
                icon: const Icon(Icons.add),
                label: const Text('Add page'),
              ),
            ],
          ),
          if (_pages.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No pages configured. The form uses one section per step for compatibility.',
              ),
            ),
          for (var pageIndex = 0; pageIndex < _pages.length; pageIndex++)
            Card(
              child: ExpansionTile(
                key: ValueKey('page-${_pages[pageIndex].id}'),
                initiallyExpanded: pageIndex == 0,
                leading: CircleAvatar(child: Text('${pageIndex + 1}')),
                title: Text(_pages[pageIndex].title),
                subtitle: Text(
                  _pages[pageIndex].description ??
                      '${_sections.where((section) => section.pageId == _pages[pageIndex].id || section.fields.any((field) => field.pageId == _pages[pageIndex].id)).length} section(s)',
                ),
                trailing: PopupMenuButton<_EditorItemAction>(
                  tooltip: 'Page actions',
                  onSelected: (action) {
                    switch (action) {
                      case _EditorItemAction.moveUp:
                        _movePage(pageIndex, -1);
                      case _EditorItemAction.moveDown:
                        _movePage(pageIndex, 1);
                      case _EditorItemAction.edit:
                        _editPage(pageIndex);
                      case _EditorItemAction.delete:
                        _deletePage(pageIndex);
                    }
                  },
                  itemBuilder:
                      (context) => [
                        PopupMenuItem(
                          value: _EditorItemAction.moveUp,
                          enabled: pageIndex > 0,
                          child: const Text('Move page up'),
                        ),
                        PopupMenuItem(
                          value: _EditorItemAction.moveDown,
                          enabled: pageIndex < _pages.length - 1,
                          child: const Text('Move page down'),
                        ),
                        const PopupMenuItem(
                          value: _EditorItemAction.edit,
                          child: Text('Edit page'),
                        ),
                        const PopupMenuItem(
                          value: _EditorItemAction.delete,
                          child: Text('Delete and merge into another page'),
                        ),
                      ],
                ),
                children: [
                  for (
                    var sectionIndex = 0;
                    sectionIndex < _sections.length;
                    sectionIndex++
                  )
                    _sectionCardForPage(
                      page: _pages[pageIndex],
                      sectionIndex: sectionIndex,
                    ),
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('Add section to this page'),
                    onTap: () => _addSection(_pages[pageIndex].id),
                  ),
                ],
              ),
            ),
          if (_pages.isEmpty) ...[
            const Divider(),
            Text('Sections', style: Theme.of(context).textTheme.titleLarge),
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
                            existing:
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
                                  pageId: _sections[sectionIndex].pageId,
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
                                  existing:
                                      _sections[sectionIndex]
                                          .fields[fieldIndex],
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
              onPressed: null,
              icon: const Icon(Icons.add),
              label: const Text('Add section'),
            ),
          ],
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
