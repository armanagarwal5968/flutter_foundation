import 'package:alramwarnaga_foundation/alramwarnaga_foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryDraftStore implements DynamicFormDraftStore {
  final drafts = <String, DynamicFormDraft>{};
  var saves = 0;
  var deletes = 0;

  @override
  Future<DynamicFormDraft?> load(DynamicFormDraftKey key) async =>
      drafts[key.documentId];

  @override
  Future<void> save(DynamicFormDraftKey key, DynamicFormDraft draft) async {
    saves++;
    drafts[key.documentId] = draft;
  }

  @override
  Future<void> delete(DynamicFormDraftKey key) async {
    deletes++;
    drafts.remove(key.documentId);
  }
}

void main() {
  const definition = DynamicFormDefinition(
    id: 'session_completion',
    title: 'Session checklist',
    sections: [
      DynamicFormSection(
        id: 'profile',
        title: 'Profile',
        fields: [
          DynamicFormField(
            id: 'name',
            label: 'Name',
            type: DynamicFieldType.text,
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
          ),
        ],
      ),
    ],
  );
  const key = DynamicFormDraftKey(
    ownerId: 'expert-1',
    formId: 'session_completion',
    patientId: 'patient-1',
    sessionId: 'home_visit_1',
  );
  const delay = Duration(milliseconds: 100);

  Widget app(
    _MemoryDraftStore store, {
    Future<void> Function(Map<String, Object?>)? onSubmit,
  }) => MaterialApp(
    home: Scaffold(
      body: DraftableDynamicFormView(
        definition: definition,
        draftKey: key,
        draftStore: store,
        saveDelay: delay,
        onSubmit: onSubmit ?? (_) async {},
      ),
    ),
  );

  test('draft IDs start with the owner and are safe document IDs', () {
    expect(
      key.documentId,
      'expert-1__session_completion__patient-1__home_visit_1',
    );
    expect(
      const DynamicFormDraftKey(ownerId: 'u1', formId: 'a/b').documentId,
      'u1__a_b__-__-',
    );
  });

  test('restored values keep only questions in the current form', () {
    expect(
      draftValuesForDefinition(definition, {
        'name': 'Asha',
        'removed_question': 'x',
        'first_pregnancy_other_details': 'kept',
      }),
      {'name': 'Asha', 'first_pregnancy_other_details': 'kept'},
    );
  });

  testWidgets('saves typed answers and the page after a pause', (tester) async {
    final store = _MemoryDraftStore();
    await tester.pumpWidget(app(store));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'Asha');
    await tester.pump(delay * 2);
    expect(store.drafts[key.documentId]?.values, {'name': 'Asha'});
    expect(store.drafts[key.documentId]?.pageIndex, 0);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No'));
    await tester.pump(delay * 2);
    final draft = store.drafts[key.documentId]!;
    expect(draft.values, {'name': 'Asha', 'first_pregnancy': false});
    expect(draft.pageIndex, 1);
    expect(find.textContaining('Draft saved'), findsOneWidget);
  });

  testWidgets('reopening restores answers on the saved page', (tester) async {
    final store =
        _MemoryDraftStore()
          ..drafts[key.documentId] = const DynamicFormDraft(
            values: {'name': 'Asha', 'first_pregnancy': true},
            pageIndex: 1,
            formVersion: 1,
          );
    Map<String, Object?>? submitted;
    await tester.pumpWidget(
      app(store, onSubmit: (values) async => submitted = values),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Continuing your saved draft'), findsOneWidget);
    expect(find.text('First pregnancy?', findRichText: true), findsWidgets);
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(submitted, {'name': 'Asha', 'first_pregnancy': true});
    expect(store.drafts, isEmpty);
  });

  testWidgets('submitting deletes the draft and stops saving', (tester) async {
    final store = _MemoryDraftStore();
    await tester.pumpWidget(app(store));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Asha');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes'));
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    await tester.pump(delay * 2);

    expect(store.drafts, isEmpty);
    expect(store.deletes, greaterThanOrEqualTo(1));
  });

  testWidgets('a failed submit keeps the draft', (tester) async {
    final store =
        _MemoryDraftStore()
          ..drafts[key.documentId] = const DynamicFormDraft(
            values: {'name': 'Asha', 'first_pregnancy': true},
            pageIndex: 1,
            formVersion: 1,
          );
    await tester.pumpWidget(
      app(store, onSubmit: (_) async => throw StateError('offline')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(store.drafts[key.documentId], isNotNull);
  });

  testWidgets('discarding clears the draft and restarts the form', (
    tester,
  ) async {
    final store =
        _MemoryDraftStore()
          ..drafts[key.documentId] = const DynamicFormDraft(
            values: {'name': 'Asha'},
            pageIndex: 1,
            formVersion: 1,
          );
    await tester.pumpWidget(app(store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Discard draft'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(store.drafts, isEmpty);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.textContaining('Continuing your saved draft'), findsNothing);
    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.controller?.text ?? '', isEmpty);
  });

  testWidgets('leaving mid-pause still saves the latest answers', (
    tester,
  ) async {
    final store = _MemoryDraftStore();
    await tester.pumpWidget(app(store));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Asha');
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();

    expect(store.drafts[key.documentId]?.values, {'name': 'Asha'});
  });
}
