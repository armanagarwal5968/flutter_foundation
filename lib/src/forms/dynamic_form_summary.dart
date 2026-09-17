import 'dynamic_form_definition.dart';
import '../formatting/friendly_date.dart';

/// Builds the summary configured by form and option metadata.
List<String> buildDynamicFormSummary(
  DynamicFormDefinition definition,
  Map<String, Object?> values,
) {
  final summary = <String>[];
  for (final section in definition.sections) {
    for (final field in section.fields) {
      final value = values[field.id];
      if (value == null ||
          value == '' ||
          (value is Iterable && value.isEmpty)) {
        continue;
      }
      switch (field.type) {
        case DynamicFieldType.singleChoice:
          final option = field.options.where(
            (candidate) =>
                candidate.value == value && candidate.includeInSummary,
          );
          if (option.isNotEmpty) {
            summary.add('${field.label}: ${option.first.label}');
          }
        case DynamicFieldType.multiChoice:
          final selected = (value as Iterable).whereType<String>().toSet();
          final labels = field.options
              .where(
                (option) =>
                    selected.contains(option.value) && option.includeInSummary,
              )
              .map((option) => option.label)
              .toList(growable: false);
          if (labels.isNotEmpty) {
            summary.add('${field.label}: ${labels.join(', ')}');
          }
        case DynamicFieldType.yesNo:
          if (field.includeInSummary && value == true) {
            summary.add('${field.label}: Yes');
          }
        case DynamicFieldType.info:
          break;
        case DynamicFieldType.text:
        case DynamicFieldType.multiline:
        case DynamicFieldType.phone:
        case DynamicFieldType.number:
        case DynamicFieldType.rating:
          if (field.includeInSummary) {
            summary.add('${field.label}: $value');
          }
        case DynamicFieldType.date:
          if (field.includeInSummary) {
            summary.add('${field.label}: ${formatFriendlyDateValue(value)}');
          }
      }
    }
  }
  return List.unmodifiable(summary);
}
