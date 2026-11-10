enum DynamicFieldType {
  info,
  text,
  multiline,
  phone,
  number,
  date,
  yesNo,
  singleChoice,
  multiChoice,
  privacy,
  fileUpload,
  rating;

  static DynamicFieldType fromJson(Object? value) => values.firstWhere(
    (type) => type.name == value,
    orElse: () => DynamicFieldType.text,
  );
}

enum DynamicQuestionIndicator {
  none,
  numbered,
  bullet;

  static DynamicQuestionIndicator fromJson(Object? value) => values.firstWhere(
    (indicator) => indicator.name == value,
    orElse: () => DynamicQuestionIndicator.numbered,
  );
}

enum DynamicConditionOperator {
  equals,
  notEquals,
  contains;

  static DynamicConditionOperator fromJson(Object? value) => values.firstWhere(
    (operator) => operator.name == value,
    orElse: () => DynamicConditionOperator.equals,
  );
}

class DynamicFieldCondition {
  const DynamicFieldCondition({
    required this.fieldId,
    required this.value,
    this.operator = DynamicConditionOperator.equals,
  });

  final String fieldId;
  final Object? value;
  final DynamicConditionOperator operator;

  factory DynamicFieldCondition.fromJson(Map<String, dynamic> json) =>
      DynamicFieldCondition(
        fieldId: json['fieldId'] as String,
        value: json['value'],
        operator: DynamicConditionOperator.fromJson(json['operator']),
      );

  bool matches(Map<String, Object?> values) {
    final actual = values[fieldId];
    return switch (operator) {
      DynamicConditionOperator.equals => actual == value,
      DynamicConditionOperator.notEquals => actual != value,
      DynamicConditionOperator.contains =>
        actual is Iterable && actual.contains(value),
    };
  }

  Map<String, dynamic> toJson() => {
    'fieldId': fieldId,
    'operator': operator.name,
    'value': value,
  };
}

class DynamicFieldOption {
  const DynamicFieldOption({
    required this.value,
    required this.label,
    this.description,
    this.includeInSummary = false,
  });

  final String value;
  final String label;
  final String? description;
  final bool includeInSummary;

  factory DynamicFieldOption.fromJson(Map<String, dynamic> json) =>
      DynamicFieldOption(
        value: json['value'] as String,
        label: json['label'] as String,
        description: json['description'] as String?,
        includeInSummary: json['includeInSummary'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
    'value': value,
    'label': label,
    if (description != null) 'description': description,
    'includeInSummary': includeInSummary,
  };
}

class DynamicFormField {
  const DynamicFormField({
    required this.id,
    required this.label,
    required this.type,
    this.description,
    this.linkLabel,
    this.linkUrl,
    this.secondaryLinkLabel,
    this.secondaryLinkUrl,
    this.confirmationText,
    this.placeholder,
    this.required = false,
    this.options = const [],
    this.minimum,
    this.maximum,
    this.includeInSummary = false,
    this.visibleWhen,
    this.pageId,
  });

  final String id;
  final String label;
  final DynamicFieldType type;
  final String? description;
  final String? linkLabel;
  final String? linkUrl;
  final String? secondaryLinkLabel;
  final String? secondaryLinkUrl;
  final String? confirmationText;
  final String? placeholder;
  final bool required;
  final List<DynamicFieldOption> options;
  final num? minimum;
  final num? maximum;
  final bool includeInSummary;
  final DynamicFieldCondition? visibleWhen;

  /// Optional page override. The section page is used when this is null.
  final String? pageId;

  factory DynamicFormField.fromJson(Map<String, dynamic> json) =>
      DynamicFormField(
        id: json['id'] as String,
        label: json['label'] as String,
        type: DynamicFieldType.fromJson(json['type']),
        description: json['description'] as String?,
        linkLabel: json['linkLabel'] as String?,
        linkUrl: json['linkUrl'] as String?,
        secondaryLinkLabel: json['secondaryLinkLabel'] as String?,
        secondaryLinkUrl: json['secondaryLinkUrl'] as String?,
        confirmationText: json['confirmationText'] as String?,
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
        includeInSummary: json['includeInSummary'] as bool? ?? false,
        visibleWhen:
            json['visibleWhen'] is Map
                ? DynamicFieldCondition.fromJson(
                  Map<String, dynamic>.from(json['visibleWhen'] as Map),
                )
                : null,
        pageId: json['pageId'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'type': type.name,
    if (description != null) 'description': description,
    if (linkLabel != null) 'linkLabel': linkLabel,
    if (linkUrl != null) 'linkUrl': linkUrl,
    if (secondaryLinkLabel != null) 'secondaryLinkLabel': secondaryLinkLabel,
    if (secondaryLinkUrl != null) 'secondaryLinkUrl': secondaryLinkUrl,
    if (confirmationText != null) 'confirmationText': confirmationText,
    if (placeholder != null) 'placeholder': placeholder,
    'required': required,
    if (options.isNotEmpty)
      'options': options.map((option) => option.toJson()).toList(),
    if (minimum != null) 'minimum': minimum,
    if (maximum != null) 'maximum': maximum,
    'includeInSummary': includeInSummary,
    if (visibleWhen != null) 'visibleWhen': visibleWhen!.toJson(),
    if (pageId != null) 'pageId': pageId,
  };
}

class DynamicFormPage {
  const DynamicFormPage({
    required this.id,
    required this.title,
    this.description,
  });

  final String id;
  final String title;
  final String? description;

  factory DynamicFormPage.fromJson(Map<String, dynamic> json) =>
      DynamicFormPage(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (description != null) 'description': description,
  };
}

class DynamicFormSection {
  const DynamicFormSection({
    required this.id,
    required this.title,
    required this.fields,
    this.description,
    this.pageId,
  });

  final String id;
  final String title;
  final String? description;
  final List<DynamicFormField> fields;

  /// Default page for all fields in this section.
  final String? pageId;

  factory DynamicFormSection.fromJson(Map<String, dynamic> json) =>
      DynamicFormSection(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        pageId: json['pageId'] as String?,
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
    if (pageId != null) 'pageId': pageId,
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
    this.confirmBeforeSubmit = false,
    this.enforceRequiredFields = false,
    this.questionIndicator = DynamicQuestionIndicator.numbered,
    this.pages = const [],
  });

  final String id;
  final String title;
  final String? description;
  final String submitLabel;
  final int version;
  final bool published;
  final bool catalogVisible;
  final bool confirmBeforeSubmit;
  final bool enforceRequiredFields;
  final DynamicQuestionIndicator questionIndicator;
  final List<DynamicFormSection> sections;

  /// Optional page layout. Empty keeps the legacy one-section-per-step flow.
  final List<DynamicFormPage> pages;

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
    confirmBeforeSubmit: json['confirmBeforeSubmit'] as bool? ?? false,
    enforceRequiredFields: json['enforceRequiredFields'] as bool? ?? false,
    questionIndicator: DynamicQuestionIndicator.fromJson(
      json['questionIndicator'],
    ),
    pages: (json['pages'] as List<dynamic>? ?? const [])
        .map(
          (page) =>
              DynamicFormPage.fromJson(Map<String, dynamic>.from(page as Map)),
        )
        .toList(growable: false),
    sections: (json['sections'] as List<dynamic>? ?? const [])
        .map(
          (section) => DynamicFormSection.fromJson(
            Map<String, dynamic>.from(section as Map),
          ),
        )
        .toList(growable: false),
  );

  Map<String, dynamic> toJson() => {
    // Lets Firestore distinguish page-aware editors from legacy clients while
    // keeping the legacy sections/questions payload intact.
    'layoutVersion': 2,
    'title': title,
    if (description != null) 'description': description,
    'submitLabel': submitLabel,
    'version': version,
    'published': published,
    'catalogVisible': catalogVisible,
    'confirmBeforeSubmit': confirmBeforeSubmit,
    'enforceRequiredFields': enforceRequiredFields,
    'questionIndicator': questionIndicator.name,
    if (pages.isNotEmpty) 'pages': pages.map((page) => page.toJson()).toList(),
    'sections': sections.map((section) => section.toJson()).toList(),
  };
}
