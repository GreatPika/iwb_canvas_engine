<!-- CONTEXT:BEGIN -->
Registry id: `section_04_public_api_v1`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/contracts/public_api_v1.md`
Owns:
- 4. Public API v1: полный surface
Must read before editing:
- `section_00_status_and_scope` -> `docs/architecture/00_architecture_overview.md`
- `section_03_package_layout` -> `docs/architecture/02_package_boundaries.md`
Feeds phases:
- `P1.5`
- `P2`
- `P10`
- `P11`
- `P12`
- `P13`
Related donors:
- `foundation_transform2d`
- `foundation_contract_limits`
- `foundation_error_contract`
- `foundation_validators`
- `foundation_tri_state_patch_semantics`
- `foundation_immutable_collections`
- `foundation_pointer_input_contract`
- `foundation_action_event_immutability`
- `dto_snapshot_behavior`
- `dto_node_spec_behavior`
Related diagrams:
- `c4_context`
- `dfd_public_edit`
- `seq_single_active_surface`
Required tests:
- `test.api_contract.public_readable_union_variants`
- `test.api_contract.public_api_v1_compiles_as_written`
- `test.api.canvas_field_update`
- `test.api_contract.canvas_field_update_static_semantics`
- `test.api_contract.no_undefined_public_type_references`
- `test.api_contract.no_legacy_public_symbols`
- `test.api_contract.dto_immutability`
- `test.api_contract.public_equality_policy`
- `test.api.typed_action_payloads`
- `test.runtime.dispose_lifecycle`
- `test.runtime.runtime_state_publication`
- `test.runtime.interaction_settings_state`
- `test.flutter_bridge.interactive_false_pending_line_preserved`
- `test.flutter_bridge.single_active_surface`
- `test.api_contract.v1_scope_gate`
Guardrails:
- `api.public_exports_complete`
- `api.public_types_complete`
- `api.public_api_compiles_as_written`
- `api.resource_source_app_key_publicly_readable`
- `api.exported_dartdoc_complete`
- `api.public_class_modifiers_explicit`
- `api.public_signature_shape`
- `api.no_undefined_public_type_references`
- `api.dto_immutability`
- `api.equality_policy_explicit`
- `api.id_validation_no_extension_type_escape`
- `surface.interactive_false_pending_line_preserved`
Do not assume:
- no legacy public API shape
- no PatchField export
- no SceneController export
- no raw Map metadata as ordinary public DTO metadata; use CanvasMetadata
<!-- CONTEXT:END -->

## 4. Public API v1: полный surface

Dart declarations below are normative. Implementation must compile against these names and semantics.

### 4.1 Public exports

`lib/iwb_canvas_engine.dart` exports exactly the public names listed in
`docs/_registry/public_api_v1.yaml`.

That registry is the canonical machine-readable inventory for exported-name
completeness. This document owns the public API semantics, signature rules, and
declaration contracts for those names.

The legacy public symbols listed in `tool/goldens/public_api_symbols.txt` from
the legacy package are not exported by this package. Natural concepts may exist
under next-owned names, but legacy public shapes are banned.

Factory target classes may be private only for construction-only sealed values.
Sealed values that application code must read at public boundaries expose their
concrete variants through the public barrel. In v1, `CanvasResourceSource` and
`CanvasDiagnosticPolicy` are public-readable unions; their concrete variants are
stable exported API names.

The root package is Flutter-based. Public API may use:

```text
- dart:ui;
- dart:typed_data;
- package:flutter/widgets.dart;
- package:flutter/foundation.dart.
```

### 4.1.1 Dart API design constraints

Effective Dart is the baseline for public Dart library design unless this
contract states a project-specific rule.

Project-specific public API rules:

```text
- exported public declarations must have a non-empty `///` dartdoc summary
  before API freeze;
- public classes must use explicit Dart 3 subtype policy modifiers such as
  final, sealed, abstract interface, or another deliberate modifier;
- public signatures must not return FutureOr<T>;
- public signatures must not return nullable async/container types such as
  Future<T>?, Stream<T>?, List<T>?, Map<K, V>?, or Set<T>?;
- use empty collections, Stream.empty(), Future<T?>, or an explicit result type
  instead of nullable async/container returns;
- dynamic is allowed only at raw JSON or diagnostic projection boundaries and
  must not leak as a normal public API type;
- toX() names conversion or copy operations; asX() names backed views or
  adaptation;
- the project spelling is Id, not ID, because the public API consistently uses
  CanvasElementId, CanvasLayerId, CanvasResourceId, and CanvasActionId.
```

### 4.1.2 Equality policy

Public equality is part of the API contract. Concrete public classes that are
not listed here use Dart's default identity equality unless their own section
explicitly says otherwise. Public enums use normal Dart enum equality. Public
interfaces, typedefs, and top-level functions do not add an equality contract.

Required value equality:

```text
CanvasElementId
CanvasLayerId
CanvasResourceId
CanvasActionId
CanvasRuntimeState
CanvasRuntimeRevisions
CanvasRuntimeSummary
CanvasTransform
CanvasFieldUpdate and its variants
CanvasMetadata
CanvasDocumentSummary
CanvasCamera
CanvasBackground
CanvasGrid
CanvasSelectionStyle
CanvasGridStyle
CanvasPointerPolicy
CanvasPointerSample
CanvasDrawStyle
CanvasResourceSource and CanvasAppKeyResourceSource
CanvasElementRead
CanvasMoveResolution and its variants
CanvasDiagnosticPolicy, CanvasDiagnosticsDisabled, CanvasDiagnosticsSummary,
CanvasDiagnosticsVerbose
```

For these types, two independently-created instances with the same public values
must compare equal with `==` and must have the same `hashCode`.
`CanvasFieldSet(x)` compares `x` with Dart's normal `==`; it does not add
special deep equality for arbitrary `List`, `Map`, `Set`, or application-owned
objects.

Default identity equality:

```text
CanvasRuntime
CanvasRuntimeConfig
CanvasSurface
CanvasDocument
CanvasLayer
CanvasPalette
CanvasElement and element family types
CanvasElementUpdate and update family types
CanvasClearResult
CanvasPreviewState
CanvasActionCommitted
CanvasActionPayload and payload family types
CanvasTextEditRequested
CanvasMoveCommitRequest
CanvasResource and resource family types
CanvasDataException
```

These runtime-owned objects, larger snapshots, operation records, and event
records may contain collections, callbacks, widget state, or runtime-specific
facts. `CanvasDataException` also uses identity equality, but its public fields
are limited to the safe diagnostic projection: code, message, path, and
sanitized bounded details. Callers must compare ids, revisions, or fields
explicitly when they need semantic comparison.

Future public types must choose one of these policies in this section before
implementation. Adding value equality later is an API behavior change and must
be backed by `test.api_contract.public_equality_policy`.

### 4.2 Identifier types

No public `extension type` is used for ids. Id constructors validate immediately.

```dart
final class CanvasElementId {
  CanvasElementId._(this.value);
  factory CanvasElementId(String value) {
    CanvasIdValidators.requireElementId(value, name: 'elementId');
    return CanvasElementId._(value);
  }
  final String value;
}

final class CanvasLayerId {
  CanvasLayerId._(this.value);
  factory CanvasLayerId(String value) {
    CanvasIdValidators.requireLayerId(value, name: 'layerId');
    return CanvasLayerId._(value);
  }
  final String value;
}

final class CanvasResourceId {
  CanvasResourceId._(this.value);
  factory CanvasResourceId(String value) {
    CanvasIdValidators.requireResourceId(value, name: 'resourceId');
    return CanvasResourceId._(value);
  }
  final String value;
}

final class CanvasActionId {
  CanvasActionId._(this.value);
  factory CanvasActionId(String value) {
    CanvasIdValidators.requireActionId(value, name: 'actionId');
    return CanvasActionId._(value);
  }
  final String value;
}
```

Validation:

```text
CanvasElementId  -> non-empty trimmed string, length <= 256, no control characters.
CanvasLayerId    -> non-empty trimmed string, length <= 256, no control characters.
CanvasResourceId -> non-empty trimmed string, length <= 1024, no control characters.
CanvasActionId   -> non-empty trimmed string, length <= 256, no control characters.
```

Generated ids:

```dart
CanvasElementId CanvasRuntime.generateElementId();   // e0, e1, ...
CanvasLayerId CanvasRuntime.generateLayerId();       // l0, l1, ...
CanvasResourceId CanvasRuntime.generateResourceId(); // r0, r1, ...
```

Generated ids are unique within the current runtime. `loadDocument` resets id generators so that new generated ids do not collide with loaded ids.

### 4.3 Field update patch semantics

The next API does not use legacy `PatchField`. It uses a next-owned field
update intent type with explicit absent, non-null set, and nullable clear
semantics.

```dart
sealed class CanvasFieldUpdate<T> {
  const CanvasFieldUpdate();
  const factory CanvasFieldUpdate.absent() = CanvasFieldAbsent<T>;
}

final class CanvasFieldAbsent<T> extends CanvasFieldUpdate<T> {
  const CanvasFieldAbsent();
}

final class CanvasFieldSet<T extends Object> extends CanvasFieldUpdate<T> {
  const CanvasFieldSet(this.value);
  final T value;
}

final class CanvasFieldClear<T extends Object> extends CanvasFieldUpdate<T?> {
  const CanvasFieldClear();
}
```

Rules:

```text
CanvasFieldAbsent<T> -> do not touch field;
CanvasFieldSet<T extends Object>(x) -> set field to non-null x;
CanvasFieldClear<T extends Object> -> set nullable field T? to null;
CanvasFieldSet(null) -> static error for ordinary public API consumers;
CanvasFieldClear<T> assigned to CanvasFieldUpdate<T> -> static error;
dynamic or generated invalid field updates -> validation error before draft mutation.
```

### 4.4 Runtime and public ports

```dart
final class CanvasRuntime {
  CanvasRuntime({
    CanvasDocument? initialDocument,
    CanvasRuntimeConfig config = const CanvasRuntimeConfig(),
  });

  CanvasDocument readDocument();
  ValueListenable<CanvasRuntimeState> get state;

  CanvasEditPort get edits;
  CanvasSelectionPort get selection;
  CanvasToolPort get tools;
  CanvasCommandPort get commands;
  CanvasCameraPort get camera;
  CanvasResourcePort get resources;

  CanvasPreviewState get preview;

  Stream<CanvasActionCommitted> get actions;
  Stream<CanvasTextEditRequested> get textEditRequests;

  CanvasElementId generateElementId();
  CanvasLayerId generateLayerId();
  CanvasResourceId generateResourceId();

  void dispose();
}
```

`CanvasRuntime` is not a Flutter widget. It may be used in tests without mounting UI.
When `initialDocument` is provided, construction installs that document as the
initial committed document and initializes the runtime view camera from the
document's persisted camera. No public state notification is emitted during
construction; the initial `state.value` and `camera` getters already reflect the
installed document and runtime view camera.
`state.value` is the single public runtime observation snapshot. Applications
that need repaint, cache, badge, toolbar, or save-state updates subscribe to
`state` and compare the public revision domains they care about.

Dispose contract:

```text
- dispose is idempotent;
- after dispose, mutating public operations throw StateError('CanvasRuntime is disposed.');
- readDocument after dispose is allowed and returns last committed immutable document;
- actions stream closes;
- textEditRequests stream closes;
- state.value remains readable after dispose and returns the final runtime
  snapshot;
- dispose alone never increments the committed document revision;
- during the first dispose call, state may notify listeners only when dispose
  clears existing preview state and advances state.revisions.preview;
- after dispose returns, state delivers no further notifications, including on
  repeated dispose calls;
- removeListener is allowed after dispose;
- CanvasRuntime does not own application listeners; CanvasSurface removes only
  listeners it registered during detach, dispose, or runtime swap, and
  applications remove listeners they registered directly;
- mandatory v1 resource caches are cleared without disposing app-provided ui.Image objects.
```

Runtime state snapshot:

```dart
final class CanvasRuntimeState {
  const CanvasRuntimeState({
    required this.revisions,
    required this.summary,
  });

  final CanvasRuntimeRevisions revisions;
  final CanvasRuntimeSummary summary;
}

final class CanvasRuntimeRevisions {
  const CanvasRuntimeRevisions({
    required this.document,
    required this.selection,
    required this.preview,
    required this.viewCamera,
    required this.resourceVisual,
    required this.interaction,
    required this.epoch,
  });

  final int document;
  final int selection;
  final int preview;
  final int viewCamera;
  final int resourceVisual;
  final int interaction;
  final int epoch;
}

final class CanvasRuntimeSummary {
  const CanvasRuntimeSummary({
    required this.elementCount,
    required this.layerCount,
    required this.resourceCount,
    required this.selectedCount,
  });

  final int elementCount;
  final int layerCount;
  final int resourceCount;
  final int selectedCount;
}
```

`CanvasRuntimeState` is atomic from the public API perspective: `revisions` and
`summary` describe the same runtime moment. `CanvasRuntimeRevisions` exposes
application-observation domains only. Internal cache and projection revisions
such as structural, bounds, element visual, frame meta, projection, or resource
descriptor revisions are not public API fields.

### 4.5 Runtime config

```dart
final class CanvasRuntimeConfig {
  const CanvasRuntimeConfig({
    this.pointerPolicy = const CanvasPointerPolicy(),
    this.initialMode = CanvasInteractionMode.move,
    this.initialDrawStyle = const CanvasDrawStyle(),
    this.clearSelectionOnDrawModeEnter = false,
    this.moveCommitResolver,
    this.diagnosticPolicy = const CanvasDiagnosticPolicy.disabled(),
  });

  final CanvasPointerPolicy pointerPolicy;
  final CanvasInteractionMode initialMode;
  final CanvasDrawStyle initialDrawStyle;
  final bool clearSelectionOnDrawModeEnter;
  final CanvasMoveCommitResolver? moveCommitResolver;
  final CanvasDiagnosticPolicy diagnosticPolicy;
}
```

### 4.6 Flutter surface

```dart
final class CanvasSurface extends StatefulWidget {
  const CanvasSurface({
    required this.runtime,
    this.resourceResolver,
    this.selectionStyle = const CanvasSelectionStyle(),
    this.gridStyle = const CanvasGridStyle(),
    this.interactive = true,
    super.key,
  });

  final CanvasRuntime runtime;
  final CanvasResourceResolver? resourceResolver;
  final CanvasSelectionStyle selectionStyle;
  final CanvasGridStyle gridStyle;
  final bool interactive;
}
```

Surface contract:

```text
- v1 supports one active CanvasSurface per CanvasRuntime;
- multiple CanvasSurface widgets may be active at the same time when each uses
  a different CanvasRuntime;
- a CanvasSurface is active from successful runtime attachment until detach or
  dispose completes; interactive=false surfaces are still active;
- attaching a second active CanvasSurface to the same CanvasRuntime throws
  StateError('CanvasRuntime already has an active CanvasSurface.') before
  pointer routing, paint, repaint-listener, or resourceResolver attachment side
  effects;
- after the active CanvasSurface detaches, another CanvasSurface may attach to
  the same CanvasRuntime;
- interactive=false disables pointer routing on CanvasSurface only;
- interactive=false still paints document;
- interactive=false does not mutate runtime mode, document, selection, preview or resources;
- if interactive changes from true to false while a pointer session is active,
  CanvasSurface routes cancel cleanup before disabling further routing;
- pending preview state that is not owned by an active routed pointer session is
  preserved when interactive becomes false;
- pending line start and line preview are not active routed pointer sessions after
  their tap sample has completed; `interactive=false` preserves them until line
  cleanup, mode/tool change, successful load, dispose, or terminal line decision;
- toggling interactive back to true resumes routing only for subsequent pointer events;
- CanvasSurface never mutates committed document directly;
- CanvasSurface routes pointer samples into InteractionEngine;
- CanvasSurface resourceResolver is the app-owned synchronous image resolver for that surface;
- CanvasSurface does not own or dispose app-provided ui.Image instances.
```

### 4.7 Visual styles

```dart
final class CanvasSelectionStyle {
  const CanvasSelectionStyle({
    this.color = const Color(0xFF1565C0),
    this.strokeWidth = 1.0,
    this.marqueeFillOpacity = 0.15,
    this.haloWidth = 4.0,
  });

  final Color color;
  final double strokeWidth;
  final double marqueeFillOpacity;
  final double haloWidth;
}

final class CanvasGridStyle {
  const CanvasGridStyle({this.strokeWidth = 1.0});
  final double strokeWidth;
}
```

Validation: all numeric fields finite and non-negative; opacity in `[0, 1]`.

### 4.8 Document DTOs

All public DTOs are immutable. Any constructor receiving caller-owned
`Iterable`, `List`, `Set`, `Map`, or metadata input must defensively copy,
deep-freeze nested metadata values where applicable, validate at runtime, and
expose only unmodifiable values. Such constructors are non-const. Safe
scalar-only DTOs and marker/empty variants may remain `const` when they accept no
caller-owned mutable input and need no runtime validation beyond safe defaults.

`CanvasMetadata` is the public value object for schema metadata materialized into
DTOs. Raw `Map<String, Object?>` metadata is allowed only at raw JSON codec
boundaries. Diagnostic details remain sanitized map-shaped public data, but they
are not schema metadata and are not `CanvasMetadata`.

```dart
final class CanvasMetadata {
  const CanvasMetadata.empty();
  CanvasMetadata.fromMap(Map<String, Object?> values);

  bool get isEmpty;
  Iterable<String> get keys;
  bool containsKey(String key);
  Object? operator [](String key);
}

final class CanvasDocument {
  CanvasDocument({
    CanvasCamera camera = const CanvasCamera(),
    CanvasBackground background = const CanvasBackground(),
    CanvasPalette? palette,
    Iterable<CanvasResource> resources = const [],
    Iterable<CanvasElement> backgroundElements = const [],
    Iterable<CanvasLayer> layers = const [],
    CanvasMetadata metadata = const CanvasMetadata.empty(),
  });

  final CanvasCamera camera;
  final CanvasBackground background;
  final CanvasPalette palette;

  List<CanvasResource> get resources;
  List<CanvasElement> get backgroundElements;
  List<CanvasLayer> get layers;
  CanvasMetadata get metadata;
}

final class CanvasDocumentSummary {
  const CanvasDocumentSummary({
    required this.elementCount,
    required this.layerCount,
    required this.resourceCount,
  });

  final int elementCount;
  final int layerCount;
  final int resourceCount;
}

final class CanvasLayer {
  CanvasLayer({
    required CanvasLayerId id,
    Iterable<CanvasElement> elements = const [],
    CanvasMetadata metadata = const CanvasMetadata.empty(),
  });

  final CanvasLayerId id;
  List<CanvasElement> get elements;
  CanvasMetadata get metadata;
}

final class CanvasCamera {
  const CanvasCamera({this.offset = Offset.zero});
  final Offset offset;
}

final class CanvasBackground {
  const CanvasBackground({
    this.color = const Color(0xFFFFFFFF),
    this.grid = const CanvasGrid(),
  });

  final Color color;
  final CanvasGrid grid;
}

final class CanvasGrid {
  const CanvasGrid({
    this.enabled = false,
    this.cellSize = 10.0,
    this.color = const Color(0x1F000000),
  });

  final bool enabled;
  final double cellSize;
  final Color color;
}

final class CanvasPalette {
  CanvasPalette({
    required Iterable<Color> penColors,
    required Iterable<Color> backgroundColors,
    required Iterable<double> gridSizes,
  });

  CanvasPalette.defaults();

  List<Color> get penColors;
  List<Color> get backgroundColors;
  List<double> get gridSizes;
}
```

`CanvasDocument` materializes `CanvasPalette.defaults()` when `palette` is null.
`CanvasPalette` is non-const because it owns caller-provided iterables and must
copy and validate them before exposing unmodifiable lists. `CanvasMetadata.empty()`
is const-safe because it accepts no caller-owned input; `CanvasMetadata.fromMap`
is non-const because it validates and deep-freezes caller-owned map/list values.
`CanvasDocument.camera` stores the persisted document default camera offset,
matching legacy engine behavior for schema/readDocument round trips. The same
`CanvasCamera` value type is also used by `CanvasCameraPort.camera` to report
the runtime view camera; runtime view camera offset is owned by
`CanvasCameraPort` and published through `CanvasRuntime.state`.

### 4.9 Geometry enums and transform

The current package exposes `Transform2D` as a six-component affine transform
with JSON shape `{a,b,c,d,tx,ty}` and Flutter canvas matrix conversion. The
public `CanvasTransform` keeps that complete behavior under the next API name.

```dart
enum CanvasElementKind {
  image,
  path,
  text,
  stroke,
  line,
  rect,
}

enum CanvasPathFillRule {
  nonZero,
  evenOdd,
}

final class CanvasTransform {
  const CanvasTransform({
    required this.a,
    required this.b,
    required this.c,
    required this.d,
    required this.tx,
    required this.ty,
  });

  static const identity = CanvasTransform(
    a: 1,
    b: 0,
    c: 0,
    d: 1,
    tx: 0,
    ty: 0,
  );

  factory CanvasTransform.translation(Offset delta);
  factory CanvasTransform.scale(double sx, double sy);
  factory CanvasTransform.rotationRadians(double radians);
  factory CanvasTransform.rotationDegrees(double degrees);
  factory CanvasTransform.trs({
    Offset translation = Offset.zero,
    double rotationDegrees = 0,
    double scaleX = 1,
    double scaleY = 1,
  });

  final double a;
  final double b;
  final double c;
  final double d;
  final double tx;
  final double ty;

  Offset get translation;
  bool get isFinite;
  bool get isInvertible;

  CanvasTransform withTranslation(Offset translation);
  CanvasTransform multiply(CanvasTransform other);
  Offset applyToPoint(Offset point);
  Rect applyToRect(Rect rect);
  CanvasTransform? invert();
  Float64List toCanvasTransform();
  void writeToCanvasTransform(Float64List out);
  Map<String, double> toJsonMap();
}
```

Validation:

```text
- all components must be finite at public construction and decode;
- multiply order: a.multiply(b) applies b first, then a;
- applyToRect returns axis-aligned bounding box of four transformed rect corners;
- invert returns null when transform is not invertible;
- toCanvasTransform uses Flutter column-major 4x4 layout;
- element transforms must be invertible;
- scale singular values must remain within [1e-4, 1e4] when invertibility is
  required;
- toCanvasTransform layout:
  [a,b,0,0, c,d,0,0, 0,0,1,0, tx,ty,0,1].
```

### 4.10 Element DTOs

Common fields for every element:

```dart
sealed class CanvasElement {
  CanvasElement({
    required CanvasElementId id,
    int revision = 0,
    CanvasTransform transform = CanvasTransform.identity,
    double opacity = 1.0,
    double hitPadding = 0.0,
    bool isVisible = true,
    bool isSelectable = true,
    bool isLocked = false,
    bool isDeletable = true,
    bool isTransformable = true,
    CanvasMetadata metadata = const CanvasMetadata.empty(),
  });

  CanvasElementId get id;
  CanvasElementKind get kind;
  int get revision;
  CanvasTransform get transform;
  double get opacity;
  double get hitPadding;
  bool get isVisible;
  bool get isSelectable;
  bool get isLocked;
  bool get isDeletable;
  bool get isTransformable;
  CanvasMetadata get metadata;
}
```

Element families:

```dart
final class CanvasImageElement extends CanvasElement {
  CanvasImageElement({
    required super.id,
    required this.resourceId,
    required this.size,
    this.naturalSize,
    super.revision,
    super.transform,
    super.opacity,
    super.hitPadding,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
    super.metadata,
  });

  final CanvasResourceId resourceId;
  final Size size;
  final Size? naturalSize;
}

final class CanvasPathElement extends CanvasElement {
  CanvasPathElement({
    required super.id,
    required this.svgPathData,
    this.fillColor,
    this.strokeColor,
    this.strokeWidth = 0.0,
    this.fillRule = CanvasPathFillRule.nonZero,
    super.revision,
    super.transform,
    super.opacity,
    super.hitPadding,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
    super.metadata,
  });

  final String svgPathData;
  final Color? fillColor;
  final Color? strokeColor;
  final double strokeWidth;
  final CanvasPathFillRule fillRule;
}

final class CanvasTextElement extends CanvasElement {
  CanvasTextElement({
    required super.id,
    required this.text,
    this.fontSize = 24.0,
    required this.color,
    this.align = TextAlign.left,
    required this.textDirection,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.fontFamily,
    this.maxWidth,
    this.lineHeight,
    super.revision,
    super.transform,
    super.opacity,
    super.hitPadding,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
    super.metadata,
  });

  final String text;
  final double fontSize;
  final Color color;
  final TextAlign align;
  final TextDirection textDirection;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final String? fontFamily;
  final double? maxWidth;
  final double? lineHeight;
}

final class CanvasStrokeElement extends CanvasElement {
  CanvasStrokeElement({
    required super.id,
    required Iterable<Offset> points,
    required this.thickness,
    required this.color,
    super.revision,
    super.transform,
    super.opacity,
    super.hitPadding,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
    super.metadata,
  });

  List<Offset> get points;
  final double thickness;
  final Color color;
}

final class CanvasLineElement extends CanvasElement {
  CanvasLineElement({
    required super.id,
    required this.start,
    required this.end,
    required this.thickness,
    required this.color,
    super.revision,
    super.transform,
    super.opacity,
    super.hitPadding,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
    super.metadata,
  });

  final Offset start;
  final Offset end;
  final double thickness;
  final Color color;
}

final class CanvasRectElement extends CanvasElement {
  CanvasRectElement({
    required super.id,
    required this.size,
    this.fillColor,
    this.strokeColor,
    this.strokeWidth = 0.0,
    super.revision,
    super.transform,
    super.opacity,
    super.hitPadding,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
    super.metadata,
  });

  final Size size;
  final Color? fillColor;
  final Color? strokeColor;
  final double strokeWidth;
}
```

### 4.11 Element updates

Partial updates use `CanvasFieldUpdate`, not legacy `NodePatch`.

```dart
sealed class CanvasElementUpdate {
  CanvasElementUpdate({
    required this.id,
    this.transform = const CanvasFieldUpdate.absent(),
    this.opacity = const CanvasFieldUpdate.absent(),
    this.hitPadding = const CanvasFieldUpdate.absent(),
    this.isVisible = const CanvasFieldUpdate.absent(),
    this.isSelectable = const CanvasFieldUpdate.absent(),
    this.isLocked = const CanvasFieldUpdate.absent(),
    this.isDeletable = const CanvasFieldUpdate.absent(),
    this.isTransformable = const CanvasFieldUpdate.absent(),
    this.metadata = const CanvasFieldUpdate.absent(),
  });

  final CanvasElementId id;
  final CanvasFieldUpdate<CanvasTransform> transform;
  final CanvasFieldUpdate<double> opacity;
  final CanvasFieldUpdate<double> hitPadding;
  final CanvasFieldUpdate<bool> isVisible;
  final CanvasFieldUpdate<bool> isSelectable;
  final CanvasFieldUpdate<bool> isLocked;
  final CanvasFieldUpdate<bool> isDeletable;
  final CanvasFieldUpdate<bool> isTransformable;
  final CanvasFieldUpdate<CanvasMetadata> metadata;
}
```

Family updates are concrete Dart classes, not field-list shorthand:

```dart
final class CanvasImageElementUpdate extends CanvasElementUpdate {
  CanvasImageElementUpdate({
    required super.id,
    super.transform,
    super.opacity,
    super.hitPadding,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
    super.metadata,
    this.resourceId = const CanvasFieldUpdate.absent(),
    this.size = const CanvasFieldUpdate.absent(),
    this.naturalSize = const CanvasFieldUpdate.absent(),
  });

  final CanvasFieldUpdate<CanvasResourceId> resourceId;
  final CanvasFieldUpdate<Size> size;
  final CanvasFieldUpdate<Size?> naturalSize;
}

final class CanvasPathElementUpdate extends CanvasElementUpdate {
  CanvasPathElementUpdate({
    required super.id,
    super.transform,
    super.opacity,
    super.hitPadding,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
    super.metadata,
    this.svgPathData = const CanvasFieldUpdate.absent(),
    this.fillColor = const CanvasFieldUpdate.absent(),
    this.strokeColor = const CanvasFieldUpdate.absent(),
    this.strokeWidth = const CanvasFieldUpdate.absent(),
    this.fillRule = const CanvasFieldUpdate.absent(),
  });

  final CanvasFieldUpdate<String> svgPathData;
  final CanvasFieldUpdate<Color?> fillColor;
  final CanvasFieldUpdate<Color?> strokeColor;
  final CanvasFieldUpdate<double> strokeWidth;
  final CanvasFieldUpdate<CanvasPathFillRule> fillRule;
}

final class CanvasTextElementUpdate extends CanvasElementUpdate {
  CanvasTextElementUpdate({
    required super.id,
    super.transform,
    super.opacity,
    super.hitPadding,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
    super.metadata,
    this.text = const CanvasFieldUpdate.absent(),
    this.fontSize = const CanvasFieldUpdate.absent(),
    this.color = const CanvasFieldUpdate.absent(),
    this.align = const CanvasFieldUpdate.absent(),
    this.textDirection = const CanvasFieldUpdate.absent(),
    this.isBold = const CanvasFieldUpdate.absent(),
    this.isItalic = const CanvasFieldUpdate.absent(),
    this.isUnderline = const CanvasFieldUpdate.absent(),
    this.fontFamily = const CanvasFieldUpdate.absent(),
    this.maxWidth = const CanvasFieldUpdate.absent(),
    this.lineHeight = const CanvasFieldUpdate.absent(),
  });

  final CanvasFieldUpdate<String> text;
  final CanvasFieldUpdate<double> fontSize;
  final CanvasFieldUpdate<Color> color;
  final CanvasFieldUpdate<TextAlign> align;
  final CanvasFieldUpdate<TextDirection> textDirection;
  final CanvasFieldUpdate<bool> isBold;
  final CanvasFieldUpdate<bool> isItalic;
  final CanvasFieldUpdate<bool> isUnderline;
  final CanvasFieldUpdate<String?> fontFamily;
  final CanvasFieldUpdate<double?> maxWidth;
  final CanvasFieldUpdate<double?> lineHeight;
}

final class CanvasStrokeElementUpdate extends CanvasElementUpdate {
  CanvasStrokeElementUpdate({
    required super.id,
    super.transform,
    super.opacity,
    super.hitPadding,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
    super.metadata,
    this.points = const CanvasFieldUpdate.absent(),
    this.thickness = const CanvasFieldUpdate.absent(),
    this.color = const CanvasFieldUpdate.absent(),
  });

  final CanvasFieldUpdate<List<Offset>> points;
  final CanvasFieldUpdate<double> thickness;
  final CanvasFieldUpdate<Color> color;
}

final class CanvasLineElementUpdate extends CanvasElementUpdate {
  CanvasLineElementUpdate({
    required super.id,
    super.transform,
    super.opacity,
    super.hitPadding,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
    super.metadata,
    this.start = const CanvasFieldUpdate.absent(),
    this.end = const CanvasFieldUpdate.absent(),
    this.thickness = const CanvasFieldUpdate.absent(),
    this.color = const CanvasFieldUpdate.absent(),
  });

  final CanvasFieldUpdate<Offset> start;
  final CanvasFieldUpdate<Offset> end;
  final CanvasFieldUpdate<double> thickness;
  final CanvasFieldUpdate<Color> color;
}

final class CanvasRectElementUpdate extends CanvasElementUpdate {
  CanvasRectElementUpdate({
    required super.id,
    super.transform,
    super.opacity,
    super.hitPadding,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
    super.metadata,
    this.size = const CanvasFieldUpdate.absent(),
    this.fillColor = const CanvasFieldUpdate.absent(),
    this.strokeColor = const CanvasFieldUpdate.absent(),
    this.strokeWidth = const CanvasFieldUpdate.absent(),
  });

  final CanvasFieldUpdate<Size> size;
  final CanvasFieldUpdate<Color?> fillColor;
  final CanvasFieldUpdate<Color?> strokeColor;
  final CanvasFieldUpdate<double> strokeWidth;
}
```

Update semantics:

```text
- update kind must match existing element kind;
- mismatched update kind throws ArgumentError before draft mutation;
- no-op update returns false and emits no action;
- changed update increments element revision;
- changed update invalidates only typed touched sets;
- nullable common/family fields accept `CanvasFieldClear<T>()`, where the field
  type is `CanvasFieldUpdate<T?>`;
- non-nullable common/family fields cannot accept `CanvasFieldClear<T>()` in
  ordinary statically checked code;
- dynamic or generated clear requests for non-nullable fields are rejected
  before draft mutation.
```

### 4.12 Edit API

```dart
abstract interface class CanvasEditPort {
  T edit<T>(T Function(CanvasEdit edit) fn);
  void loadDocument(CanvasDocument document);
}

abstract interface class CanvasEdit {
  CanvasDocument readDraftDocument();
  CanvasDocumentSummary get draftSummary;

  bool ensureLayer(CanvasLayerId id, {int? index});
  CanvasElementId addElement(CanvasElement element, {CanvasLayerId? layerId, int? index});
  CanvasElementId addBackgroundElement(CanvasElement element, {int? index});
  bool updateElement(CanvasElementUpdate update);
  bool removeElement(CanvasElementId id);

  bool upsertResource(CanvasResource resource);
  bool removeUnusedResource(CanvasResourceId id);

  void setBackgroundColor(Color color);
  void setGrid(CanvasGrid grid);
  void setPalette(CanvasPalette palette);
  void setCameraOffset(Offset offset);

  CanvasClearResult clearContent({bool removeUnusedResources = false});
  void replaceDraftDocument(CanvasDocument document);
}
```

Edit contract:

```text
- edit callback is synchronous;
- nested edit is rejected;
- callback returning Future is rejected;
- all draft mutations are atomic;
- exception in callback rolls back document, resources, selection-owner changes, signals and repaint;
- public notifications occur only after atomic install;
- CanvasEdit handle becomes stale after callback;
- stale handle operations throw StateError;
- readDraftDocument may materialize a public document and is not allowed in hot pointer/paint paths;
- addElement with id collision throws CanvasDataException duplicateId;
- addElement with missing resource reference throws CanvasDataException missingReference;
- removeUnusedResource fails with false if resource is referenced by any background/content element, including invisible or locked elements.
- CanvasEdit.removeElement is a low-level document edit and emits no user action event;
- CanvasEdit.clearContent is a low-level document edit and emits no user action event.
```

`CanvasEdit.setCameraOffset` changes the persisted document camera. It is a
document edit: changed offsets increment `state.revisions.document`, invalidate
the public `CanvasDocument` projection, and are visible through `readDocument`.
It never directly mutates the runtime view camera. Runtime construction with an
`initialDocument` and `loadDocument` both initialize the runtime view camera from
the installed document's persisted camera.

`CanvasClearResult`:

```dart
final class CanvasClearResult {
  CanvasClearResult({
    required Iterable<CanvasElementId> removedElementIds,
    required Iterable<CanvasResourceId> removedResourceIds,
    required this.didClearContent,
  });

  List<CanvasElementId> get removedElementIds;
  List<CanvasResourceId> get removedResourceIds;
  final bool didClearContent;
}
```

### 4.13 High-level commands

High-level commands are public user-intent operations. They use EditKernel for
atomic mutation, but they own user action event emission. This keeps low-level
`CanvasEdit` usable for programmatic synchronization without polluting the app's
undo/redo action stream.

```dart
abstract interface class CanvasCommandPort {
  bool removeElement(CanvasElementId id, {int? timestampMs});
  CanvasClearResult clearContent({
    bool removeUnusedResources = false,
    int? timestampMs,
  });
}
```

Rules:

```text
- command mutations must go through EditKernel and inherit rollback/stale/dispose checks;
- removeElement emits deleteElements only when it removes an element;
- CanvasCommandPort.clearContent emits clearContent only when removedElementIds is not empty;
- if only unused resources are removed and no elements are removed, no user
  action event is emitted;
- command action payloads are emitted after atomic install;
- if command mutation rolls back or no-ops, no action event is emitted.
```

### 4.14 Selection API

```dart
abstract interface class CanvasSelectionPort {
  Set<CanvasElementId> get selectedElementIds;

  void setSelection(Iterable<CanvasElementId> ids);
  void toggleSelection(CanvasElementId id);
  void clearSelection();
  void selectAll({bool onlySelectable = true});

  void moveSelection(Offset delta, {int? timestampMs});
  void rotateSelectionClockwise({int? timestampMs});
  void rotateSelectionCounterClockwise({int? timestampMs});
  void flipSelectionVertical({int? timestampMs});
  void flipSelectionHorizontal({int? timestampMs});
  void deleteSelection({int? timestampMs});
}
```

Selection rules:

```text
- CanvasSelectionPort is the public boundary for selection commands;
- selection is runtime view state owned by the internal selection owner, not by
  CanvasDocument or DocumentStoreKernel;
- the selection owner stores content element ids only;
- selecting non-existing, background, or otherwise ineligible ids normalizes them out;
- onlySelectable=true selects visible && isSelectable elements;
- selection-only changes update selectionRevision, not documentRevision;
- selection-only changes do not evict the public document projection;
- move/rotate/flip operate only on selected elements with isTransformable=true && isLocked=false;
- deleteSelection deletes only selected elements with isDeletable=true;
- selection actions preserve document order in emitted elementIds.
```

### 4.15 Tools and pointer API

```dart
enum CanvasInteractionMode { move, draw }
enum CanvasDrawTool { pencil, marker, line, eraser }
enum CanvasPointerLifecyclePhase { down, move, up, cancel }

final class CanvasPointerPolicy {
  const CanvasPointerPolicy({
    this.tapSlop = 8.0,
    this.doubleTapSlop = 24.0,
    this.doubleTapMaxDelayMs = 300,
    this.deferSingleTap = true,
    this.dragStartSlop,
  });

  final double tapSlop;
  final double doubleTapSlop;
  final int doubleTapMaxDelayMs;
  final bool deferSingleTap;
  final double? dragStartSlop;
}

final class CanvasPointerSample {
  const CanvasPointerSample({
    required this.pointerId,
    required this.position,
    this.timestampMs,
    required this.phase,
    required this.kind,
  });

  final int pointerId;
  final Offset position;
  final int? timestampMs;
  final CanvasPointerLifecyclePhase phase;
  final PointerDeviceKind kind;
}

final class CanvasDrawStyle {
  const CanvasDrawStyle({
    this.tool = CanvasDrawTool.pencil,
    this.color = const Color(0xFF000000),
    this.pencilThickness = 3.0,
    this.markerThickness = 12.0,
    this.markerOpacity = 0.4,
    this.lineThickness = 3.0,
    this.eraserThickness = 20.0,
  });

  final CanvasDrawTool tool;
  final Color color;
  final double pencilThickness;
  final double markerThickness;
  final double markerOpacity;
  final double lineThickness;
  final double eraserThickness;
}

abstract interface class CanvasToolPort {
  CanvasInteractionMode get mode;
  CanvasDrawStyle get drawStyle;
  CanvasPointerPolicy get pointerPolicy;

  void setMode(CanvasInteractionMode mode);
  void setDrawStyle(CanvasDrawStyle style);
  void setDrawTool(CanvasDrawTool tool);
  void setDrawColor(Color color);
  void setPointerPolicy(CanvasPointerPolicy policy);

  void handlePointer(CanvasPointerSample sample);
  void handleDoubleTap({required Offset position, int? timestampMs});
}
```

Validation:

```text
pointer slops -> finite >= 0;
doubleTapMaxDelayMs -> >= 0;
dragStartSlop -> null or finite >= 0;
pencil/marker/line/eraser thickness -> finite > 0;
markerOpacity -> finite in [0, 1];
pointer position -> finite for down/move; invalid terminal samples are routed to cleanup logic.
```

Pointer scope for v1:

```text
- pointerId is used only to route samples and reject stale terminal samples;
- one runtime has at most one active pointer session;
- a second pointer down while a session is active is ignored;
- no concurrent pointer sessions are stored.
```

### 4.16 Camera API

```dart
abstract interface class CanvasCameraPort {
  CanvasCamera get camera;
  Offset get offset;

  void setOffset(Offset offset);
  void panBy(Offset delta);
}
```

Offset validation: finite x/y within `[-1e7, 1e7]`.

`CanvasCameraPort` owns the runtime view camera. `setOffset` and `panBy` update
`state.revisions.viewCamera` and repaint affected surfaces without incrementing
`state.revisions.document`, invalidating public `CanvasDocument` projection, or
changing the persisted document camera. `camera` and `offset` expose the current
runtime view camera, while `readDocument().camera` exposes the persisted
document camera.

### 4.17 Resource API

```dart
abstract interface class CanvasResourcePort {
  List<CanvasResource> get resources;
  CanvasResource? resourceById(CanvasResourceId id);

  void markResourceDirty(CanvasResourceId id);
  void markAllResourcesDirty();
}
```

Resource mutation is intentionally **not** on `CanvasResourcePort`. It is inside `CanvasEdit` to guarantee atomic resource + element operations.

Resource descriptors:

```dart
sealed class CanvasResource {
  CanvasResource({
    required this.id,
    required this.source,
    this.contentHash,
    this.byteLength,
    CanvasMetadata metadata = const CanvasMetadata.empty(),
  });

  final CanvasResourceId id;
  final CanvasResourceSource source;
  final String? contentHash;
  final int? byteLength;
  CanvasMetadata get metadata;
}

final class CanvasImageResource extends CanvasResource {
  CanvasImageResource({
    required super.id,
    required super.source,
    this.mimeType,
    super.contentHash,
    super.byteLength,
    super.metadata,
  });

  final String? mimeType;
}

sealed class CanvasResourceSource {
  const CanvasResourceSource();
  const factory CanvasResourceSource.appKey(String key) = CanvasAppKeyResourceSource;
}

final class CanvasAppKeyResourceSource extends CanvasResourceSource {
  const CanvasAppKeyResourceSource(this.key);
  final String key;
}
```

Application code may type-test or pattern-match `CanvasImageResource.source` as
`CanvasAppKeyResourceSource` and read `key` without importing `src/**`.

Resolver:

```dart
abstract interface class CanvasResourceResolver {
  ui.Image? resolveImage(CanvasImageResource resource);
}
```

v1 resource rules:

```text
- CanvasResourceSource.appKey is mandatory for v1 resource sources;
- no engine IO;
- no asset-bundle loading;
- no file loading;
- no remote/network loading;
- resourceResolver is synchronous in v1;
- all ui.Image objects returned by CanvasResourceResolver are app-owned;
- the engine never disposes app-provided ui.Image instances;
- the engine stores only resource descriptors and render cache references;
- markResourceDirty invalidates visual cache but does not mutate document;
- markResourceDirty publishes main repaint intent; an attached CanvasSurface
  observes it if present;
- resolver must return a stable visual result for the same resource descriptor
  unless the app calls markResourceDirty/markAllResourcesDirty.
```

### 4.18 Preview state

The next API exposes read-only preview state because the legacy example reads pending line and stroke preview state.

```dart
enum CanvasPreviewKind {
  none,
  marquee,
  selectedMove,
  pencilStroke,
  markerStroke,
  pendingLineStart,
  linePreview,
  eraser,
}

final class CanvasPreviewState {
  CanvasPreviewState({
    required this.kind,
    this.activePointerId,
    this.sessionId,
    this.selectedMoveDelta = Offset.zero,
    this.marqueeRect,
    Iterable<Offset> strokePoints = const [],
    this.strokeColor,
    this.strokeThickness,
    this.strokeOpacity,
    this.lineStart,
    this.lineEnd,
    this.lineTimestampMs,
    this.lineColor,
    this.lineThickness,
    Iterable<Offset> eraserCorridor = const [],
    this.eraserThickness,
  });

  final CanvasPreviewKind kind;
  final int? activePointerId;
  final int? sessionId;
  final Offset selectedMoveDelta;
  final Rect? marqueeRect;
  List<Offset> get strokePoints;
  final Color? strokeColor;
  final double? strokeThickness;
  final double? strokeOpacity;
  final Offset? lineStart;
  final Offset? lineEnd;
  final int? lineTimestampMs;
  final Color? lineColor;
  final double? lineThickness;
  List<Offset> get eraserCorridor;
  final double? eraserThickness;
}
```

Rules:

```text
- preview state is immutable;
- every pointer preview update creates a small new snapshot or reuses previous unchanged snapshot;
- no CanvasDocument materialization in preview getters;
- pending line start is epoch-bound;
- loadDocument success clears preview;
- loadDocument failure preserves preview;
- selected move preview is main-scene preview, not overlay-only preview.
```

### 4.19 Action and text events

```dart
enum CanvasActionType {
  moveSelection,
  selectMarquee,
  transformSelection,
  deleteElements,
  clearContent,
  drawPencil,
  drawMarker,
  drawLine,
  erase,
}

final class CanvasActionCommitted {
  CanvasActionCommitted({
    required this.actionId,
    required this.type,
    required Iterable<CanvasElementId> elementIds,
    required this.timestampMs,
    required this.payload,
  });

  final CanvasActionId actionId;
  final CanvasActionType type;
  List<CanvasElementId> get elementIds;
  final int timestampMs;
  final CanvasActionPayload payload;
}

sealed class CanvasActionPayload { const CanvasActionPayload(); }
```

Payload subclasses:

```dart
enum CanvasTransformOperation {
  move,
  rotateClockwise,
  rotateCounterClockwise,
  flipVertical,
  flipHorizontal,
}

final class CanvasTransformActionPayload extends CanvasActionPayload {
  CanvasTransformActionPayload({
    required this.delta,
    required this.operation,
    this.pivotWorld,
  });

  final CanvasTransform delta;
  final CanvasTransformOperation operation;
  final Offset? pivotWorld;
}

final class CanvasSelectionActionPayload extends CanvasActionPayload {
  CanvasSelectionActionPayload({
    required Iterable<CanvasElementId> previousSelection,
    required Iterable<CanvasElementId> nextSelection,
    this.marqueeRectWorld,
  });

  List<CanvasElementId> get previousSelection;
  List<CanvasElementId> get nextSelection;
  final Rect? marqueeRectWorld;
}

final class CanvasDeleteActionPayload extends CanvasActionPayload {
  CanvasDeleteActionPayload({
    required Iterable<CanvasElementId> removedElementIds,
  });

  List<CanvasElementId> get removedElementIds;
}

final class CanvasClearActionPayload extends CanvasActionPayload {
  CanvasClearActionPayload({
    required Iterable<CanvasElementId> removedElementIds,
    required Iterable<CanvasResourceId> removedResourceIds,
  });

  List<CanvasElementId> get removedElementIds;
  List<CanvasResourceId> get removedResourceIds;
}

final class CanvasDrawStrokeActionPayload extends CanvasActionPayload {
  const CanvasDrawStrokeActionPayload({
    required this.tool,
    required this.color,
    required this.thickness,
    required this.opacity,
    required this.pointCount,
  });

  final CanvasDrawTool tool;
  final Color color;
  final double thickness;
  final double opacity;
  final int pointCount;
}

final class CanvasDrawLineActionPayload extends CanvasActionPayload {
  const CanvasDrawLineActionPayload({
    required this.color,
    required this.thickness,
    required this.opacity,
    required this.startWorld,
    required this.endWorld,
  });

  final Color color;
  final double thickness;
  final double opacity;
  final Offset startWorld;
  final Offset endWorld;
}

final class CanvasEraseActionPayload extends CanvasActionPayload {
  CanvasEraseActionPayload({
    required this.eraserThickness,
    required Iterable<CanvasElementId> erasedElementIds,
    required this.corridorPointCount,
  });

  final double eraserThickness;
  List<CanvasElementId> get erasedElementIds;
  final int corridorPointCount;
}
```

Payload collection rules:

```text
- CanvasSelectionActionPayload.previousSelection defensively copies input;
- CanvasSelectionActionPayload.nextSelection defensively copies input;
- CanvasDeleteActionPayload.removedElementIds defensively copies input;
- CanvasClearActionPayload.removedElementIds defensively copies input;
- CanvasClearActionPayload.removedResourceIds defensively copies input;
- CanvasEraseActionPayload.erasedElementIds defensively copies input;
- CanvasActionCommitted.elementIds defensively copies input.
```

Event emission matrix:

| Operation | Emits action? | Type | Payload |
|---|---:|---|---|
| programmatic addElement | no | — | — |
| programmatic updateElement | no | — | — |
| CanvasEdit.removeElement | no | — | — |
| CanvasEdit.clearContent | no | — | — |
| high-level command removeElement | yes if removed | `deleteElements` | `CanvasDeleteActionPayload` |
| high-level command clearContent | yes if removed elements | `clearContent` | `CanvasClearActionPayload` |
| selection.setSelection from API | no | — | — |
| marquee selection commit | yes if changed | `selectMarquee` | `CanvasSelectionActionPayload` |
| selected move commit | yes if moved | `moveSelection` | `CanvasTransformActionPayload` |
| rotate/flip selection | yes if affected | `transformSelection` | `CanvasTransformActionPayload` |
| deleteSelection | yes if removed | `deleteElements` | `CanvasDeleteActionPayload` |
| pencil stroke commit | yes | `drawPencil` | `CanvasDrawStrokeActionPayload` |
| marker stroke commit | yes | `drawMarker` | `CanvasDrawStrokeActionPayload` |
| line commit | yes | `drawLine` | `CanvasDrawLineActionPayload` |
| eraser commit | yes if removed | `erase` | `CanvasEraseActionPayload` |
| loadDocument | no | — | — |
| set camera/background/grid/palette | no | — | — |
| markResourceDirty | no | — | — |

Text edit event:

```dart
final class CanvasTextEditRequested {
  CanvasTextEditRequested({
    required this.elementId,
    required this.timestampMs,
    required this.viewPosition,
    required this.worldPosition,
    required this.boundsWorld,
    required this.textSnapshot,
  });

  final CanvasElementId elementId;
  final int timestampMs;
  final Offset viewPosition;
  final Offset worldPosition;
  final Rect boundsWorld;
  final CanvasTextElement textSnapshot;
}
```

Text editing model:

```text
- engine detects double-tap on text;
- engine emits CanvasTextEditRequested;
- application displays Flutter text editor overlay;
- application may hide text element by updateElement(isVisible=false);
- application commits changed text through updateElement(CanvasTextElementUpdate);
- engine does not store active text-input session;
- IME/focus/accessibility/text selection are application responsibilities;
- loadDocument/dispose/tool change while editing is application responsibility.
```

### 4.20 Move commit resolver

The resolver is synchronous in v1. Async resolver is not supported in v1.

```dart
typedef CanvasMoveCommitResolver = CanvasMoveResolution Function(CanvasMoveCommitRequest request);

final class CanvasMoveCommitRequest {
  CanvasMoveCommitRequest({
    required this.documentSummary,
    required Iterable<CanvasElementRead> movedElements,
    required this.proposedDelta,
    required this.selectionBoundsWorld,
    required this.timestampMs,
  });

  final CanvasDocumentSummary documentSummary;
  List<CanvasElementRead> get movedElements;
  final Offset proposedDelta;
  final Rect selectionBoundsWorld;
  final int timestampMs;
}

final class CanvasElementRead {
  const CanvasElementRead({
    required this.id,
    required this.kind,
    required this.revision,
    required this.boundsWorld,
    required this.transform,
    required this.isLocked,
    required this.isTransformable,
  });

  final CanvasElementId id;
  final CanvasElementKind kind;
  final int revision;
  final Rect boundsWorld;
  final CanvasTransform transform;
  final bool isLocked;
  final bool isTransformable;
}

sealed class CanvasMoveResolution { const CanvasMoveResolution(); }

final class CanvasMoveCommit extends CanvasMoveResolution {
  const CanvasMoveCommit({required this.delta});
  final Offset delta;
}

final class CanvasMoveCancel extends CanvasMoveResolution {
  const CanvasMoveCancel({this.reason});
  final String? reason;
}
```

Resolver rules:

```text
- called once at selected move terminal pointer-up;
- not called during preview;
- not called if movement is zero;
- not called if selected movable set is empty;
- not called when gesture is cancelled by loadDocument/modeChange/dispose;
- reentrant public mutation from inside resolver throws StateError;
- returned delta must be finite;
- CanvasMoveCancel discards move commit and emits no action;
- resolver exception clears preview and rethrows through pointer handling boundary as runtime-safe error.
```

### 4.21 Errors and diagnostics

```dart
enum CanvasDataErrorCode {
  invalidJson,
  unsupportedSchemaVersion,
  missingField,
  invalidFieldType,
  forbiddenField,
  fieldMustNotBeEmpty,
  fieldMaxLength,
  fieldMustBeFinite,
  fieldMustBePositive,
  fieldMustBeNonNegative,
  fieldMustBeInRange,
  fieldMustBeInvertible,
  duplicateElementId,
  duplicateLayerId,
  duplicateResourceId,
  missingResourceReference,
  maxItems,
  maxNodes,
  maxRawJsonLength,
  invalidMetadata,
}

final class CanvasDataException implements Exception {
  const CanvasDataException({
    required this.code,
    required this.message,
    this.path,
    this.details = const {},
  });

  final CanvasDataErrorCode code;
  final String message;
  final String? path;
  final Map<String, Object?> details;
}

sealed class CanvasDiagnosticPolicy {
  const CanvasDiagnosticPolicy();
  const factory CanvasDiagnosticPolicy.disabled() = CanvasDiagnosticsDisabled;
  const factory CanvasDiagnosticPolicy.summary() = CanvasDiagnosticsSummary;
  factory CanvasDiagnosticPolicy.verbose({
    int maxPreviewLength = 256,
    int maxListEntries = 32,
  }) = CanvasDiagnosticsVerbose;
}

final class CanvasDiagnosticsDisabled extends CanvasDiagnosticPolicy {
  const CanvasDiagnosticsDisabled();
}

final class CanvasDiagnosticsSummary extends CanvasDiagnosticPolicy {
  const CanvasDiagnosticsSummary();
}

final class CanvasDiagnosticsVerbose extends CanvasDiagnosticPolicy {
  factory CanvasDiagnosticsVerbose({
    int maxPreviewLength = 256,
    int maxListEntries = 32,
  }) {
    CanvasDiagnosticPolicyValidators.requireVerboseLimits(
      maxPreviewLength: maxPreviewLength,
      maxListEntries: maxListEntries,
    );
    return CanvasDiagnosticsVerbose._(
      maxPreviewLength: maxPreviewLength,
      maxListEntries: maxListEntries,
    );
  }

  const CanvasDiagnosticsVerbose._({
    required this.maxPreviewLength,
    required this.maxListEntries,
  });

  final int maxPreviewLength;
  final int maxListEntries;
}
```

`CanvasDiagnosticPolicy.verbose` validates `maxPreviewLength` and
`maxListEntries` during construction and any runtime config materialization path.
The limits are owned by `section_06_validation_limits`.
Application code may type-test or pattern-match `CanvasRuntimeConfig.diagnosticPolicy`
as `CanvasDiagnosticsDisabled`, `CanvasDiagnosticsSummary`, or
`CanvasDiagnosticsVerbose`; verbose limits are public readable fields on
`CanvasDiagnosticsVerbose`.

`CanvasDataException` must not expose raw input, application objects, runtime
objects, images, handles, closures, canvases, or full document dumps. Raw failure
context remains internal to `DiagnosticsHub` or is projected only through
sanitized bounded `details`.

No public diagnostics stream is exported in v1. Diagnostics are projected only through `CanvasDataException` and test-only/internal sinks.

---
