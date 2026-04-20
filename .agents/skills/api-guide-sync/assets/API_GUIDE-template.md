# API Guide

One short paragraph describing the supported public integration contract and the intended audience.

## 1. Supported public import

```dart
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
```

State clearly that `src/**` imports are unsupported internal detail.

## 2. Public API map

Group the currently exported public symbols by role. Prefer small curated groups over exhaustive commentary.

### Documents and value types

- `...`

### Runtime and interaction

- `...`

### View and host integration

- `...`

### Transactions and mutations

- `...`

### Serialization and schema

- `...`

### Errors and validation

- `...`

## 3. Scene document model

Describe the immutable document boundary, layer model, node families, ids, ordering rules, and other durable public model facts.

## 4. Runtime model

Describe `SceneController`, public owned subsurfaces, lifecycle expectations, and observable behavior.

## 5. SceneView and host integration

Describe the preferred widget surface and the host-facing hooks that integrators need first.

## 6. Transactions and mutation semantics

Describe `write(...)`, `SceneWriteTxn`, callback scope, atomicity expectations, and how updates become visible.

## 7. Serialization and schema contract

Describe `SceneBuilder`, `encodeScene*`, `decodeScene*`, `schemaVersionWrite`, `schemaVersionsRead`, and current payload compatibility rules.

## 8. Error model

Describe stable machine-readable failure surfaces such as `SceneDataException`, `SceneDataErrorCode`, `path`, and `details`.

## 9. Minimal integration example

```dart
// Minimal example using only supported public imports and currently exported symbols.
```

## 10. Migration notes

Record only real migration guidance for checked-in compatibility changes that affect integrators.
