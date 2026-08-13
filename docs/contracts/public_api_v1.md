<!-- CONTEXT:BEGIN -->
Registry id: `section_04_public_api_v1`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/contracts/public_api_v1.md`
Owns:
- 4. Public API v1: complete surface
Must read before editing:
- `section_00_status_and_scope` -> `docs/architecture/00_architecture_overview.md`
- `section_03_package_layout` -> `docs/architecture/02_package_boundaries.md`
Current owners:
- `contract`
Related diagrams:
- `c4_context`
- `dfd_public_edit`
- `seq_single_active_surface`
Required tests:
- `test.api_contract.public_readable_union_variants`
- `test.api_contract.preview_state_sealed_union`
- `test.api_contract.public_api_v1_compiles_as_written`
- `test.api_contract.public_api_no_unapproved_placeholders`
- `test.guardrails.public_api_declaration_checks`
- `test.guardrails.public_api_import_cycles`
- `test.api.canvas_transform`
- `test.api.canvas_field_update`
- `test.api_contract.canvas_field_update_static_semantics`
- `test.api_contract.no_undefined_public_type_references`
- `test.api_contract.public_exports_complete`
- `test.api_contract.example_public_boundary`
- `test.api_contract.dto_immutability`
- `test.api_contract.public_equality_policy`
- `test.api.typed_action_payloads`
- `test.api_contract.public_integration_compile_fixture`
- `test.api_contract.prepared_vector_public_api`
- `test.api.canvas_prepared_vector_lifecycle`
- `test.api.vector_preparation_cleanup`
- `test.api.vector_preparation_context`
- `test.api.vector_preparation_input_failure`
- `test.api.vector_preparation_private_adapter`
- `test.api.vector_preparation_retention`
- `test.interaction.context_action_request`
- `test.interaction.text_edit_stale_commit_guard`
- `test.runtime.text_editing_port`
- `test.surface.text_editing_overlay`
- `test.guardrails.text_surface_guardrail_checks`
- `test.runtime.dispose_lifecycle`
- `test.runtime.runtime_state_publication`
- `test.api.tool_port_settings`
- `test.surface.interactive_false_state_isolation`
- `test.surface.interactive_false_pending_line_preserved`
- `test.surface.single_active_surface`
- `test.surface.surface_resource_session_lifecycle`
- `test.surface.canvas_surface_layout_constraints`
- `test.api.runtime_surface_frame_bridge`
Guardrails:
- `api.integration_surface_complete`
- `api.public_exports_complete`
- `api.no_public_internal_load_types`
- `api.no_unapproved_document_load_inputs`
- `api.facades_do_not_export_internal`
- `api.public_types_complete`
- `api.public_api_compiles_as_written`
- `api.resource_source_app_key_publicly_readable`
- `api.preview_state_sealed_union_publicly_readable`
- `api.exported_dartdoc_complete`
- `api.public_class_modifiers_explicit`
- `api.no_public_api_import_cycles`
- `api.public_signature_shape`
- `api.no_undefined_public_type_references`
- `api.dto_immutability`
- `api.equality_policy_explicit`
- `api.id_validation_no_extension_type_escape`
- `interaction.text_edit_stale_commit_guard`
- `text.no_overlay_textpainter_measurement`
- `surface.editable_text_surface_only`
- `surface.interactive_false_pending_line_preserved`
Do not assume:
- no unregistered public API shape
- no unregistered field-update export
- no implementation-owner export
- no raw Map metadata as ordinary public DTO metadata; use CanvasMetadata
<!-- CONTEXT:END -->

## 4. Public API v1: complete surface

Dart declarations below are authoritative. Implementation must compile against these names and semantics.

### 4.1 Public exports

`lib/iwb_canvas_engine.dart` exports exactly the public names listed in
`docs/_registry/public_api_v1.yaml`.

That registry is the canonical machine-readable inventory for exported-name
completeness. This document owns the public API semantics, signature rules, and
declaration contracts for those names.

The registry also owns the `diagnostics_public_surface` membership
classification for diagnostics-facing Public API v1 declarations. That group is
metadata over exported names, must remain a subset of `public_exports`, and
initially contains `CanvasDiagnosticPolicy`, `CanvasDiagnosticsDisabled`,
`CanvasDiagnosticsSummary`, `CanvasDiagnosticsVerbose`, `CanvasDataException`,
and `CanvasDataErrorCode`. The classification does not add public API names or
change this document's semantic ownership of those declarations.

The registry's `public_exports` list is the current public barrel allow-list.
`api.public_exports_complete` rejects root-package exports that are absent from
that list and registry names that are missing from the root package public
barrel.

The root package does not expose named extension declarations in Public API v1.
Adding one later is a public API decision that requires an explicit registry and
signature traversal update; this clarification does not remove any approved v1
API, require a public API change, or change the package version.

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

External adapter static proof:

```text
test.api_contract.public_integration_compile_fixture proves that an
application-owned integration code can statically reference the public public integration surface
from an external package by importing only
package:iwb_canvas_engine/iwb_canvas_engine.dart.
```

That fixture must compile without `src/**`, package-internal or unregistered public symbols, or internal
runtime classes. It is compile-time coverage for the external operation
families an application integration needs: runtime lifecycle, state/document
observation, edit/load, selection/camera/tools, high-level commands,
actions/context-action requests, resources, and `CanvasSurface` construction
with public resolver/style inputs. Behavioral integration remains covered by the
focused runtime, interaction, and surface tests for those operation families.

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
CanvasInteractionRequestId
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
CanvasPointerTerminalCleanup
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
CanvasPreviewState and preview family types
CanvasActionCommitted
CanvasActionPayload and payload family types
CanvasContextActionRequested
CanvasContextActionTarget and target family types
CanvasMoveCommitRequest
CanvasResource and resource family types
CanvasDataException
CanvasPreparedVector
```

These runtime-owned records and snapshots, together with application-owned
lifecycle handles such as `CanvasPreparedVector`, may contain collections,
callbacks, widget state, or runtime-specific facts. `CanvasDataException` also
uses identity equality, but its public fields
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

final class CanvasInteractionRequestId {
  CanvasInteractionRequestId._(this.value);
  factory CanvasInteractionRequestId(String value) {
    CanvasIdValidators.requireInteractionRequestId(
      value,
      name: 'interactionRequestId',
    );
    return CanvasInteractionRequestId._(value);
  }
  final String value;
}
```

Validation:

```text
CanvasElementId  -> non-empty canonical string, no leading/trailing whitespace, length <= 256, no control characters.
CanvasLayerId    -> non-empty canonical string, no leading/trailing whitespace, length <= 256, no control characters.
CanvasResourceId -> non-empty canonical string, no leading/trailing whitespace, length <= 1024, no control characters.
CanvasResourceSource.appKey key -> non-empty raw string, no leading/trailing whitespace, length <= 1024, no control characters.
CanvasActionId   -> non-empty canonical string, no leading/trailing whitespace, length <= 256, no control characters.
CanvasInteractionRequestId -> non-empty canonical string, no leading/trailing whitespace, length <= 256, no control characters.
```

Generated ids:

```dart
CanvasElementId CanvasRuntime.generateElementId();   // e0, e1, ...
CanvasLayerId CanvasRuntime.generateLayerId();       // l0, l1, ...
CanvasResourceId CanvasRuntime.generateResourceId(); // r0, r1, ...
```

There is no public `CanvasRuntime.generateInteractionRequestId()`. The engine
generates interaction request ids for emitted interaction requests; application
code stores the id from the request and passes it back to guarded command seams.

Generated ids are unique within the current runtime.
`loadDocumentFromJson` resets id generators so that new generated ids do not
collide with loaded ids.

### 4.3 Field update patch semantics

The current API represents partial updates with a package-owned field update
intent type that has explicit absent, non-null set, and nullable clear
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
  Stream<CanvasContextActionRequested> get contextActionRequests;

  CanvasElementId generateElementId();
  CanvasLayerId generateLayerId();
  CanvasResourceId generateResourceId();

  void dispose();
}
```

`CanvasRuntime` is not a Flutter widget. It may be used in tests without mounting UI.
Construction always creates the default empty committed document and initializes
the runtime view camera from that default document's persisted camera. Public
runtime construction has no document or JSON load input. Applications that need
to install saved schema v1 content construct a runtime first and then call
`runtime.edits.loadDocumentFromJson(json)`. No public state notification is
emitted during construction; the initial `state.value` and `camera` getters
already reflect the default committed document and runtime view camera.
`state.value` is the single public runtime observation snapshot. Applications
that need repaint, cache, badge, toolbar, or save-state updates subscribe to
`state` and compare the public revision domains they care about.

Dispose contract:

```text
- dispose is idempotent;
- after dispose, mutating public operations throw StateError('CanvasRuntime is disposed.');
- readDocument after dispose is allowed and returns last committed immutable document;
- actions stream closes;
- contextActionRequests stream closes;
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
- mandatory v1 resource caches and retained main-output resource borrows are
  cleared without disposing app-provided `ui.Image` objects or
  `CanvasPreparedVector` wrappers; a prepared vector's private Picture remains
  application-owned.
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
such as structural, bounds, element visual, `backgroundRevision`,
`gridRevision`, projection, or resource descriptor revisions are not public API
fields. Surface style values are paint inputs and are also not public runtime
revision domains.

### 4.5 Runtime config

```dart
final class CanvasRuntimeConfig {
  const CanvasRuntimeConfig({
    this.pointerPolicy = CanvasPointerPolicy.defaultPolicy,
    this.initialMode = CanvasInteractionMode.move,
    this.initialDrawStyle = CanvasDrawStyle.defaultStyle,
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
    this.selectionStyle = CanvasSelectionStyle.defaultStyle,
    this.gridStyle = CanvasGridStyle.defaultStyle,
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
- public API facade exports the surface-owned CanvasSurface implementation;
- v1 supports one active CanvasSurface per CanvasRuntime;
- multiple CanvasSurface widgets may be active at the same time when each uses
  a different CanvasRuntime;
- a CanvasSurface is active from successful runtime attachment until detach or
  dispose completes; interactive=false surfaces are still active;
- attaching a second active CanvasSurface to the same CanvasRuntime throws
  StateError('CanvasRuntime already has an active CanvasSurface.') before
  pointer routing, paint, repaint-listener, or resourceResolver attachment side
  effects;
- successful attach installs the surface's internal runtime repaint listener,
  output cache, resource session, and stable main/overlay paint hosts only after
  the active-surface admission succeeds; these internals do not change the public
  constructor or any public DTO shape;
- after the active CanvasSurface detaches, another CanvasSurface may attach to
  the same CanvasRuntime;
- interactive=false disables pointer routing on CanvasSurface only;
- interactive=false still paints document;
- interactive=false does not mutate runtime mode, committed document, selection or resources;
- if interactive changes from true to false while a pointer session is active,
  CanvasSurface routes cancel cleanup before disabling further routing;
- pending preview state that is not owned by an active routed pointer session is
  preserved when interactive becomes false;
- pending line start and line preview are not active routed pointer sessions after
  their tap sample has completed; `interactive=false` preserves them until line
  cleanup, mode/tool change, prepared load cleanup, dispose, or terminal line
  decision;
- toggling interactive back to true resumes routing only for subsequent pointer events;
- CanvasSurface requires bounded Flutter layout width and height; if either
  axis is unbounded, it throws a FlutterError on the ordinary execution path
  instead of silently painting a zero-size surface;
- applications should place CanvasSurface in a finite-constraints parent such
  as SizedBox, Expanded, AspectRatio, or an equivalent layout owner;
- valid bounded layout remains a constant-time surface boundary check that
  returns the bounded constraint size and does not add runtime, frame, cache,
  painter, pointer, resource, or interaction work;
- CanvasSurface never mutates committed document directly;
- CanvasSurface routes pointer input into InteractionEngine: finite samples for
  usable coordinates and terminal cleanup input for non-finite up/cancel;
- CanvasSurface resourceResolver is the app-owned synchronous image/vector
  resolver for that surface;
- successful attach creates an empty `SurfaceResourceSession` for that active
  surface before paint can resolve image/vector assets;
- rejected attach creates no `SurfaceResourceSession` and performs no resolver,
  cache, pointer routing, paint, or repaint-listener side effects;
- replacing resourceResolver on the active CanvasSurface refreshes that
  surface's session generation and prevents old resolver results from being
  reused; the refresh is a surface-local main-layer invalidation and does not
  require public runtime state or overlay output changes;
- detach, dispose, or runtime swap removes the internal repaint listener, drops
  cached layer outputs, and drops the `SurfaceResourceSession`;
- CanvasSurface does not own or dispose app-provided `ui.Image` instances or
  `CanvasPreparedVector` wrappers; a prepared vector's private Picture remains
  application-owned.
```

### 4.7 Visual styles

```dart
final class CanvasSelectionStyle {
  factory CanvasSelectionStyle({
    Color color = const Color(0xFF1565C0),
    double strokeWidth = 1.0,
    double marqueeFillOpacity = 0.15,
    double haloWidth = 4.0,
  }) {
    CanvasStyleValidators.requireSelectionStyle(
      strokeWidth: strokeWidth,
      marqueeFillOpacity: marqueeFillOpacity,
      haloWidth: haloWidth,
    );
    return CanvasSelectionStyle._(
      color: color,
      strokeWidth: strokeWidth,
      marqueeFillOpacity: marqueeFillOpacity,
      haloWidth: haloWidth,
    );
  }

  static const defaultStyle = CanvasSelectionStyle._(
    color: Color(0xFF1565C0),
    strokeWidth: 1.0,
    marqueeFillOpacity: 0.15,
    haloWidth: 4.0,
  );

  const CanvasSelectionStyle._({
    required this.color,
    required this.strokeWidth,
    required this.marqueeFillOpacity,
    required this.haloWidth,
  });

  final Color color;
  final double strokeWidth;
  final double marqueeFillOpacity;
  final double haloWidth;
}

final class CanvasGridStyle {
  factory CanvasGridStyle({double strokeWidth = 1.0}) {
    CanvasStyleValidators.requireGridStyle(strokeWidth: strokeWidth);
    return CanvasGridStyle._(strokeWidth: strokeWidth);
  }

  static const defaultStyle = CanvasGridStyle._(strokeWidth: 1.0);

  const CanvasGridStyle._({required this.strokeWidth});

  final double strokeWidth;
}
```

Validation: all numeric fields finite and non-negative; opacity in `[0, 1]`.

### 4.8 Document DTOs

All public DTOs are immutable. Any constructor receiving caller-owned
`Iterable`, `List`, `Set`, `Map`, or metadata input must defensively copy,
deep-freeze nested metadata values where applicable, validate at runtime, and
expose only unmodifiable values. Public constructors accepting caller-provided
values with documented runtime validation or sanitization are non-const
factories, even when the values are scalar-only. `const` remains available only
for marker, empty, default, or private storage forms where invalid public state
cannot be constructed.

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
    CanvasCamera camera = CanvasCamera.origin,
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
  factory CanvasCamera({Offset offset = Offset.zero}) {
    CanvasGeometryValidators.requireBoundedOffset(offset, name: 'offset');
    return CanvasCamera._(offset: offset);
  }

  static const origin = CanvasCamera._(offset: Offset.zero);

  const CanvasCamera._({required this.offset});

  final Offset offset;
}

final class CanvasBackground {
  const CanvasBackground({
    this.color = const Color(0xFFFFFFFF),
    this.grid = CanvasGrid.disabled,
  });

  final Color color;
  final CanvasGrid grid;
}

final class CanvasGrid {
  factory CanvasGrid({
    bool enabled = false,
    double cellSize = 10.0,
    Color color = const Color(0x1F000000),
  }) {
    CanvasStyleValidators.requireGrid(
      enabled: enabled,
      cellSize: cellSize,
    );
    return CanvasGrid._(
      enabled: enabled,
      cellSize: cellSize,
      color: color,
    );
  }

  static const disabled = CanvasGrid._(
    enabled: false,
    cellSize: 10.0,
    color: Color(0x1F000000),
  );

  const CanvasGrid._({
    required this.enabled,
    required this.cellSize,
    required this.color,
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
Validated scalar value objects such as `CanvasCamera` and `CanvasGrid` expose
non-const public factories. Their approved defaults use private const storage
only for already-validated values that cannot expose invalid public state.
`CanvasDocument.camera` stores the persisted document default camera offset,
using the schema and readDocument round-trip semantics required by this contract. The same
`CanvasCamera` value type is also used by `CanvasCameraPort.camera` to report
the runtime view camera; runtime view camera offset is owned by
`CanvasCameraPort` and published through `CanvasRuntime.state`.

### 4.8.1 Codec API

```dart
const int canvasSchemaVersionWrite = 1;
const Set<int> canvasSchemaVersionsRead = {1};

Map<String, Object?> encodeCanvasDocument(CanvasDocument document);
String encodeCanvasDocumentToJson(CanvasDocument document);
```

These are public API declarations for schema v1 encoding and schema version
introspection. Public schema v1 JSON load is not a public decode helper; it is
the runtime command `CanvasEditPort.loadDocumentFromJson(String json)`. The
`CodecBoundary` contract owns canonical encoding and the internal validation
policy shared by runtime JSON load, while runtime load must not expose a public
`CanvasDocument` decode route or materialize a public DTO as its load input.

### 4.9 Geometry enums and transform

The current package exposes `CanvasTransform` as a six-component affine transform
with JSON shape `{a,b,c,d,tx,ty}` and Flutter canvas matrix conversion. The
public `CanvasTransform` keeps that complete behavior under the current API name.

```dart
enum CanvasElementKind {
  image,
  path,
  text,
  stroke,
  line,
  rect,
  vector,
}

enum CanvasPathFillRule {
  nonZero,
  evenOdd,
}

final class CanvasTransform {
  factory CanvasTransform({
    required double a,
    required double b,
    required double c,
    required double d,
    required double tx,
    required double ty,
  }) {
    CanvasGeometryValidators.requireFiniteTransformComponents(
      a: a,
      b: b,
      c: c,
      d: d,
      tx: tx,
      ty: ty,
    );
    return CanvasTransform._(
      a: a,
      b: b,
      c: c,
      d: d,
      tx: tx,
      ty: ty,
    );
  }

  static const identity = CanvasTransform._(
    a: 1,
    b: 0,
    c: 0,
    d: 1,
    tx: 0,
    ty: 0,
  );

  const CanvasTransform._({
    required this.a,
    required this.b,
    required this.c,
    required this.d,
    required this.tx,
    required this.ty,
  });

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

`CanvasTransform` remains the general public affine value type, so
`invert()` may return null for non-invertible math values. Admission into
`CanvasElement.transform` is stricter: public element DTO construction rejects
non-invertible element transforms with `fieldMustBeInvertible` before exposing
the DTO.

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

final class CanvasVectorElement extends CanvasElement {
  CanvasVectorElement({
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

Partial updates use `CanvasFieldUpdate` values within `CanvasElementUpdate`.

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

final class CanvasVectorElementUpdate extends CanvasElementUpdate {
  CanvasVectorElementUpdate({
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
- `CanvasElementUpdate.transform` accepts only finite invertible element
  transforms within the transform singular-value limits;
- dynamic or generated clear requests for non-nullable fields are rejected
  before draft mutation;
- dynamic or generated `CanvasElementUpdate.transform` values that are
  non-invertible are rejected with `fieldMustBeInvertible` before draft
  mutation.
- `CanvasVectorElement` and `CanvasVectorElementUpdate` use the same sparse
  resourceId, size, and nullable naturalSize shape as image values, but validate
  at `vector.size` and `vector.naturalSize`; intrinsic prepared-vector size is
  a paint source extent and never rewrites either document field.
```

Changed `CanvasEdit.updateElement` effects are field-granular and are compiled
by the edit contract's `Element update field-effect taxonomy`. The public API
owns the update DTO field names and validation shape; the edit contract owns
document revision, internal revision, spatial, projection, resource, repaint,
selection-normalization, no-op, and rollback effects for changed fields.

### 4.12 Edit API

```dart
abstract interface class CanvasEditPort {
  T edit<T>(T Function(CanvasEdit edit) fn);
  void loadDocumentFromJson(String json);
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
- addElement with id collision throws CanvasDataException duplicateElementId;
- image/vector resource elements with an absent id throw
  `CanvasDataException(code: CanvasDataErrorCode.missingResourceReference)` at
  `image.resourceId` or `vector.resourceId`; a present descriptor of the other
  kind throws the one public `CanvasDataErrorCode.resourceKindMismatch` at the
  same path;
- final-candidate relationship admission runs before an edit installs or
  publishes any partial document, so a resource plus all replacement references
  may be supplied in either callback order;
- removeUnusedResource fails with false if resource is referenced by any background/content element, including invisible or locked elements.
- clearContent removes every ordinary-layer element regardless of
  `isDeletable`, while preserving persisted background/grid metadata and the
  ordered background-element layer; when `removeUnusedResources` is true, it
  retains image and vector descriptors still referenced by those preserved
  background elements and removes only descriptors that are actually unused;
- CanvasEdit.removeElement is a low-level document edit and emits no user action event;
- CanvasEdit.clearContent is a low-level document edit and emits no user action event.
```

`CanvasEdit.setCameraOffset` changes the persisted document camera. It is a
document edit: changed offsets increment `state.revisions.document`, invalidate
the public `CanvasDocument` projection, and are visible through `readDocument`.
It never directly mutates the runtime view camera. Runtime construction
initializes the runtime view camera from the default persisted document camera.
Successful `loadDocumentFromJson` initializes the runtime view camera from the
installed schema v1 document's persisted camera.

Persisting the current runtime view camera is an explicit edit boundary:

```dart
runtime.edits.edit((edit) {
  edit.setCameraOffset(runtime.camera.offset);
});
```

`CanvasCameraPort` does not expose a camera persistence helper. Applications
that want the current view to become document state must cross the document edit
boundary explicitly.

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

`CanvasClearResult` lists only elements and descriptors actually removed by the
accepted clear. A retained-background-only clear is a no-op; a clear that only
releases unused descriptors returns those descriptor ids without claiming an
element removal.

### 4.13 High-level commands

High-level commands are public user-intent operations. They use EditKernel for
atomic mutation, but they own user action event emission. This keeps low-level
`CanvasEdit` usable for programmatic synchronization without polluting the app's
user-action notification stream.

`CanvasActionCommitted` is a user-action notification stream. It is not an
undo/redo journal. Undo/redo is application-owned, and v1 action payloads do not
carry inverse patches.

Runtime timestamp contract (`runtime_created_timestamps_monotonic`):

```text
- runtime-created timestampMs values are millisecond ordering tokens resolved by
  one CanvasRuntime, not wall-clock creation facts;
- nullable timestampMs inputs on command, selection, pointer, and double-tap
  boundaries are hints;
- each CanvasRuntime owns one internal timestamp cursor for timestamped runtime
  outputs;
- a new CanvasRuntime initializes that cursor to -1, so the first output with a
  null or backwards hint resolves to 0;
- when the runtime creates a timestamped output, it computes next as the
  previous resolved timestamp plus one;
- a non-null hint greater than or equal to next resolves to the hint value;
- a null hint or a hint less than next resolves to next;
- the resolved value becomes the new cursor value before the output is
  published;
- the monotonicity scope is one CanvasRuntime only; no global, process-wide, or
  cross-runtime ordering guarantee is made;
- stale host timestamps and host clock rollback are backwards hints and resolve
  to next;
- the primary proof covers CanvasActionCommitted.timestampMs and
  CanvasContextActionRequested.timestampMs;
- the same runtime-local resolver also applies to
  CanvasPendingLineStartPreview.timestampMs because pending line starts are
  timestamped runtime preview outputs;
- CanvasMoveCommitRequest is a resolver callback request, not a timestamped
  runtime output, and does not expose timestampMs;
- CanvasPendingLineStartPreview remains a preview output, not a user-action
  event;
- CanvasDocument, schema v1 data, resource state, selection state, document
  revisions, and preview revisions do not persist or reconstruct the timestamp
  cursor;
- no-op, stale rejection, rollback, cancel, `loadDocumentFromJson`, and dispose stream
  close paths do not create timestamped action or context request outputs.
- selected-move resolver callbacks do not resolve timestamps; only the accepted
  move action resolves the original terminal timestamp hint during action
  finalization after the resolver returns a finite non-zero delta and edit
  preparation succeeds;
- stale terminals, invalid terminals, no-op movement, cancel, resolver cancel,
  resolver zero delta, resolver exception, selected-move edit-preparation
  failure, rollback, load cleanup, dispose cleanup, invalid direct double tap,
  and unknown or already-consumed text request ids remain timestamp-silent.
```

```dart
abstract interface class CanvasCommandPort {
  bool removeElement(CanvasElementId id, {int? timestampMs});
  bool commitTextEdit(
    CanvasInteractionRequestId requestId,
    String newText, {
    int? timestampMs,
  });
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
- when a request id is unknown because no live `InteractionRequestRegistry`
  entry exists, commitTextEdit returns false and performs no document,
  selection, preview, interaction, action, timestamp, or request-consumption
  effect;
- commitTextEdit returns false when the request id is unknown or already
  consumed; unknown and already-consumed request ids perform no mutation,
  private request consumption, public state snapshot, document, selection,
  preview, spatial, projection, resource, repaint, or action effect;
- commitTextEdit returns false and privately consumes a known live request id in
  InteractionRequestRegistry when the request target is empty canvas, the
  request target is non-text content, the controller epoch changed, the current
  element is missing, the current element generation no longer matches the
  issued request, the current elementRevision changed, or the current element
  family no longer matches a text element;
- commitTextEdit private request consumption has no public state snapshot,
  document, selection, preview, spatial, projection, resource, repaint, or
  action effect;
- commitTextEdit validates newText through the existing text validation path
  before request consumption and before draft mutation;
- commitTextEdit treats documentRevision as an observation fact, not a stale
  guard, so unrelated document edits do not reject a still-current text edit;
- commitTextEdit returns true, consumes the request id, and emits no document
  revision, repaint, or action event when newText equals the current text;
- commitTextEdit changed-text commits run through EditKernel, consume the
  request after successful prepare, may compensate the target text element
  transform to preserve the resolved horizontal text anchor and top edit edge
  when measured text bounds change, and emit editText after atomic install;
- CanvasCommandPort.clearContent emits clearContent only when removedElementIds is not empty;
- if only unused resources are removed and no elements are removed, no user
  action event is emitted;
- command clear has the same layer-only scope as `CanvasEdit.clearContent`:
  it does not remove background/grid state, ordered background elements, or
  descriptors referenced by preserved background image/vector elements; a
  background-only retained state therefore no-ops without an action;
- command action payloads are emitted after atomic install;
- a clear action payload uses exactly the accepted `CanvasClearResult` removal
  ids, rather than preflight candidates;
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
- rotateSelectionClockwise, rotateSelectionCounterClockwise,
  flipSelectionVertical, and flipSelectionHorizontal use the center of the
  union bounds of eligible selected elements as `pivotWorld`;
- selection actions preserve document order in emitted elementIds.
```

### 4.15 Tools and pointer API

```dart
enum CanvasInteractionMode { move, draw }
enum CanvasDrawTool { pencil, marker, line, eraser }
enum CanvasPointerLifecyclePhase { down, move, up, cancel }

final class CanvasPointerPolicy {
  factory CanvasPointerPolicy({
    double tapSlop = 8.0,
    double doubleTapSlop = 24.0,
    int doubleTapMaxDelayMs = 300,
    bool deferSingleTap = true,
    double? dragStartSlop,
  }) {
    CanvasPointerValidators.requirePointerPolicy(
      tapSlop: tapSlop,
      doubleTapSlop: doubleTapSlop,
      doubleTapMaxDelayMs: doubleTapMaxDelayMs,
      dragStartSlop: dragStartSlop,
    );
    return CanvasPointerPolicy._(
      tapSlop: tapSlop,
      doubleTapSlop: doubleTapSlop,
      doubleTapMaxDelayMs: doubleTapMaxDelayMs,
      deferSingleTap: deferSingleTap,
      dragStartSlop: dragStartSlop,
    );
  }

  static const defaultPolicy = CanvasPointerPolicy._(
    tapSlop: 8.0,
    doubleTapSlop: 24.0,
    doubleTapMaxDelayMs: 300,
    deferSingleTap: true,
    dragStartSlop: 1.0,
  );

  const CanvasPointerPolicy._({
    required this.tapSlop,
    required this.doubleTapSlop,
    required this.doubleTapMaxDelayMs,
    required this.deferSingleTap,
    required this.dragStartSlop,
  });

  final double tapSlop;
  final double doubleTapSlop;
  final int doubleTapMaxDelayMs;
  final bool deferSingleTap;
  final double? dragStartSlop;
}

sealed class CanvasPointerInput {
  const CanvasPointerInput();
}

final class CanvasPointerSample extends CanvasPointerInput {
  factory CanvasPointerSample({
    required int pointerId,
    required Offset position,
    int? timestampMs,
    required CanvasPointerLifecyclePhase phase,
    required PointerDeviceKind kind,
  }) {
    CanvasPointerValidators.requirePointerSample(
      pointerId: pointerId,
      position: position,
      phase: phase,
    );
    return CanvasPointerSample._(
      pointerId: pointerId,
      position: position,
      timestampMs: timestampMs,
      phase: phase,
      kind: kind,
    );
  }

  const CanvasPointerSample._({
    required this.pointerId,
    required this.position,
    required this.timestampMs,
    required this.phase,
    required this.kind,
  });

  final int pointerId;
  final Offset position;
  final int? timestampMs;
  final CanvasPointerLifecyclePhase phase;
  final PointerDeviceKind kind;
}

final class CanvasPointerTerminalCleanup extends CanvasPointerInput {
  factory CanvasPointerTerminalCleanup({
    required int pointerId,
    required CanvasPointerLifecyclePhase phase,
    required PointerDeviceKind kind,
    int? timestampMs,
  }) {
    CanvasPointerValidators.requireTerminalCleanup(
      pointerId: pointerId,
      phase: phase,
      timestampMs: timestampMs,
    );
    return CanvasPointerTerminalCleanup._(
      pointerId: pointerId,
      phase: phase,
      kind: kind,
      timestampMs: timestampMs,
    );
  }

  const CanvasPointerTerminalCleanup._({
    required this.pointerId,
    required this.phase,
    required this.kind,
    required this.timestampMs,
  });

  final int pointerId;
  final CanvasPointerLifecyclePhase phase;
  final PointerDeviceKind kind;
  final int? timestampMs;
}

final class CanvasDrawStyle {
  factory CanvasDrawStyle({
    CanvasDrawTool tool = CanvasDrawTool.pencil,
    Color color = const Color(0xFF000000),
    double pencilThickness = 3.0,
    double markerThickness = 12.0,
    double markerOpacity = 0.4,
    double lineThickness = 3.0,
    double eraserThickness = 20.0,
  }) {
    CanvasStyleValidators.requireDrawStyle(
      pencilThickness: pencilThickness,
      markerThickness: markerThickness,
      markerOpacity: markerOpacity,
      lineThickness: lineThickness,
      eraserThickness: eraserThickness,
    );
    return CanvasDrawStyle._(
      tool: tool,
      color: color,
      pencilThickness: pencilThickness,
      markerThickness: markerThickness,
      markerOpacity: markerOpacity,
      lineThickness: lineThickness,
      eraserThickness: eraserThickness,
    );
  }

  static const defaultStyle = CanvasDrawStyle._(
    tool: CanvasDrawTool.pencil,
    color: Color(0xFF000000),
    pencilThickness: 3.0,
    markerThickness: 12.0,
    markerOpacity: 0.4,
    lineThickness: 3.0,
    eraserThickness: 20.0,
  );

  const CanvasDrawStyle._({
    required this.tool,
    required this.color,
    required this.pencilThickness,
    required this.markerThickness,
    required this.markerOpacity,
    required this.lineThickness,
    required this.eraserThickness,
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

  void handlePointer(CanvasPointerInput input);
  void handleDoubleTap({required Offset position, int? timestampMs});
}
```

Pointer policy semantics:

```text
- tapSlop controls terminal tap classification for point selection and
  context-tap recognition;
- dragStartSlop controls the first visible drag preview for selected move,
  marquee selection, and first-pointer line drag;
- the effective drag-start threshold is `dragStartSlop ?? tapSlop`;
- after a selected-move or marquee preview starts, dragStartSlop no longer
  suppresses move updates when the pointer returns inside the start radius;
- a gesture may publish a drag preview after effective drag-start slop and
  still resolve as a tap if its terminal position remains within tapSlop;
- doubleTapSlop is used only to match two tap terminals into a double tap.
```

Public tool-port behavior:

```text
- CanvasRuntime.tools is non-throwing for mode, draw style, pointer
  policy, and handlePointer dispatch;
- the runtime's configured initial mode, draw style, and pointer policy are
  visible immediately after construction without a construction-time
  `state.revisions.interaction` increment;
- effective post-construction mode, style, tool, color, or pointer-policy
  changes increment `state.revisions.interaction`;
- setter no-ops publish no state and create no timestamped output;
- mode/tool/pointer-policy changes request interaction cleanup before
  publishing their public state;
- entering draw mode clears selection in the same public state only when
  `CanvasRuntimeConfig.clearSelectionOnDrawModeEnter` is true;
- entering draw mode with `clearSelectionOnDrawModeEnter` false does not clear
  selection;
- `CanvasPointerInput` is the sealed public dispatch input; concrete finite
  samples and no-position terminal cleanup input own their own validation and
  equality policies;
- `CanvasPointerSample` carries finite view coordinates for any lifecycle
  phase, including finite `up` and `cancel`;
- `CanvasPointerTerminalCleanup` carries invalid terminal cleanup intent
  without coordinates and is valid only for `up` and `cancel`;
- draw-mode pointer input is a behavior no-op except for cleanup-capable
  terminal handling; pencil, marker, line, eraser, text, and context-action
  production behavior remains tool-owned scope;
- terminal cleanup input routes through the same runtime pointer admission and
  invalid-terminal cleanup owner as finite terminal samples; it does not create
  document commits, user actions, context requests, resolver requests, or
  timestamped runtime outputs;
- `CanvasRuntime.contextActionRequests` is a non-throwing empty broadcast
  stream that closes on dispose.
```

`CanvasToolPort.handleDoubleTap` accepts a finite host-recognized double-tap
view position, does not require pending first-tap history, and emits at most one
asynchronous context-action request after candidate spatial admission with all
candidate handles resolved to current immutable facts. Invalid positions and
unreliable target reads are rejected before target resolution and request
emission. Pending request delivery is suppressed if load/dispose cleanup runs
before the scheduled delivery microtask. Delivery has no document, selection,
preview, repaint, spatial, projection, resource, or action effect.

Validation:

```text
pointer slops -> finite >= 0;
doubleTapMaxDelayMs -> >= 0;
dragStartSlop -> null or finite >= 0;
pencil/marker/line/eraser thickness -> finite > 0;
markerOpacity -> finite in [0, 1];
pointer sample position -> finite for every phase;
terminal cleanup phase -> up or cancel only;
pointerId and timestampMs -> >= 0 when present.
```

Pointer scope for v1:

```text
- pointerId is used only to route pointer input and reject stale terminal
  samples or stale terminal cleanup input;
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
document camera. Persisting `camera` or `offset` requires the explicit
`CanvasEdit.setCameraOffset(runtime.camera.offset)` edit shown in the edit
contract.

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

final class CanvasVectorResource extends CanvasResource {
  CanvasVectorResource({
    required super.id,
    required super.source,
    super.contentHash,
    super.byteLength,
    super.metadata,
  });
}

sealed class CanvasResourceSource {
  const CanvasResourceSource();
  factory CanvasResourceSource.appKey(String key) {
    CanvasResourceValidators.requireAppKey(key, name: 'key');
    return CanvasAppKeyResourceSource._(key);
  }
}

final class CanvasAppKeyResourceSource extends CanvasResourceSource {
  factory CanvasAppKeyResourceSource(String key) {
    CanvasResourceValidators.requireAppKey(key, name: 'key');
    return CanvasAppKeyResourceSource._(key);
  }

  const CanvasAppKeyResourceSource._(this.key);

  final String key;
}
```

Application code may type-test or pattern-match either resource source as
`CanvasAppKeyResourceSource` and read `key` without importing `src/**`.
`CanvasImageResource` and `CanvasVectorResource` are the sealed descriptor
kinds. Their subtype, never nullable `mimeType`, determines descriptor kind;
the vector descriptor has no MIME inference or serialized vector bytes.

Resolver:

```dart
abstract interface class CanvasResourceResolver {
  ui.Image? resolveImage(CanvasImageResource resource);
  CanvasPreparedVector? resolveVector(CanvasVectorResource resource);
}
```

v1 resource rules:

```text
- CanvasResourceSource.appKey is mandatory for v1 resource sources;
- CanvasResourceSource.appKey stores the application-owned identity exactly as
  supplied; no trimming or canonicalization is applied;
- CanvasResourceSource.appKey key must be non-empty, have no leading/trailing
  whitespace, have raw length <= 1024, and contain no control characters;
- no engine IO;
- no asset-bundle loading;
- no file loading;
- no remote/network loading;
- resourceResolver is synchronous in v1;
- all ui.Image objects and CanvasPreparedVector wrappers returned by
  CanvasResourceResolver are app-owned;
- the engine never disposes app-provided images or prepared-vector wrappers;
- the runtime stores only resource descriptors and render cache references;
- resolved image/vector references can be retained by the active
  `SurfaceResourceSession` and the active CanvasSurface main output;
- markResourceDirty synchronously releases matching active session and retained
  main-output references for the target resource before public publication, but
  does not mutate document, call the resolver, or dispose an application asset;
- markResourceDirty publishes main repaint intent; an attached CanvasSurface
  observes it if present and rebuilds only main-layer output unless another
  runtime or local surface invalidation target also requires overlay work;
- resolver must return a stable visual result for the same resource descriptor
  unless the app calls markResourceDirty/markAllResourcesDirty.
```

### 4.18 Preview state

The current API exposes read-only preview state because applications need to
render pending line, stroke, marquee, eraser, and selected-move previews without
being able to construct impossible cross-kind states.

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

sealed class CanvasPreviewState {
  const CanvasPreviewState();

  const factory CanvasPreviewState.none() = CanvasNoPreview;
  const factory CanvasPreviewState.marquee({
    required Rect rect,
  }) = CanvasMarqueePreview;
  const factory CanvasPreviewState.selectedMove({
    required Offset delta,
  }) = CanvasSelectedMovePreview;
  factory CanvasPreviewState.pencilStroke({
    required Iterable<Offset> points,
    required Color color,
    required double thickness,
    required double opacity,
  }) = CanvasPencilStrokePreview;
  factory CanvasPreviewState.markerStroke({
    required Iterable<Offset> points,
    required Color color,
    required double thickness,
    required double opacity,
  }) = CanvasMarkerStrokePreview;
  const factory CanvasPreviewState.pendingLineStart({
    required Offset start,
    required int timestampMs,
    required Color color,
    required double thickness,
  }) = CanvasPendingLineStartPreview;
  const factory CanvasPreviewState.linePreview({
    required Offset start,
    required Offset end,
    required Color color,
    required double thickness,
  }) = CanvasLinePreview;
  factory CanvasPreviewState.eraser({
    required Iterable<Offset> corridor,
    required double thickness,
  }) = CanvasEraserPreview;

  CanvasPreviewKind get kind;
}

final class CanvasNoPreview extends CanvasPreviewState {
  const CanvasNoPreview();

  @override
  CanvasPreviewKind get kind => CanvasPreviewKind.none;
}

final class CanvasMarqueePreview extends CanvasPreviewState {
  const CanvasMarqueePreview({required this.rect});
  final Rect rect;

  @override
  CanvasPreviewKind get kind => CanvasPreviewKind.marquee;
}

final class CanvasSelectedMovePreview extends CanvasPreviewState {
  const CanvasSelectedMovePreview({required this.delta});
  final Offset delta;

  @override
  CanvasPreviewKind get kind => CanvasPreviewKind.selectedMove;
}

sealed class CanvasStrokePreview extends CanvasPreviewState {
  const CanvasStrokePreview();
  List<Offset> get points;
  Color get color;
  double get thickness;
  double get opacity;
}

final class CanvasPencilStrokePreview extends CanvasStrokePreview {
  CanvasPencilStrokePreview({
    required Iterable<Offset> points,
    required this.color,
    required this.thickness,
    required this.opacity,
  }) : points = List.unmodifiable(points);

  @override
  final List<Offset> points;
  @override
  final Color color;
  @override
  final double thickness;
  @override
  final double opacity;

  @override
  CanvasPreviewKind get kind => CanvasPreviewKind.pencilStroke;
}

final class CanvasMarkerStrokePreview extends CanvasStrokePreview {
  CanvasMarkerStrokePreview({
    required Iterable<Offset> points,
    required this.color,
    required this.thickness,
    required this.opacity,
  }) : points = List.unmodifiable(points);

  @override
  final List<Offset> points;
  @override
  final Color color;
  @override
  final double thickness;
  @override
  final double opacity;

  @override
  CanvasPreviewKind get kind => CanvasPreviewKind.markerStroke;
}

final class CanvasPendingLineStartPreview extends CanvasPreviewState {
  const CanvasPendingLineStartPreview({
    required this.start,
    required this.timestampMs,
    required this.color,
    required this.thickness,
  });

  final Offset start;
  final int timestampMs;
  final Color color;
  final double thickness;

  @override
  CanvasPreviewKind get kind => CanvasPreviewKind.pendingLineStart;
}

final class CanvasLinePreview extends CanvasPreviewState {
  const CanvasLinePreview({
    required this.start,
    required this.end,
    required this.color,
    required this.thickness,
  });

  final Offset start;
  final Offset end;
  final Color color;
  final double thickness;

  @override
  CanvasPreviewKind get kind => CanvasPreviewKind.linePreview;
}

final class CanvasEraserPreview extends CanvasPreviewState {
  CanvasEraserPreview({
    required Iterable<Offset> corridor,
    required this.thickness,
  }) : corridor = List.unmodifiable(corridor);

  final List<Offset> corridor;
  final double thickness;

  @override
  CanvasPreviewKind get kind => CanvasPreviewKind.eraser;
}
```

Rules:

```text
- preview state is immutable;
- CanvasPreviewState variants represent the only valid preview payload shapes;
- CanvasPreviewKind remains a stable read-only discriminator;
- CanvasStrokePreview owns shared pencil and marker preview facts;
- pencil, marker, and eraser iterable inputs are copied into unmodifiable lists;
- selected ids, pointer tokens, active pointer ids, and session ids are not
  public preview payload;
- every pointer preview update creates a small new snapshot or reuses previous unchanged snapshot;
- no CanvasDocument materialization in preview getters;
- pending line start is epoch-bound;
- `loadDocumentFromJson` prepared cleanup before install clears preview;
- `loadDocumentFromJson` failure preserves preview;
- selected move preview is main-scene preview, not overlay-only preview.
- consumers use type testing or pattern matching on concrete preview variants.
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
  editText,
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

final class CanvasTextEditActionPayload extends CanvasActionPayload {
  const CanvasTextEditActionPayload({
    required this.requestId,
    required this.previousTextLength,
    required this.nextTextLength,
  });

  final CanvasInteractionRequestId requestId;
  final int previousTextLength;
  final int nextTextLength;
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
- CanvasTextEditActionPayload carries text lengths only and never raw previous
  or next text content;
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
| guarded text edit changed commit | yes | `editText` | `CanvasTextEditActionPayload` |
| guarded text edit stale/no-op commit | no | — | — |
| loadDocumentFromJson | no | — | — |
| set camera/background/grid/palette | no | — | — |
| markResourceDirty | no | — | — |

Context-action request event:

```dart
enum CanvasContextActionTrigger { doubleTap }

final class CanvasContextActionRequested {
  CanvasContextActionRequested({
    required this.requestId,
    required this.trigger,
    required this.target,
    required this.controllerEpoch,
    required this.documentRevision,
    required this.timestampMs,
    required this.viewPosition,
    required this.worldPosition,
  });

  final CanvasInteractionRequestId requestId;
  final CanvasContextActionTrigger trigger;
  final CanvasContextActionTarget target;
  final int controllerEpoch;
  final int documentRevision;
  final int timestampMs;
  final Offset viewPosition;
  final Offset worldPosition;
}

sealed class CanvasContextActionTarget {
  const CanvasContextActionTarget();
}

final class CanvasContentElementContextActionTarget
    extends CanvasContextActionTarget {
  CanvasContentElementContextActionTarget({
    required this.elementSnapshot,
    required this.boundsWorld,
  });

  final CanvasElement elementSnapshot;
  final Rect boundsWorld;
}

final class CanvasEmptyCanvasContextActionTarget
    extends CanvasContextActionTarget {
  const CanvasEmptyCanvasContextActionTarget();
}
```

Context-action and text editing model:

```text
- when there is no context-action request producer, `contextActionRequests` is an
  empty broadcast stream that closes on dispose;
- direct `CanvasToolPort.handleDoubleTap` is a supported host-recognized
  double-tap input that can emit one asynchronous context-action request after
  candidate spatial admission with all candidate handles resolved to current
  immutable facts;
- engine behavior detects an accepted double-tap context target after
  candidate spatial admission;
- rejected invalid-index, stale-index, budget-exceeded, and
  unresolved/skipped-candidate target reads emit no context request; stale,
  budget, and unresolved/skipped-candidate rejected reads record bounded
  interaction diagnostics, while invalid-index rejected reads record none;
- engine queues exactly one asynchronous CanvasContextActionRequested for the
  accepted target and delivers it through contextActionRequests unless
  load/dispose cleanup suppresses pending context requests before the scheduled
  delivery microtask;
- trigger is CanvasContextActionTrigger.doubleTap;
- target is either CanvasContentElementContextActionTarget or
  CanvasEmptyCanvasContextActionTarget;
- content-element targets carry an immutable public CanvasElement snapshot and
  boundsWorld;
- empty-canvas targets carry no element snapshot;
- application decides whether to display a context menu first, call
  CanvasRuntime.textEditing.startFromContextAction(request), or mount the
  official CanvasTextEditingOverlay with inlineEditOnDoubleTap enabled;
- CanvasRuntime owns one active CanvasTextEditSession through
  CanvasTextEditingPort.activeSession; starting a text session consumes only
  current text content-target requests and returns null for empty-canvas,
  non-text, stale, family-mismatched, read-only, unknown, or already-consumed
  requests;
- active editing suppresses the original frame text paint through frame output
  and must not mutate CanvasTextElement.isVisible, remove the element from hit
  or context membership, or change document visibility as a hide/show bridge;
- CanvasTextEditSession.updateText updates live session text and live measured
  geometry without committing document state; commit() delegates to the guarded
  text command path and dismiss() exits without document or action effects;
- application commits request-originated text changes through
  CanvasCommandPort.commitTextEdit(requestId, newText) or the active session
  commit() helper;
- request facts are live and consumed/removed once rather than kept as durable
  registry state; unknown and already-consumed ids are no-effect false
  results;
- direct CanvasEdit.updateElement(CanvasTextElementUpdate) remains available
  for programmatic non-request synchronization;
- documentRevision is emitted as an observation and diagnostics fact, not a
  DiagnosticsHub write and not a stale-rejection guard; unrelated document
  edits do not reject a still-current text edit;
- CanvasTextEditingOverlay is a public Flutter helper owned by surface; it uses
  EditableText, consumes CanvasTextEditingPort.activeSession, supports
  configurable auto-start, max-height scroll, cursor/selection hooks, escape
  dismissal, focus-loss commit, and multiline growth from session geometry;
- while an inline text session is active, CanvasTextEditSession.geometry
  preserves the session-start resolved horizontal text anchor and the top edge
  of the edit bounds as live text width or line count changes; committing the
  session applies the same anchor-preserving behavior to the committed text
  element;
- custom overlays may replace CanvasTextEditingOverlay using only
  CanvasTextEditingPort.activeSession plus session geometry/style/liveText
  without importing src/**, recomputing text bounds, mutating visibility, or
  changing the inline-edit anchor contract above;
- context menus, app-specific editor decoration, focus policy choices,
  accessibility presentation, and text selection controls remain application
  responsibilities;
- `loadDocumentFromJson` success changes controllerEpoch, which makes existing
  interaction request ids stale; after runtime disposal, commitTextEdit follows
  the existing mutating public operation rule and throws
  StateError('CanvasRuntime is disposed.').
```

Text editing public surface:

```dart
final class CanvasTextEditGeometry {
  const CanvasTextEditGeometry({
    required this.paintBoundsWorld,
    required this.editBoundsWorld,
    required this.transform,
    required this.maxWidth,
    this.editBoundsLocal,
  });

  final Rect paintBoundsWorld;
  final Rect editBoundsWorld;
  final CanvasTransform transform;
  final double? maxWidth;
  final Rect? editBoundsLocal;
}

final class CanvasTextEditStyle {
  const CanvasTextEditStyle({
    required this.fontSize,
    required this.fontFamily,
    required this.isBold,
    required this.isItalic,
    required this.isUnderline,
    required this.color,
    required this.textAlign,
    required this.textDirection,
    required this.lineHeight,
  });

  final double fontSize;
  final String? fontFamily;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final Color color;
  final TextAlign textAlign;
  final TextDirection textDirection;
  final double? lineHeight;
}

final class CanvasTextEditSession {
  final CanvasElementId elementId;
  final CanvasInteractionRequestId requestId;
  final int documentRevision;
  final int elementRevision;
  final int generation;
  final String initialText;
  String get liveText;
  CanvasTextEditGeometry get geometry;
  CanvasTextEditStyle get style;
  bool get isActive;
  bool get isStale;

  void updateText(String text);
  bool commit({int? timestampMs});
  void dismiss();
}

abstract interface class CanvasTextEditingPort {
  ValueListenable<CanvasTextEditSession?> get activeSession;
  bool get readOnly;

  CanvasTextEditSession? sessionCandidateFor(
    CanvasContextActionRequested request,
  );
  CanvasTextEditSession? start(CanvasTextEditSession session);
  CanvasTextEditSession? startFromContextAction(
    CanvasContextActionRequested request,
  );
  void setReadOnly(bool value);
  void dismissActive();
}

final class CanvasTextEditingOverlay extends StatefulWidget {
  const CanvasTextEditingOverlay({
    required this.runtime,
    this.inlineEditOnDoubleTap = false,
    this.maxEditorHeight,
    this.cursorColor = const Color(0xFF1565C0),
    this.selectionColor = const Color(0x331565C0),
    this.backgroundCursorColor = const Color(0x00000000),
    this.selectionControls,
    this.autofocus = true,
    this.commitOnFocusLoss = true,
    this.dismissOnEscape = true,
    super.key,
  });

  final CanvasRuntime runtime;
  final bool inlineEditOnDoubleTap;
  final double? maxEditorHeight;
  final Color cursorColor;
  final Color selectionColor;
  final Color backgroundCursorColor;
  final TextSelectionControls? selectionControls;
  final bool autofocus;
  final bool commitOnFocusLoss;
  final bool dismissOnEscape;
}

// CanvasRuntime exposes:
// CanvasTextEditingPort get textEditing;
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
  });

  final CanvasDocumentSummary documentSummary;
  List<CanvasElementRead> get movedElements;
  final Offset proposedDelta;
  final Rect selectionBoundsWorld;
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
- not called when gesture is cancelled by `loadDocumentFromJson`/modeChange/dispose;
- reentrant public mutation from inside resolver throws StateError;
- returned delta must be finite;
- CanvasMoveCancel discards move commit and emits no action;
- a zero returned delta discards move commit and emits no action;
- resolver callback requests are not timestamped runtime outputs;
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
  invalidVectorData,
  resourceKindMismatch,
}

final class CanvasDataException implements Exception {
  factory CanvasDataException({
    required CanvasDataErrorCode code,
    required String message,
    String? path,
    Map<String, Object?> details = const {},
  }) {
    return CanvasDataException._(
      code: code,
      message: message,
      path: path,
      details: sanitizeCanvasErrorDetails(details),
    );
  }

  const CanvasDataException._({
    required this.code,
    required this.message,
    required this.path,
    required this.details,
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
sanitized, bounded, deeply immutable `details`. The public factory sanitizes
details once at construction, so later caller mutation cannot change public
exception state.

No public diagnostics stream is exported in v1. Diagnostics are projected only
through `CanvasDataException` and test-only/internal sinks. Public diagnostics
policy and exception declarations are classified in
`docs/_registry/public_api_v1.yaml` under `diagnostics_public_surface` so
`diagnostics.sanitized_public_projection` can traverse the registry-owned
diagnostics public surface with analyzer-resolved signatures.

---

### 4.22 Vector preparation

```dart
final class CanvasPreparedVector {
  final Size intrinsicSize;

  void dispose();
}

Future<CanvasPreparedVector> prepareVector(
  ByteData bytes, {
  BuildContext? context,
});
```

`CanvasPreparedVector` has no public constructor, liveness flag, raw
`ui.Picture`, upstream type, or preparation diagnostics. Only `prepareVector`
constructs it. It has default identity equality as classified in §4.1.2.
`dispose` is application-owned and idempotent; it releases the owned Picture
once and later calls do nothing.

`prepareVector` accepts only the supplied `ByteData` view. It rejects a view
larger than `32 * 1024 * 1024` bytes with `CanvasDataException` code
`fieldMaxLength` at `vector.bytes` before copying or upstream work. It copies
exactly that view before its first await, captures the supplied effective
locale and text direction at invocation, and does not retain the caller bytes
or `BuildContext` after completion.

The helper accepts precompiled raster-free vector bytes only; it performs no
file, asset, network, or external lookup. A failure of the selected upstream
preparation Future is projected as `CanvasDataException` code
`invalidVectorData` at `vector.bytes`, without an upstream error identity,
message, or stack-trace contract. On success, intrinsic size uses the existing
finite, positive, maximum-size validation under `vector.intrinsicSize`; a
rejected intrinsic disposes its unpublished Picture before the validation
error propagates.

---
