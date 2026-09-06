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

  testWidgets('multi-choice requires and submits selected options', (
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
    await tester.pump();
    expect(find.text('Support topics is required.'), findsOneWidget);

    await tester.tap(find.text('Nutrition'));
    await tester.tap(find.text('Exercise'));
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(submitted, {
      'support_topics': ['nutrition', 'exercise'],
    });
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
}
