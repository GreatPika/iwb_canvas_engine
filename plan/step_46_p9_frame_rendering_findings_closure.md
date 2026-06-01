# Change Contract

## Goal

Close the P9 frame-rendering findings as owner-level fixes: frame rendering must fail visibly and predictably at frame, geometry, guardrail, and source-of-truth boundaries instead of silently dropping selected preview records, relying on ambiguous degenerate drawing, or letting executable guardrails and durable documentation drift behind the implementation.

## Source Inputs

- Design: `.design/2026-06-01-p9-frame-rendering-findings-closure.md`
- Research: `.research/2026-06-01-p9-frame-rendering-findings.md`
- Phase: none
- PLAN: `PLAN.md`
- Other: `docs/contracts/frame_rendering.md`, `docs/contracts/spatial_kernel.md`, `docs/contracts/cache_policy.md`, `docs/contracts/resources.md`, `docs/architecture/01_runtime_ownership.md`, `docs/architecture/02_package_boundaries.md`, `docs/implementation/p9_frame_rendering_and_caches.md`, `docs/verification/guardrails.md`, `docs/verification/tests.md`, `docs/_registry/sections.yaml`

## Classification

Profile: ANALYZER_RULE

Obligations:

- BUG_FIX: selected-move shifted spatial failures must not silently produce an empty supplement after selected ordinary records are removed; accepted degenerate draw inputs must render through explicit frame-owned commands; source-of-truth drift must be repaired.
- SEAM_MIGRATION: `SpatialQueryResult` candidate access must migrate from permissive base getters to explicit candidate-result admission, with frame consumers adopting a frame-owned admission boundary.

## Decision Trace

| Source decision | Contract location | Execution unit / proof surface |
|---|---|---|
| `D1` Retire permissive base candidate access on `SpatialQueryResult`; candidate lists must be read from `SpatialCandidatesResult` or an explicit admission result. | `Boundaries.Source of Truth`, `Boundaries.Order Constraints`, Unit 1 | Unit 1 compile/semantic proof that base `SpatialQueryResult.candidates` and `hasCandidates` are removed or inaccessible at the spatial result owner, and all production plus spatial/frame test-support consumers use `SpatialCandidatesResult` or explicit admission. |
| `D2` Selected supplement shifted spatial admission must happen before selected ordinary records are removed; rejected shifted admission returns ordinary records unchanged for that frame. | `Boundaries.Order Constraints`, `Temporal and all-or-nothing constraints`, Unit 2 | Unit 2 selected supplement negative tests for budget, invalid-index, and stale-result shifted queries. |
| `D3` Ordinary cache all-or-nothing behavior remains owned by `OrdinaryPaintPlanner`; supplement rejection must not write ordinary cache entries. | `Boundaries.Owner`, `Temporal and all-or-nothing constraints`, Unit 2 | Unit 2 ordinary/supplement cache probe tests showing no ordinary cache write during rejected supplement admission. |
| `D4` One frame-owned drawable policy must handle one-point overlay eraser, one-point pencil/marker previews, committed one-point strokes, and same-point committed lines. | `Boundaries.Owner`, Unit 3 | Unit 3 pixel or recorded-canvas proof for overlay and main painter degenerate output. |
| `D5` Marquee overlay primitives must carry captured selection style and draw fill/stroke from that immutable style. | `Boundaries.Source of Truth`, Unit 4 | Unit 4 primitive field and pixel/style tests using non-default `CanvasSelectionStyle`. |
| `D6` Frame/cache guardrails must use analyzer-backed recognition and a single ordinary-cache surface registry that includes `OrdinaryPaintRecordCacheEntry`. | `Classification`, Unit 5 | Unit 5 runner-backed guardrail tests for forbidden preview/selection facts across every ordinary cache surface. |
| `D7` No-global-scene-sort recognition must catch structural bypasses while preserving local scalar sort allowance. | `Classification`, Unit 6 | Unit 6 analyzer AST guardrail fixtures for multi-line, cascade, named comparator/helper, and allowed local scalar sort. |
| `D8` Source-of-truth repair must update docs/diagrams/registry to actual cohesive file names and resource-session ownership/order. | `Boundaries.Source of Truth`, Unit 7 | Unit 7 docs sync/checks and architecture graph checks when triggered by changed architecture-owned files. |
| `D9` Public API compatibility is preserved; degenerate accepted inputs are rendered at frame boundary rather than rejected at public constructors. | `Boundaries.Compatibility`, Units 3 and 7 | Unit 3 rendering and constructor proof plus Unit 7 public API/barrel compatibility checks proving no DTO shape drift and no frame collaborator exports; no `PUBLIC_API_CHANGE` obligation. |

## Evidence

- `.design/2026-06-01-p9-frame-rendering-findings-closure.md:13` / design readiness: design disposition is `READY_FOR_CONTRACT` -> proceed with a full contract rather than returning a blocker.
- `.design/2026-06-01-p9-frame-rendering-findings-closure.md:23` / classification: design selects `ANALYZER_RULE` -> contract must include executable guardrail/analyzer proof, not only code and docs tests.
- `.design/2026-06-01-p9-frame-rendering-findings-closure.md:25` / bug-fix obligation: selected supplement failure, degenerate accepted drawing, and source-of-truth drift are locked bug-fix classes -> execution units must close each class directly.
- `.design/2026-06-01-p9-frame-rendering-findings-closure.md:26` / seam-migration obligation: `SpatialQueryResult` candidate access must move from permissive base getters to explicit admission -> Unit 1 must establish the replacement seam before consumers migrate.
- `.design/2026-06-01-p9-frame-rendering-findings-closure.md:169` / selected form: Candidate B is selected -> implement owner-level frame hardening with explicit seams instead of symptom patches, public input rejection, or rename-only docs churn.
- `.design/2026-06-01-p9-frame-rendering-findings-closure.md:173` / spatial decision: candidate access becomes explicit through `SpatialCandidatesResult` or an admission helper -> Unit 1 owns the replacement path and migration proof.
- `.design/2026-06-01-p9-frame-rendering-findings-closure.md:175` / selected supplement decision: shifted admission must happen before selected ordinary records are filtered out, and rejected admission returns ordinary records unchanged -> Unit 2 owns all-or-nothing ordering proof.
- `.design/2026-06-01-p9-frame-rendering-findings-closure.md:177` / drawable decision: one frame-owned drawable policy covers empty, one-point, same-point, and multi-point draw inputs, and marquee uses captured selection style -> Units 3 and 4 own direct painter output proof.
- `.design/2026-06-01-p9-frame-rendering-findings-closure.md:179` / enforcement decision: analyzer-backed guardrails and source-of-truth repair are mandatory -> Units 5, 6, and 7 are in scope.
- `.design/2026-06-01-p9-frame-rendering-findings-closure.md:181` / compatibility decision: public preview and element constructors remain source-compatible -> contract must not reject existing public degenerate inputs or export frame collaborators.
- `.design/2026-06-01-p9-frame-rendering-findings-closure.md:337` / verification strategy: API compatibility tests are required -> Unit 7 must name public API/barrel proof, not only docs checks.
- `.design/2026-06-01-p9-frame-rendering-findings-closure.md:338` / verification strategy: `dart analyze`, `dcm analyze .`, and targeted `dcm calculate-metrics` are required for changed production/test/tool owners -> Units 1-6 must carry static-analysis completion checks.
- `lib/src/geometry/spatial_query_result.dart:6` / spatial root: base `SpatialQueryResult` exposes `hasCandidates => false` -> retiring candidate-like base state is a geometry seam migration, not a frame-only patch.
- `lib/src/geometry/spatial_query_result.dart:7` / spatial root: base `SpatialQueryResult` exposes `candidates => const []` -> non-candidate typed failures can currently look like successful empty candidates.
- `lib/src/geometry/spatial_query_result.dart:19` / candidate subtype: only `SpatialCandidatesResult` returns ordered candidates -> candidate admission can use subtype-specific access as the success boundary.
- `docs/contracts/spatial_kernel.md:102` / spatial contract: the paint query hot path ends in typed results -> frame consumers must preserve typed failure semantics.
- `docs/contracts/spatial_kernel.md:105` / spatial contract: budget-exceeded results contain no partial candidates and do not mutate indexes -> selected supplement must reject typed non-candidate results rather than build partial records.
- `lib/src/frame/frame_capture_service.dart:59` / raw candidate use: frame capture reads `spatialResult.candidates` from a base result -> Unit 1 must migrate production frame capture to explicit candidate admission.
- `lib/src/frame/selected_move_supplement_planner.dart:65` / selected supplement ordering: selected ordinary records are filtered before supplement records are built -> current order places selected-record removal before shifted spatial admission.
- `lib/src/frame/selected_move_supplement_planner.dart:138` / shifted query: selected supplement performs the shifted spatial query inside supplement record construction -> admission must move before irreversible filtering.
- `lib/src/frame/selected_move_supplement_planner.dart:139` / raw candidate use: supplement iterates `spatial.candidates` directly -> Unit 1 and Unit 2 must remove base getter consumption and prove typed rejection.
- `docs/contracts/cache_policy.md:65` / ordinary cache source of truth: `OrdinaryPaintRecordCache` stores ordinary committed records only -> selected supplement fallback must not write ordinary cache entries.
- `docs/contracts/cache_policy.md:72` / ordinary cache exclusion: ordinary cache must not store selected-move supplement records, `selectedMoveDelta`, or `previewDelta` -> guardrails must scan all ordinary cache surfaces for preview facts.
- `docs/contracts/cache_policy.md:74` / ordinary cache exclusion: ordinary cache must not store selected ids, selection flags, or `selectionRevision` -> guardrails must scan all ordinary cache surfaces for selection facts.
- `lib/src/frame/overlay_frame_painter.dart:47` / overlay painter: stroke previews use `PointMode.polygon` -> one-point pencil/marker previews need explicit drawable handling.
- `lib/src/frame/overlay_frame_painter.dart:77` / overlay painter: eraser previews use `PointMode.polygon` -> one-point eraser corridors need explicit drawable handling.
- `lib/src/frame/render_family_caches.dart:130` / committed stroke cache: stroke paths start with `moveTo` -> one-point committed strokes risk move-only path output.
- `lib/src/frame/main_frame_record_painter.dart:189` / committed line painter: committed lines draw through `drawLine` -> same-point lines need explicit point/circle output.
- `lib/src/frame/captured_frame.dart:24` / capture input: captured frame inputs include `selectionStyle` -> marquee style can be immutable frame output rather than live painter state.
- `lib/src/frame/captured_frame.dart:58` / capture snapshot: captured frame stores the raw spatial paint result -> frame can preserve rejected typed reasons for admission proof.
- `lib/src/frame/paint_plan.dart:102` / cache entry surface: `OrdinaryPaintRecordCacheEntry` stores cached records -> guardrail recognition must include cache entries, not only keys and plans.
- `tool/guardrails/src/frame_cache_guardrail_checks.dart:214` / cache scanner: cache exclusion checks are centralized in `_checkCachedPaintSurfacesExclude` -> repair the existing scanner path instead of adding prose-only enforcement.
- `tool/guardrails/src/frame_cache_guardrail_checks.dart:232` / cache surface registry: `_cachedPaintSurfaces` omits `OrdinaryPaintRecordCacheEntry` -> Unit 5 must add a single ordinary-cache surface registry that includes entry/value surfaces.
- `tool/guardrails/src/frame_cache_guardrail_checks.dart:305` / sort scanner: no-global-sort currently starts from textual `.sort(` search -> Unit 6 must migrate structural recognition to analyzer AST.
- `tool/guardrails/src/frame_cache_guardrail_checks.dart:321` / sort scanner: comparator recognition reads only a local statement/fallback substring -> Unit 6 must add bypass fixtures for realistic structural forms.
- `docs/architecture/02_package_boundaries.md:115` / package docs: package layout lists `captured_main_frame.dart` -> docs drift from cohesive implemented `captured_frame.dart`.
- `docs/architecture/02_package_boundaries.md:116` / package docs: package layout lists `captured_overlay_frame.dart` -> docs drift from cohesive implemented `captured_frame.dart`.
- `docs/architecture/02_package_boundaries.md:125` / package docs: package layout lists `repaint_bus.dart` -> docs drift from implemented `frame_repaint_signal.dart`.
- `docs/architecture/02_package_boundaries.md:188` / package docs: listed frame collaborator names are documentation layout names, not required public exports -> Unit 7 should repair docs to actual cohesive owners without public barrel churn.
- `lib/src/frame/captured_frame.dart:77` / implementation layout: `CapturedMainFrame` lives in `captured_frame.dart` -> source-of-truth repair should preserve cohesive implemented file ownership.
- `lib/src/frame/captured_frame.dart:87` / implementation layout: `CapturedOverlayFrame` also lives in `captured_frame.dart` -> source-of-truth repair should not split files only to match stale docs.
- `docs/architecture/01_runtime_ownership.md:200` / runtime docs: ownership tree says `SurfaceResourceSession` is owned by active `CanvasSurface` while listed under `RuntimeRoot` -> Unit 7 must align ownership wording without pulling P13 lifecycle into P9.
- `lib/src/frame/paint_asset_binding_service.dart:28` / resource ordering: frame asset binding calls `beginFrameResourcePass()` before image resolution -> Unit 7 should update sequence docs to actual frame-pass reset ordering.
- `docs/implementation/p9_frame_rendering_and_caches.md:162` / implementation note: P9 note lists frame test inventory -> Unit 7 must keep implementation notes aligned with the new focused P9 proof surfaces.
- `docs/_registry/sections.yaml:619` / registry: P9 test inventory starts with a subset of frame tests -> docs/registry proof inventory must be updated with the new focused proof surfaces and regenerated indexes.
- `tool/guardrails/src/guardrail_executor.dart:159` / public API proof path: `api.public_api_compiles_as_written` maps to `test/api_contract/public_api_v1_compiles_as_written_test.dart` -> public compatibility proof can use existing runner-backed API tests.
- `tool/guardrails/src/guardrail_executor.dart:162` / public API proof path: `api.facades_do_not_export_internal` maps to `test/api_contract/api_facades_do_not_export_internal_test.dart` -> frame collaborator export leakage has an existing proof surface.
- `tool/guardrails/src/guardrail_executor.dart:306` / public API guardrail route: `api.public_exports_complete` is a registered violation check -> public barrel/registry parity is executable.
- `tool/guardrails/src/public_api_checks.dart:13` / public API guardrail: `checkPublicExportsComplete` compares public barrel exports to the registry -> Unit 7 can prove no unregistered frame collaborator export appears.
- `tool/guardrails/src/public_api_checks.dart:35` / public API guardrail: `checkApiFacadesDoNotExportInternal` resolves facade exports and detects internal leaks -> Unit 7 can prove frame-private symbols remain internal.
- `PLAN.md:8` / roadmap format: each step has a linked document -> this step must add a dedicated `plan/step_46_p9_frame_rendering_findings_closure.md` entry.
- `PLAN.md:12` / roadmap order: step order defines intended implementation order -> append Step 46 after completed Step 45.

## Boundaries

Owner:

Primary behavior owner is `frame.renderer` / `FrameEngine` under `lib/src/frame/**`. Delegated seam owners are `lib/src/geometry/**` for typed spatial result shape and explicit candidate access, `tool/guardrails/**` plus `test/guardrails/**` for executable analyzer-backed recognition, and `docs/**` plus generated docs/indexes for durable source-of-truth repair. `FrameFactsPort`, selection facts, spatial candidates, and resource session/cache policy remain owned by their existing seams.

In Scope:

Migrate spatial candidate access from permissive base getters to explicit candidate-result or frame-admission success. Update frame capture, ordinary planning where needed, selected supplement staging, and bounded tests/helpers to use that admission. Move selected supplement shifted admission before selected ordinary filtering and make typed non-candidate shifted results return ordinary records unchanged with a rejected-admission probe/reason and no ordinary cache write. Add or reuse one frame-private drawable policy for overlay eraser, overlay pencil/marker, committed stroke, committed line, and empty/no-op handling. Make marquee overlay primitives carry captured `CanvasSelectionStyle` fields and paint fill/stroke from that immutable style. Upgrade frame/cache guardrails to analyzer-backed recognition over a single ordinary-cache surface registry that includes `OrdinaryPaintRecordCacheEntry`. Upgrade no-global-scene-sort recognition to catch structural bypasses while preserving unrelated local scalar/string sort allowances. Repair docs, diagrams, registry sections, generated indexes, and implementation notes that drift from actual P9 owners, file names, resource-session ordering, and proof inventory. Add focused frame, guardrail, compatibility, docs, and architecture verification named by the execution units.

Out of Scope:

Do not add P10 interaction preview producers, selected-move lifecycle, pointer sessions, or preview mutation APIs. Do not add P13 active surface/session lifecycle, surface attach/detach, runtime-swap cleanup, or resolver ownership changes. Do not expose frame collaborators, painters, caches, `RuntimeRoot`, or internal bridge APIs through the public package barrel. Do not reject existing public one-point preview corridors, one-point stroke elements, or same-point line elements at public constructors. Do not rename or split cohesive implementation files only to match stale documentation. Do not replace `FrameFactsPort`, `SelectionFactsPort`, `SpatialKernel`, `SurfaceResourceSession`, or docs registries with duplicate sources of truth. Do not add production dependencies on guardrail/test fixtures or docs tooling.

Source of Truth:

The design source of truth for this step is `.design/2026-06-01-p9-frame-rendering-findings-closure.md`. The original findings source is `.research/2026-06-01-p9-frame-rendering-findings.md`. Frame rendering behavior belongs in `docs/contracts/frame_rendering.md`; spatial typed result semantics belong in `docs/contracts/spatial_kernel.md`; ordinary cache exclusions belong in `docs/contracts/cache_policy.md`; resource session ownership and frame-pass reset semantics belong in `docs/contracts/resources.md`; package and runtime ownership belong in `docs/architecture/02_package_boundaries.md` and `docs/architecture/01_runtime_ownership.md`; P9 implementation-note inventory belongs in `docs/implementation/p9_frame_rendering_and_caches.md`; guardrail behavior belongs in `docs/verification/guardrails.md` plus `tool/guardrails/**`; proof inventory belongs in `docs/verification/tests.md`, `docs/_registry/sections.yaml`, and generated `docs/indexes/**`. The roadmap source of truth is `PLAN.md` plus this linked step contract.

Compatibility:

Public package API and public DTO shapes remain source-compatible. Accepted public degenerate inputs remain accepted and are rendered or safely no-op at the frame boundary. `SpatialQueryResult` is internal; its base candidate getters may be retired or made inaccessible as part of the seam migration only after replacement admission paths and migrated consumers exist. Guardrail fixture names and bypass-only values must stay in test/guardrail fixture surfaces and must not become public API, schemas, durable contracts, generated docs, or production source-of-truth data.

Order Constraints:

First create the replacement spatial admission path while the old base getters still exist. Then migrate all production and spatial/frame test-support consumers, including frame capture, ordinary planning where needed, selected supplement consumers, and spatial fixtures. Then remove or make inaccessible the base `SpatialQueryResult.candidates` and `hasCandidates` getters at the spatial result owner and run retirement proof. Then move selected supplement shifted admission before selected ordinary filtering and prove rejection fallback/no ordinary cache write. Then add the frame drawable policy and painter integrations. Then add marquee captured-style primitive behavior. Then upgrade cache and no-global-sort guardrails with analyzer-backed fixtures. Then repair docs/diagrams/implementation notes/registries/generated indexes and run docs/architecture checks as triggered. Roadmap checkbox closure remains a later implementation workflow action and is not an execution unit in this planning contract. Unit `Depends On` entries below describe technical dependencies; this `Order Constraints` sequence controls implementation workflow order when a unit is technically independent but must still run later.

Temporal and all-or-nothing constraints:

Temporal invariant: a frame may publish only a fully admitted frame output or a failure-contained fallback for that paint. Synchronous callback surfaces are `CustomPainter.paint` calls and resolver callbacks during `SurfaceResourceSession.resolveImage`; selected supplement shifted admission itself has no user/runtime callback. Guard/boundary owners are frame spatial admission, frame drawable policy, and existing resolver/session mutation guards. Allowed public observation order is: rejected shifted supplement admission publishes the ordinary frame unchanged for that paint, exposes the internal rejected-admission probe/reason to tests/diagnostics, and performs no ordinary cache mutation; resolver reentrancy remains `StateError`/no runtime effects under existing resource tests.

All-or-nothing boundary: ordinary cache write and selected-record removal are the irreversible frame points. Fallible ordinary spatial admission and row resolution must complete before ordinary cache write. Fallible shifted supplement spatial admission must complete before selected ordinary records are filtered. Later draw classification is deterministic and failure-contained as explicit command construction or no-op for empty inputs. Failure projection before irreversible points is unchanged ordinary records, no shifted records, no ordinary cache write, and a rejected-admission probe/reason. Proof surfaces are selected supplement negative tests, valid-empty shifted candidate tests, and ordinary cache probe tests.

## Execution Units

### [x] Unit 1: Explicit Spatial Admission Seam

Owner:

`lib/src/geometry/spatial_query_result.dart`, frame-private spatial admission code under `lib/src/frame/**`, affected frame consumers, and focused spatial/frame seam tests.

Boundary:

Typed spatial query result admission only. Do not change public API shape, spatial index ownership, frame painter behavior, cache policy, selected supplement merge semantics, or docs beyond source-of-truth updates scheduled in Unit 7.

Change:

Add or use an explicit admission path that accepts only `SpatialCandidatesResult` as candidate success and returns a typed rejection reason for `SpatialBudgetExceededResult`, `SpatialInvalidIndexResult`, and `SpatialStaleCandidateResult`. Migrate every production consumer and spatial/frame test-support consumer, including frame capture, ordinary planning where needed, selected supplement staging, and spatial fixtures, away from raw base `.candidates` / `.hasCandidates` consumption while the old base getters still exist. After replacement paths and migrated consumers are in place, remove permissive candidate-like access from the `SpatialQueryResult` base type or make the base `candidates` and `hasCandidates` getters inaccessible at the spatial result owner, so the root seam no longer exposes non-candidate failures as empty candidate success.

Completion Check:

`dart analyze`, `dcm analyze .`, and `dcm calculate-metrics lib/src/geometry lib/src/frame test/spatial test/frame` pass for the changed production and test owners. Focused spatial/frame tests compile only after base candidate-like access is removed or inaccessible from `SpatialQueryResult`. A semantic or analyzer-backed structural test over production code plus spatial/frame test-support consumers proves no code reads `SpatialQueryResult.candidates` or `SpatialQueryResult.hasCandidates` from the base type, and candidate lists are read only from `SpatialCandidatesResult` or the explicit admission result. Tests distinguish typed non-candidate rejection from a successful `SpatialCandidatesResult(orderedCandidates: [])`, so a fake implementation that treats all empty lists as failure or all failures as empty success fails.

Depends On:

None.

### [x] Unit 2: Selected Supplement Rejection Fallback

Owner:

`lib/src/frame/selected_move_supplement_planner.dart`, ordinary cache probe surfaces in `lib/src/frame/**`, and focused selected supplement tests.

Boundary:

Selected-move supplement staging for the current frame. Do not change ordinary paint-plan construction except for adopting explicit admission from Unit 1. Do not add P10 preview producers, selected-move commit/cancel lifecycle, or public preview mutation APIs.

Change:

Move shifted spatial admission before selected ordinary records are removed from the per-frame ordinary stream. For `SpatialBudgetExceededResult`, `SpatialInvalidIndexResult`, and `SpatialStaleCandidateResult`, return the ordinary records unchanged for that paint, build no partial shifted records, expose an internal rejected-admission reason/probe, and perform no ordinary cache write during supplement handling. Preserve successful empty shifted candidates as a valid selected-preview path.

Completion Check:

`dart analyze`, `dcm analyze .`, and `dcm calculate-metrics lib/src/frame test/frame` pass for the changed frame production and test owners. Focused selected supplement tests inject each typed non-candidate shifted result and assert merged records equal the original ordinary plan, selected ordinary records remain present, shifted supplement record count is zero, rejected-admission reason/probe identifies the typed rejection, and ordinary cache writes during supplement remain zero. A separate valid-empty `SpatialCandidatesResult(orderedCandidates: [])` test asserts the selected-preview path remains admitted and selected ordinary records are removed when the preview moves selected elements outside the viewport. These checks name the irreversible selected-record removal point and fail if admission is performed after filtering.

Depends On:

Unit 1.

### [x] Unit 3: Frame Drawable Degenerate Policy

Owner:

Frame-private drawable policy code under `lib/src/frame/**`, `lib/src/frame/overlay_frame_painter.dart`, `lib/src/frame/main_frame_record_painter.dart`, `lib/src/frame/render_family_caches.dart` where needed, and painter output tests.

Boundary:

Frame-owned drawing command classification for already accepted frame inputs. Do not reject public constructors, change element/preview DTOs, alter geometry bounds policy, or introduce separate per-call-site degenerate fixes that can diverge.

Change:

Add or reuse one frame-private drawable policy that classifies empty point lists as no-op, one-point corridors/strokes as explicit point/circle output using accepted thickness/color/opacity, same-point lines as the same explicit point/circle output, and multi-point paths/segments through existing path or line drawing. Route overlay eraser, overlay pencil/marker, committed one-point stroke, and committed same-point line painting through this policy or a single equivalent helper.

Completion Check:

`dart analyze`, `dcm analyze .`, and `dcm calculate-metrics lib/src/frame test/frame test/api_contract` pass for the changed frame production, frame test, and public API test owners. Overlay painter pixel or recorded-canvas tests prove non-transparent output at the expected point for one-point eraser, pencil, and marker previews. Main-frame pixel or recorded-canvas tests prove non-transparent output at the expected point for committed one-point stroke and same-point line records. Empty point-list tests prove no drawing command or no visible output without throwing. Public API compatibility tests prove one-point preview corridors, one-point stroke elements, and same-point line elements remain constructible and are not newly rejected.

Depends On:

None.

### [x] Unit 4: Captured-Style Marquee Overlay

Owner:

`lib/src/frame/overlay_preview_planner.dart`, `lib/src/frame/overlay_frame_painter.dart`, captured overlay frame models under `lib/src/frame/**`, and marquee overlay tests.

Boundary:

Marquee overlay primitive construction and painter output from captured immutable `CanvasSelectionStyle`. Do not pull live runtime/surface style reads into painters and do not add P10/P13 lifecycle behavior.

Change:

Carry captured selection style fields needed for marquee fill and stroke through the marquee overlay primitive, then draw marquee fill and stroke from those captured fields. Preserve immutable painter input semantics: `CustomPainter.paint` consumes classified frame output and does not read runtime, store, resolver, or public document projection.

Completion Check:

`dart analyze`, `dcm analyze .`, and `dcm calculate-metrics lib/src/frame test/frame` pass for the changed frame production and test owners. Focused primitive tests assert marquee overlay primitives include the captured color, stroke width, and marquee fill opacity from a non-default `CanvasSelectionStyle`. Pixel or recorded-canvas painter tests prove fill/stroke output reflects that non-default captured style. Existing no-live-runtime-read painter tests still pass, proving the synchronous `CustomPainter.paint` callback consumes immutable output rather than live runtime/surface state.

Depends On:

None.

### [x] Unit 5: Analyzer-Backed Ordinary Cache Guardrails

Owner:

`tool/guardrails/src/frame_cache_guardrail_checks.dart`, guardrail registry/executor surfaces as needed, and `test/guardrails/**` fixtures for frame cache exclusions.

Boundary:

Executable guardrail recognition for ordinary cache surfaces and forbidden preview/selection facts. Do not add prose-only reminders, production fixture data, or new duplicate cache policy sources.

Change:

Replace narrow text/body scanning with analyzer-backed structural recognition for the ordinary cache exclusion checks. Keep a single guardrail-local ordinary-cache surface registry that includes `PaintPlanKey`, `OrdinaryPaintRecordKey`, `PaintPlan`, `OrdinaryPaintRecordCacheEntry`, `RenderElementRecord`, and any future registered frame cache value/key surfaces that can store ordinary records. Ensure guardrail runner paths stay registered and blocking where they are already blocking.

Completion Check:

`dart analyze`, `dcm analyze .`, and `dcm calculate-metrics tool/guardrails test/guardrails` pass for the changed guardrail tool and guardrail test owners. Runner-backed guardrail tests reject negative fixtures that place preview or selection facts in `PaintPlanKey`, `OrdinaryPaintRecordKey`, `PaintPlan`, `OrdinaryPaintRecordCacheEntry`, and `RenderElementRecord`. Positive allowed fixtures without preview/selection facts pass. Fixture-only names and bypass data remain under `test/guardrails/**` or guardrail fixture surfaces and do not appear in production source-of-truth docs, public API registries, schemas, or generated indexes. Both `dart run tool/guardrails/run.dart --guardrail=frame.paint_plan_excludes_preview_delta` and `dart run tool/guardrails/run.dart --guardrail=frame.paint_plan_excludes_selection_state` pass, or one focused `dart test test/guardrails/...` command that covers both guardrail ids passes, proving both blocking guardrail paths are active.

Depends On:

None.

### [x] Unit 6: Analyzer-Backed No-Global-Sort Guardrail

Owner:

`tool/guardrails/src/frame_cache_guardrail_checks.dart`, guardrail registry/executor surfaces as needed, and `test/guardrails/frame_no_global_scene_sort_guardrail_test.dart` plus focused bypass fixtures.

Boundary:

Executable recognition for forbidden global scene/record stream sorting by `orderToken`. Do not ban unrelated local scalar/string sorts and do not rely on substring windows as the claimed proof.

Change:

Migrate no-global-scene-sort recognition from textual `.sort(` scanning to analyzer AST recognition that catches multi-line comparator forms, cascade sort calls, named comparator/helper indirection, and record/order-token stream sort patterns. Preserve the existing allowed local scalar/string sort behavior.

Completion Check:

`dart analyze`, `dcm analyze .`, and `dcm calculate-metrics tool/guardrails test/guardrails` pass for the changed guardrail tool and guardrail test owners. Runner-backed guardrail tests reject multi-line comparator, cascade sort, named comparator/helper, and order-token record-stream bypass fixtures. The existing allowed local scalar/string sort fixture remains allowed. Tests fail if recognition depends only on a short substring around `.sort(` or over-rejects local non-record sorts.

Depends On:

None.

### [x] Unit 7: Source-Of-Truth And Generated Docs Repair

Owner:

`docs/contracts/frame_rendering.md`, `docs/contracts/spatial_kernel.md`, `docs/contracts/cache_policy.md`, `docs/implementation/p9_frame_rendering_and_caches.md`, `docs/verification/guardrails.md`, `docs/verification/tests.md`, `docs/_registry/sections.yaml`, generated `docs/indexes/**`, `docs/architecture/02_package_boundaries.md`, `docs/architecture/01_runtime_ownership.md`, `docs/diagrams/seq_main_paint.mmd`, `docs/diagrams/seq_overlay_paint.mmd`, and architecture graph/generated views only when triggered.

Boundary:

Durable source-of-truth alignment for implemented P9 behavior, file ownership, resource-session ordering, guardrail semantics, and proof inventory. Do not create non-authoritative task notes, duplicate docs, rename cohesive implementation files only for docs, or update architecture graph/generated architecture views unless implementation changes graph-owned declarations or edges.

Change:

Document explicit spatial admission, selected supplement rejected-shifted-query fallback, degenerate drawable policy, marquee captured-style primitive behavior, typed non-candidate spatial result semantics, ordinary cache surface recognition including `OrdinaryPaintRecordCacheEntry`, analyzer-backed guardrail recognition, actual cohesive frame file names, resource-session ownership/order, and new focused P9 proof inventory. Update `docs/implementation/p9_frame_rendering_and_caches.md` where its P9 test/proof inventory or implementation note text would otherwise conflict with the implemented closure. Update registry-backed tests and generated indexes through the existing docs sync flow. Update sequence diagrams to show `beginFrameResourcePass()` before per-record image resolution and captured-style marquee primitive construction.

Completion Check:

`dart test test/api_contract/public_api_v1_compiles_as_written_test.dart test/api_contract/public_exports_complete_test.dart test/api_contract/api_facades_do_not_export_internal_test.dart test/api_contract/public_signature_shape_test.dart` passes and proves public DTO/barrel shape remains compatible, registry/barrel parity is intact, and frame-private collaborators are not exported. `dart run tool/guardrails/run.dart --guardrail=api.public_exports_complete` and `dart run tool/guardrails/run.dart --guardrail=api.facades_do_not_export_internal` also pass if guardrail routes are touched. `dart run docs/tool/sync_generated_docs.dart --check` and `dart run docs/tool/check_docs.dart` pass after any required generated-doc sync is reviewed. If architecture graph, architecture-owned production seams, generated architecture diagrams, or architecture docs/diagrams are changed, `dart run tool/architecture_graph/check.dart --phase P9` and `dart run tool/architecture_graph/generate_views.dart --phase P9 --check` pass. Manual review confirms `docs/implementation/p9_frame_rendering_and_caches.md` remains aligned with the new focused P9 proof inventory, confirms docs name `captured_frame.dart` and `frame_repaint_signal.dart` as actual cohesive owners unless implementation creates a real cohesive split, and confirms docs describe `RuntimeRoot` as owning the nullable active invalidation sink rather than active `SurfaceResourceSession` lifecycle.

Depends On:

Units 1, 2, 3, 4, 5, and 6.
