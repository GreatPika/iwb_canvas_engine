# Change Contract

## Goal

The maintained package supports one serializable vector-document element backed by an app-key descriptor and an application-prepared raster-free vector picture, preserves synchronous frame resolution and application lifetime ownership, renders the picture directly at the element size in background and content locations, and records the resulting public, lifecycle, architecture, documentation, and verification contracts without serialized vector bytes, fixed-resolution rasterization, duplicate family truth, or a second resource-policy owner.

## Source Inputs

| Category | Source ID | Location or authority |
| --- | --- | --- |
| Design | `vector-element-resource-design` | docs/planning/designs/2026-08-08-vector-element-resource.md |
| Research | `full-svg-surface-research` | docs/history/research/2026-08-07-full-svg-node-resource-surface.md |
| PLAN | none | none |
| Other | `user-request` | user request |
| Other | `repository-policy` | AGENTS.md |
| Other | `planning-policy` | docs/planning/README.md |
| Other | `adr-0001` | architecture/decisions/ADR-0001-single-maintained-acyclic-runtime.md |
| Other | `adr-0004` | architecture/decisions/ADR-0004-canonical-schema-reader-and-atomic-load.md |
| Other | `adr-0005` | architecture/decisions/ADR-0005-surface-owned-resource-resolution.md |
| Other | `adr-0006` | architecture/decisions/ADR-0006-derived-spatial-indexing.md |
| Other | `adr-0007` | architecture/decisions/ADR-0007-immutable-frame-planning-and-caches.md |
| Other | `adr-0008` | architecture/decisions/ADR-0008-selection-move-and-chrome-ownership.md |
| Other | `adr-0011` | architecture/decisions/ADR-0011-surface-lifecycle-and-layer-repaint.md |
| Other | `adr-0013` | architecture/decisions/ADR-0013-documentation-graph-and-proof-ownership.md |
| Other | `adr-catalog` | architecture/decisions/README.md |
| Other | `package-boundaries` | docs/architecture/02_package_boundaries.md |
| Other | `runtime-ownership` | docs/architecture/01_runtime_ownership.md |
| Other | `data-model` | docs/architecture/03_data_model.md |
| Other | `architecture-graph` | docs/architecture/architecture_graph.yaml |
| Other | `verification-tests` | docs/verification/tests.md |
| Other | `public-api-owner` | docs/contracts/public_api_v1.md |
| Other | `validation-owner` | docs/contracts/validation_limits.md |
| Other | `schema-owner` | docs/contracts/schema_v1.md |
| Other | `codec-owner` | docs/contracts/codec_boundary.md |
| Other | `edit-owner` | docs/contracts/edit_kernel.md |
| Other | `load-owner` | docs/contracts/load_document.md |
| Other | `resource-owner` | docs/contracts/resources.md |
| Other | `cache-owner` | docs/contracts/cache_policy.md |
| Other | `operation-owner` | docs/contracts/operation_matrix.md |
| Other | `frame-owner` | docs/contracts/frame_rendering.md |
| Other | `geometry-owner` | docs/contracts/geometry.md |
| Other | `interaction-owner` | docs/contracts/interaction_engine.md |
| Other | `diagnostics-owner` | docs/contracts/diagnostics.md |
| Other | `public-registry` | docs/_registry/public_api_v1.yaml |
| Other | `section-registry` | docs/_registry/sections.yaml |
| Other | `diagram-registry` | docs/_registry/diagrams.yaml |
| Other | `guardrail-registration` | tool/guardrails/src/guardrail_executor.dart |

## Classification

Profile: `BEHAVIOR_CHANGE`
Obligations: `PUBLIC_API_CHANGE`, `SEAM_MIGRATION`, `SEQUENCED_MIGRATION_AND_RETIREMENT`, `NEGATIVE_PROOF_AND_FIXTURE_QUARANTINE`, `TEMPORAL_SURFACE_CLOSURE`, `ALL_OR_NOTHING_FAILURE_BOUNDARY`, `SOURCE_OF_TRUTH_SINGULARITY`

## Decision Trace

| Decision ID | Source decision | Contract location | Acceptance or evidence target |
| --- | --- | --- | --- |
| `vector-document-model` | Design D1 requires one vector element with resource id, validated size, optional natural size, inherited common fields, and a sparse update family. | Boundaries; Unit 5 | `vector-model-and-update` |
| `descriptor-only-resource` | Design D2 requires a typed vector descriptor with inherited fields and no serialized `.vec` bytes. | Boundaries; Units 3 and 5 | `vector-schema-roundtrip` |
| `prepared-before-attach` | Design D3 fixes public `prepareVector(ByteData, {BuildContext? context})`, keeps its asynchronous work outside synchronous frame resolution, and fixes invocation-time locale and direction behavior. | Boundaries; Units 2 and 5 | `preparation-context-closure` |
| `prepared-wrapper-ownership` | Design D4 fixes helper-only prepared construction, private Picture/liveness, public intrinsic size and idempotent disposal, and observation-only global hooks. | Boundaries; Unit 2 | `prepared-wrapper-lifecycle` |
| `prepared-equality-policy` | Design D16 requires default identity equality for `CanvasPreparedVector`: distinct preparations remain unequal even at matching intrinsic size, and equality/hash never depend on mutable liveness or disposal. | Boundaries; Unit 2 | `prepared-vector-identity-equality` |
| `caller-freshness` | Design D5 assigns context freshness, stale-result disposal, publication, and release-before-dispose to the application. | Boundaries; Unit 5 | `caller-context-freshness` |
| `aggregate-borrow-cache` | Design D6 requires one aggregate image/vector LRU, image-only byte accounting, internal keys, invalid-prepared rejection, synchronous target/all release, and no engine disposal. | Boundaries; Units 1, 4, and 5 | `aggregate-resource-cache` |
| `direct-picture-paint` | Design D7 requires clipping, anisotropic scaling, `drawPicture`, no image conversion, and zero/full or one/partial record-explicit group layer. | Boundaries; Unit 5 | `vector-picture-paint` |
| `single-element-kind` | Design D8 requires sized-box geometry and selection, vector content interaction, background exclusion, and retirement of both duplicate family enums. | Boundaries; Units 5, 6, and 7 | `vector-geometry-and-interaction` |
| `vector-selection-owner` | Design D8 separately requires direct vector `outsideBox`, unchanged current single-family placement, union-box multi-selection, and retirement through sealed-row dispatch. | Units 5 and 7 | `vector-selection-placement` |
| `typed-relationship-errors` | Design D9 requires independent codec/export/store admission, absent-id `missingResourceReference`, wrong-kind `resourceKindMismatch`, exact element paths, and internal decode helpers. | Boundaries; Units 3 and 5 | `resource-relationship-classification` |
| `schema-v1-extension` | Design D10 extends Schema v1 in place while preserving old canonical output and independent unknown element/resource rejection. | Boundaries; Unit 5 | `schema-v1-compatibility` |
| `generic-invalidation-retirement` | Design D11 replaces image-named invalidation with resource-generic target/all release, preserves accepted publication after later notification failure, and retires private mirrors without a permanent token scanner; current production already carries that seam, so Unit 1 closes its still-stale source owners and graph while preserving the behavior. | Boundaries; Unit 1 | `generic-resource-release` |
| `release-owner-order-correction` | The user authorizes moving release-specific semantic-owner and graph closure from Unit 8 into Unit 1 so the generic release seam, its current source documents, and architecture enforcement remain atomically committable. | Boundaries; Units 1 and 8; Verification Gate | `release-semantic-owner-closure` |
| `incremental-source-owner-closure` | Repository policy and Design D13 require each behavior-changing unit to leave its current semantic owners, registries, diagrams, graph, and generated projections consistent rather than deferring feature truth to a terminal documentation unit. | Boundaries; Units 1 through 8; Verification Gate | `semantic-owner-closure` |
| `private-upstream-boundary` | Design D12 keeps upstream package types and byte loading private and forbids engine IO, a fork, global error interception, duplicate parsing, and new vector diagnostic routes. | Boundaries; Units 2 and 5 | `raster-free-private-adapter` |
| `source-owner-closure` | Design D13 fixes the affected semantic owners, registries, diagrams, graph, proof registrations, ADR lifecycle, and generated projections; each Unit 1-7 closes the current owners affected by its behavior or seam change, while Unit 8 performs only cross-unit ADR, proof-inventory, structured-parity, and lifecycle integration. | Units 1 through 8; Verification Gate | `semantic-owner-closure` |
| `exact-view-admission` | Design D14 fixes the 32 MiB view limit and `fieldMaxLength` at `vector.bytes`, exact pre-await copy, real `vg.loadPicture` invocation, immediate source independence, post-settlement non-retention, selected-Future `invalidVectorData` mapping at `vector.bytes`, intrinsic policy at `vector.intrinsicSize`, and bounded claims. | Boundaries; Unit 2 | `preparation-view-ownership` |
| `raster-free-input` | Design D15 supports only precompiled raster-free `.vec` and forbids adding a fork, process-global error interceptor, or duplicate raster-command recognizer. | Boundaries; Unit 2 | `raster-free-private-adapter` |
| `typed-resource-foundation` | Current descriptor/frame facts infer image semantics from nullable MIME data and current final-candidate relationships prove id membership without an explicit resource kind. | Unit 3 | `typed-resource-foundation` |
| `resource-pipeline-foundation` | Current request/result/cache/binding/output asset flow is image-shaped even where its ownership and lifetime rules are family-neutral. | Unit 4 | `resource-pipeline-foundation` |
| `adr-numbering-repair` | The design authority precondition requires correcting the stale next ADR id, creating ADR-0016 plus catalog/concern rows, and advancing the next id to ADR-0017 atomically. | Unit 8 | `adr-0016-closure` |
| `manual-mirror-closure` | Current direct consumers mirror image-only invalidation, interaction/render discriminators, adapter shape, cache numbers, public exports, and proof registration; only the export registry has a distinct authorized inventory lifecycle. | Units 1, 2, 3, 4, 5, 6, 7, and 8 | `manual-mirror-retirement` |

## Repository Evidence

- `docs/planning/designs/2026-08-08-vector-element-resource.md:5` / disposition: the active design is `READY_FOR_CONTRACT` -> implementation decomposition is authorized.
- `docs/planning/designs/2026-08-08-vector-element-resource.md:414` / open decisions: the section resolves to `None` at `:416` -> implementation requires no additional architecture choice.
- `lib/src/contracts/public/canvas_element.dart:12` / public element discriminator: six families are closed in `CanvasElementKind` -> vector admission must update every exhaustive consumer atomically.
- `lib/src/contracts/public/canvas_element.dart:57` / sized resource-backed model: image already owns the accepted resource id, size, natural size, and inherited-field pattern -> vector reuses value semantics without overloading image rendering.
- `lib/src/contracts/public/canvas_resource.dart:12` / descriptor owner: base resource fields are centralized, while `CanvasImageResource` at `:47` is the only current subtype -> vector adds a typed descriptor without copying source or payload bytes.
- `lib/src/contracts/public/canvas_resource.dart:98` / resolver port: the only current callback is synchronous image resolution -> preparation stays outside the resolver and the resolver seam migrates atomically.
- `lib/src/contracts/public/canvas_errors.dart:4` / public data error vocabulary: absent-resource failure exists but wrong-kind failure does not -> the family-neutral mismatch code belongs here.
- `lib/src/store/family_tables.dart:69` / committed family tables: six family maps own committed state, and reference lookup at `:78` is image-only -> vector needs a peer row and typed relationship admission at this owner.
- `lib/src/store/family_tables.dart:520` / current relationship guard: membership alone produces `missingResourceReference` -> final candidate validation must distinguish absence from a present wrong-kind descriptor.
- `lib/src/codec/schema_v1_reader.dart:552` / resource reader: one canonical reader accepts only image descriptors, while element mapping at `:1515` is exhaustive -> both known vector branches extend the same reader and retain unknown-kind rejection.
- `lib/src/codec/schema_v1_encoder.dart:62` / canonical writer: resource and element branches are explicit and descriptor-only -> vector wire output is added without a second writer or byte field.
- `lib/src/frame/render_element_record.dart:12` / frame mirror: `RenderElementFamily` duplicates public kind and is stored beside sealed `RenderElementRow` at `:143` -> Unit 5 first proves a sealed vector row and Unit 7 then retires the complete mirror.
- `lib/src/frame/selection_decoration_planner.dart:228` / selection placement: placement switches on the duplicate render enum -> sealed rows become the direct owner and later classify vector as `outsideBox`.
- `lib/src/interaction/interaction_read_port.dart:315` / interaction mirror: `InteractionElementFamily` duplicates `CanvasElementKind` already stored at `:346` and `:388` -> Unit 5 first proves vector snapshot behavior and Unit 6 then retires the complete mirror.
- `lib/src/runtime/runtime_interaction_read_mapping.dart:100` / interaction consumer: a complete kind-to-family mirror exists beside public snapshot construction at `:120` -> only snapshot construction receives the vector branch.
- `lib/src/contracts/internal/resource_session_release_sink.dart:3` / release seam: the current runtime-to-session contract already exposes resource-generic target/all release -> Unit 1 preserves this production boundary while closing its stale current semantic owners and graph evidence.
- `lib/src/contracts/internal/frame_facts_port.dart:134` / immutable resource facts: the current descriptor facts encode image meaning through nullable MIME data without an explicit resource kind -> Unit 3 makes the existing facts kind-aware while preserving current behavior.
- `lib/src/resources/resource_resolver_adapter.dart:9` / resolved-asset seam: current requests/results are image-specific, and `ImageResolveCache` at `lib/src/resources/resource_cache.dart:14` stores the same family-specific value -> Unit 4 generalizes one existing pipeline before a second family is admitted.
- `lib/src/resources/surface_resource_session.dart:210` / session lifecycle: reset, target/all release, resolver replacement, and drop remove session borrows and invoke retained-output release callbacks -> Unit 1 documents this already-current two-owner postcondition without changing resolver/cache family semantics.
- `lib/src/surface/layer_frame_output_cache.dart:80` / retained output: target/all release removes matching retained main-output bindings while preserving unrelated bindings and overlay -> Unit 1 aligns the current graph and semantic diagrams with this identity-aware surface ownership.
- `docs/contracts/resources.md:61` / stale current owner: resource lifecycle still names `ResourceSessionInvalidationSink` and session-cache-only invalidation despite the generic production seam -> Unit 1 must close resource, operation, runtime-ownership, diagram, and graph truth before later units consume the lifecycle.
- `docs/architecture/architecture_graph.yaml:614` / stale required edge: the existing runtime-to-session edge still lists `ResourceSessionInvalidationSink` as its actual composition field -> Unit 1 updates the same edge and its source documents together rather than adding a graph owner.
- `docs/contracts/resources.md:135` / numeric mirror: the 1024-entry and 64 MiB policy is copied from the cache ledger at `docs/contracts/cache_policy.md:43` -> cache policy remains the sole numeric owner and resources links to it.
- `test/resources/resource_resolver_adapter_shape_test.dart:8` / stable boundary proof: the current fixture checks resource-owned dependency direction and denied IO without copying release method/request/result inventories -> Unit 1 preserves this narrow proof and creates no replacement private-name scanner.
- `tool/guardrails/src/guardrail_executor.dart:318` / current proof registration: resolver ownership retains the stable adapter boundary while `resources.app_key_only` at `:333` credits only the external public-union fixture -> Unit 1 source closure must not restore stale private-shape or app-key credit.
- `docs/_registry/public_api_v1.yaml:1` / intentional mirror: exported-name membership has a distinct machine-readable owner and bidirectional consumer in `tool/guardrails/src/public_api_checks.dart` -> vector public names update this registry rather than deleting it.
- `docs/contracts/public_api_v1.md:237` / future-type admission: every new public type must select an equality policy in this owner before implementation -> Unit 2 records identity equality for lifecycle-owning `CanvasPreparedVector` before adding the class.
- `architecture/decisions/README.md:23` / ADR number owner: the next id is incorrectly `ADR-0001` while the catalog reaches ADR-0015 -> ADR-0016 creation and the next-id advance are one atomic change.
- `docs/architecture/architecture_graph.yaml:31` / existing API owner: public API and contract nodes already own declarations and implementation direction -> vector preparation updates existing nodes/edges and source coverage; it does not create an unapproved architecture owner.
- `pubspec.yaml:10` / dependency boundary: no vector package dependency exists -> the direct `vector_graphics` dependency is added behind API and never enters public signatures.

## Boundaries

Owner: Public vector element/update/resource/result/resolver declarations, result lifecycle, raster-free input contract, and public error taxonomy belong to `contracts/public`; `prepareVector`, exact-view copying, invocation-time context capture, intrinsic validation, selected-upstream-Future mapping, and the private upstream adapter belong behind API. Store owns committed rows and final candidate relationships; codec owns the one Schema v1 traversal, codec-local public-DTO sink, and canonical encode. `CanvasElementKind` is the sole semantic element-kind discriminator; sealed render rows own frame payload variants. Geometry owns sized-box bounds and hit policy. Frame owns immutable vector rows/bindings, selection placement, clipping, scaling, group opacity, and `drawPicture`. Resources owns synchronous resolver admission, aggregate borrowed references, suppression/retry, and non-fallible target/all retirement; cache numbers live only in `docs/contracts/cache_policy.md`; surface owns retained frame output and its narrow synchronous release implementation. The application owns prepared-result freshness, publication aliases, aggregate release-before-dispose authorization, and disposal. Existing codec and interaction diagnostic routes remain their owners; preparation, resources, and frame remain non-hub. Existing architecture graph nodes own these routes; no new graph owner is introduced.
  `docs/contracts/public_api_v1.md` owns the explicit default-identity equality classification for `CanvasPreparedVector`; wrapper identity remains independent of intrinsic size, private Picture identity, and mutable liveness.

In Scope: Retire both duplicate family discriminators and their manual mirrors; introduce resource-generic target/all invalidation and total identity-aware retained-output release before vector consumers; preserve accepted dirty/edit/load publication when later notification fails; add `CanvasPreparedVector` and public raster-free preparation with exact-view admission, context closure, bounded failure mapping, intrinsic cleanup, and idempotent disposal; add one vector element, sparse update, descriptor, synchronous resolver branch, typed store/import/frame facts, Schema v1 branches, relationship classification, background/content projection, geometry, interaction snapshots, aggregate image/vector borrowing, placeholders, direct painting, selection chrome, and group opacity; update affected current semantic owners, public registry, section/diagram relationships, architecture graph, ADR catalog, proof registration, durable verification inventory, and generated projections.

Out of Scope: Raw SVG compilation or parsing; embedded PNG/JPEG or other raster commands as supported input; a fork or patch of `vector_graphics`; process-global Flutter error interception; a duplicate `.vec` parser, raster-command recognizer, hostile-content sandbox, exact decoded-command or decoded-memory bound; engine file, network, asset-bundle, or external-reference IO; serialized `.vec`, SVG, or base64 payloads; public `PictureInfo`, upstream exceptions/types, `ui.Picture`, prepared constructor, or liveness getter; asynchronous resolver state, pending preparation, lazy attach-time decode, or completion repaint; an engine reverse wrapper-to-key/session registry; application-visible generation/revision keys; session/frame disposal of application values; natural-size synchronization; image rasterization, path-level Picture hits, color/theme remapping, Schema v2, a diagnostics field or vector-specific diagnostic route, a successful-release result taxonomy, an invalidation compatibility alias, a permanent legacy-name scanner, restored retired benchmark machinery, or a frame-wide opacity degradation cap.

Source of Truth: Store rows are the sole committed vector document truth and Schema v1 is their wire projection. `CanvasElementKind` alone owns semantic family identity; sealed resource types own descriptor kind and sealed render rows own frame-only payload shape without parallel enums. The public preparation contract alone owns raster-free input; the transient adapter alone owns the exact-view copy until settlement. Under non-interfering global Picture hooks, the application-owned wrapper alone owns Picture liveness and disposal; the non-exported accessor only observes admitted state. Application publication state owns wrapper aliases; engine generation/resource/revision keys own derived borrows but never wrapper uniqueness. Intrinsic size is paint source extent, element size is geometry target extent, and natural size remains optional document data. Validation limits owns 32 MiB; cache policy alone owns cache numbers; resources owns lifecycle; diagnostics owns existing routing; public API, schema, codec, resource, operation, frame, geometry, interaction, architecture, verification, registry, and ADR documents keep their existing concern ownership. The public export registry remains the only authorized copied inventory because it has its own consumer and parity check.
  Public equality is not inferred from prepared fields or liveness: the public API equality owner classifies the wrapper once, and Dart object identity is the only source of its equality and hash behavior.

Compatibility: Schema v1 remains version 1; old image-only documents retain exact canonical output, current readers accept vector branches, and older binaries reject vector kinds through their existing unknown-kind rule. Existing image/path/text/stroke/line/rect behavior, cache limits, diagnostics routes, selection behavior, and post-acceptance failure containment remain unchanged. Public additions are source-compatibility events for exhaustive switches; `CanvasResourceResolver` implementers add the synchronous vector method and external `CanvasDataErrorCode` switches add `resourceKindMismatch`. No public symbol is renamed or removed. Image-only sessions retain the effective 1024-entry and 64 MiB behavior; mixed sessions share 1024 entries and vector borrows have no guessed byte weight. Callers must reprepare for locale/direction change and release every application publication before disposal. Observation-only Picture hooks remain compatible; interfering hooks and embedded-raster input are explicitly unsupported. No document migration is required.
  External exhaustive `CanvasDataErrorCode` switches adopt both `invalidVectorData` from Unit 2 and `resourceKindMismatch` from Unit 5. `CanvasPreparedVector` enters the public API with default identity equality; callers compare stable public fields explicitly for semantic comparison, and a later value-equality change requires a new public API behavior decision.

Order Constraints: Unit 1 starts from the already-current generic release implementation and atomically closes its release-specific resource/operation/runtime-ownership semantics, hand-authored diagrams, existing graph edge, and generated projections before committing. Unit 2 first records Design D16 identity equality for lifecycle-owning `CanvasPreparedVector` in the current public API owner, then atomically adds `CanvasDataErrorCode.invalidVectorData`, implements the type and exact `prepareVector(ByteData, {BuildContext? context})` helper, lands their public export-registry entries, and closes every preparation/public/validation semantic owner and affected structured projection before committing; preparation performs `vector.bytes` size admission, exact-range copy, invocation-time locale/direction capture, and `vg.loadPicture` invocation before first await, then selected-Future mapping at `vector.bytes`, intrinsic admission at `vector.intrinsicSize`, and wrapper publication. Unit 3 makes the current descriptor, final-candidate relationship, and immutable frame facts explicitly kind-aware while preserving image-only public and wire behavior, then closes the affected schema/resource/frame/data-model owners and graph relationships in the same commit. Unit 4 consumes Units 1 and 3 to generalize the current image-shaped request/result/cache/binding/output path into one family-neutral resource pipeline while preserving all image outcomes and current numeric policy, then closes the affected resource/cache/frame/architecture owners, diagrams, graph, and projections before committing. Unit 5 adds the public sealed vector family plus `resourceKindMismatch` atomically across every production exhaustive branch, resolver implementation, binding, public registry entry, external fixture, and test double so the repository compiles, and closes all affected public/schema/codec/edit/load/resource/cache/frame/geometry/interaction/architecture owners, registries, diagrams, graph, proof registrations, and projections in the same unit; temporary interaction/render mirrors receive complete vector branches at this step. Its frame order is capture, record completion, resource pass, cache/liveness admission, synchronous resolution, immutable binding, clip/translate/scale, zero-or-one layer, `drawPicture`, restore. Relationship validation precedes codec DTO return, exported JSON return, and store install. Caller order is freshness check, immediate stale disposal without publication, or current publication before attach; replacement is prepare new, publish new, release every old alias/session/output, then dispose old. Only after direct seven-family interaction and selection outcomes pass does Unit 6 retire the interaction mirror and atomically close its interaction/runtime-ownership/diagram/graph/proof owners, and Unit 7 retire the frame mirror and atomically close its frame/runtime-ownership/diagram/graph/proof owners. Unit 8 performs only terminal ADR-0016 catalog/concern closure, cross-unit proof-inventory reconciliation, structured parity and generated-projection verification, and lifecycle archival; it must not be the first unit to record a feature semantic or route introduced by Units 1-7.

Temporal Surface Closure: Preparation synchronously rejects an oversized view, copies only the supplied range, and captures effective locale/direction before its first await. The original buffer is unborrowed when the Future returns; mutation or release cannot affect decode. Transient upstream invocation retention is allowed only until settlement; no engine or completed-upstream owner retains the snapshot or supplied BuildContext afterward. Global Picture hooks may observe and must return without disposal or mutation; interference ends the supported contract. `resolveImage` and `resolveVector` remain synchronous, guarded, and share the per-frame call budget. Invalid/disposed prepared values are not cached or bound, are suppressed for that key in the frame, and retry only in a later frame. Target/all invalidation, resolver replacement, reset, detach, drop, and runtime swap remove matching session and output borrows before return; active identities clear before notification and stale identities prove absence without mutating current output. Target release proves only one resource publication absent; disposal waits for every same-wrapper publication across resource ids and attached surfaces/runtimes.

All-Or-Nothing Failure Boundary: Oversize preparation rejects as `CanvasDataException(code: fieldMaxLength, path: 'vector.bytes')` before copy/upstream work; any error completion from the awaited selected-upstream Future maps to `CanvasDataException(code: invalidVectorData, path: 'vector.bytes')` with no wrapper publication; intrinsic validation uses the existing finite/positive/maximum policy at `vector.intrinsicSize`, and its failure disposes the exact unpublished Picture once before propagation. Unsupported embedded-raster input and interfering Picture hooks have no defined result taxonomy. Codec-local explicit decode returns no `CanvasDocument`, exported encode returns no JSON, and edit/load install no candidate until typed resource relationships pass; rejected mutations preserve document, revisions, selection, output, and diagnostics ownership. Generic reference retirement is non-fallible and establishes no matching borrow before any fallible notification; a later notification failure remains contained and cannot rethrow, roll back, block accepted state/revision/repaint/return publication, or restore a borrow. Wrapper disposal first retires its private reference, disposes the Picture at most once, and becomes an idempotent no-op thereafter.

Negative Proof And Fixture Quarantine: Invalid states include oversize or whole-backing-buffer copy, post-return input borrowing, post-settlement snapshot/context retention, post-call context values, supported embedded-raster claims, fork/global interceptor/duplicate recognizer, public prepared construction/liveness/Picture, selected-Future error leakage, invalid intrinsic Picture leak, absent/wrong-kind code or path collapse, partial DTO/JSON/store publication, exported internal decode helpers, pending resolver state, separate family caches, vector byte weighting, disposed wrapper cache/paint, engine disposal, incomplete session/output release, alias disposal before aggregate release, application-visible engine keys, post-acceptance failure escape, stale release mutation, retained duplicate family enum/field/mapping, non-`outsideBox` vector selection chrome, vector diagnostics ownership, image conversion, escaping target clip, or more than one partial-opacity layer. Durable fixtures may contain raster-free `.vec` bytes, sentinel buffers, malformed release-rejected bytes, invalid intrinsic content, observation-only hooks, contexts, retaining-path probes, wrappers, images, canvases, and selection facts only under test ownership. Fixture bytes, dimensions, ids, cache keys, package types, family inventories, and diagnostic vocabulary never enter production DTOs, schemas, registries, or semantic docs. Embedded-raster material may document upstream limitations only and never becomes a supported acceptance fixture.
  Equality-specific invalid states are value equality for `CanvasPreparedVector`, equality/hash derived from intrinsic size or private Picture identity, and equality/hash changing when disposal mutates liveness. Direct external behavior over distinct equal-size wrappers before and after disposal is required; owner prose, unequal public values, private liveness inspection, or a fixture-derived identity marker is insufficient.

Bounded Recognition Scope: No new analyzer, schema validator architecture, general source recognizer, or generated-output grammar is introduced. Existing structured export, docs, ADR, and architecture checks continue consuming their established owners. Legacy invalidation and duplicate-family absence is one-time implementation diff/analyzer evidence combined with durable owner behavior; no replacement-name inventory or permanent token scanner is admitted.

## Execution Units

### [x] Unit 1: Close generic resource release semantics and graph ownership

Owner: Release-specific resource and operation contracts, runtime-ownership documentation, semantic diagrams, the existing runtime-to-session graph edge, and their generated projections.
Boundary: Start from the current generic non-fallible target/all release implementation and close its still-stale current source owners without adding vector resolution, changing image resolver/cache policy, or reopening application ownership and accepted-publication behavior.
Verification Profile: `SOURCE_OF_TRUTH_DOCS`
Change: Align only the current release-specific semantic owners, hand-authored diagrams, existing graph edge, and generated projections with the already-current two-borrow target/all release, post-acceptance containment, stale-identity, and application no-dispose behavior while preserving all production behavior and later aggregate/vector documentation scope.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `generic-resource-release` | Current production already removes active or stale target/all session-cache and retained-output borrows through the generic release seam, while its semantic owners still describe image/session invalidation. | Release-specific current owners are aligned without changing the implementation. | The documented return contract matches the current synchronous non-fallible no-borrow or stale-absence behavior for dirty delivery, replacement, reset, detach, drop, and runtime swap. | Target release remains resource-id scoped, invokes no resolver or app disposal, and existing direct owner coverage remains authoritative rather than prose. |
| `post-acceptance-resource-containment` | Current runtime behavior contains notification failure after generic reference removal, while operation/resource semantics still describe the retired invalidation form. | The current operation and lifecycle owners are aligned with the accepted-publication boundary. | Documentation states that accepted document/dirty state, revisions, repaint intent, return, and the no-borrow postcondition survive later notification failure. | Rejected/no-op paths still mutate neither retention owner; documentation introduces no new public error or success taxonomy. |
| `resource-seam-retirement` | Production and stable proof registration have retired the image-named seam and copied private inventories, but current semantic and graph owners still name the old boundary. | Remaining current owner and graph references migrate to the generic release meaning. | No current source owner, graph actual field, consumer, compatibility alias, copied replacement inventory, or false proof registration preserves the retired seam. | Stable dependency-boundary and external app-key behavior proof remains; absence is one-time source evidence, not a permanent scanner. |
| `release-semantic-owner-closure` | Current resource, operation, runtime-ownership, diagram, and graph owners still describe the retired image-named invalidation seam or session-cache-only effects. | Release-specific source owners and graph projections are updated together. | Current semantic owners state target/all session and retained-output release before notification with contained post-acceptance failure, and the existing graph edge resolves through the generic release seam. | Only release-specific meaning moves forward: image-only resolver/cache behavior and cache values remain unchanged until later units, no vector or aggregate-cache route is documented early, graph source documents agree with the edge, and generated projections remain non-authoritative. |

Depends On: None

### [x] Unit 2: Add the bounded public vector preparation boundary

Owner: Public contracts own `CanvasDataErrorCode.invalidVectorData`, the prepared-result/default-identity contract, and the exact helper signature; the API preparation adapter owns `vg.loadPicture`, byte/context admission, failure projection, intrinsic validation, private Picture access, and cleanup; current public API, validation, preparation, dependency-boundary, registry, architecture, and generated-projection owners record that boundary in the same unit.
Boundary: Add preparation and prepared-result lifecycle and close every semantic or structured owner affected by that public boundary without yet admitting a vector document family, `resourceKindMismatch`, or frame resolver branch; third-party types and raw Picture remain private, and generated projections remain non-authoritative.
Verification Profile: `BEHAVIOR_CHANGE`
Change: Preserve Design D16 by first classifying lifecycle-owning `CanvasPreparedVector` under the existing default-identity public API owner, then atomically add `CanvasDataErrorCode.invalidVectorData`, the direct upstream dependency, the helper-only class, and exact public `prepareVector(ByteData, {BuildContext? context})`. The adapter checks `ByteData.lengthInBytes <= 32 * 1024 * 1024` at `vector.bytes`, copies only the supplied view, captures invocation context, and invokes `vg.loadPicture` over that copy before first await; it maps every error completion of the awaited selected-upstream Future to `invalidVectorData` at `vector.bytes`, validates intrinsic size through the existing finite/positive/maximum policy at `vector.intrinsicSize`, disposes the exact unpublished Picture on intrinsic failure, keeps live-Picture access private, exposes only intrinsic size plus idempotent application-owned disposal, lands the matching public export-registry entries, and closes affected preparation/public/validation/dependency/architecture owners and projections in the same unit.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `prepared-vector-identity-equality` | The future prepared type has no admitted public equality policy. | Before class implementation, the current public API equality owner classifies it and existing equality-policy verification adopts it. | Separate prepared wrappers remain unequal by identity even when their public intrinsic sizes match. | Mutable disposal/liveness ownership never participates in value equality, and later equality changes remain public behavior changes. |
| `prepared-public-api-shape` | No engine-defined prepared vector or preparation helper is public. | An external root-barrel consumer analyzes and uses the new preparation API. | It can await preparation, read intrinsic size, and dispose idempotently, but cannot construct the wrapper, inspect liveness, extract Picture, or name upstream types through engine signatures. | Vector DTOs gain no diagnostic field/hub type; only the helper constructs prepared values. |
| `preparation-view-ownership` | Caller input may be a nonzero-offset view over a larger mutable buffer. | Preparation is called and the caller immediately mutates/releases the original while the real selected loader continuation proceeds. | Decode observes only the original admitted view; prefix/suffix sentinels never enter decode, and completed preparations retain no per-completion engine-owned snapshot path. | Length is checked before allocation/upstream call, the copy occurs before first await, and claims cover retaining paths rather than GC timing. |
| `preparation-context-closure` | Raster-free text vectors can vary with effective locale and text direction. | Two preparations start under different effective contexts and a supplied context changes or unmounts during continuation. | Rendered outputs reflect invocation-time values and no engine/completed-upstream path retains the supplied context after settlement. | Transient in-flight retention is allowed; cache keys alone are not evidence; no production test-control seam is added. |
| `preparation-input-failure-bounds` | Inputs include limit-boundary views, named release-rejected streams, and an assertion-only malformed stream that upstream currently accepts. | Exact public `prepareVector(ByteData, {BuildContext? context})` invokes `vg.loadPicture` through the selected adapter and handles each input. | Oversize yields `CanvasDataException(code: fieldMaxLength, path: 'vector.bytes')` before copy/upstream; selected-Future errors yield `CanvasDataException(code: invalidVectorData, path: 'vector.bytes')` with no value; the accepted-malformed witness bounds rather than overstates validity claims. | `invalidVectorData` is added and exported in this unit; no upstream object/type/stack promise, partial wrapper, surface mutation, exhaustive validity claim, or embedded-raster guarantee is made. |
| `unpublished-picture-cleanup` | A real invalid-intrinsic stream reaches upstream Picture creation but cannot produce an admitted prepared result. | The existing finite/positive/maximum size admission runs at `vector.intrinsicSize` after decode. | The exact unpublished Picture is disposed once before the path-specific validation failure propagates and no wrapper or surface state is published. | The witness is independent from byte/error classification; observation-only hooks return normally and no fake liveness flag is used. |
| `prepared-wrapper-lifecycle` | A successful wrapper owns one upstream Picture under absent or observation-only global hooks. | The application disposes it repeatedly and engine internal access is attempted before and after disposal. | The exact Picture is available only while admitted, its private reference retires before one native disposal, and later disposal/access is a no-op/rejection. | Hooks return normally and do not dispose/mutate; interfering hooks are unsupported rather than detected through debug state. |
| `raster-free-private-adapter` | The package currently has no vector dependency or preparation route. | Supported raster-free bytes are prepared. | Caller bytes are the only input and no file/network/asset/external lookup, public upstream type, fork, global error interceptor, or duplicate parser/recognizer is introduced. | Embedded-raster input remains unsupported and upstream/package types stay behind API. |
| `preparation-owner-closure` | Current public, validation, dependency, architecture, registry, and diagram owners have no preparation boundary or prepared-wrapper lifecycle. | The affected current owners and structured projections are updated with the preparation implementation. | Public preparation, exact input/context ownership, bounded error and cleanup semantics, private upstream boundary, default identity, application disposal, and exports are current before Unit 2 commits. | No vector document family, resolver/cache/frame route, diagnostics route, upstream public type, duplicated signature inventory, or generated semantic owner appears early. |

Depends On: None

### [x] Unit 3: Make current resource facts and relationships kind-aware

Owner: Public resource descriptors, store final-candidate relationships, codec-local descriptor admission, immutable frame resource facts, and the affected schema/resource/frame/data-model/architecture owners, diagrams, graph relationships, and generated projections.
Boundary: Preserve the current image-only public API, Schema v1 wire form, store behavior, and frame output while replacing nullable MIME and id-membership inference with an explicit kind-aware owner and closing its current source owners; no vector public family or wire branch is introduced in this unit.
Verification Profile: `REFACTOR`
Change: Make current descriptor admission/projection, codec-local and store final-candidate validation, and immutable frame descriptor facts explicitly kind-aware for the sole current image kind; migrate current consumers and atomically align affected schema/resource/frame/data-model/architecture owners, diagrams, graph relationships, and projections without adding vector symbols, a second descriptor inventory, or a second relationship validator.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `typed-resource-foundation` | Current immutable facts infer image semantics from nullable MIME data and final-candidate relationships prove only resource-id membership. | Existing image documents decode, encode, edit, load, bind, and paint after descriptor/fact/relationship migration. | Every current image outcome and canonical wire value remains exact while descriptor kind is explicit and the shared relationship owner is ready to distinguish kind without MIME inference. | Unknown resource kinds still reject at the canonical reader; one reader and one final-candidate relationship owner remain; no public vector symbol, wire kind, second inventory, or behavior change appears. |
| `typed-resource-owner-closure` | Current schema/resource/frame/data-model and graph owners describe image behavior without the explicit kind-aware descriptor and relationship foundation. | The affected current owners, diagrams, graph relationships, and projections are updated with the refactor. | Current image-only semantics remain exact while the explicit kind and singular final-candidate relationship owner are documented before Unit 3 commits. | No vector symbol or wire branch appears, no second inventory/validator is introduced, and generated output remains non-authoritative. |

Depends On: None

### [x] Unit 4: Generalize the current resolved-asset pipeline

Owner: Resource request/result/cache/session owners, immutable frame binding/output owners, existing image lifecycle consumers, and the affected resource/cache/frame/architecture contracts, diagrams, graph relationships, and generated projections.
Boundary: Preserve all current image resolution, cache, placeholder, binding, output, and application-ownership behavior while making the existing path family-neutral and aggregate-ready and closing its current source owners; no public vector resolver branch is introduced in this unit.
Verification Profile: `REFACTOR`
Change: Generalize the current image-shaped request/result/cache value and binding/output handling into one typed resource-asset pipeline, retaining internal keys, current capacity and byte accounting, resolver guards and budget, placeholder semantics, generic release, and no-dispose ownership; atomically align affected resource/cache/frame/architecture contracts, diagrams, graph relationships, and projections without documenting vector admission early.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `resource-pipeline-foundation` | Requests, results, cache entries, immutable bindings, and retained output are image-shaped even where lifecycle policy is family-neutral. | Existing image hit, miss, suppression, retry, eviction, invalidation, binding, placeholder, paint, and output-retention flows execute through the generalized pipeline. | All current image outcomes remain exact through one family-neutral asset path that can later admit another sealed family without a second cache or output owner. | The effective 1024-entry and 64 MiB image behavior, internal key, per-frame guard/budget, synchronous resolution, generic release, and application no-dispose rule remain unchanged; no vector resolver branch or copied family inventory appears. |
| `resource-pipeline-owner-closure` | Current resource/cache/frame/architecture owners and diagrams describe image-shaped request, cache, binding, and output shapes. | The affected current owners, graph relationships, and projections are aligned with the generalized image-preserving pipeline. | Family-neutral ownership, unchanged image policy, generic release, and application no-dispose semantics are current before Unit 4 commits. | Cache numbers remain solely in cache policy; no vector branch, second cache, copied family inventory, new graph owner, or generated semantic owner appears. |

Depends On:

- Unit 1 — produces: generic non-fallible target/all session-output release; consumed as: the sole lifecycle seam for the generalized asset path.
- Unit 3 — produces: explicit current descriptor kind and kind-aware immutable facts; consumed as: typed request, cache, binding, and output discrimination without MIME inference.

### [x] Unit 5: Admit the vector family through every runtime owner

Owner: Public model, store, codec, edit/load, resource session, frame, geometry, interaction, their atomic seam consumers, and every affected public/schema/codec/operation/resource/cache/frame/geometry/interaction/architecture contract, registry, diagram, graph relationship, proof registration, and generated projection.
Boundary: Add the sealed public vector element/resource variants only together with every remaining production exhaustive branch, resolver implementation, binding, fake, test double, public export-registry entry, and current semantic or structured owner required for a compiling and mechanically consistent repository. Extend the existing interaction/render mirrors with vector only as the design-required temporary migration state; Units 6 and 7 retire them after direct vector outcomes pass.
Verification Profile: `BEHAVIOR_CHANGE`
Change: Add vector element/update/resource plus the family-neutral `resourceKindMismatch` relationship error and synchronous resolver surface, committed rows and sparse updates, typed Schema v1 import/encode and relationship validation, vector admission to the generalized aggregate cache, synchronous prepared resolution and placeholder policy, background/content capture, sized geometry and interactions, immutable bindings, direct clipped Picture paint, vector selection chrome, existing diagnostic routing, and all external/public projections. `invalidVectorData` and preparation paths are consumed from Unit 2 rather than redefined here. Before Unit 5 commits, align all affected public/schema/codec/operation/resource/cache/frame/geometry/interaction/architecture owners, registries, diagrams, graph relationships, proof registrations, and generated projections with the admitted vector behavior while keeping diagnostics ownership unchanged.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `vector-model-and-update` | Public/store families do not contain vector values. | External code constructs vector element/resource/update values, commits and reads them, and applies sparse updates. | All common and vector fields survive projection; only supplied update fields change; invalid size/natural-size paths reject before mutation. | Common-field truth is inherited, not copied into a second schema or feature inventory. |
| `vector-schema-roundtrip` | Schema v1 has image-only descriptor and six element branches. | Vector resources/elements are decoded and canonically encoded in background and content. | Descriptor-only JSON roundtrips all accepted fields with no `.vec`/SVG/base64 payload. | One reader/writer remains; current unknown-field policy and metadata owner remain unchanged. |
| `resource-relationship-classification` | Current sinks distinguish only present membership from absence. | Codec-local public DTO decode, exported encode, edit commit, and runtime load receive absent and both wrong-kind directions. | Absence yields `missingResourceReference`; existing wrong kind yields one `resourceKindMismatch`; each uses `image.resourceId` or `vector.resourceId` and returns/installs nothing partial. | Internal decode helpers stay unexported; assertions use code/path, not message text; no per-family mismatch codes appear. |
| `document-admission-atomicity` | A candidate may change a resource kind and every reference in one edit or may fail relationship admission. | Resource-plus-element edits run in either callback order and invalid edits/loads are attempted. | Coherent candidates succeed independent of callback order; rejected candidates preserve document, revisions, selection, and output. | Final-candidate validation precedes irreversible install and codec-local DTO return remains independently guarded. |
| `schema-v1-compatibility` | Existing canonical image documents and independent unknown-kind rejections are current behavior. | Old documents encode/decode and unknown element/resource witnesses are read after vector admission. | Old canonical output is exact; both unknown-kind branches still reject independently; no Schema v2 or second reader appears. | New vector kinds remain forward-incompatible with older binaries by the established unknown-kind rule. |
| `synchronous-vector-resolution` | Frame resource binding is synchronous and image-only. | A main frame resolves a vector descriptor through the public resolver. | It receives a prepared value or bounded placeholder in the same resource pass with no pending state or completion repaint. | Image/vector callbacks share the resolver guard and budget; no preparation or IO starts in frame. |
| `aggregate-resource-cache` | The session cache currently retains only images under its internal key. | Interleaved image/vector keys hit, miss, evict, invalidate, replace, and drop. | One LRU stays at 1024 aggregate entries; vector entries count zero against the image-only 64 MiB ledger; each family can evict the other. | Internal key remains generation/resource/revision, cache numbers live only in cache policy, and no reverse alias registry appears. |
| `disposed-prepared-admission` | A resolver or existing cache entry can contain a wrapper disposed through the supported public method. | The session admits/binds the value in one frame and retries in a later frame. | The invalid value is dropped, never exposes Picture, never caches/binds/paints, produces a bounded placeholder, suppresses same-frame retry, and retries later. | Session/frame does not dispose it or infer liveness from Flutter debug-only state. |
| `caller-context-freshness` | Two preparations for one logical vector can complete out of order across locale/direction changes. | The application observes a delayed stale completion and replaces a current published value. | The stale result is disposed immediately and never published; cache identity changes with effective locale/direction; current replacement publishes before attach, then every old publication releases before old disposal. | Freshness belongs to application state, not engine keys; engine generation/revision keys are neither supplied nor observed; context-capture semantics remain a separate preparation outcome. |
| `caller-publication-lifecycle` | One wrapper may be published under two resource ids and across multiple attached runtimes/surfaces. | The application replaces or retires it using target releases or aggregate replacement/detach. | One target release closes only its publication; disposal becomes safe only after every alias/session/output release, and no later paint uses the disposed wrapper. | Application neither supplies nor observes engine generation/revision keys; engine adds no reverse wrapper registry or success taxonomy. |
| `application-assets-not-disposed` | Images and prepared vectors are application-owned. | Cache eviction, invalidation, resolver replacement, reset, detach, drop, and dispose remove engine references. | Neither family's underlying application asset is disposed by engine resource/frame owners. | Exact unpublished intrinsic-failure cleanup and application-requested wrapper disposal remain the only engine-owned Picture disposal routes. |
| `vector-geometry-and-interaction` | Geometry, spatial, marquee/eraser/move, and interaction owners know only current families. | Vector elements appear in content and background with varied transforms and sizes. | Sized centered bounds drive spatial candidates, box hits, marquee/eraser/selection move, and content interaction while background remains excluded. | Prepared intrinsic size and natural size do not alter geometry; selection placement is proved separately; temporary mirrors are retired only in Units 6 and 7. |
| `vector-selection-placement` | Selection-decoration placement has no vector outcome and still mirrors render family. | One vector, every current single-family placement, and a mixed multi-selection are decorated. | Vector/image/rect use `outsideBox`, path/text/stroke/line retain `boundsOutline`, and multi-selection retains union-box chrome. | Direct selection-plan output is the oracle; no copied family inventory or geometry proxy is used; Unit 7 later preserves these outcomes while deleting the mirror. |
| `vector-interaction-context` | Context snapshot reconstruction and stale guards have no vector branch. | A visible content vector and a background vector receive context and text-commit flows. | Content requests carry an immutable `CanvasVectorElement` snapshot guarded by `CanvasElementKind.vector`; background yields no content target; vector cannot enter text commit. | Existing stale/no-op consumption, reliability handling, and one semantic kind owner remain unchanged. |
| `vector-frame-binding` | Asset binding and immutable output have no prepared Picture variant. | Valid, missing, failing, wrong-kind, and disposed vector resources bind for background/content records. | Valid assets enter immutable bindings; failures retain element-sized placeholders and never paint a Picture. | Resolver access remains only in binding, painters stay output-only, and retained output participates in generic release. |
| `vector-picture-paint` | Current painter draws image resources with image commands and has no vector row. | A prepared vector paints at multiple anisotropic target sizes. | Recording observes centered target clip/translation, independent x/y intrinsic scale, and `drawPicture`; pixels stay resolution-independent and no draw-image conversion occurs. | Commands cannot escape the target clip; natural size is not the source extent. |
| `vector-group-opacity` | Ordinary primitive alpha has no explicit vector group effect. | Full- and partial-opacity vectors, including overlapping opaque shapes and multiple records, paint. | Full opacity creates zero engine layers; partial opacity creates exactly one target-bounded layer per record and correct group-composited pixels. | Effect intent is record-explicit, no frame-wide degradation occurs, and retired benchmark ids/custom result schema are not restored. |
| `vector-diagnostics-routing` | Codec and interaction routes are generic while resource/frame paths are non-hub. | Vector schema rejection, an existing vector-targeted interaction reliability event, and preparation/resource/frame failures occur with diagnostics enabled and disabled. | Codec and interaction each use their existing route once; preparation/resource/frame allocate no record; disabled policy preserves no-allocation behavior. | Vector DTOs gain no diagnostic field, no new code/writer/stream/graph edge appears, and diagnostics owners remain otherwise unchanged. |
| `vector-owner-closure` | Current public/schema/codec/operation/resource/cache/frame/geometry/interaction/architecture owners, registries, diagrams, graph relationships, and proof registrations do not contain the admitted vector family or aggregate-resource route. | Every current owner affected by Unit 5 is updated with the implementation and its direct evidence. | Vector model, Schema v1, relationship admission, synchronous resolution, aggregate borrowing, lifecycle, geometry, interaction, frame painting, opacity, compatibility, and existing diagnostics routing are current before Unit 5 commits. | Cache numbers remain singular; diagnostics gains no feature route; temporary interaction/render mirrors are explicitly temporary; no generated output, test fixture, or copied family inventory becomes semantic authority. |

Depends On:

- Unit 1 — produces: generic non-fallible target/all session-output release; consumed as: vector borrow retirement and aggregate alias release-before-dispose.
- Unit 2 — produces: private-liveness `CanvasPreparedVector`, public preparation helper, and synchronized preparation exports; consumed as: synchronous resolver value, validity admission, immutable binding, direct Picture paint, and caller freshness.
- Unit 3 — produces: explicit descriptor kind, shared relationship admission, and kind-aware immutable facts; consumed as: the second descriptor kind, exact mismatch classification, and vector frame facts.
- Unit 4 — produces: one family-neutral request/result/cache/binding/output path with preserved image policy; consumed as: vector resolution, aggregate cache admission, immutable binding, and retained-output lifecycle without a parallel pipeline.

### [x] Unit 6: Retire the duplicate interaction family discriminator after vector admission

Owner: Interaction read facts, request guards, runtime interaction adapters, their stable behavioral fixtures, and the affected interaction/runtime-ownership contracts, diagrams, graph relationships, proof registrations, and generated projections.
Boundary: Preserve image/path/text/stroke/line/rect/vector context targeting, background exclusion, and text-commit behavior while making the already-carried `CanvasElementKind` the sole semantic discriminator and closing every current owner of that retirement in the same unit.
Verification Profile: `REFACTOR`
Change: After Unit 5 proves vector snapshot and text-rejection outcomes, migrate context target facts, request guards, stale text-commit admission, adapters, and fixtures to `CanvasElementKind`, delete the copied interaction enum, fields, mapping, and compatibility surface, and atomically align affected interaction/runtime-ownership contracts, diagrams, graph relationships, proof registrations, and projections.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `interaction-kind-singularity` | Context and text-guard facts temporarily carry public kind plus an interaction-family mirror extended for vector. | Current and vector context requests and guarded text commits are issued, revalidated, consumed, rejected, or accepted after migration. | All seven-family observable outcomes remain unchanged and only `CanvasElementKind` determines target identity and text-only admission. | Background remains excluded, unknown/stale/non-text requests preserve no-mutation behavior, and no duplicate enum/field/mapping or compatibility alias remains. |
| `interaction-owner-closure` | Unit 5 current owners explicitly record the complete temporary interaction-family mirror required for vector admission. | Interaction/runtime-ownership owners, diagrams, graph relationships, proof registrations, and projections are updated as the mirror is retired. | All current sources of truth identify `CanvasElementKind` as the sole interaction discriminator before Unit 6 commits. | No replacement kind inventory, compatibility alias, permanent legacy scanner, generated semantic owner, or unrelated interaction behavior change appears. |

Depends On:

- Unit 5 — produces: passing image/path/text/stroke/line/rect/vector context reconstruction and text-only rejection through the temporary complete mirror; consumed as: the retirement gate required by the accepted sequence.

### [x] Unit 7: Retire the duplicate frame family discriminator after vector admission

Owner: Frame immutable-record, selected-move supplement, painter, selection-decoration owners, and the affected frame/runtime-ownership contracts, diagrams, graph relationships, proof registrations, and generated projections.
Boundary: Preserve image/path/text/stroke/line/rect/vector record, paint, cache, and selection outcomes while making sealed render rows the only frame payload discriminator and closing every current owner of that retirement in the same unit.
Verification Profile: `REFACTOR`
Change: After Unit 5 proves the sealed vector row and direct vector selection outcomes, migrate selection placement and record consumers to sealed-row pattern matching, remove copied family constructor values, delete the render enum, stored field, mapping, and compatibility surface, and atomically align affected frame/runtime-ownership contracts, diagrams, graph relationships, proof registrations, and projections.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `render-row-discriminator-singularity` | Records temporarily store a sealed row plus a render-family mirror extended for vector. | Frame capture, selection decoration, selected-move supplement, caching, and all seven-family painting execute after migration. | The same records, paint, cache, and chrome outcomes are produced through sealed-row dispatch and no duplicate enum, stored field, mapping, constructor value, or alias remains. | Vector/image/rect stay `outsideBox`; path/text/stroke/line stay `boundsOutline`; multi-selection stays a union box; Unit 5 vector paint/binding outcomes remain exact. |
| `frame-owner-closure` | Unit 5 current owners explicitly record the complete temporary render-family mirror required for vector admission. | Frame/runtime-ownership owners, diagrams, graph relationships, proof registrations, and projections are updated as the mirror is retired. | All current sources of truth identify sealed render rows as the sole frame payload discriminator before Unit 7 commits. | No replacement family inventory, compatibility alias, permanent legacy scanner, generated semantic owner, or change to seven-family paint/cache/chrome behavior appears. |

Depends On:

- Unit 5 — produces: passing sealed vector-row paint/binding and direct seven-family selection-placement outcomes through the temporary complete mirror; consumed as: the retirement gate required by the accepted sequence.

### [ ] Unit 8: Close ADR, cross-unit proof inventory, and lifecycle

Owner: ADR-0016 and its catalog/concern lifecycle, cross-unit verification/proof inventory, terminal structured-registry and architecture-graph parity, generated projections, and planning lifecycle closure.
Boundary: Integrate only semantics and structured relationships already closed by Units 1-7; do not make Unit 8 the first owner of feature behavior, defer a unit-local graph or registry update, or make generated output, tests, historical artifacts, or duplicated prose into behavior authority.
Verification Profile: `SOURCE_OF_TRUTH_DOCS`
Change: Create ADR-0016 with atomic numbering/catalog/concern closure; reconcile the cross-unit proof and verification inventory against direct owners already current from Units 1-7; reverify public, section, diagram, and architecture-graph structured parity; refresh generated projections; close all findings and lifecycle artifacts. No feature semantic, unit-local route, mirror retirement, or public registry entry may first land here.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `semantic-owner-closure` | Units 1-7 have each closed the semantic owners and diagrams affected by their implementation or retirement. | Terminal ADR and cross-unit verification/proof inventory link and reconcile those already-current owners. | The durable decision and proof inventory cover public preparation/model, Schema v1, vector lifecycle, aggregate resource policy, frame, geometry, interaction, architecture, and verification without semantic drift. | No prior-unit semantic meaning changes here; cache numbers stay singular, diagnostics routes stay unchanged, and no prose parser or generated semantic owner is introduced. |
| `adr-0016-closure` | ADR next-id text contradicts the existing ADR-0001 through ADR-0015 catalog. | The durable vector architecture decision is recorded. | Next id is repaired to ADR-0016, ADR-0016 file/catalog/concern entries land together, and next id advances to ADR-0017. | The ADR links current owners and accepted design, does not copy mutable signatures/numbers/inventories, and no id is reserved separately. |
| `structured-projection-closure` | Units 1-7 have closed every unit-local public/section/diagram/graph relationship and refreshed affected projections. | Terminal structured checks reconcile cross-unit relationships and regenerate disposable views from current owners. | Export parity, registered relationships, existing graph closure, and generated views agree across the completed change. | No unit-local route or public registry entry first lands here; no new architecture owner or vector diagnostics edge is added; generated output remains disposable. |
| `manual-mirror-retirement` | Units 1-7 have retired or updated each design-identified mirror and its unit-local registration at the stable owner. | Terminal proof inventory reconciles cross-unit credit and verifies the authoritative external app-key proof remains singular. | No stale registration or duplicate proof credit remains across the completed change. | No mirror is first repaired here, and no copied replacement family/cache/private inventory, permanent legacy-name scanner, or self-referential fixture becomes authority. |

Depends On:

- Unit 1 — produces: verified generic release plus release-specific semantic and graph closure; consumed as: ADR lifecycle rationale and cross-unit proof baseline.
- Unit 2 — produces: verified public preparation, wrapper lifecycle, public/validation semantic closure, and synchronized export registry; consumed as: ADR rationale and cross-unit proof baseline.
- Unit 3 — produces: verified kind-aware descriptor/relationship/frame facts plus their semantic and graph closure; consumed as: ADR rationale and cross-unit proof baseline.
- Unit 4 — produces: verified family-neutral resolved-asset pipeline plus resource/cache/frame architecture closure; consumed as: ADR rationale and cross-unit proof baseline.
- Unit 5 — produces: verified end-to-end vector behavior plus all affected semantic, registry, diagram, graph, and proof closure; consumed as: ADR rationale and cross-unit proof baseline.
- Unit 6 — produces: verified public-kind-only interaction ownership plus interaction semantic/graph/proof closure; consumed as: terminal cross-unit proof baseline.
- Unit 7 — produces: verified sealed-row-only frame ownership plus frame semantic/graph/proof closure; consumed as: terminal cross-unit proof baseline.

## Verification Matrix

| Evidence key | Covers | Evidence class | Evidence surface | Pre-implementation witness | Pass signal | Evidence constraints and rejected proxy | Durable impact | Artifact target | Admission |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `render-row-owner-evidence` | `render-row-discriminator-singularity` | `TEST` | Existing frame selection-decoration, record-painter, selected-supplement, and cache-owning suites extended by Unit 5 vector outcomes plus one-time resolved-source inspection. | After vector admission records expose a complete seven-family `RenderElementFamily`, store `family`, and selection placement reads it. | All seven family record/paint/cache/placement outcomes are unchanged through sealed rows while resolved production/tests contain no duplicate declaration, field, mapping, constructor argument, or alias. | Direct owner behavior and analyzer resolution are admissible; token-only absence, a replacement family inventory, or unrelated green frame tests are rejected. | `UPDATE_EXISTING` | `test/frame/fixtures/selection_decoration_plan_fixture.dart`, `frame_record_painter_boundary_fixture.dart`, `frame_drawable_main_policy_fixture.dart`, and selected-move owning coverage | None |
| `frame-owner-doc-evidence` | `frame-owner-closure` | `MANUAL_INSPECTION` | Unit 7 frame/runtime-ownership contract, diagram, graph, proof-registration, and projection diff. | Unit 5 current owners explicitly carry the complete temporary render-family mirror. | All affected owners identify sealed render rows as the sole frame payload discriminator and preserve the seven-family paint/cache/chrome outcomes before Unit 7 commits. | Direct current-owner and structured relationship review is admissible; Unit 8 prose, generated output, or a replacement family inventory is rejected. | `NONE` | None | None |
| `interaction-kind-owner-evidence` | `interaction-kind-singularity` | `TEST` | Existing interaction read, context request, eraser routing, and text stale-commit owners extended by Unit 5 vector outcomes plus one-time resolved-source inspection. | After vector admission facts and fixtures construct and compare a complete seven-family `InteractionElementFamily`. | All seven family request/guard outcomes pass through `CanvasElementKind` alone and no duplicate declaration, field, mapping, consumer, or alias remains. | Direct request/commit outcomes are admissible; private field-name assertions or a copied kind inventory are rejected. | `UPDATE_EXISTING` | `test/interaction/fixtures/interaction_read_port_fixture.dart`, `context_action_request_fixture.dart`, `text_edit_stale_commit_guard_fixture.dart`, and `eraser_context_action_routing_fixture.dart` | None |
| `interaction-owner-doc-evidence` | `interaction-owner-closure` | `MANUAL_INSPECTION` | Unit 6 interaction/runtime-ownership contract, diagram, graph, proof-registration, and projection diff. | Unit 5 current owners explicitly carry the complete temporary interaction-family mirror. | All affected owners identify `CanvasElementKind` as the sole interaction discriminator before Unit 6 commits. | Direct current-owner and structured relationship review is admissible; Unit 8 prose, generated output, or a replacement kind inventory is rejected. | `NONE` | None | None |
| `generic-release-evidence` | `generic-resource-release` | `TEST` | Current resource session, runtime dirty/load publication, surface lifecycle, and retained-output owning suites preserved through Unit 1. | Production and direct owner evidence already establish active/stale target/all/replacement/reset/detach/drop removal of matching cache/output borrows, while current semantics are stale. | The unchanged direct suites remain green after release-specific source-owner closure and still prove synchronous no-borrow return without resolver calls or disposal. | Existing owner behavior is the oracle; docs wording, one callback count, session length only, or a result enum is rejected. | `NONE` | None | None |
| `post-acceptance-containment-evidence` | `post-acceptance-resource-containment` | `TEST` | Current runtime edit/load/dirty delivery owner with failure at the post-removal notification boundary, preserved through Unit 1. | Production and direct owner evidence already establish retained-output removal, contained later notification failure, and accepted publication, while current operation/resource semantics are stale. | The unchanged direct suites remain green after source-owner closure and still observe accepted state, revision, repaint, return, and both no-borrow owners. | Public outcome plus both borrow owners are the oracle; docs wording, source ordering, swallowed exception alone, or an always-green operation test is rejected. | `NONE` | None | None |
| `resource-seam-retirement-evidence` | `resource-seam-retirement` | `SOURCE_QUERY` | One-time resolved source query over current semantic/graph references plus preserved stable dependency-boundary and external app-key owners. | Production, consumers, test doubles, and proof registration have retired the image-named seam, but current semantic and graph owners still preserve the retired boundary. | No current semantic/graph reference, declaration, consumer, alias, copied replacement inventory, or stale proof registration remains; stable behavioral owners remain green. | One-time resolved evidence is admissible only with the current behavioral rows above; a committed token scanner or replacement inventory is rejected. | `NONE` | None | None |
| `prepared-equality-evidence` | `prepared-vector-identity-equality` | `TEST` | Existing public equality-policy owner and `test.api_contract.public_equality_policy` behavior over two distinct successful prepared wrappers with equal intrinsic-size values before and after disposal. | The future prepared type is absent from the owner and cannot be compared. | The owner classifies default identity equality before implementation; distinct equal-size wrappers remain unequal and their identity equality/hash behavior does not change when lifecycle state changes. | Design D16 public behavior and current policy ownership are admissible; prose classification alone, wrappers with different public values, a marker field, or private liveness inspection is rejected. | `UPDATE_EXISTING` | Existing public equality-policy owner and API contract artifact family | None |
| `prepared-api-shape-evidence` | `prepared-public-api-shape` | `STATIC_ANALYSIS` | External root-barrel public API compilation, export parity, and resolved signature traversal. | No prepared wrapper/helper exists, so required use fails and forbidden construction/liveness/Picture/upstream-type boundaries are unproved. | Required public use compiles; forbidden external construction/access does not; exports match the registry and signatures contain no upstream or diagnostics types. | Effective public surface is admissible; source-file existence, private-name scans, or in-package access are rejected. | `EXTEND_COVERAGE` | Existing external API contract and public export artifact families | `prepared-public-api-admission` |
| `exact-view-evidence` | `preparation-view-ownership` | `RUNTIME` | Public preparation with real raster-free nonzero-offset sentinel input across the selected continuation plus bounded VM retaining-path observation. | No helper exists and no exact-view, mutation-independence, or completed-snapshot retention outcome can be observed. | Mutation cannot change decode, sentinels never enter input, and repeated settled calls show no linear retained snapshot owner while live Pictures are accounted separately. | Real adapter continuation and object retaining paths are admissible; full-buffer success, field inspection, timing sleep, or immediate GC collection is rejected. | `ADD` | Preparation-owner raster-free fixture and VM retention artifact family | `exact-view-preparation-admission` |
| `context-closure-evidence` | `preparation-context-closure` | `RUNTIME` | Real locale/direction-sensitive raster-free vector under two effective contexts plus post-settlement context retaining-path observation. | No preparation output exists and caller cache identity cannot prove decode context or non-retention. | Rendered output differs as required by invocation-time values despite context change/unmount, and no completed owner retains the supplied context. | Rendered output and identity retaining paths are admissible; cache-key difference, one context, source capture shape, or GC timing is rejected. | `ADD` | Preparation-owner context-sensitive raster fixture and VM retention artifact family | `context-sensitive-preparation-admission` |
| `preparation-input-failure-evidence` | `preparation-input-failure-bounds` | `TEST` | Exact public `prepareVector(ByteData, {BuildContext? context})` over boundary-size, header/version, unknown-tag, truncated-field, named release-rejected, and assertion-only upstream-accepted malformed raster-free witnesses through real `vg.loadPicture`. | The public helper, `invalidVectorData`, and their bounded input/error classification are absent. | Oversize produces `fieldMaxLength` at `vector.bytes` before snapshot/upstream; selected-Future failures produce `invalidVectorData` at `vector.bytes` with no value/publication; the accepted-malformed witness prevents an exhaustive-validity claim. | Real selected-Future behavior and the assertion-only accepted witness are admissible; arbitrary upstream error identity, embedded-raster behavior, message text, or injected production decode results are rejected. | `ADD` | Preparation-owner bounded input/error classification artifact family | `preparation-input-failure-admission` |
| `unpublished-picture-cleanup-evidence` | `unpublished-picture-cleanup` | `TEST` | Real invalid-intrinsic raster-free witness that creates a Picture plus observation-only lifecycle hooks and public path observation. | No preparation route can expose intrinsic rejection after native Picture creation. | Existing finite/positive/maximum admission rejects at `vector.intrinsicSize`; the exact unpublished Picture is disposed once before failure and no wrapper or surface state is published. | Exact path plus Picture identity/disposal is admissible; byte-error classification, message text, fake booleans, debugDisposed, or injected production decode results are rejected. | `ADD` | Preparation-owner invalid-intrinsic Picture cleanup artifact family | `unpublished-picture-cleanup-admission` |
| `prepared-lifecycle-evidence` | `prepared-wrapper-lifecycle` | `TEST` | Observation-only Picture hooks, public disposal, and non-exported binding access under supported hook behavior. | There is no wrapper whose owner/reference/disposal lifecycle can be observed. | One native Picture identity is live only before wrapper disposal and is disposed at most once; repeated disposal is silent and internal access rejects afterward. | Native identity observation under non-interfering hooks is admissible; debugDisposed, public liveness, raw Picture export, or interfering-hook recovery is rejected. | `ADD` | Prepared-result lifecycle owning artifact family | `prepared-lifecycle-admission` |
| `private-adapter-evidence` | `raster-free-private-adapter` | `STATIC_ANALYSIS` | Public signature/dependency boundary checks plus denied file/network/asset probes during preparation. | No vector dependency route exists and current docs explicitly do not allow assuming absence of IO. | Supported preparation uses only caller bytes; upstream types stay private; no engine IO, fork, global interceptor, or duplicate recognizer appears. | Boundary/import enforcement and denied probes are admissible; offline success, URI-field absence, or prose claims alone are rejected. | `EXTEND_COVERAGE` | Existing public/import/resource boundary artifacts plus preparation denied-IO owner family | `private-vector-adapter-admission` |
| `preparation-owner-doc-evidence` | `preparation-owner-closure` | `MANUAL_INSPECTION` | Unit 2 public API, validation, preparation, dependency-boundary, registry, architecture, diagram, and projection diff. | Current owners have no prepared wrapper, helper, input/context lifetime, bounded error/cleanup, private-upstream, or default-identity semantics. | Every affected current owner and structured projection matches the implemented Unit 2 boundary before commit. | Direct current-owner review plus established registry/docs/architecture checks is admissible; Unit 8 prose, generated output as authority, or a duplicated signature inventory is rejected. | `NONE` | None | None |
| `typed-resource-foundation-evidence` | `typed-resource-foundation` | `TEST` | Existing canonical codec, store finalization, immutable frame-facts, image binding, and painter owner suites plus resolved owner inspection. | Current frame descriptor facts carry nullable MIME without kind and current final-candidate relationship admission proves ids only. | Existing image decode/encode/edit/load/frame outcomes and canonical values remain exact through explicit descriptor-kind facts and one kind-aware relationship owner. | Existing public outcomes and resolved owner singularity are admissible; private field-name locking, copied kind inventories, or vector behavior in this unit is rejected. | `UPDATE_EXISTING` | Existing codec, store finalization, frame-facts, image binding, and painter artifact families | None |
| `typed-resource-owner-doc-evidence` | `typed-resource-owner-closure` | `MANUAL_INSPECTION` | Unit 3 schema/resource/frame/data-model/architecture contract, diagram, graph, and projection diff. | Current owners describe image behavior without the explicit kind-aware descriptor and relationship foundation. | Affected current owners record the explicit kind and singular relationship owner while preserving image-only public and wire semantics before Unit 3 commits. | Direct current-owner and structured relationship review is admissible; vector semantics, Unit 8 prose, generated output as authority, or a copied kind inventory is rejected. | `NONE` | None | None |
| `resource-pipeline-foundation-evidence` | `resource-pipeline-foundation` | `TEST` | Existing image resource request/result/cache/session, immutable binding/output, painter, budget, placeholder, and lifecycle owner suites. | Current image-specific request/result/cache/binding shapes cannot admit another family without duplication. | Every current image hit/miss/retry/eviction/release/binding/output/paint outcome remains exact through one family-neutral pipeline with unchanged limits, accounting, budget, placeholders, and no-dispose ownership. | Direct current behavior across each stable owner is admissible; private type-name locking, a copied family inventory, or a second cache is rejected. | `UPDATE_EXISTING` | Existing image resource session/cache, frame binding/output, painter, budget, placeholder, and lifecycle artifact families | None |
| `resource-pipeline-owner-doc-evidence` | `resource-pipeline-owner-closure` | `MANUAL_INSPECTION` | Unit 4 resource/cache/frame/architecture contract, diagram, graph, and projection diff. | Current owners describe image-shaped request, cache, binding, and output shapes. | Affected current owners record the family-neutral image-preserving pipeline, unchanged cache policy, generic release, and application no-dispose ownership before Unit 4 commits. | Direct current-owner and structured relationship review is admissible; vector semantics, duplicated cache numbers, Unit 8 prose, or generated output as authority is rejected. | `NONE` | None | None |
| `vector-model-evidence` | `vector-model-and-update` | `TEST` | External root-barrel DTO/update use, constructor admission, edit/store projection, and before/after sparse-update outcomes. | Vector constructors, committed rows, and updates do not exist. | All common/vector fields project and only supplied fields change; invalid size paths reject before draft mutation. | External behavior and state snapshots are admissible; construction alone, copied common-field inventory, or roundtrip alone is rejected. | `EXTEND_COVERAGE` | Existing public API, edit field-update, and store projection artifact families | `vector-model-admission` |
| `vector-schema-evidence` | `vector-schema-roundtrip`, `schema-v1-compatibility` | `TEST` | Canonical Schema v1 codec owners for vector resources/background/content elements, existing exact image documents, and independent unknown element/resource kinds. | Reader/writer have no vector branches, so a canonical vector document is rejected while existing compatibility fixtures alone already pass. | Descriptor-only vector JSON roundtrips exactly with all accepted fields and no payload bytes; old canonical bytes/maps remain exact and both unknown-kind branches still reject. | Public canonical maps, known-vector roundtrip, old canonical output, and independent unknown-kind rejection are admissible; field existence, old always-green fixtures alone, vector roundtrip alone, fixture vocabulary in production, or a copied allowed-kind inventory is rejected. | `EXTEND_COVERAGE` | Existing Schema v1 canonical roundtrip, resource, and unknown-kind artifact families | `vector-schema-admission` |
| `relationship-classification-evidence` | `resource-relationship-classification` | `TEST` | Codec-local public-DTO, exported encode, edit commit, runtime load, and public export parity owners. | Present wrong-kind descriptors are not representable/classified and only absence has a public code. | All sinks independently return exact absent/mismatch code and element path with no partial result/install; public export includes the new code and decode helpers remain private. | Code/path and old/new state are admissible; exception text, one sink, constructor validation, or per-family error inventories are rejected. | `EXTEND_COVERAGE` | Existing codec, edit, runtime load, and public export artifact families | `relationship-classification-admission` |
| `document-atomicity-evidence` | `document-admission-atomicity` | `TEST` | Edit/store/load owner snapshots around coherent two-sided changes and rejected candidates. | No vector relationship candidate exists and current coverage cannot witness callback-order independence. | Both callback orders succeed for coherent candidates; rejected candidates leave document/revisions/selection/output unchanged. | Final public/store snapshots are admissible; one callback order, exception-only checks, or partial helper state is rejected. | `EXTEND_COVERAGE` | Existing edit matrix, store finalization, and staged load artifact families | `vector-document-atomicity-admission` |
| `sync-vector-resolution-evidence` | `synchronous-vector-resolution` | `TEST` | Resource session and frame binding owners with resolver call/repaint observation. | There is no vector resolver branch. | One frame receives prepared-or-placeholder synchronously under the shared budget with no pending state/listener/completion repaint. | Resolver/frame observations are admissible; eventual paint, sleeps, or private helper-name inspection is rejected. | `EXTEND_COVERAGE` | Existing synchronous resolver, budget, placeholder, and binding artifact families | `sync-vector-resolution-admission` |
| `aggregate-cache-evidence` | `aggregate-resource-cache` | `TEST` | Resource cache/session owners with interleaved image/vector keys and controlled capacities/weights. | Cache stores only images and separate-family or aggregate behavior is absent. | Typed key hits/misses, 1024 aggregate capacity, image-only bytes, cross-family LRU, target/all invalidation, and no reverse alias are directly observed. | Interleaved behavior and accounting probes are admissible; separate lengths, descriptor byteLength, or source constants alone are rejected. | `EXTEND_COVERAGE` | Existing resource cache memory-accounting and session lifecycle artifacts | `aggregate-cache-admission` |
| `disposed-admission-evidence` | `disposed-prepared-admission` | `TEST` | Resource session/frame output with resolver-returned and cached disposed wrappers across two frames. | No prepared wrapper or private liveness admission exists. | Placeholder/no cache/no binding/no paint/same-frame suppression/later retry outcomes all hold. | Owner behavior is admissible; debug state, a public isDisposed field, or resolver-count-only proof is rejected. | `EXTEND_COVERAGE` | Existing missing-result, session lifecycle, binding, and painter artifact families | `disposed-prepared-lifecycle-admission` |
| `caller-freshness-evidence` | `caller-context-freshness` | `TEST` | Application-style cache/resolver harness with locale/direction identities, controlled out-of-order preparation completion, publication, attach, release, and Picture disposal observation. | No vector preparation/publication path can witness a stale completion or context-sensitive replacement order. | Delayed stale completion is disposed and never resolver-visible; cache identity changes with effective context; current replacement publishes before attach and every old alias/session/output releases before old disposal. | Application-observable cache/publication state and Picture identity are admissible; engine generation/revision keys, context-capture output alone, or alias-release alone are rejected. | `ADD` | Application-owned vector freshness and replacement lifecycle artifact family | `caller-context-freshness-admission` |
| `caller-alias-evidence` | `caller-publication-lifecycle` | `TEST` | Same-wrapper/two-resource-id session plus multiple attached runtime/surface retained-output observations. | Current image evidence has no wrapper alias disposal authorization outcome. | One target remains insufficient; every target or aggregate release closes all borrows before disposal and no later paint uses the wrapper. | Application publication identities and actual borrows are admissible; engine key exposure, one target, result enum, or reverse registry is rejected. | `EXTEND_COVERAGE` | Resource/surface lifecycle and retained-output owner artifact families | `caller-alias-release-admission` |
| `application-no-dispose-evidence` | `application-assets-not-disposed` | `TEST` | Existing app-owned image lifecycle coverage extended with prepared Picture identity observation. | Image non-disposal is covered, but vector wrapper/Picture engine non-disposal is absent. | Eviction/invalidation/replacement/reset/drop/dispose remove references without disposing either application asset family. | Native disposal observation is admissible; cache removal alone or wrapper boolean state is rejected. | `EXTEND_COVERAGE` | `test/resources/fixtures/app_owned_image_not_disposed_fixture.dart` and vector lifecycle owner family | `application-asset-ownership-admission` |
| `geometry-interaction-evidence` | `vector-geometry-and-interaction` | `TEST` | Existing geometry bounds, spatial candidates, box-hit, marquee, eraser, selection-move, and background/content interaction owners. | No vector bounds, hit, selection move, or interaction behavior exists. | Sized vector geometry and interaction outcomes pass while current families remain unchanged and background stays excluded. | Direct owner outputs are admissible; paint success, selection-decoration output, bounds equality alone, or a replacement family inventory is rejected. | `EXTEND_COVERAGE` | Existing geometry hit, spatial, marquee, eraser, selected-move, and interaction routing artifact families | `vector-geometry-interaction-admission` |
| `selection-placement-evidence` | `vector-selection-placement` | `TEST` | Existing selection-decoration owner fixture over vector/current single selection and mixed multi-selection before and after render-mirror retirement. | No vector placement exists and current placement reads the copied render family. | Vector/image/rect are `outsideBox`, path/text/stroke/line remain `boundsOutline`, multi-selection remains a union box, and Unit 7 preserves the exact outputs through sealed-row dispatch. | Direct selection-plan outputs are admissible; geometry/hit proxies, paint success, or a copied family inventory are rejected. | `EXTEND_COVERAGE` | Existing selection-decoration owner artifact family | `vector-selection-placement-admission` |
| `vector-context-evidence` | `vector-interaction-context` | `TEST` | Interaction read/context request/text stale-commit owners with content and background vectors. | Snapshot mapping has no vector branch and vector text-guard rejection is absent. | Immutable vector snapshot, background exclusion, exact public-kind guard, stale/no-op behavior, and text-only rejection are observed. | Public request/guard facts are admissible; codec placement, private field scans, or family inventories are rejected. | `EXTEND_COVERAGE` | Existing interaction read, context request, eraser routing, and stale text commit artifacts | `vector-interaction-admission` |
| `vector-binding-evidence` | `vector-frame-binding` | `TEST` | Paint asset binding, session lifecycle, retained-output, and painter boundary owners. | Bindings and placeholders are image-only. | Valid prepared assets bind immutably in both placements; missing/failing/wrong/disposed cases preserve sized placeholders and never paint. | Binding/output/painter behavior is admissible; resolver call alone or source token bans are rejected. | `EXTEND_COVERAGE` | Existing paint asset binding, painter boundary, session lifecycle, and surface output artifacts | `vector-binding-admission` |
| `vector-paint-evidence` | `vector-picture-paint` | `RUNTIME` | Recording canvas plus rendered pixels at multiple target sizes including anisotropic scaling. | Painter has no vector row and only image drawing exists. | Clip/translation/x-y scale/`drawPicture` are observed, pixels scale without fixed rasterization, and no image draw/conversion occurs. | Combined recording and multi-size pixels are admissible; one-size pixels, source scans, or private helper calls are rejected. | `ADD` | Frame vector recording/pixel artifact family | `vector-picture-paint-admission` |
| `vector-opacity-evidence` | `vector-group-opacity` | `RUNTIME` | Immutable record effect plus recording/pixel output for full, partial, overlapping, and multiple vector records. | Current vector group-opacity behavior and explicit effect record do not exist. | Zero/full and one-bounded-layer/partial behavior produces correct group pixels without degradation. | Record and painter count/bounds plus overlap pixels are admissible; saveLayer presence alone, restored benchmark ids, or per-command alpha is rejected. | `ADD` | Frame vector opacity record/painter artifact family | `vector-group-opacity-admission` |
| `vector-diagnostics-evidence` | `vector-diagnostics-routing` | `TEST` | Existing enabled/disabled codec and interaction diagnostics plus preparation/resource/frame non-hub observation. | Vector failures/events do not exist and could accidentally create a new route. | Existing codec/interaction routes record once where applicable; other owners record zero; disabled policy preserves no allocation. | Existing routing and allocation owners are admissible; public exception alone, no observed record alone, or a feature routing table is rejected. | `EXTEND_COVERAGE` | Existing diagnostics codec/interaction/disabled artifact families plus non-hub resource/frame owners | `vector-diagnostics-admission` |
| `vector-owner-doc-evidence` | `vector-owner-closure` | `MANUAL_INSPECTION` | Unit 5 affected public/schema/codec/operation/resource/cache/frame/geometry/interaction/architecture contracts, registries, diagrams, graph relationships, proof registrations, and projections. | Current owners contain no vector family or aggregate-resource route. | Every owner affected by admitted vector behavior is current before Unit 5 commits, with singular cache numbers and unchanged diagnostics routing. | Direct current-owner and structured relationship review is admissible; Unit 8 prose, generated output as authority, copied family inventories, or an unrelated green docs build is rejected. | `NONE` | None | None |
| `release-semantic-doc-evidence` | `release-semantic-owner-closure` | `MANUAL_INSPECTION` | Release-specific resource, operation, runtime-ownership, and hand-authored diagram content diff at Unit 1. | Current owners name image/session invalidation and omit retained-output removal from the no-borrow postcondition. | Each affected owner states generic target/all release of both retention owners before notification, contained post-acceptance failure, and application no-dispose while later vector/aggregate semantics remain absent. | Direct semantic content review is admissible; docs command success, wording-token search, or final Unit 8 prose is rejected as a proxy for Unit 1 closure. | `NONE` | None | None |
| `release-graph-evidence` | `release-semantic-owner-closure` | `STRUCTURED_DATA_CHECK` | Existing runtime-to-session graph edge, its source-document agreement, and generated-view closure at Unit 1. | The edge actual field names the retired invalidation seam, so architecture closure reports a missing required edge after the generic seam migrates. | The existing edge and its current source documents agree on the generic release seam and two-borrow lifecycle, generated views are current, and no vector node or route is introduced. | Graph/source agreement plus the established architecture checks is admissible; a green checker with contradictory source docs or generated output treated as authority is rejected. | `NONE` | None | None |
| `semantic-doc-evidence` | `semantic-owner-closure` | `MANUAL_INSPECTION` | Terminal ADR and cross-unit verification/proof inventory diff against the current owners already closed by Units 1-7. | Unit-local semantic owners are current, but the durable ADR and cross-unit proof inventory do not yet integrate the completed decision. | ADR and proof inventory link and reconcile every implemented concern without changing prior-unit semantics; cache numbers and diagnostics ownership remain singular. | Direct cross-unit integration review is admissible; a semantic correction deferred from Units 1-7, docs command success, or prose parsing alone is rejected. | `NONE` | None | None |
| `adr-closure-evidence` | `adr-0016-closure` | `STRUCTURED_DATA_CHECK` | ADR file/header/catalog/concern/next-id structured inspection and existing documentation checks. | Next id is stale and ADR-0016 does not exist. | File, catalog row, concern row, and next-id transition are mutually consistent and atomic. | Structured ADR ownership is admissible; catalog row alone, duplicated numbering file, or mutable-detail prose is rejected. | `NONE` | None | None |
| `structured-owner-evidence` | `structured-projection-closure` | `STRUCTURED_DATA_CHECK` | Existing public, section, diagram, and architecture-graph parity checks plus terminal generated-view and docs generation checks. | Units 1-7 have updated unit-local structured owners; terminal cross-unit parity and disposable views remain to be reconciled. | Existing checks accept all already-current owners and refreshed cross-unit projections with no new graph owner or diagnostics edge. | Owner checks are admissible; a unit-local route deferred to Unit 8, generated output as source truth, or an unrelated green docs build is rejected. | `NONE` | None | None |
| `mirror-retirement-evidence` | `manual-mirror-retirement` | `SOURCE_QUERY` | Terminal cross-unit proof-registration and verification-inventory diff plus direct unit-local owner evidence. | Units 1-7 have retired or updated each mirror at its stable owner; cross-unit proof credit can still be stale or duplicated. | Terminal inventory assigns singular credit to every already-current owner and preserves the authoritative external app-key proof without a replacement inventory. | Exact final integration diff with owner evidence is admissible; a mirror first repaired in Unit 8, general scanner, prose inventory, or another test as authority is rejected. | `UPDATE_EXISTING` | Existing guardrail registration and verification inventory paths | None |

## Permanent Artifact Admissions

### `prepared-public-api-admission`: Prepared vector public boundary

Covers: `prepared-public-api-shape`
Impact: `EXTEND_COVERAGE`
Failure family: public preparation can omit required use or expose construction, liveness, Picture, diagnostics, or upstream types
Failure mode or stable invariant: external consumers can use only helper-created intrinsic-size/disposal behavior and cannot access forbidden lifecycle internals
Verification owner: external public API contract and export parity suites
Current verification gap: no prepared-vector public surface exists
Failing witness: an external consumer cannot reference `prepareVector` or `CanvasPreparedVector`
Durable and refactor-stable value: effective exported signature constraints survive private adapter and storage refactors
Artifact target: Existing external API contract and public export artifact families

### `exact-view-preparation-admission`: Exact pre-await input ownership

Covers: `preparation-view-ownership`
Impact: `ADD`
Failure family: preparation can borrow mutable input, copy the wrong backing range, or retain completed snapshots
Failure mode or stable invariant: only the supplied view is copied before await and no completed owner retains it
Verification owner: public vector preparation owning suite
Current verification gap: no preparation adapter or byte-lifetime proof exists
Failing witness: the current public surface cannot decode a mutable nonzero-offset raster-free view
Durable and refactor-stable value: byte ownership and settlement lifetime survive loader and helper decomposition changes
Artifact target: Preparation-owner raster-free fixture and VM retention artifact family

### `context-sensitive-preparation-admission`: Invocation context and settlement release

Covers: `preparation-context-closure`
Impact: `ADD`
Failure family: preparation can use post-call/default locale-direction or retain the supplied BuildContext after settlement
Failure mode or stable invariant: output reflects invocation-time effective values and completed owners retain no supplied context
Verification owner: public vector preparation context suite
Current verification gap: no context-sensitive vector output or retaining-path proof exists
Failing witness: the current public surface cannot prepare or render context-sensitive vector text
Durable and refactor-stable value: observable output and ownership survive cache-key and adapter refactors
Artifact target: Preparation-owner context-sensitive raster fixture and VM retention artifact family

### `preparation-input-failure-admission`: Bounded preparation input and error classification

Covers: `preparation-input-failure-bounds`
Impact: `ADD`
Failure family: oversize or selected upstream failures can allocate/publish, leak erased upstream identity, or encourage an exhaustive-validity claim
Failure mode or stable invariant: oversize is `fieldMaxLength` at `vector.bytes` before snapshot/upstream, selected-Future failure is `invalidVectorData` at `vector.bytes` with no publication, and an upstream-accepted malformed witness bounds the claim
Verification owner: public vector preparation input/error suite
Current verification gap: no vector byte-limit, selected-Future classification, or bounded-validity proof exists
Failing witness: the current public surface cannot exercise a limit or named selected-upstream failure and cannot show an accepted malformed stream
Durable and refactor-stable value: public boundary classification and non-exhaustive claims survive upstream adapter refactors
Artifact target: Preparation-owner bounded input/error classification artifact family

### `unpublished-picture-cleanup-admission`: Exact invalid-intrinsic Picture cleanup

Covers: `unpublished-picture-cleanup`
Impact: `ADD`
Failure family: intrinsic admission can reject after native Picture creation without disposing the unpublished asset exactly once
Failure mode or stable invariant: existing intrinsic admission rejects at `vector.intrinsicSize`, disposes the exact unpublished Picture once before propagation, and publishes no wrapper
Verification owner: public vector preparation invalid-intrinsic cleanup suite
Current verification gap: no vector route can create then reject an intrinsic-invalid Picture
Failing witness: the current public surface has no intrinsic-invalid stream or unpublished Picture lifecycle
Durable and refactor-stable value: native cleanup survives byte/error classification and private adapter decomposition
Artifact target: Preparation-owner invalid-intrinsic Picture cleanup artifact family

### `prepared-lifecycle-admission`: Idempotent wrapper Picture ownership

Covers: `prepared-wrapper-lifecycle`
Impact: `ADD`
Failure family: wrapper disposal can double-dispose, leave a half-live reference, or permit post-disposal engine access
Failure mode or stable invariant: the wrapper retires its private reference and disposes the exact Picture at most once
Verification owner: prepared-result lifecycle suite
Current verification gap: no engine wrapper owns a Picture lifecycle
Failing witness: the current API has no prepared value to dispose or admit internally
Durable and refactor-stable value: ownership remains observable across private storage/accessor changes
Artifact target: Prepared-result lifecycle owning artifact family

### `private-vector-adapter-admission`: Caller-bytes-only private upstream route

Covers: `raster-free-private-adapter`
Impact: `EXTEND_COVERAGE`
Failure family: vector preparation can leak upstream types or gain engine IO, a fork, global interception, or duplicate parsing
Failure mode or stable invariant: supported preparation consumes caller bytes behind existing dependency boundaries only
Verification owner: public/import/resource boundary suites plus preparation denied-IO behavior
Current verification gap: current resource docs say no IO but no vector adapter exists to enforce that boundary
Failing witness: adding a vector dependency can bypass public/resource boundary checks without vector-focused coverage
Durable and refactor-stable value: dependency and IO constraints survive adapter relocation within the approved API owner
Artifact target: Existing public/import/resource boundary artifacts plus preparation denied-IO owner family

### `vector-model-admission`: Vector DTO and sparse update preservation

Covers: `vector-model-and-update`
Impact: `EXTEND_COVERAGE`
Failure family: vector construction/projection/update can lose common fields or reset absent fields
Failure mode or stable invariant: every accepted field projects and sparse updates change only supplied values
Verification owner: public API, edit field-update, and store projection suites
Current verification gap: no vector DTO, row, or update exists
Failing witness: external construction and vector update code do not compile
Durable and refactor-stable value: public/store behavior survives private row and update-helper refactors
Artifact target: Existing public API, edit field-update, and store projection artifact families

### `vector-schema-admission`: Vector Schema v1 projection and compatibility

Covers: `vector-schema-roundtrip`, `schema-v1-compatibility`
Impact: `EXTEND_COVERAGE`
Failure family: vector wire projection can omit fields or serialize source bytes, alter old canonical output, or weaken either unknown-kind rejection
Failure mode or stable invariant: canonical vector JSON contains only accepted descriptor/element/common fields and roundtrips them, old canonical output stays exact, and unknown element/resource branches reject independently
Verification owner: Schema v1 codec owning suite
Current verification gap: reader and writer reject/omit vector kinds, so existing always-green compatibility fixtures cannot exercise compatibility after known vector admission
Failing witness: a canonical vector document is currently rejected as an unknown kind
Durable and refactor-stable value: vector wire semantics, old canonical output, and independent unknown-kind rejection survive reader/writer helper refactors and future known-kind additions
Artifact target: Existing Schema v1 canonical roundtrip, resource, and unknown-kind artifact families

### `relationship-classification-admission`: Exact absent versus wrong-kind relationship failures

Covers: `resource-relationship-classification`
Impact: `EXTEND_COVERAGE`
Failure family: materialization/publication sinks can disagree or collapse absent and present-wrong-kind resources
Failure mode or stable invariant: every sink independently emits the exact family-neutral code and referencing element path before return/install
Verification owner: codec-local DTO, exported encode, edit/store, runtime load, and public export suites
Current verification gap: wrong-kind descriptors are not representable and no mismatch code exists
Failing witness: current code can report only `missingResourceReference`
Durable and refactor-stable value: code/path/no-partial behavior survives validation helper and store layout changes
Artifact target: Existing codec, edit, runtime load, and public export artifact families

### `vector-document-atomicity-admission`: Final-candidate relationship atomicity

Covers: `document-admission-atomicity`
Impact: `EXTEND_COVERAGE`
Failure family: two-sided resource/element changes can depend on callback order or partially mutate on rejection
Failure mode or stable invariant: coherent final candidates succeed in either order and invalid candidates preserve every public/runtime owner
Verification owner: edit matrix, store finalization, and staged load suites
Current verification gap: no typed two-family resource relationship can exercise the final-candidate rule
Failing witness: current public model cannot construct the vector/image mismatch pair
Durable and refactor-stable value: final-state atomicity survives edit compilation and store validation refactors
Artifact target: Existing edit matrix, store finalization, and staged load artifact families

### `sync-vector-resolution-admission`: Synchronous prepared-only frame resolution

Covers: `synchronous-vector-resolution`
Impact: `EXTEND_COVERAGE`
Failure family: vector resolution can introduce pending work, async repaint, or attach-time preparation
Failure mode or stable invariant: one guarded frame pass returns prepared-or-placeholder synchronously under the shared budget
Verification owner: resource session and frame binding suites
Current verification gap: no vector resolver method or result exists
Failing witness: frame binding can resolve only image descriptors
Durable and refactor-stable value: synchronous temporal behavior survives resolver adapter changes
Artifact target: Existing synchronous resolver, budget, placeholder, and binding artifact families

### `aggregate-cache-admission`: Cross-family borrowed-reference cache

Covers: `aggregate-resource-cache`
Impact: `EXTEND_COVERAGE`
Failure family: separate family caches or vector byte weights can violate aggregate capacity and image accounting
Failure mode or stable invariant: one internal-key LRU enforces aggregate entries, image-only bytes, and cross-family eviction
Verification owner: resource cache and session lifecycle suites
Current verification gap: cache values and evidence are image-only
Failing witness: vector entries cannot currently be inserted or evict images
Durable and refactor-stable value: capacity/accounting behavior survives cache representation changes
Artifact target: Existing resource cache memory-accounting and session lifecycle artifacts

### `disposed-prepared-lifecycle-admission`: Invalid wrapper suppression and retry

Covers: `disposed-prepared-admission`
Impact: `EXTEND_COVERAGE`
Failure family: disposed prepared values can enter cache/binding/paint or create same-frame retry loops
Failure mode or stable invariant: invalid wrappers produce placeholder/no-cache/no-paint, suppress within frame, and retry later
Verification owner: resource session, binding, and painter suites
Current verification gap: no wrapper liveness admission exists
Failing witness: current resolver returns only `ui.Image` and cannot return a disposed wrapper
Durable and refactor-stable value: admission/retry semantics survive cache and binding decomposition
Artifact target: Existing missing-result, session lifecycle, binding, and painter artifact families

### `caller-context-freshness-admission`: Application freshness and stale-completion disposal

Covers: `caller-context-freshness`
Impact: `ADD`
Failure family: an out-of-order preparation can publish stale context output or a replacement can attach/dispose in the wrong order
Failure mode or stable invariant: stale completions are disposed without publication and current locale/direction replacements publish before attach and old aggregate release-before-dispose
Verification owner: application-owned vector preparation cache and resolver publication lifecycle suite
Current verification gap: engine preparation context evidence cannot prove caller cache identity, stale completion, or publication order
Failing witness: no current application-style harness can complete two vector preparations out of order
Durable and refactor-stable value: freshness and replacement safety survive engine cache-key, session, and preparation-adapter changes
Artifact target: Application-owned vector freshness and replacement lifecycle artifact family

### `caller-alias-release-admission`: Aggregate application publication release

Covers: `caller-publication-lifecycle`
Impact: `EXTEND_COVERAGE`
Failure family: owner disposal can occur after one target release while another same-wrapper borrow survives
Failure mode or stable invariant: disposal is authorized only after every application publication across resource ids and surfaces is absent
Verification owner: resource session, retained-output, and surface lifecycle suites
Current verification gap: current image ownership evidence has no same-wrapper alias disposal contract
Failing witness: one cached value can be keyed by resource identity but no prepared wrapper lifecycle exists
Durable and refactor-stable value: alias safety survives engine key/cache/output refactors without exposing internal keys
Artifact target: Resource/surface lifecycle and retained-output owner artifact families

### `application-asset-ownership-admission`: Engine non-disposal across asset families

Covers: `application-assets-not-disposed`
Impact: `EXTEND_COVERAGE`
Failure family: vector eviction or lifecycle cleanup can dispose an application-owned Picture
Failure mode or stable invariant: engine retirement drops references only for both images and prepared vectors
Verification owner: application-owned asset lifecycle suite
Current verification gap: only `ui.Image` non-disposal is covered
Failing witness: no prepared Picture can currently enter cache/output lifecycle
Durable and refactor-stable value: ownership survives cache/session/surface implementation changes
Artifact target: `test/resources/fixtures/app_owned_image_not_disposed_fixture.dart` and vector lifecycle owner family

### `vector-geometry-interaction-admission`: Sized vector geometry and interaction

Covers: `vector-geometry-and-interaction`
Impact: `EXTEND_COVERAGE`
Failure family: vector can be omitted from bounds, spatial, hit, marquee, eraser, move, or content/background interaction flows
Failure mode or stable invariant: element size owns every vector geometry/interaction outcome while background remains excluded
Verification owner: geometry, spatial, hit, marquee, eraser, selected-move, and interaction routing suites
Current verification gap: no vector family enters any of these owners
Failing witness: current exhaustive switches have no vector branch
Durable and refactor-stable value: user-visible geometry and interaction survive painter/cache/private-row refactors
Artifact target: Existing geometry hit, spatial, marquee, eraser, selected-move, and interaction routing artifact families

### `vector-selection-placement-admission`: Vector and existing selection placement

Covers: `vector-selection-placement`
Impact: `EXTEND_COVERAGE`
Failure family: vector can receive the wrong single-selection chrome or mirror retirement can regress an existing placement or union-box behavior
Failure mode or stable invariant: vector/image/rect use `outsideBox`, path/text/stroke/line use `boundsOutline`, and multi-selection uses union-box chrome before and after sealed-row migration
Verification owner: frame selection-decoration owner fixture
Current verification gap: no vector selection row exists and current placement depends on the duplicate render family
Failing witness: the current fixture cannot construct or assert a selected vector
Durable and refactor-stable value: placement semantics survive render-record and discriminator retirement refactors
Artifact target: Existing selection-decoration owner artifact family

### `vector-interaction-admission`: Vector context snapshot and text guard

Covers: `vector-interaction-context`
Impact: `EXTEND_COVERAGE`
Failure family: content vectors can lack immutable snapshots, become background targets, or bypass text-only commit admission
Failure mode or stable invariant: public-kind guarded content snapshots work and background/text exclusions remain exact
Verification owner: interaction read, context request, eraser routing, and text stale-commit suites
Current verification gap: public snapshot mapping has no vector branch
Failing witness: a vector context target cannot currently be constructed
Durable and refactor-stable value: request and guard semantics survive adapter/registry refactors
Artifact target: Existing interaction read, context request, eraser routing, and stale text commit artifacts

### `vector-binding-admission`: Immutable prepared binding and placeholders

Covers: `vector-frame-binding`
Impact: `EXTEND_COVERAGE`
Failure family: valid prepared values can bypass immutable binding or invalid values can paint/lose bounded placeholders
Failure mode or stable invariant: only admitted live Pictures enter output and every failure keeps element-sized placeholder/no-paint behavior
Verification owner: frame binding, painter boundary, resource session, and surface output suites
Current verification gap: asset binding is image-only
Failing witness: no vector descriptor/result can enter immutable output
Durable and refactor-stable value: binding/placeholder behavior survives record and session decomposition
Artifact target: Existing paint asset binding, painter boundary, session lifecycle, and surface output artifacts

### `vector-picture-paint-admission`: Direct resolution-independent Picture paint

Covers: `vector-picture-paint`
Impact: `ADD`
Failure family: vector rendering can rasterize, scale incorrectly, use natural size, or escape bounds
Failure mode or stable invariant: clipped anisotropic intrinsic-to-target `drawPicture` output remains resolution-independent
Verification owner: frame vector painter suite
Current verification gap: no vector row or Picture paint exists
Failing witness: recording canvas cannot observe any vector draw
Durable and refactor-stable value: visible output survives private transform/helper changes
Artifact target: Frame vector recording/pixel artifact family

### `vector-group-opacity-admission`: Explicit zero-or-one vector group layer

Covers: `vector-group-opacity`
Impact: `ADD`
Failure family: vector opacity can apply per command, create unbounded layers, or silently degrade
Failure mode or stable invariant: record-explicit full opacity creates zero layers and partial opacity creates exactly one target-bounded group layer
Verification owner: frame vector record and painter suite
Current verification gap: no vector group-opacity effect exists
Failing witness: current records report no vector effect and painter has no vector branch
Durable and refactor-stable value: compositing correctness and layer budget survive painter helper refactors
Artifact target: Frame vector opacity record/painter artifact family

### `vector-diagnostics-admission`: Existing-route and non-hub diagnostics ownership

Covers: `vector-diagnostics-routing`
Impact: `EXTEND_COVERAGE`
Failure family: vector failures can miss/duplicate existing records or create a new node/resource/frame diagnostic route
Failure mode or stable invariant: codec/interaction reuse existing routes once and preparation/resource/frame allocate none, including disabled policy
Verification owner: codec, interaction, disabled diagnostics, and non-hub owner suites
Current verification gap: no vector failure or event exercises routing
Failing witness: current tests cannot produce a vector codec, interaction, preparation, resource, or paint outcome
Durable and refactor-stable value: routing ownership survives vector implementation refactors without node-attached state
Artifact target: Existing diagnostics codec/interaction/disabled artifact families plus non-hub resource/frame owners

## Verification Gate

| Check | Scope | Future command or evidence | Pass signal |
| --- | --- | --- | --- |
| Finding disposition | Whole implementation and all eight units | Layered code review findings mapped to owner, unit, and verification evidence | No unresolved actionable finding; every finding is fixed or explicitly shown non-applicable with owner evidence. |
| Changed-owner static analysis | All changed Dart production, test, and tool code | From repository root: `dart analyze` and `dcm analyze .` | Both commands exit 0. |
| Changed-owner metrics | Each changed production, test, and tool owner separately | From repository root: `dcm calculate-metrics <changed-owner-scope>` for every changed `lib/src/<owner>`, `test/<area>`, and `tool/<area>` scope | Every scoped command exits 0; any localized exception follows repository policy and is not a metric-only refactor. |
| Architecture closure | Existing graph nodes/edges, source coverage, and generated graph views affected by Units 1-7 plus terminal cross-unit parity in Unit 8 | From repository root after every architecture-changing unit: `dart run tool/architecture_graph/check.dart` and `dart run tool/architecture_graph/generate_views.dart --check` | Both commands exit 0 before each such unit commits and at terminal closure, with source documents consistent and no unit-local route deferred, unapproved owner node, or diagnostics edge. |
| Documentation closure | Every documentation, registry, diagram, ADR, or generated-projection owner affected by its Unit 1-8 change | From repository root after every documentation-changing unit: `dart run docs/tool/sync_generated_docs.dart --check` and `dart run docs/tool/check_docs.dart` | Both commands exit 0 before each such unit commits and after terminal lifecycle changes; the unit-scoped manual evidence rows separately prove semantic content rather than command success. |
| Guardrail closure | Public, resource, frame, interaction, codec, unit-local proof-registration routes, and terminal cross-unit proof inventory | From repository root after every guardrail/proof-registration-changing unit and at terminal closure: `dart run tool/guardrails/run.dart` | Exit 0 before each such unit commits and at terminal closure, with stable boundary ids registered, unit-local credit current, and stale app-key/private-shape credit absent. |
| Dependency compatibility | Direct `vector_graphics` dependency and supported Flutter/Dart constraints | Lockfile diff plus package resolution/build evidence from the established package verification route | Selected versions resolve under repository constraints and no upstream type enters the public surface. |
| Canonical-route integrity | Public barrel, one Schema v1 reader, generic resource release, existing diagnostics routes, and existing graph owners | Final implementation/source-owner diff against Design D1-D16 and the Repository Evidence mirror set | No second reader, cache owner, parser, diagnostic route, family enum, release alias, public raw Picture route, or second prepared-wrapper equality policy exists. |
| Diff hygiene | Whole change | `git diff --check` | Exit 0 |
| Lifecycle closure | Active contract and source design | After all units, Matrix evidence, Gate checks, and findings close, move this contract under `docs/history/plans/` with its filename unchanged; move the linked design under `docs/history/designs/` with its filename unchanged only when no active plan still references it; run documentation checks after the moves | No completed plan remains active, no completed design is moved while still referenced, and planning registrations contain no stale direct child. |
