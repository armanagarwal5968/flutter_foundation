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
