import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'dynamic_form_definition.dart';
import '../telemetry/performance_timing.dart';

abstract interface class DynamicFormRepository {
  Stream<DynamicFormDefinition?> watchForm(String formId);

  Stream<List<DynamicFormDefinition>> watchForms({bool includeDrafts = false});

  Future<void> saveForm(DynamicFormDefinition form);

  Future<void> submit({
    required String formId,
    required String userId,
    required int formVersion,
    required Map<String, Object?> values,
    Map<String, Object?> context = const {},
  });
}

class FirestoreDynamicFormRepository implements DynamicFormRepository {
  FirestoreDynamicFormRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'asia-south1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _forms =>
      _firestore.collection('form_definitions');

  @override
  Stream<DynamicFormDefinition?> watchForm(String formId) => _forms
      .doc(formId)
      .snapshots()
      .timeFirstEvent('load_form', attributes: {'form_id': formId})
      .map(
        (snapshot) =>
            snapshot.exists
                ? DynamicFormDefinition.fromJson(snapshot.id, snapshot.data()!)
                : null,
      );

  @override
  Stream<List<DynamicFormDefinition>> watchForms({bool includeDrafts = false}) {
    Query<Map<String, dynamic>> query = _forms.orderBy('title');
    if (!includeDrafts) {
      query = query
          .where('published', isEqualTo: true)
          .where('catalogVisible', isEqualTo: true);
    }
    return query
        .snapshots()
        .timeFirstEvent(
          'load_form_catalog',
          attributes: {'include_drafts': includeDrafts ? 'yes' : 'no'},
        )
        .map(
          (snapshot) => snapshot.docs
              .map(
                (document) => DynamicFormDefinition.fromJson(
                  document.id,
                  document.data(),
                ),
              )
              .toList(growable: false),
        );
  }

  @override
  Future<void> saveForm(DynamicFormDefinition form) => _forms.doc(form.id).set({
    ...form.toJson(),
    'updatedAt': FieldValue.serverTimestamp(),
  });

  @override
  Future<void> submit({
    required String formId,
    required String userId,
    required int formVersion,
    required Map<String, Object?> values,
    Map<String, Object?> context = const {},
  }) => PerformanceTiming.instance.measure(
    'form_submit',
    attributes: {'form_id': formId},
    (_) => _functions.callTimed('submitDynamicForm', {
      'formId': formId,
      'formVersion': formVersion,
      'values': values,
      'context': context,
    }),
  );
}
