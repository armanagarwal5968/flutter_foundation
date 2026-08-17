# Alramwarnaga Foundation

Shared, app-agnostic infrastructure for Alramwarnaga Flutter projects.

This package is the home for common services, wrappers, abstractions, and
foundation layers. Product-specific UI and business rules belong in the
consuming application.

## Package layout

```text
lib/
├── alramwarnaga_foundation.dart
└── src/
    ├── layers/
    ├── services/
    └── wrappers/
```

Public APIs must be exported from `lib/alramwarnaga_foundation.dart` so apps can
import them through one stable package entry point:

```dart
import 'package:alramwarnaga_foundation/alramwarnaga_foundation.dart';
```

## Dynamic forms

Foundation provides Firebase-backed, app-neutral dynamic forms:

- `DynamicFormDefinition`, sections, fields, options, and field types
- `FirestoreDynamicFormRepository` for live definitions and callable submissions
- `DynamicFormView` for multi-step rendering and client validation
- `DynamicFormEditorPage` for structured administrator editing

Definitions live in `form_definitions/{formId}`. Consuming apps configure
Firestore Security Rules and the `submitDynamicForm` callable backend; the
foundation client never uses privileged credentials.
