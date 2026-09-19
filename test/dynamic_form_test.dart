import 'package:alramwarnaga_foundation/alramwarnaga_foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const definition = DynamicFormDefinition(
    id: 'test_form',
    title: 'Test form',
    sections: [
      DynamicFormSection(
        id: 'profile',
        title: 'Profile',
        fields: [
          DynamicFormField(
            id: 'name',
            label: 'Name',
            type: DynamicFieldType.text,
            required: true,
          ),
        ],
      ),
      DynamicFormSection(
        id: 'history',
        title: 'History',
        fields: [
          DynamicFormField(
            id: 'first_pregnancy',
            label: 'First pregnancy?',
            type: DynamicFieldType.yesNo,
            required: true,
          ),
        ],
      ),
    ],
  );

  test('form definition round-trips through Firestore JSON', () {
    final parsed = DynamicFormDefinition.fromJson(
      definition.id,
      definition.toJson(),
    );

    expect(parsed.title, definition.title);
    expect(parsed.sections.length, 2);
    expect(parsed.sections.last.fields.single.type, DynamicFieldType.yesNo);
  });

  testWidgets('info fields expose a privacy-policy link', (tester) async {
    const linkedDefinition = DynamicFormDefinition(
      id: 'linked_info',
      title: 'Consent',
      sections: [
        DynamicFormSection(
          id: 'notice',
          title: 'Notice',
          fields: [
            DynamicFormField(
              id: 'privacy',
              label: 'Privacy notice',
              type: DynamicFieldType.info,
              linkLabel: 'Read the privacy policy',
              linkUrl: 'https://example.com/privacy',
            ),
          ],
        ),
      ],
    );

    final parsed = DynamicFormDefinition.fromJson(
      linkedDefinition.id,
      linkedDefinition.toJson(),
    );
    expect(
      parsed.sections.single.fields.single.linkUrl,
      'https://example.com/privacy',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DynamicFormView(
            definition: linkedDefinition,
            onSubmit: (_) async {},
          ),
        ),
      ),
    );

    expect(find.text('Read the privacy policy'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('dynamic-form-link-privacy')),
      findsOneWidget,
    );
  });

  test('summary includes marked choices and only Yes red flags', () {
    const summaryDefinition = DynamicFormDefinition(
      id: 'summary',
      title: 'Summary',
      confirmBeforeSubmit: true,
      sections: [
        DynamicFormSection(
          id: 'review',
          title: 'Review',
          fields: [
            DynamicFormField(
              id: 'outcome',
              label: 'Outcome',
              type: DynamicFieldType.singleChoice,
              options: [
                DynamicFieldOption(value: 'normal', label: 'Normal'),
                DynamicFieldOption(
                  value: 'concern',
                  label: 'Concern',
                  includeInSummary: true,
                ),
              ],
            ),
            DynamicFormField(
              id: 'fever',
              label: 'Fever',
              type: DynamicFieldType.yesNo,
              includeInSummary: true,
            ),
            DynamicFormField(
              id: 'jaundice',
              label: 'Jaundice',
              type: DynamicFieldType.yesNo,
              includeInSummary: true,
            ),
          ],
        ),
      ],
    );

    expect(
      buildDynamicFormSummary(summaryDefinition, {
        'outcome': 'concern',
        'fever': true,
        'jaundice': false,
      }),
      ['Outcome: Concern', 'Fever: Yes'],
    );
    final parsed = DynamicFormDefinition.fromJson(
      summaryDefinition.id,
      summaryDefinition.toJson(),
    );
    expect(parsed.confirmBeforeSubmit, isTrue);
    expect(
      parsed.sections.single.fields.first.options.last.includeInSummary,
      isTrue,
    );
  });

  testWidgets('multi-step form accepts No and submits values', (tester) async {
    Map<String, Object?>? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DynamicFormView(
            definition: definition,
            onSubmit: (values) async => submitted = values,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField), 'Mother');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No'));
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(submitted, {'name': 'Mother', 'first_pregnancy': false});
  });

  testWidgets('required metadata does not block an empty submission', (
    tester,
  ) async {
    Map<String, Object?>? submitted;
    const multiChoiceDefinition = DynamicFormDefinition(
      id: 'preferences',
      title: 'Preferences',
      sections: [
        DynamicFormSection(
          id: 'topics',
          title: 'Topics',
          fields: [
            DynamicFormField(
              id: 'support_topics',
              label: 'Support topics',
              type: DynamicFieldType.multiChoice,
              required: true,
              options: [
                DynamicFieldOption(value: 'nutrition', label: 'Nutrition'),
                DynamicFieldOption(value: 'exercise', label: 'Exercise'),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DynamicFormView(
            definition: multiChoiceDefinition,
            onSubmit: (values) async => submitted = values,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(submitted, isEmpty);
    expect(find.textContaining('*'), findsNothing);
  });

  testWidgets('single choice with more than ten options uses a dropdown', (
    tester,
  ) async {
    Map<String, Object?>? submitted;
    final manyOptions = List.generate(
      11,
      (index) => DynamicFieldOption(
        value: 'option_${index + 1}',
        label: 'Option ${index + 1}',
      ),
    );
    final dropdownDefinition = DynamicFormDefinition(
      id: 'many_options',
      title: 'Many options',
      sections: [
        DynamicFormSection(
          id: 'choice',
          title: 'Choice',
          fields: [
            DynamicFormField(
              id: 'large_choice',
              label: 'Large choice',
              type: DynamicFieldType.singleChoice,
              required: true,
              options: manyOptions,
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DynamicFormView(
            definition: dropdownDefinition,
            onSubmit: (values) async => submitted = values,
          ),
        ),
      ),
    );

    final dropdown = find.byKey(
      const ValueKey('single-choice-dropdown-large_choice'),
    );
    expect(dropdown, findsOneWidget);
    expect(find.byType(RadioListTile<String>), findsNothing);

    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Option 5').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(submitted, {'large_choice': 'option_5'});
  });

  testWidgets('single choice with ten options keeps radio buttons', (
    tester,
  ) async {
    final radioDefinition = DynamicFormDefinition(
      id: 'ten_options',
      title: 'Ten options',
      sections: [
        DynamicFormSection(
          id: 'choice',
          title: 'Choice',
          fields: [
            DynamicFormField(
              id: 'short_choice',
              label: 'Short choice',
              type: DynamicFieldType.singleChoice,
              options: List.generate(
                10,
                (index) => DynamicFieldOption(
                  value: 'option_${index + 1}',
                  label: 'Option ${index + 1}',
                ),
              ),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DynamicFormView(
            definition: radioDefinition,
            onSubmit: (_) async {},
          ),
        ),
      ),
    );

    expect(find.byType(RadioListTile<String>), findsNWidgets(10));
    expect(
      find.byKey(const ValueKey('single-choice-dropdown-short_choice')),
      findsNothing,
    );
  });

  testWidgets('preview identifies itself and does not save a response', (
    tester,
  ) async {
    const previewDefinition = DynamicFormDefinition(
      id: 'preview',
      title: 'Preview form',
      sections: [
        DynamicFormSection(id: 'empty', title: 'Preview step', fields: []),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: DynamicFormPreviewPage(definition: previewDefinition),
      ),
    );

    expect(
      find.text('Preview mode — responses are not saved.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Submit'));
    await tester.pump();
    expect(find.text('Preview completed. Nothing was saved.'), findsOneWidget);
  });

  testWidgets('review page blocks submission until final confirmation', (
    tester,
  ) async {
    Map<String, Object?>? submitted;
    const reviewDefinition = DynamicFormDefinition(
      id: 'review',
      title: 'Review form',
      confirmBeforeSubmit: true,
      sections: [
        DynamicFormSection(
          id: 'answer',
          title: 'Answer',
          fields: [
            DynamicFormField(
              id: 'notes',
              label: 'Notes',
              type: DynamicFieldType.text,
              required: true,
              includeInSummary: true,
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DynamicFormView(
            definition: reviewDefinition,
            onSubmit: (values) async => submitted = values,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), 'Looks good');
    await tester.tap(find.text('Review answers'));
    await tester.pumpAndSettle();

    expect(submitted, isNull);
    expect(find.text('• Notes: Looks good'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-form-submit')));
    await tester.pumpAndSettle();
    expect(submitted, {'notes': 'Looks good'});
  });

  testWidgets('file upload stores response-safe metadata', (tester) async {
    Map<String, Object?>? submitted;
    const definition = DynamicFormDefinition(
      id: 'enrolment',
      title: 'Enrollment',
      sections: [
        DynamicFormSection(
          id: 'reports',
          title: 'Reports',
          fields: [
            DynamicFormField(
              id: 'latest_reports',
              label: 'Latest reports',
              type: DynamicFieldType.fileUpload,
              options: [
                DynamicFieldOption(value: 'cbc_report', label: 'CBC report'),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DynamicFormView(
            definition: definition,
            fileUploader:
                ({required formId, required fieldId, category}) async => {
                  'storagePath': 'form_uploads/user/$formId/$fieldId/file.pdf',
                  'fileName': 'file.pdf',
                  'category': category,
                },
            onSubmit: (values) async => submitted = values,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Upload CBC report'));
    await tester.pumpAndSettle();
    expect(find.text('file.pdf'), findsOneWidget);
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    final uploads = submitted!['latest_reports']! as List<Object?>;
    final upload = Map<String, Object?>.from(uploads.single! as Map);
    expect(upload['category'], 'CBC report');
    expect(upload['fileName'], 'file.pdf');
  });
}
