# Change Contract

## Goal

Make the public resource port executable for committed resource catalog reads
and dirty-resource revision behavior while keeping committed resource
descriptors store-owned, public state publication runtime-owned, and resolver,
cache, frame, and surface-session behavior deferred to later P7/P9/P13 work.

## Evidence

- `.design/2026-05-28-resource-kernel-read-seam-and-dirty-orchestration.md` / disposition and selected form: the design is `READY_FOR_CONTRACT` and selects Candidate A, a narrow `ResourceCatalogPort` plus `ResourceKernel` ownership of `CanvasResourcePort` behavior -> this step must implement that form instead of extending `DocumentFactsPort`, reusing `FrameFactsPort`, or keeping the resource port in `RuntimeRoot`.
- `.design/2026-05-28-resource-kernel-read-seam-and-dirty-orchestration.md` / target classification: the required profile is `BEHAVIOR_CHANGE` with `SEAM_MIGRATION` obligation -> this step must prove both public behavior and import/owner seam shape.
- `.design/2026-05-28-resource-kernel-read-seam-and-dirty-orchestration.md` / public dirty operation order: runtime/resource mutation guards run before catalog checks, catalog no-ops happen before revision changes, accepted dirty calls increment `resourceVisualRevision` once, then invalidation and state publication happen after acceptance -> execution units must preserve this temporal and all-or-nothing boundary.
- `.design/2026-05-28-resource-kernel-read-seam-and-dirty-orchestration.md` / excluded future scope: synchronous image resolution, image cache policy, resolver frame budgeting, missing-result suppression, real surface lifecycle, and edit/load descriptor delivery are not part of this narrow seam -> this contract must not absorb full P7/P9/P13 behavior.
- `docs/contracts/resources.md` / ownership contract: `DocumentStoreKernel` owns committed resource descriptors, `ResourceKernel` owns the non-surface resource API and dirty-resource orchestration, and active `CanvasSurface` instances own `SurfaceResourceSession` under `lib/src/resources/**` -> the read seam must not make resources own committed descriptors or image cache entries.
- `docs/contracts/resources.md` / dirty behavior: `markResourceDirty` and `markAllResourcesDirty` replace legacy scene-change notification, do not change document revision, increment `state.revisions.resourceVisual`, and send target/all invalidation to an attached session if one exists -> tests must distinguish public dirty visual revision from committed document/resource revision.
- `docs/contracts/public_api_v1.md` / public resource API: `CanvasResourcePort` exposes `resources`, `resourceById`, `markResourceDirty`, and `markAllResourcesDirty`, while resource mutation stays inside `CanvasEdit` -> this step must not change public method signatures or add resource mutation commands to the port.
- `docs/contracts/operation_matrix.md` / resource rows: `markResourceDirty` and `markAllResourcesDirty` have dedicated no-op and publication rules for missing targets or empty registered resource visual state -> completion checks must prove no-op behavior as well as accepted dirty behavior.
- `docs/architecture/01_runtime_ownership.md` / owner split: committed document facts stay store-owned, `ResourceKernel` owns resource visual state and dirty invalidation, `RuntimeRoot` publishes the single public `CanvasRuntime.state` snapshot, and `SurfaceResourceSession` owns resolved images/cache -> implementation must keep publication coordination in runtime and resolved-image behavior out of the narrow seam.
- `docs/architecture/02_package_boundaries.md` / package boundaries: public DTOs and port interfaces belong in `contracts/public/**`; non-exported owner ports, immutable facts, delivery effects, dirty outcomes, and guards belong in `contracts/internal/**` -> `ResourceCatalogPort` belongs under `contracts/internal/**`, not API, runtime, store, or resources.
- `docs/architecture/architecture_graph.yaml` / P7 graph: `ResourceKernel` and `SurfaceResourceSession` are P7 nodes, `RuntimeRoot` composes `ResourceKernel`, resource invalidation flows from `ResourceKernel` to `SurfaceResourceSession`, and `ResourceKernel` imports of runtime or frame are forbidden -> graph and guardrail proof must be updated for the new seam without closing full session/frame behavior prematurely.
- `docs/implementation/p7_resources_and_images.md` / P7 scope: P7 includes `ResourceKernel`, `SurfaceResourceSession`, `markResourceDirty`, `markAllResourcesDirty`, dirty-resource public revision effects through `ResourceDirtyOutcome`, and resolver reentrancy rejection through `ResolverMutationGuard` -> this step implements only the catalog-read and public dirty subset and leaves resolver/session cache tests for later P7 work.
- `docs/implementation/p9_frame_rendering_and_caches.md` / frame dependency: frame image resolution uses `SurfaceResourceSession` and frame descriptor lookup uses `FrameFactsPort` -> `ResourceCatalogPort` must not become a frame asset-binding path.
- `docs/implementation/p13_flutter_surface.md` / surface dependency: P13 wires `SurfaceResourceSession` lifecycle through the resource session owner -> this step may expose an invalidation boundary or fake sink for tests but must not implement Flutter surface lifecycle.
- `docs/verification/tests.md` and `docs/verification/guardrail_design_patterns.md` / planned proof: resource dirty tests must cover `state.revisions.resourceVisual` without document revision changes, mark-all cache/session effects are separately planned, and `resources.dirty_no_document_revision` is a behavioral guardrail -> focused tests must activate the dirty no-document-revision proof while leaving real cache clearing for full P7.
- `lib/src/api/canvas_runtime.dart` / public facade: `CanvasRuntime.resources` currently throws `UnimplementedError` -> this step must replace the P7 placeholder with a resource-backed port and remove its placeholder allowance.
- `lib/src/contracts/public/canvas_resource.dart` / public declaration: `CanvasResourcePort` already declares the exact read and dirty methods -> implementation must preserve this public contract.
- `lib/src/contracts/internal/resource_dirty_outcome.dart` and `lib/src/contracts/internal/resolver_mutation_guard.dart` / existing seams: dirty outcomes and runtime mutation guard declarations already exist without naming resource/runtime/session implementations -> this step must reuse or minimally extend those seams rather than inventing a parallel dirty result source of truth.
- `lib/src/runtime/runtime_root.dart` / runtime state: `RuntimeRoot` implements document and frame facts, owns public mutation guards and publication, and currently hardcodes `resourceVisual` to `0` in public state -> runtime must compose the resource owner and read its visual revision during state publication.
- `lib/src/store/document_store_kernel.dart` and `lib/src/store/resource_table.dart` / committed resource source: the store owns the committed document projection, resource revision, frame descriptor lookup, copied `CanvasResource` rows, and descriptor facts -> store-backed catalog reads must copy immutable public resource descriptors at the boundary and must not expose store internals.
- `tool/guardrails/src/owner_dag_import_checks.dart` and `test/guardrails/owner_dag_import_boundaries_test.dart` / existing owner DAG: resources may import public/internal contracts, while resources-to-runtime and resources-to-frame edges are forbidden -> this step must preserve that direction and add any missing negative proof needed to keep resources from importing store/runtime/frame or letting frame use `ResourceCatalogPort`.

## Boundaries

Owner:

`ResourceKernel` under `lib/src/resources/**` owns public resource port behavior,
`resourceVisualRevision`, public dirty no-op/acceptance decisions, and
resource dirty invalidation outcomes. `ResourceCatalogPort` under
`lib/src/contracts/internal/**` owns the read-only catalog seam.
`DocumentStoreKernel` remains the committed resource descriptor owner.
`RuntimeRoot` owns composition, runtime mutation guard enforcement, public
`CanvasRuntime.state` publication, action/repaint delivery containment, and the
public facade handoff from `CanvasRuntime.resources`.

In Scope:

- Add `ResourceCatalogPort` under `lib/src/contracts/internal/**` with read-only
  public resource list and lookup by `CanvasResourceId`.
- Implement the store-backed catalog boundary in `RuntimeRoot` and
  `DocumentStoreKernel` so public resource reads return copied immutable
  `CanvasResource` descriptors from committed state without exposing
  `ResourceTable` or descriptor facts.
- Add the focused `ResourceKernel` implementation under `lib/src/resources/**`
  and make it own the concrete `CanvasResourcePort` behavior for `resources`,
  `resourceById`, `markResourceDirty`, and `markAllResourcesDirty`.
- Wire `CanvasRuntime.resources` through `RuntimeRoot` to the resource-owned
  port and remove the `CanvasRuntime.resources` public placeholder allowance.
- Implement public dirty behavior for existing single target and mark-all calls:
  guard before catalog checks, no-op for missing target or empty catalog,
  increment `resourceVisualRevision` exactly once on accepted dirty calls,
  emit `ResourceDirtyOutcome`, publish one runtime state snapshot with the new
  `state.revisions.resourceVisual`, and emit the main repaint intent/effect
  without changing document, selection, preview, view-camera, interaction,
  epoch, public action, or committed `resourceRevision` state.
- Keep the dirty invalidation boundary compatible with a future attached
  `SurfaceResourceSession`, using a fake or absent sink only for the bounded
  proof in this step.
- Add focused tests for public resource reads, resource dirty no-op and accepted
  behavior, runtime publication, mutation-guard rejection before dirty side
  effects, observer/effect failure containment after accepted dirty publication,
  import-boundary guardrails, internal seam shape, and public placeholder
  removal.
- Update durable docs, architecture graph data, generated graph views, and
  verification/guardrail registries only where the narrow catalog-read and
  public dirty subset changes the source of truth; do not mark full P7
  resolver/cache/session behavior complete.
- After implementation and verification pass, mark Step 39 complete in
  `PLAN.md` and mark this step document's execution-unit checkboxes complete in
  the same change.

Out of Scope:

- Do not implement synchronous resolver calls, `CanvasResourceResolver`
  execution, resolver frame budgeting, resolver generation, same-frame
  null/missing suppression, image cache eviction, LRU policy, placeholder
  rendering, app image ownership, or surface attach/detach lifecycle.
- Do not implement real `SurfaceResourceSession` cache behavior or Flutter
  surface lifecycle; an invalidation fake or no attached sink is allowed only
  for the dirty seam proof.
- Do not route frame rendering, paint asset binding, ordinary paint planning, or
  painters through `ResourceCatalogPort`; `FrameFactsPort` remains the frame
  descriptor seam.
- Do not implement edit/load descriptor delivery into the resource invalidation
  boundary. Descriptor changes remain committed store/resource revision behavior
  and must not increment `resourceVisualRevision` in this step.
- Do not change public API method names, signatures, DTO shapes, schema v1
  formats, public resource mutation ownership, public action payloads, or
  public error-code contracts.
- Do not move committed resource descriptors, public state publication, document
  revision ownership, or resolved-image cache ownership into a second source of
  truth.
- Do not satisfy DCM or architecture checks through metric-only wrappers,
  broad suppressions, or production fixture-only declarations.

Source of Truth:

The design input for this step is
`.design/2026-05-28-resource-kernel-read-seam-and-dirty-orchestration.md`.
Durable resource behavior remains defined by `docs/contracts/resources.md`,
`docs/contracts/public_api_v1.md`, and `docs/contracts/operation_matrix.md`.
Runtime/store/resource ownership remains defined by
`docs/architecture/01_runtime_ownership.md`,
`docs/architecture/02_package_boundaries.md`,
`docs/architecture/03_data_model.md`, and
`docs/architecture/architecture_graph.yaml`. P7 scope remains defined by
`docs/implementation/p7_resources_and_images.md`; P9 and P13 documents remain
the source of truth for future frame and surface-session behavior. Executable
enforcement lives in `tool/guardrails/**`, `tool/architecture_graph/**`, and
their tests. Roadmap closure state remains owned by `PLAN.md` and this linked
step file.

Compatibility:

Supported public consumers importing
`package:iwb_canvas_engine/iwb_canvas_engine.dart` must see unchanged
`CanvasResourcePort`, `CanvasResource`, `CanvasResourceId`, and runtime state
APIs. `CanvasRuntime.resources` changes from a documented P7 placeholder to an
implemented public port. Existing resource reads must return the committed
public resource descriptors without allowing mutation of store-owned state.
Dirty-resource calls must preserve existing disposed, active edit session,
post-commit delivery, and resolver callback mutation rejection semantics. No
resource dirty call may change document data, schema output, committed
`resourceRevision`, public document projection, selection, preview, view-camera,
epoch, interaction revision, or action streams.

Order Constraints:

Create `ResourceCatalogPort` and the store-backed catalog read boundary before
wiring the public resource port. Create `ResourceKernel` and its read behavior
before dirty behavior so dirty no-op checks use the same catalog seam as public
reads. For every public dirty call, enforce this order: runtime/resource
mutation guard; catalog existence or non-empty check; no-op return when the
target is missing or the catalog is empty; `resourceVisualRevision` increment;
`ResourceDirtyOutcome` target/all invalidation; runtime public state
publication and main repaint delivery. The irreversible point for accepted
dirty behavior is the `resourceVisualRevision` increment. All fallible guard and
catalog work must happen before that point. Observer/repaint delivery after
publication must be failure-contained and must not roll back the accepted
revision. Update guardrails before relying on the new resource owner shape for
later P7 work. Update docs, graph data, generated graph views, and plan closure
only after code and focused tests establish the enforced behavior.

## Execution Units

### [ ] Unit 1: Resource catalog read seam

Owner:

`lib/src/contracts/internal/**`, `DocumentStoreKernel`, and the runtime-owned
store adapter boundary.

Boundary:

Only the read-only committed catalog seam and store-backed public resource
copying surface: `ResourceCatalogPort`, store resource list/lookup accessors,
runtime implementation of the catalog port, and focused seam/store tests. This
unit must not add `ResourceKernel`, wire `CanvasRuntime.resources`, or implement
dirty behavior.

Change:

Add `ResourceCatalogPort` under `contracts/internal/**` with immutable public
catalog list and lookup methods. Extend the store read boundary so
`RuntimeRoot` can implement the port by reading committed `CanvasResource`
rows and returning copied public descriptors. Keep descriptor facts for frame
lookup on `FrameFactsPort` unchanged, and keep `ResourceCatalogPort` free of
runtime, store, frame, resources, surface, resolver, cache, and callback types.

Completion Check:

`dart test test/contracts/internal_seam_shape_test.dart
test/runtime/resource_catalog_port_test.dart` passes with coverage that
`ResourceCatalogPort` exists under `contracts/internal/**`, imports only public
resource/id declarations, exposes list and id lookup methods, does not name
`DocumentStoreKernel`, `RuntimeRoot`, `FrameFactsPort`, `ResourceKernel`,
`SurfaceResourceSession`, resolver, cache, or callback types, and leaves
`FrameFactsPort.resourceDescriptor` as the only frame descriptor-fact lookup
seam. The focused runtime catalog test proves catalog `resources` and
`resourceById` return copied committed `CanvasResource` descriptors, missing ids
return `null`, and mutating a returned list cannot mutate the store-owned
catalog. `dart analyze` reports no duplicate declaration or unresolved import
errors for the new internal seam.

Depends On:

None.

### [ ] Unit 2: ResourceKernel read port wiring

Owner:

`lib/src/resources/**`, `RuntimeRoot`, and the public `CanvasRuntime.resources`
facade handoff.

Boundary:

Only the resource-owned concrete `CanvasResourcePort` read behavior and runtime
composition: `ResourceKernel`, its resource-port adapter if one is needed, the
`RuntimeRoot` resource getter, `CanvasRuntime.resources`, and focused public
read tests. This unit must not implement dirty revision changes beyond throwing
or delegating to still-unimplemented dirty methods until Unit 3 completes.

Change:

Create `ResourceKernel` under `lib/src/resources/**` with constructor
dependencies on `ResourceCatalogPort` and the existing mutation guard seam
needed by the future dirty path. Make the resource-owned concrete
`CanvasResourcePort` return catalog `resources` and `resourceById` results
through the catalog port without importing runtime, store, frame, or surface
owners. Compose `ResourceKernel` in `RuntimeRoot`, expose a `resources` getter
from runtime, and replace `CanvasRuntime.resources` `UnimplementedError` with
the resource-backed port while preserving the public API signature.

Completion Check:

`dart test test/resources/resource_kernel_read_port_test.dart
test/smoke/public_incremental_smoke_test.dart` passes and proves a public
consumer can obtain `runtime.resources`, read all committed resources, look up a
resource by id, get `null` for a missing id, and keep root-barrel public access
without private `src/api/**` imports. `dart test
test/guardrails/owner_dag_import_boundaries_test.dart
test/guardrails/import_boundaries_test.dart` passes with resources-to-runtime,
resources-to-store, resources-to-frame, and frame-to-`ResourceCatalogPort`
negative fixtures rejected while resources-to-contracts imports remain allowed.
`rg -n "src/(runtime|store|frame|surface)|\\.\\./(runtime|store|frame|surface)"
lib/src/resources` prints no matches. `dart analyze` reports no
`CanvasRuntime.resources` unresolved or placeholder implementation errors.

Depends On:

Unit 1.

### [ ] Unit 3: Public dirty revision orchestration

Owner:

`ResourceKernel` owns dirty decisions and `resourceVisualRevision`; `RuntimeRoot`
owns guard composition, public state publication, repaint/effect delivery, and
failure containment.

Boundary:

Only public `CanvasResourcePort.markResourceDirty` and
`CanvasResourcePort.markAllResourcesDirty` behavior, the dirty outcome handoff,
`resourceVisualRevision`, runtime state publication, main repaint/effect
delivery, and focused dirty tests. This unit does not implement real image cache
eviction, resolver calls, frame cache invalidation, or edit/load descriptor
delivery.

Change:

Implement dirty calls so the injected runtime mutation guard rejects disposed
runtime, active edit session, post-commit delivery, and resolver callback
reentry before any catalog read, revision increment, invalidation outcome, or
state publication. For `markResourceDirty(id)`, use `ResourceCatalogPort` to
return a no-op when the target resource is missing; accepted targets increment
`resourceVisualRevision` exactly once and emit a target `ResourceDirtyOutcome`.
For `markAllResourcesDirty()`, return a no-op when the catalog is empty;
accepted non-empty catalogs increment `resourceVisualRevision` exactly once and
emit an all-resources `ResourceDirtyOutcome`. Runtime publication reads
`ResourceKernel.resourceVisualRevision` into
`state.revisions.resourceVisual`, publishes one public state snapshot, and emits
the main repaint/effect signal after the revision is accepted. Any
post-publication observer/effect failure is contained and does not roll back the
accepted dirty revision.

Completion Check:

`dart test test/resources/resource_dirty_port_test.dart
test/runtime/resource_dirty_state_publication_test.dart` passes and proves
existing-target `markResourceDirty` increments only
`state.revisions.resourceVisual`, leaves document/resource/selection/preview/
view-camera/interaction/epoch revisions unchanged, publishes one state snapshot,
emits main repaint/effect without public action events, and produces a target
dirty outcome. The same tests prove missing-target dirty and empty-catalog
mark-all are complete no-ops with no revision, no publication, no repaint/effect,
and no action emission. Mark-all with a non-empty catalog increments
`resourceVisualRevision` once, publishes one state snapshot, emits main
repaint/effect without public action events, leaves document/resource/
selection/preview/view-camera/interaction/epoch revisions unchanged, and
produces an all-resources dirty outcome. Guard tests in the same focused files
prove disposed runtime, active edit session, post-commit delivery callback, and
resolver mutation guard callback attempts throw `StateError` before resource
catalog reads, resource revision changes, invalidation state changes, public
state publication, repaint/effect emission, or action emission. That guard-order
proof uses a spy or failing `ResourceCatalogPort` and covers both
`markResourceDirty` and `markAllResourcesDirty`, proving rejected calls do not
invoke `ResourceCatalogPort.resourceById` or `ResourceCatalogPort.resources`.
Failure-containment tests prove post-publication commit/effect observer failure
does not roll back the accepted `resourceVisualRevision`; `ValueNotifier`
listener behavior remains framework-owned and is not changed by this step.

Depends On:

Unit 2.

### [ ] Unit 4: Resource seam enforcement and source-of-truth closure

Owner:

Guardrail tooling, architecture graph data, generated graph views, durable
resource/architecture/verification docs, placeholder registry, `PLAN.md`, and
this step file.

Boundary:

Only source-of-truth and enforcement surfaces that describe or mechanically
prove the narrow catalog-read and public dirty implementation:
`tool/guardrails/**`, guardrail tests, `tool/architecture_graph/**` inputs if
needed, `docs/architecture/architecture_graph.yaml`, generated P6 graph views,
`docs/architecture/01_runtime_ownership.md`,
`docs/architecture/02_package_boundaries.md`,
`docs/contracts/resources.md`, `docs/contracts/operation_matrix.md`,
`docs/implementation/p7_resources_and_images.md`,
`docs/verification/tests.md`, `docs/verification/guardrails.md`,
`docs/verification/guardrail_design_patterns.md`, the public placeholder
allowlist, `PLAN.md`, and this step file. This unit must not claim resolver,
cache, frame rendering, or surface lifecycle closure.

Change:

Remove the `CanvasRuntime.resources` placeholder allowance once the public
resource port is backed by resource state. Add or tighten structural proof so
`ResourceKernel` cannot import runtime, store, frame, surface, interaction, or
Flutter owners, and so frame/painter code cannot use `ResourceCatalogPort` for
asset binding. Update architecture graph nodes, forbidden edges, and generated
graph views only for the `CanvasRuntime.resources` placeholder replacement,
`ResourceCatalogPort`, and the implemented ResourceKernel read/dirty subset;
leave full `SurfaceResourceSession`, resolver, cache, and frame-rendering graph
scope future. Update `docs/architecture/01_runtime_ownership.md` and
`docs/architecture/02_package_boundaries.md` to record `ResourceCatalogPort` as
the runtime-backed/resource-consumed catalog seam and lock its internal
declaration-only package boundary. Update the remaining durable docs to record
that the narrow P7 ResourceKernel read/dirty subset is implemented while full
resolver/cache/session behavior remains future P7/P9/P13 scope. Mark Step 39
complete in
`PLAN.md` and mark this file's unit checkboxes complete only after all code,
guardrail, architecture, documentation, and focused test checks pass.

Completion Check:

`dart test test/api_contract/public_api_no_unapproved_placeholders_test.dart
test/guardrails/owner_dag_import_boundaries_test.dart
test/guardrails/import_boundaries_test.dart` passes and proves
`CanvasRuntime.resources` is no longer allowlisted as an unimplemented public
placeholder, resources forbidden imports are rejected, and frame/painter use of
`ResourceCatalogPort` is rejected by a negative fixture or equivalent structural
proof. After resource guardrails are routed through the guardrail registry,
`dart run tool/guardrails/run.dart` passes. `dart run
tool/architecture_graph/check.dart --phase P7` and `dart run
tool/architecture_graph/generate_views.dart --phase P6 --check` pass with graph
data that distinguishes implemented catalog-read/dirty seams from future
resolver/session/frame work. `dart run docs/tool/sync_generated_docs.dart
--check` and `dart run docs/tool/check_docs.dart` pass after the resource,
operation-matrix, implementation, architecture ownership, package-boundary,
verification, graph-view, registry, and generated-doc surfaces are updated.
Final implementation verification from the repository root also includes
`dart analyze`, `dcm analyze .`, `dcm calculate-metrics .`, and the focused
tests named by Units 1-3.

Depends On:

Unit 3.
