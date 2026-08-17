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
}
