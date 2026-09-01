<!-- CONTEXT:BEGIN -->
Registry id: `section_02_architecture_model`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/architecture/01_runtime_ownership.md`
Owns:
- 2. Runtime ownership model
Must read before editing:
- `section_00_status_and_scope` -> `docs/architecture/00_architecture_overview.md`
Current owners:
- `architecture`
Related diagrams:
- `c4_container`
- `c4_component_runtime`
- `generated/actual_vs_expected_diff`
- `generated/full_architecture`
- `state_runtime_lifecycle`
Required tests:
- `test.guardrails.blocking_suite`
- `test.selection.runtime_owner_separation`
Guardrails:
- `core.single_runtime_root`
- `selection.owner_separate_from_document`
Do not assume:
- no public facade bypass
- no controller shape
<!-- CONTEXT:END -->

## 2. Runtime ownership model

The package provides the canvas runtime. It does not store application domain
state.

```text
Application domain state
  -> lives in the application;
  -> may reference canvas element ids;
  -> is not stored inside engine core.

Canvas engine state
  -> canvas document;
  -> elements;
  -> resources;
  -> selection;
  -> camera;
  -> modes and preview;
  -> render/cache/spatial/runtime state.
```

Runtime responsibilities are split as follows:

| Zone | Owns | Must not do |
|---|---|---|
| Public API | stable DTOs, operations, events, errors, and application-owned prepared vector values | expose tables, handles, caches, runtime internals, raw Picture liveness, or upstream types |
| DocumentStoreKernel | committed document state, document revisions, resource descriptors, public document projection cache, coherent appearance reads | read gesture state, selection state, Flutter widget state, or a second stored appearance value |
| FrameFactsPort | immutable committed frame facts for capture, row resolution, descriptor snapshots, and resourceRevision | expose store tables, public document projections, drafts, mutations, selection facts, or frame-owned render models |
| SelectionKernel | runtime selected ids, selectionRevision, selection normalization, content-only filtering | store committed document content, selected-order cache, or public API types |
| EditKernel | synchronous edit sessions, draft, touched sets, cross-owner commit/rollback coordination | perform paint or pointer routing |
| InteractionEngine | pointer sessions, immutable selected-move participant basis/conflict state, tools, preview state, terminal commit requests, interaction request guard facts, target pointer cleanup coordinator composition | read or mutate DocumentStoreKernel directly; store Flutter text editor session state |
| CanvasTextEditingPort | single runtime-owned active text edit session, read-only admission, live text geometry/style projection, guarded commit/dismiss lifecycle | own Flutter IME/editor widgets, mutate document visibility to hide text, or replace context-action ownership |
| FrameEngine | frame-internal facade for capture, planning, painter input assembly, and repaint buses; target composition owner for frame-private collaborators | read concrete DocumentStoreKernel internals, export public document, own selection, or expose frame collaborators outside `lib/src/frame/**` |
| ResourceKernel | resource API, committed catalog reads through `ResourceCatalogPort`, dirty resource ids, resource visual state publication, dirty outcomes for runtime target/all release | own app domain assets, resolved image/vector references, or committed descriptors |
| SurfaceResourceSession | surface-scoped resolver reference, resolverGeneration, ResourceAssetCache, typed resource-asset resolution, resolver budget, same-frame null-result suppression, bounded placeholders, and synchronous cache/suppression wrapper-borrow retirement before its narrow retained-output release callback | own committed descriptors, public runtime state, Flutter widget lifecycle, or application assets/Pictures |
| CanvasSurface | Flutter lifecycle, active-surface listener attachment, transient layer output cache, identity-aware retained main-output target/all wrapper-borrow release, local surface invalidation keys, and main/overlay paint hosts | decide interaction repaint policy, own frame planning, own resource descriptors, or dispose application assets/Pictures |
| SpatialKernel | coarse candidate lookup, outlier policy | be the document source of truth |
| CodecBoundary | schema v1 encode/decode, validation, diagnostics | depend on Flutter widgets or gestures |
| DiagnosticsHub | internal diagnostic records, public error projection | add a public stream without an API decision |

Public runtime observation is owned by `RuntimeRoot`. It publishes the single
`CanvasRuntime.state` listenable as immutable `CanvasRuntimeState` snapshots
after accepted document, selection, preview, view camera, resource visual,
interaction, or epoch changes. Downstream owners contribute facts through their
own boundaries; they do not own the public snapshot object or depend on Flutter
widget state to publish core runtime state.

`CanvasRuntime.readAppearance` is a synchronous facade-to-`RuntimeRoot`-to-Store
read. `DocumentStoreKernel` captures one committed aggregate and returns only
its background color, grid, and palette without entering `DocumentProjectionCache`
or traversing unrelated document owners. The read neither changes state nor
publishes it: during an edit it exposes the last installed committed values,
after successful installation it exposes the new values, rollback retains the
old values, and disposal keeps the final committed appearance readable.

Raster-free vector preparation is a separate public API boundary, not a runtime
or resource-session route. It captures the invocation context while preparing
caller bytes and returns an application-owned prepared value; only the
application disposes that value and its private Picture. `RuntimeRoot` and
`ResourceKernel` neither retain nor dispose prepared-vector wrappers or
Pictures. The active `SurfaceResourceSession` cache and `CanvasSurface` retained
main output may temporarily borrow a wrapper for paint; both synchronously drop
only those borrows on target/all release, replacement, reset, or drop and never
dispose the wrapper or its Picture. The application owns wrapper publication and
freshness across resource ids and attached runtime/surface aliases: it publishes
a current value before attaching it, synchronously releases every old alias
before disposal, and discards an out-of-order completion without publication.
Engine generation or revision keys are not application-visible lifecycle state.

Runtime-to-surface repaint routing has a separate internal surface-frame seam.
`RuntimeRoot` aggregates operation, interaction, camera, resource, load, and
fallback repaint intent into `CanvasSurfaceRepaintTarget` before Flutter surface
output construction. The runtime-surface bridge publishes that target with the
current runtime state for the active surface token only. `CanvasSurface` owns the
transient `SurfaceFrameOutputCache`, local input invalidation mapping, output
notifier publication, and the independent main/overlay paint hosts. `FrameEngine`
still owns frame output construction and `FrameRepaintSignal` metadata inside
immutable main/overlay outputs; that frame-owned signal must not be read as
ownership of pre-output surface invalidation scheduling.

Frame, cache, lifecycle, and public edit diagrams use this public runtime state
model: `CanvasRuntime.state` carries runtime-visible revisions, runtime view
camera is distinct from persisted document camera, and no separate public
listener getter is a diagram seam.

The target `PointerToolCleanupCoordinator` is an internal
`InteractionEngine` collaborator and cleanup policy seam. `InteractionEngine`
owns its composition and is the only caller. Tool machines may return typed
cleanup requests to `InteractionEngine`, but they must not call the coordinator
directly. The coordinator calculates an effect-only `PointerCleanupOutcome`
from interaction-owned state and request ownership context; it does not publish
runtime state, emit actions or context requests, schedule repaints, call
resolvers, open edits, read stores or selection internals, or become a second
state store.

Camera ownership is split deliberately:

```text
Runtime view camera
  -> owned by RuntimeRoot/CanvasCameraPort;
  -> published through state.revisions.viewCamera;
  -> repaints affected surfaces;
  -> does not dirty document state or invalidate CanvasDocument projection.

Persisted document camera
  -> owned by DocumentStoreKernel as committed document content;
  -> stored in CanvasDocument and schema v1;
  -> changed only through CanvasEdit.setCameraOffset or document replacement;
  -> read back through readDocument.
```

Gesture decisions may need committed facts such as controller epoch,
selection ids, movable flags, text snapshots, and bounds. Document facts enter
`InteractionEngine` through `InteractionReadPort`, the target read-only
interaction query boundary owned by the runtime/document interaction boundary.
Selection facts enter through intent-specific selection query boundaries owned
by the runtime/selection boundary and may be batched into `InteractionReadPort`
responses when the interaction intent needs document order plus selected ids.
The port returns only immutable, batched, intent-specific facts: hit/order
facts, immutable element snapshots, `boundsWorld`, element generation,
`elementRevision`, `CanvasElementKind` as the sole semantic target
discriminator, `controllerEpoch`, visibility, and top-hit status. It must not
expose mutation APIs, draft access, `CanvasDocument`
projection, store internals, resource/session internals, selection internals, or
per-property concrete owner probes. Committed mutations requested by interaction
still go through `EditKernel`.

For selected move, that one start response becomes the session-owned immutable
participant basis (id, generation, revision, transform, bounds, prior
selection, token/session/epoch). RuntimeRoot remains the accepted-change
delivery owner: before publishing an edit or selection outcome, it routes the
accepted touched ids and selection change to InteractionEngine. Interaction
cancels only when this basis conflicts; it neither compares a global document
revision nor keeps a persistent generation mirror. Frame receives the active
basis membership as an input, so selected-move paint cannot recruit objects
that become selectable/transformable after pointer-down.

`RuntimeRoot` materializes `CanvasRuntimeConfig.eraserElementKinds` once and
passes only that runtime-owned policy to its `InteractionReadPort` adapter.
After eraser facts resolve, the shared adapter admits `CanvasElementKind` values
before terminal eraser candidate and exact-check budgets; it does not duplicate
the element-kind truth or alter spatial-query failure semantics. Down and move
build visual previews directly from immutable capture snapshots and do not
enter the interaction read adapter.

For terminal eraser deletion, the final exact-hit IDs are passed directly to
the Store-owned deletion-entry projection. The interaction read adapter carries
the resulting immutable entry facts without a document-wide frame-handle walk
or a `CanvasDocument` projection; Store remains the sole owner of canonical
deletion order and original layer positions.

Frame capture also uses a narrow intent-specific document boundary.
`FrameFactsPort` is owned by `lib/src/contracts/internal/**` and is the
accepted committed-state read seam between the frame-internal facade and
`DocumentStoreKernel`:

```text
FrameEngine -> FrameFactsPort -> DocumentStoreKernel
```

The port supplies only immutable frame-facing facts: `documentRevision`,
`structuralRevision`, `boundsRevision`, `elementVisualRevision`,
`backgroundRevision`, `gridRevision`, committed render-row facts resolved
against the captured structural revision and generation, immutable resource
descriptor snapshots, and `resourceRevision`. It does not own mutable document
state and must not return `CanvasDocument`, `CommittedDocument`, raw family
tables, `DocumentProjectionCache`, drafts, mutation APIs, selection facts,
`RenderElementRecord`, `PaintPlan`, selected supplement records, decoration
plans, or frame cache classes.

The selected target frame form keeps `FrameEngine` as the orchestration facade
and splits its internal work across seven frame-private collaborators:
`FrameCaptureService`, `OrdinaryPaintPlanner`,
`SelectedMoveSupplementPlanner`, `SelectionDecorationPlanner`,
`PaintAssetBindingService`, `StaticBackgroundPlanner`, and
`OverlayPreviewPlanner`. The collaborators remain implementation details under
`lib/src/frame/**`; package consumers continue to see only the public API
barrel.

Target ownership boundaries:

| Target collaborator | Owns | Must not own |
|---|---|---|
| `FrameCaptureService` | one-time capture of main/overlay live frame facts into `CapturedMainFrame` and `CapturedOverlayFrame` | record planning, resolver/session calls, cache mutation beyond captured-frame construction |
| `OrdinaryPaintPlanner` | per-frame ordinary spatial admission and committed render-record cache lookup/build inside the 16-entry viewport/revision OrdinaryPaintRecordCache | selection revision, selection style, selected move delta, preview state, resource resolver/session, static background identity |
| `SelectedMoveSupplementPlanner` | per-frame selected move filtering, shifted candidate lookup, row resolution, and merge by `orderToken` | ordinary `OrdinaryPaintRecordCache` writes, overlay rendering, global scene sort |
| `SelectionDecorationPlanner` | selection UI decoration and `SelectionDecorationPlan` key including `boundsRevision` | ordinary record cache identity, selected move supplement records, static background identity |
| `PaintAssetBindingService` | typed descriptor-to-asset binding for records with resource ids, using sealed immutable descriptor facts and `SurfaceResourceSession` | ordinary paint plan construction, painter resolver calls, app resolver ownership |
| `StaticBackgroundPlanner` | static background/grid plan and cache identity | selection, preview, resource visual, ordinary element visual identity |
| `OverlayPreviewPlanner` | immutable overlay primitives admitted from `CapturedOverlayFrame` | selected move rendering, resource resolver reads, cache invalidation, repaint scheduling |

Committed document facts stay store-owned and enter frame code only through the
contract-owned `FrameFactsPort`. Selection facts stay selection-owned and enter
frame code through contract-owned selection fact seams. Preview and view-camera
facts stay runtime/interaction-owned and are captured at frame boundaries.
Sealed `RenderElementRow` variants are the sole frame payload discriminator:
record capture creates the immutable row once, and the ordinary cache,
selected-move supplement, asset binding, selection decoration, and painter
carry or pattern-match it directly. `RenderElementRecord` has no render-family
mirror or alternate payload mapping.
Resolver/cache state stays owned by the future `SurfaceResourceSession` under
`lib/src/resources/**`; among the target frame collaborators, only
`PaintAssetBindingService` receives that session. Committed resource catalog
reads for the public resource port go through `ResourceCatalogPort`, while
frame descriptor lookup stays on `FrameFactsPort`.

`InteractionRequestRegistry` is the interaction-owned registry for issued
request guard facts, such as the `CanvasInteractionRequestId`, context request
target kind, controllerEpoch, and live request status. For content-element
targets, it also stores target element id, element generation, elementRevision,
and element kind. `RuntimeRoot` owns the registry instance lifetime,
`InteractionEngine` records issued request facts, and guarded command-port
operations consume and remove those facts through a narrow boundary before
delegating accepted mutations to `EditKernel`. The registry is not an active
text-input session, not a context menu or app overlay state owner, and not
`CanvasPreviewState`.

`CanvasTextEditingPort` is the runtime-owned active inline text editing
boundary. It admits only current text content-action requests, exposes one
`ValueListenable<CanvasTextEditSession?>`, derives live session geometry from
the frame-measured text layout source, and commits through the guarded command
path. It does not own Flutter `EditableText`, app decoration, context menus, or
visibility hiding; active paint suppression is frame output behavior.

Composition root:

```text
RuntimeRoot
  ├─ DocumentStoreKernel
  ├─ FrameFactsPort (contracts/internal seam implemented by runtime/store facts)
  ├─ SelectionKernel
  ├─ EditKernel
  ├─ InteractionEngine
  │  └─ PointerToolCleanupCoordinator (internal interaction collaborator)
  ├─ InteractionReadPort
  ├─ InteractionRequestRegistry
  ├─ CanvasTextEditingPort
  ├─ FrameEngine (frame-internal facade)
  ├─ SpatialKernel
  ├─ ResourceKernel
  ├─ active ResourceSessionReleaseSink? (nullable target/all release port)
  ├─ active SurfaceResourceSessionLifecycle? (nullable reset/drop lifecycle port)
  ├─ CodecBoundary
  └─ DiagnosticsHub
```

---
