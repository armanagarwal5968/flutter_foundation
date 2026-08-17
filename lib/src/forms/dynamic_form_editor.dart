import 'package:flutter/material.dart';

import 'dynamic_form_definition.dart';
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
        DynamicFormDefinition(
          id: widget.form.id,
          title: _title.text.trim(),
          description:
              _description.text.trim().isEmpty
                  ? null
                  : _description.text.trim(),
          submitLabel: _submitLabel.text.trim(),
          version: widget.form.version + 1,
          published: _published,
          catalogVisible: _catalogVisible,
          sections: _sections,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
    final options = TextEditingController(
      text: existing?.options.map((option) => option.label).join('\n'),
    );
    var type = existing?.type ?? DynamicFieldType.text;
    var required = existing?.required ?? false;
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
                        if (type == DynamicFieldType.singleChoice)
                          TextField(
                            controller: options,
                            minLines: 3,
                            maxLines: 6,
                            decoration: const InputDecoration(
                              labelText: 'Options (one per line)',
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
                              options:
                                  options.text
                                      .split('\n')
                                      .map((line) => line.trim())
                                      .where((line) => line.isNotEmpty)
                                      .map(
                                        (line) => DynamicFieldOption(
                                          value: line.toLowerCase().replaceAll(
                                            RegExp(r'[^a-z0-9]+'),
                                            '_',
                                          ),
                                          label: line,
                                        ),
                                      )
                                      .toList(),
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
    options.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit form'),
        actions: [
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
