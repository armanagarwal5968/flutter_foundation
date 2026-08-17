enum DynamicFieldType {
  info,
  text,
  multiline,
  phone,
  number,
  date,
  yesNo,
  singleChoice,
  rating;

  static DynamicFieldType fromJson(Object? value) => values.firstWhere(
    (type) => type.name == value,
    orElse: () => DynamicFieldType.text,
  );
}

class DynamicFieldOption {
  const DynamicFieldOption({
    required this.value,
    required this.label,
    this.description,
  });

  final String value;
  final String label;
  final String? description;

  factory DynamicFieldOption.fromJson(Map<String, dynamic> json) =>
      DynamicFieldOption(
        value: json['value'] as String,
        label: json['label'] as String,
        description: json['description'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'value': value,
    'label': label,
    if (description != null) 'description': description,
  };
}

class DynamicFormField {
  const DynamicFormField({
    required this.id,
    required this.label,
    required this.type,
    this.description,
    this.placeholder,
    this.required = false,
    this.options = const [],
    this.minimum,
    this.maximum,
  });

  final String id;
  final String label;
  final DynamicFieldType type;
  final String? description;
  final String? placeholder;
  final bool required;
  final List<DynamicFieldOption> options;
  final num? minimum;
  final num? maximum;

  factory DynamicFormField.fromJson(Map<String, dynamic> json) =>
      DynamicFormField(
        id: json['id'] as String,
        label: json['label'] as String,
        type: DynamicFieldType.fromJson(json['type']),
        description: json['description'] as String?,
        placeholder: json['placeholder'] as String?,
        required: json['required'] as bool? ?? false,
        options: (json['options'] as List<dynamic>? ?? const [])
            .map(
              (option) => DynamicFieldOption.fromJson(
                Map<String, dynamic>.from(option as Map),
              ),
            )
            .toList(growable: false),
        minimum: json['minimum'] as num?,
        maximum: json['maximum'] as num?,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'type': type.name,
    if (description != null) 'description': description,
    if (placeholder != null) 'placeholder': placeholder,
    'required': required,
    if (options.isNotEmpty)
      'options': options.map((option) => option.toJson()).toList(),
    if (minimum != null) 'minimum': minimum,
    if (maximum != null) 'maximum': maximum,
  };
}

class DynamicFormSection {
  const DynamicFormSection({
    required this.id,
    required this.title,
    required this.fields,
    this.description,
  });

  final String id;
  final String title;
  final String? description;
  final List<DynamicFormField> fields;

  factory DynamicFormSection.fromJson(Map<String, dynamic> json) =>
      DynamicFormSection(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        fields: (json['fields'] as List<dynamic>? ?? const [])
            .map(
              (field) => DynamicFormField.fromJson(
                Map<String, dynamic>.from(field as Map),
              ),
            )
            .toList(growable: false),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (description != null) 'description': description,
    'fields': fields.map((field) => field.toJson()).toList(),
  };
}

class DynamicFormDefinition {
  const DynamicFormDefinition({
    required this.id,
    required this.title,
    required this.sections,
    this.description,
    this.submitLabel = 'Submit',
    this.version = 1,
    this.published = true,
    this.catalogVisible = true,
  });

  final String id;
  final String title;
  final String? description;
  final String submitLabel;
  final int version;
  final bool published;
  final bool catalogVisible;
  final List<DynamicFormSection> sections;

  factory DynamicFormDefinition.fromJson(
    String id,
    Map<String, dynamic> json,
  ) => DynamicFormDefinition(
    id: id,
    title: json['title'] as String,
    description: json['description'] as String?,
    submitLabel: json['submitLabel'] as String? ?? 'Submit',
    version: json['version'] as int? ?? 1,
    published: json['published'] as bool? ?? false,
    catalogVisible: json['catalogVisible'] as bool? ?? true,
    sections: (json['sections'] as List<dynamic>? ?? const [])
        .map(
          (section) => DynamicFormSection.fromJson(
            Map<String, dynamic>.from(section as Map),
          ),
        )
        .toList(growable: false),
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    if (description != null) 'description': description,
    'submitLabel': submitLabel,
    'version': version,
    'published': published,
    'catalogVisible': catalogVisible,
    'sections': sections.map((section) => section.toJson()).toList(),
  };
}
