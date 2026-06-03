# Change Contract

## Goal

Implement P13 by turning `CanvasSurface` into the public Flutter widget adapter that mounts against a `CanvasRuntime`, enforces one active surface per runtime, paints resource-backed and resource-free documents through the existing frame/resource owners, routes finite Flutter pointer events into runtime interaction behavior, and preserves source-compatible public construction while moving the implementation under the surface owner.

## Source Inputs

- Design: `.design/2026-06-03-p13-flutter-surface.md`
- Research: `.research/2026-06-03-p13-flutter-surface-research.md`
- Phase: `docs/implementation/p13_flutter_surface.md`
- PLAN: `PLAN.md`
- Other: `docs/contracts/public_api_v1.md`, `docs/contracts/resources.md`, `docs/contracts/interaction_engine.md`, `docs/contracts/frame_rendering.md`, `docs/contracts/cache_policy.md`, `docs/verification/tests.md`, `docs/verification/guardrails.md`, `docs/verification/guardrail_design_patterns.md`, `docs/verification/release_gates.md`, `docs/architecture/02_package_boundaries.md`, `docs/architecture/architecture_graph.yaml`, `docs/_registry/donors.yaml`, `lib/src/api/canvas_surface.dart`, `lib/src/api/canvas_runtime_frame_bridge.dart`, `lib/src/api/canvas_runtime.dart`, `lib/src/runtime/runtime_root.dart`, `lib/src/resources/surface_resource_session.dart`, `lib/src/frame/frame_engine.dart`, `lib/src/frame/paint_asset_binding_service.dart`, `lib/src/frame/main_frame_painter.dart`, `lib/src/frame/overlay_frame_painter.dart`, `lib/src/interaction/pointer_sample_normalizer.dart`, `lib/src/interaction/pointer_tool_cleanup_coordinator.dart`, `tool/architecture_graph/src/phase_closure.dart`, `tool/guardrails/src/owner_dag_import_checks.dart`, `tool/guardrails/src/core_boundary_checks.dart`, `tool/guardrails/src/interaction_guardrail_checks.dart`, `tool/guardrails/src/guardrail_executor.dart`, `test/smoke/public_incremental_smoke_test.dart`

## Classification

Profile: BEHAVIOR_CHANGE

Obligations: BUG_FIX, SEAM_MIGRATION, PUBLIC_API_CHANGE

## Decision Trace

| Source decision | Contract location | Execution unit / proof surface |
|---|---|---|
| `D1` `CanvasSurface` declaration moves to `lib/src/surface/canvas_surface_widget.dart`; API becomes wrapper export only. | `Boundaries.Owner`, `Boundaries.Source of Truth`, Unit 0 | `lib/src/surface/canvas_surface_widget.dart` owns the class declaration; `lib/src/api/canvas_surface.dart` exports styles and `CanvasSurface` only; `dart run tool/architecture_graph/check.dart --phase P13` sees `flutter.surface`. |
| `D2` Surface uses a narrow runtime-surface bridge, never `RuntimeRoot`. | `Boundaries.Owner`, `Boundaries.Order Constraints`, Unit 0, Unit 1 | Unit 0 creates `lib/src/api/canvas_runtime_surface_bridge.dart`, attaches it from `CanvasRuntime`, removes production surface use of the root-returning bridge, and guardrails reject `RuntimeRoot` and root barrel imports from `lib/src/surface/**`; Unit 1 fills the active-token behavior on that port. |
| `D3` Single-active attach is runtime-token owned and fallible before session/listener/paint/resolver side effects. | `Boundaries.All-Or-Nothing Failure Boundary`, Unit 1 | `test/surface/single_active_surface_test.dart` proves exact `StateError`, no resolver/session/pointer/paint side effects, old active surface continuity, and independent runtime coexistence. |
| `D4` `SurfaceResourceSession` is created only after accepted attach and remains the only resolver/cache/generation owner; runtime sees only `SurfaceResourceSessionLifecycle`. | `Boundaries.Source of Truth`, Unit 0, Unit 2 | Unit 0 creates the compile-safe `SurfaceResourceSessionLifecycle` contract and port signature; Unit 2 makes `SurfaceResourceSession` implement it and proves attach, replace, dirty invalidation, detach, dispose, runtime swap, and no image disposal in `test/surface/surface_resource_session_lifecycle_test.dart`. |
| `D5` Main frame uses `FrameEngine.buildMainFrameWithAssetBindings`; `CanvasSurfaceImageBridge` supplies a `FrameAssetBindingBuilder`; overlay frame remains resource-free. | `Boundaries.Source of Truth`, Unit 3 | `lib/src/surface/image_bridge.dart`, runtime-surface port main/overlay builders, `test/surface/widget_paint_test.dart`, and resource/frame tests prove resolver-backed main paint and resource-free overlay paint. |
| `D6` Flutter `CustomPainter` adapters move to surface owner and consume immutable frame outputs. | `Boundaries.Owner`, Unit 3 | `lib/src/surface/main_painter.dart` and `lib/src/surface/overlay_painter.dart` consume frame outputs only; import guardrails and no-live-runtime-read painter tests target surface paths. |
| `D7` Pointer adapter converts only finite Flutter pointer events to public samples; world normalization stays in interaction. | `Boundaries.Source of Truth`, Unit 4 | `lib/src/surface/pointer_adapter.dart` rejects non-finite local positions before sample construction; `test/surface/pointer_adapter_finite_normalization_test.dart` proves no runtime call for non-finite events and camera-aware world facts through interaction normalization. |
| `D8` `interactive=false` triggers runtime cleanup only for the active route while preserving non-owned pending line state. | `Boundaries.Temporal Surface Closure`, Unit 5 | `test/surface/interactive_false_pointer_routing_test.dart`, `test/surface/interactive_false_active_session_cancel_test.dart`, `test/surface/interactive_false_pending_line_preserved_test.dart`, and `test/surface/interactive_false_state_isolation_test.dart` prove routing disable, active cleanup, pending preservation, and state isolation. |
| `D9` Public smoke appends P13 external consumer behavior through Flutter events and resource-backed surface paint using the root barrel only. | `Boundaries.Compatibility`, Unit 6 | `test/smoke/public_incremental_smoke_test.dart` appends resource-backed paint, Flutter-event routing, and `interactive=false` public behavior through `runFlutterConsumerTest`. |
| `D10` Unit 0 closes guardrail, docs, graph, test-path, and obsolete `flutter_bridge` drift before behavior implementation relies on P13 proof surfaces. | `Boundaries.Order Constraints`, Unit 0 | Guardrail registry/executor route the named ids; owner-DAG and boundary checks encode the exact surface edges; docs/verification ids use `test.surface.*`; `lib/src/flutter_bridge/**` and `test/flutter_bridge/**` are not live P13 proof owners. |
| `D11` Ordinary opacity and no-saveLayer policy remains frame/surface paint proof, not a widget choice. | `Boundaries.Source of Truth`, Unit 3 | Surface painters delegate record painting to frame-owned helpers and do not call `Canvas.saveLayer` for ordinary opacity; existing frame opacity proof and surface painter guardrails cover the hot path. |
| `D12` Hidden DCM dependency output is informational unless file-level evidence is available. | `Boundaries.Order Constraints`, Unit 0, Unit 6 | Unit 0 records no metric-only or hidden-report refactor; if `dcm check-dependencies lib` reveals file-level violations, implementation stops and fixes the owning boundary before behavior work. |

## Evidence

- `.design/2026-06-03-p13-flutter-surface.md:13` / disposition: design is `READY_FOR_CONTRACT` -> write a full contract, not a blocker.
- `.design/2026-06-03-p13-flutter-surface.md:17` / product outcome: `CanvasSurface` becomes a public Flutter adapter while runtime, resources, interaction, frame, cache, document, and app images keep their owners -> surface must compose existing owners, not replace them.
- `.design/2026-06-03-p13-flutter-surface.md:24` / non-goal: do not expand the current API file in place -> implementation moves to `lib/src/surface/**`.
- `.design/2026-06-03-p13-flutter-surface.md:25` / non-goal: no `lib/src/flutter_bridge/**` owner -> Unit 0 must retire bridge naming from guardrail/test proof surfaces.
- `.design/2026-06-03-p13-flutter-surface.md:31` / classification: selected profile is `BEHAVIOR_CHANGE` -> behavior units must prove public widget behavior, not only structure.
- `.design/2026-06-03-p13-flutter-surface.md:32` / obligations: selected obligations are `BUG_FIX`, `SEAM_MIGRATION`, and `PUBLIC_API_CHANGE` -> contract must close drift, migrate seams, and preserve public source compatibility.
- `.design/2026-06-03-p13-flutter-surface.md:280` / selected form: Candidate A is locked -> surface-owned widget with narrow runtime-surface bridge is mandatory.
- `.design/2026-06-03-p13-flutter-surface.md:286` / locked shape: primary widget file and class are fixed -> Unit 0 must create `lib/src/surface/canvas_surface_widget.dart` with `final class CanvasSurface extends StatefulWidget`.
- `.design/2026-06-03-p13-flutter-surface.md:290` / locked shape: pointer adapter file and class are fixed -> Unit 4 must create `CanvasSurfacePointerAdapter`.
- `.design/2026-06-03-p13-flutter-surface.md:296` / locked shape: image bridge file, class, imports, and method shape are fixed -> Unit 3 must create `CanvasSurfaceImageBridge.bindAssets(SurfaceResourceSession session)`.
- `.design/2026-06-03-p13-flutter-surface.md:303` / locked shape: surface main painter consumes `MainFramePaintOutput` and delegates record painting -> Unit 3 must move the painter adapter without copying frame planning.
- `.design/2026-06-03-p13-flutter-surface.md:308` / locked shape: surface overlay painter consumes `OverlayFramePaintOutput` -> Unit 3 must keep overlay frame resource-free.
- `.design/2026-06-03-p13-flutter-surface.md:312` / locked shape: API surface file becomes wrapper-export only -> Unit 0 must remove implementation imports from the API file.
- `.design/2026-06-03-p13-flutter-surface.md:317` / locked shape: runtime-surface bridge stores an `Expando` from `CanvasRuntime` to a narrow surface port and never returns `RuntimeRoot` -> Unit 0 must replace production surface usage of the root-returning bridge.
- `.design/2026-06-03-p13-flutter-surface.md:326` / locked shape: add `SurfaceResourceSessionLifecycle` with exactly `ResourceSessionInvalidationSink` plus `void drop()` -> Unit 0 must create the structural contract before the port signature uses it, and Unit 2 must not expose resolver methods through the runtime bridge.
- `.design/2026-06-03-p13-flutter-surface.md:340` / required port: the port exposes only state, attach, install session, detach, interactive-disabled cleanup, pointer handling, main frame, overlay frame, and resolver mutation guard -> Unit 0 creates the allowed port shape, and later units must not widen it.
- `.design/2026-06-03-p13-flutter-surface.md:389` / attach order: attach token before session construction or install -> Unit 1 owns the irreversible point and Unit 2 owns post-attach session lifecycle.
- `.design/2026-06-03-p13-flutter-surface.md:397` / attach rejection: rejected attach creates no session/listener/paint/pointer/resolver side effects and throws exact error -> Unit 1 must prove all-or-nothing failure.
- `.design/2026-06-03-p13-flutter-surface.md:399` / update lifecycle: resolver replacement, interactive false, runtime swap, and no old-runtime reattach are fixed -> Units 2 and 5 must preserve update ordering.
- `.design/2026-06-03-p13-flutter-surface.md:408` / dispose lifecycle: interactive cleanup before detach and idempotent local drop fallback are fixed -> Units 2 and 5 must prove dispose cleanup.
- `.design/2026-06-03-p13-flutter-surface.md:419` / pointer semantics: adapter must be a Flutter `Listener`, not a gesture recognizer -> Unit 4 must not use `GestureDetector`/recognizer routing.
- `.design/2026-06-03-p13-flutter-surface.md:423` / pointer semantics: interactive false admits no pointer route, true routes only down/move/up/cancel phases -> Unit 4 and Unit 5 must prove routing.
- `.design/2026-06-03-p13-flutter-surface.md:433` / pointer semantics: reject non-finite local position before constructing samples or calling runtime -> Unit 4 must prove the negative path.
- `.design/2026-06-03-p13-flutter-surface.md:437` / paint semantics: build path uses state observation, layout viewport, DPR, image bridge, main/overlay frame builders, stable paint host key, and surface painters -> Unit 3 must implement this exact path.
- `.design/2026-06-03-p13-flutter-surface.md:453` / resource semantics: empty documents do not call resolver and image records call synchronous app resolver through session -> Unit 3 must prove both.
- `.design/2026-06-03-p13-flutter-surface.md:462` / source-of-truth closure: Unit 0 is mandatory before behavior units rely on proof surfaces -> Unit 0 must close guardrail, graph, naming, and test-path drift.
- `.design/2026-06-03-p13-flutter-surface.md:478` / guardrail closure: P13 guardrail ids must be runner-backed and docs-only listings are insufficient -> Unit 0 must update registry/executor and tests.
- `.design/2026-06-03-p13-flutter-surface.md:485` / boundary tooling: owner-DAG edges and forbidden imports are exact -> Unit 0 must not add broad allowlists.
- `.design/2026-06-03-p13-flutter-surface.md:492` / graph closure: final P13 graph check is required after behavior units; unrelated P10/P12 drift is not in scope -> Unit 6 must run graph checks and stop on unrelated contradictions.
- `.design/2026-06-03-p13-flutter-surface.md:516` / decision trace: `D1` maps widget move and API wrapper closure to Unit 0 and graph proof -> Unit 0 carries the API/surface migration.
- `.design/2026-06-03-p13-flutter-surface.md:517` / decision trace: `D2` maps narrow runtime-surface bridge to Unit 0 and guardrail proof -> Unit 0 must expose no `RuntimeRoot`, and later units must preserve that boundary.
- `.design/2026-06-03-p13-flutter-surface.md:518` / decision trace: `D3` maps single-active attach to tests -> Unit 1 must prove side-effect-free rejection.
- `.design/2026-06-03-p13-flutter-surface.md:519` / decision trace: `D4` maps session lifecycle to Unit 2 tests -> Unit 2 owns resolver/cache/drop lifecycle.
- `.design/2026-06-03-p13-flutter-surface.md:520` / decision trace: `D5` maps image bridge to Unit 3 -> Unit 3 must use frame asset binding seam.
- `.design/2026-06-03-p13-flutter-surface.md:521` / decision trace: `D6` maps painter migration to Unit 3 -> Unit 3 must preserve immutable-output painter behavior.
- `.design/2026-06-03-p13-flutter-surface.md:522` / decision trace: `D7` maps pointer adapter to Unit 4 -> Unit 4 must keep world normalization in interaction.
- `.design/2026-06-03-p13-flutter-surface.md:523` / decision trace: `D8` maps interactive false behavior to Unit 5 -> Unit 5 must prove temporal cleanup.
- `.design/2026-06-03-p13-flutter-surface.md:524` / decision trace: `D9` maps public smoke to Unit 6 -> Unit 6 must append external root-barrel proof.
- `.design/2026-06-03-p13-flutter-surface.md:525` / decision trace: `D10` maps drift closure to Unit 0 -> Unit 0 must close guardrails/docs/graph/test naming before relying on them.
- `.design/2026-06-03-p13-flutter-surface.md:526` / decision trace: `D11` maps ordinary opacity and no-saveLayer proof to Unit 3 -> Unit 3 must preserve frame-owned opacity policy.
- `.design/2026-06-03-p13-flutter-surface.md:527` / decision trace: `D12` treats hidden DCM dependency output as informational unless file-level evidence exists -> Unit 0 and Unit 6 must not ship metric-only hidden-report refactors.
- `.design/2026-06-03-p13-flutter-surface.md:786` / source-of-truth impact: future contract must update implementation docs, public API, resources, frame, interaction, cache policy, release gates, verification docs, generated docs, guardrails, architecture graph, and diagrams as required -> Unit 6 must explicitly own these source-of-truth updates.
- `.design/2026-06-03-p13-flutter-surface.md:903` / smoke expansion: public incremental smoke must append the exact P13 scenario named `public consumer uses CanvasSurface pointer and resource bridge` -> Unit 6 must not replace it with generic smoke wording.
- `.design/2026-06-03-p13-flutter-surface.md:920` / smoke resolver proof: smoke uses a public null-returning resolver spy, proves image-resource resolver calls through surface paint, replacement resolver use, stale-result avoidance, and bounded null-result behavior -> Unit 6 must include these assertions.
- `.design/2026-06-03-p13-flutter-surface.md:926` / smoke pointer proof: smoke uses WidgetTester Flutter pointer gestures on the paint host rather than direct runtime pointer calls -> Unit 6 must preserve this public boundary.
- `.design/2026-06-03-p13-flutter-surface.md:929` / smoke pending line proof: smoke exercises pending-line preservation through Flutter pointer events where practical -> Unit 6 must require the pending-line preview preservation assertions unless implementation documents a design-backed impossibility.
- `.design/2026-06-03-p13-flutter-surface.md:569` / lock facts: `lib/src/surface/**` owns widget, pointer adapter, image bridge, and painter adapters -> owner boundary is fixed.
- `.design/2026-06-03-p13-flutter-surface.md:617` / temporal closure: only the active token routes pointer events, installs/drops sessions, triggers cleanup, or clears attachment -> port token checks are mandatory.
- `.design/2026-06-03-p13-flutter-surface.md:623` / all-or-nothing boundary: accepted `attachSurface(token)` is irreversible and post-attach session install failure rolls back token/session -> Units 1 and 2 must prove rollback.
- `docs/implementation/p13_flutter_surface.md:45` / donors: P13 lists required positive donors -> every unit must explicitly use or reject the relevant donor records.
- `docs/implementation/p13_flutter_surface.md:54` / forbidden donor structure: scene controller/runtime/builder/codec/store-controller shapes are forbidden -> guardrails and implementation must not copy legacy facades.
- `docs/contracts/public_api_v1.md:505` / public contract: `CanvasSurface` extends `StatefulWidget` with the existing constructor fields -> public class name and constructor shape remain compatible.
- `docs/contracts/public_api_v1.md:526` / public contract: v1 supports one active surface per runtime and independent runtimes may have independent surfaces -> Unit 1 attach gate must prove both.
- `docs/contracts/public_api_v1.md:531` / public contract: second active attach throws exact `StateError` before side effects -> Unit 1 must prove exact failure projection.
- `docs/contracts/public_api_v1.md:537` / public contract: `interactive=false` disables pointer routing but still paints and does not mutate runtime/document/selection/resources -> Unit 5 must prove routing and state isolation.
- `docs/contracts/public_api_v1.md:552` / public contract: successful attach creates a session before image paint and rejected attach creates no session or resolver side effects -> Unit 2 must keep attach/session ordering.
- `docs/contracts/resources.md:53` / resource contract: resource descriptors are committed document state and resolver declarations live in public contracts -> surface must not own descriptors.
- `docs/contracts/resources.md:63` / resource contract: runtime holds active invalidation sink and invalidates before dirty publication -> Unit 2 must install the session handle through runtime, not widget-owned dirty state.
- `docs/contracts/resources.md:97` / resource contract: `PaintAssetBindingService` is the only frame collaborator that receives `SurfaceResourceSession` -> Unit 3 image bridge must delegate to this service.
- `docs/contracts/resources.md:109` / resource contract: session creation after attach, no rejected side effects, resolver generation replacement, and drop/no-dispose are fixed -> Unit 2 must prove these lifecycle signals.
- `docs/contracts/resources.md:208` / resource contract: resolver calls are synchronous and app-owned -> no async/file/network/asset-bundle resource loading is in scope.
- `docs/contracts/cache_policy.md:49` / cache policy: `ImageResolveCache` is owned by `SurfaceResourceSession` -> surface cannot add a parallel resolver cache.
- `docs/contracts/interaction_engine.md:131` / interaction contract: raw pointer routing belongs to Flutter bridge and public samples are normalized by interaction -> Unit 4 surface adapter must not world-normalize.
- `docs/contracts/interaction_engine.md:172` / interaction contract: `interactive=false` cancels active routed pointer sessions and preserves non-owned pending line state -> Unit 5 must delegate cleanup to runtime/interaction.
- `docs/contracts/frame_rendering.md:97` / frame contract: selected-move preview is main-scene only while overlay variants remain overlay capture -> Unit 3 must consume main and overlay frame outputs as produced.
- `docs/contracts/frame_rendering.md:119` / frame contract: painters do not live-read runtime -> Unit 3 must keep painters immutable-output consumers.
- `docs/contracts/frame_rendering.md:126` / frame contract: `SurfaceResourceSession` is the only image resolution boundary in paint -> Unit 3 must not give painters resolver access.
- `docs/contracts/frame_rendering.md:139` / frame contract: `FrameEngine` remains frame-internal facade -> surface must not fork frame planning.
- `docs/contracts/frame_rendering.md:180` / frame contract: ordinary opacity is primitive alpha and must not create offscreen layers -> Unit 3 must preserve no-saveLayer hot path.
- `docs/architecture/02_package_boundaries.md:153` / architecture layout: `lib/src/surface/**` contains `canvas_surface_widget.dart`, `pointer_adapter.dart`, `main_painter.dart`, `overlay_painter.dart`, and `image_bridge.dart` -> file placement is fixed.
- `docs/architecture/02_package_boundaries.md:184` / architecture boundary: root barrel exports only `src/api/**` and API files are facade/wrapper files -> API surface file must be wrapper-only.
- `docs/architecture/02_package_boundaries.md:248` / test ownership: tests mirror production ownership folders -> P13 focused tests must live under `test/surface/**`, while smoke remains cross-cutting.
- `docs/architecture/02_package_boundaries.md:293` / forbidden imports: `lib/src/surface/**` may not import legacy package -> guardrails must preserve legacy import exclusion.
- `docs/architecture/architecture_graph.yaml:482` / graph node: `flutter.surface` is owner `surface`, introduced and required by P13 with declaration `CanvasSurface` -> graph closure requires the declaration under `lib/src/surface/**`.
- `docs/architecture/architecture_graph.yaml:1009` / graph edge: `flutter.surface.drives_runtime_ports` targets `api.canvas_runtime` -> runtime driving must happen through `CanvasRuntime` bridge, not runtime internals.
- `docs/architecture/architecture_graph.yaml:1212` / forbidden graph edge: `flutter.surface` must not depend on `api.public_surface` -> surface code must not import the public root barrel or API facade as a type library.
- `tool/architecture_graph/src/phase_closure.dart:20` / graph tooling: owner `surface` maps to `lib/src/surface/` -> graph checks cannot close with implementation left in API.
- `lib/src/api/canvas_surface.dart:13` / current code: `CanvasSurface` currently lives in API and imports frame painters -> Unit 0 must migrate implementation out of API.
- `lib/src/api/canvas_surface.dart:49` / current code: passive widget observes runtime state -> Unit 3 preserves public-state observation through the new surface port.
- `lib/src/api/canvas_surface.dart:75` / current code: stable paint host key exists -> Unit 3 must preserve `ValueKey<String>('iwb_canvas_surface.paint_host')`.
- `lib/src/api/canvas_runtime_frame_bridge.dart:15` / current bridge: production bridge returns `RuntimeRoot?` -> Unit 0 must replace surface usage with a non-root port.
- `lib/src/runtime/runtime_root.dart:279` / current runtime: resource-free main frame facade exists -> Unit 3 must add asset-bound main frame path without deleting needed resource-free behavior.
- `lib/src/runtime/runtime_root.dart:330` / current runtime: resource session invalidation sink attach exists -> Unit 2 must token-guard install/clear.
- `lib/src/runtime/runtime_root.dart:818` / current runtime: interactive disabled cleanup already delegates to interaction and publishes only when needed -> Unit 5 must call this through token-checked port.
- `lib/src/runtime/runtime_root.dart:901` / current runtime: pointer handling delegates to interaction engine -> Unit 4 must route samples to this existing boundary.
- `lib/src/runtime/runtime_root.dart:1022` / current runtime: resolver callbacks run through mutation guard -> Unit 2 session construction must use the exposed guard.
- `lib/src/runtime/runtime_root.dart:1219` / current runtime: dirty delivery invalidates active session before effects -> Unit 2 must preserve invalidation-before-publication.
- `lib/src/resources/surface_resource_session.dart:17` / current resources: session owns resolver/cache/generation and implements invalidation sink -> Unit 2 uses this concrete owner, not a widget cache.
- `lib/src/resources/surface_resource_session.dart:167` / current resources: `replaceResolver` increments generation and clears cache/suppression -> Unit 2 uses replace rather than creating a second session.
- `lib/src/resources/surface_resource_session.dart:188` / current resources: `drop()` clears resolver/cache without image disposal -> Unit 2 must call drop on detach/dispose/runtime swap.
- `lib/src/frame/frame_engine.dart:24` / current frame: `FrameAssetBindingBuilder` is the existing asset-binding closure seam -> Unit 3 must pass a closure, not a session through the runtime-surface port.
- `lib/src/frame/frame_engine.dart:80` / current frame: `buildMainFrameWithAssetBindings` already exists -> Unit 3 must use it.
- `lib/src/frame/paint_asset_binding_service.dart:23` / current frame: binding service receives captured frame, records, and session -> Unit 3 image bridge must call this service.
- `lib/src/frame/main_frame_painter.dart:16` / current painter: painter consumes immutable `MainFramePaintOutput` -> Unit 3 preserves immutable output consumption in surface painter.
- `lib/src/frame/overlay_frame_painter.dart:12` / current painter: painter consumes immutable `OverlayFramePaintOutput` -> Unit 3 preserves overlay output consumption in surface painter.
- `lib/src/frame/render_element_record.dart:149` / current frame: ordinary records do not require saveLayer -> Unit 3 must not introduce ordinary saveLayer in surface painters.
- `lib/src/interaction/pointer_sample_normalizer.dart:45` / current interaction: normalizer computes world position from view position plus camera offset -> Unit 4 must not duplicate world normalization in surface.
- `lib/src/interaction/pointer_tool_cleanup_coordinator.dart:71` / current interaction: interactive-disabled pending line disposition is preserved when not owned -> Unit 5 must preserve this interaction-owned decision.
- `docs/verification/tests.md:573` / verification: public incremental smoke is external Flutter consumer proof through root public barrel -> Unit 6 must append, not replace, P13 public behavior.
- `docs/verification/guardrails.md:96` / guardrail docs: surface guardrail ids are named -> Unit 0 must make them runner-backed.
- `docs/verification/guardrail_design_patterns.md:151` / guardrail patterns: surface pointer proof form is semantic sequence plus behavioral seam test -> Unit 0 and Unit 4 must provide both.
- `tool/guardrails/src/owner_dag_import_checks.dart:623` / current tooling: surface owner currently allows only public/internal contracts -> Unit 0 must add exact P13 edges.
- `tool/guardrails/src/core_boundary_checks.dart:687` / current tooling: surface painter paths are already recognized for resolver-ownership checks -> Unit 3 must use surface painter paths.
- `tool/guardrails/src/core_boundary_checks.dart:889` / current tooling: API-to-frame painter allowlist exists only for `lib/src/api/canvas_surface.dart` -> Unit 0 must remove it after migration.
- `tool/guardrails/src/interaction_guardrail_checks.dart:372` / current tooling: obsolete `lib/src/flutter_bridge/` path is still encoded -> Unit 0 must replace with `lib/src/surface/`.
- `tool/guardrails/src/guardrail_executor.dart:130` / current tooling: unknown guardrail ids exit with 64 -> Unit 0 must register and route P13 ids before relying on them.
- `.research/2026-06-03-p13-flutter-surface-research.md:199` / research: P13 surface guardrail ids were not found in registry/executor -> Unit 0 owns runner-backed registration.
- `.research/2026-06-03-p13-flutter-surface-research.md:201` / research: resource proof ids are absent from searched runner registry/executor -> Unit 0 must close resource guardrail parity.
- `.research/2026-06-03-p13-flutter-surface-research.md:203` / research: multiple P13 focused tests are absent -> each behavior unit must create/migrate its focused tests under `test/surface/**` with real assertions, not placeholder files.
- `.research/2026-06-03-p13-flutter-surface-research.md:215` / research: P13 graph currently fails only `flutter.surface` and `flutter.surface.drives_runtime_ports` -> Unit 6 graph proof must target P13 obligations and stop on unrelated graph drift.
- `.research/2026-06-03-p13-flutter-surface-research.md:223` / research: `dcm check-dependencies lib` reported hidden dependency issues without file-level details -> contract forbids metric-only or hidden-report refactors.

## Boundaries

Owner:

`lib/src/surface/**` owns Flutter widget lifecycle, layout, pointer adapter, image bridge, and Flutter `CustomPainter` adapter classes. `lib/src/api/canvas_surface.dart` is a wrapper export only. `lib/src/api/canvas_runtime_surface_bridge.dart` owns the non-public bridge from `CanvasRuntime` to a narrow surface port and is the only surface route to runtime internals. `RuntimeRoot` owns active surface token state, public runtime state, pointer routing, interactive-disabled cleanup, frame capture delegation, resolver mutation guard, runtime disposal, and active session invalidation/drop handle installation. `lib/src/resources/**` owns `SurfaceResourceSession`, resolver/cache/generation/budget/drop policy, and app-image no-dispose behavior. `lib/src/frame/**` owns frame capture, planning, asset binding, opacity policy, and immutable frame outputs. `lib/src/interaction/**` owns pointer session, preview, cleanup classification, and view-to-world pointer normalization. Guardrail tooling owns mechanical enforcement; docs, diagrams, architecture graph, and donor registry own source-of-truth updates. Unit 0 owns the structural seam migration that makes the surface owner, API wrapper, and non-root bridge true before later behavior units.

In Scope:

Create `lib/src/surface/canvas_surface_widget.dart`, `pointer_adapter.dart`, `image_bridge.dart`, `main_painter.dart`, and `overlay_painter.dart` with the exact primary declarations and responsibilities from the design. Convert `lib/src/api/canvas_surface.dart` to wrapper exports for public styles and `CanvasSurface`. Replace production surface use of `canvas_runtime_frame_bridge.dart` with `canvas_runtime_surface_bridge.dart` and a narrow token-checked port. Add `SurfaceResourceSessionLifecycle` with exactly `ResourceSessionInvalidationSink` plus `void drop();`. Token-guard active attach, session install/drop, interactive-disabled cleanup, pointer routing, main-frame build, and overlay-frame build. Use `SurfaceResourceSession` for synchronous app resolver lifecycle and image cache only after accepted attach. Build main frames with `CanvasSurfaceImageBridge.bindAssets(activeSession)` and `FrameEngine.buildMainFrameWithAssetBindings`; build overlay frames resource-free. Route only finite Flutter `PointerDownEvent`, `PointerMoveEvent`, `PointerUpEvent`, and `PointerCancelEvent` through a Flutter `Listener`. Preserve `interactive=false` painting and route cleanup only through runtime/interaction. Migrate focused proof to `test/surface/**`; append public smoke; register/reroute required guardrail ids; update owner-DAG, boundary checks, docs/verification ids, architecture graph closure, generated docs, and graph views as required.

Out of Scope:

Do not add multi-surface shared-runtime collaboration. Do not turn `CanvasSurface` into a scene controller, document owner, store owner, resolver owner, resource descriptor owner, interaction owner, frame planner, cache owner, or image disposer. Do not import or expose `RuntimeRoot`, store, edit, selection, interaction internals, resource internals other than concrete `SurfaceResourceSession`, root public barrel, legacy package paths, or `lib/src/flutter_bridge/**` from `lib/src/surface/**`. Do not keep public surface implementation in `lib/src/api/canvas_surface.dart`. Do not add `lib/src/flutter_bridge/**`. Do not add async, file, network, asset-bundle, engine-owned, or auto-disposing image loading. Do not add ordinary-opacity `Canvas.saveLayer` behavior. Do not repair unrelated P10/P12 graph-status drift in P13; stop and report if current P13 graph checks surface unrelated contradictions after P13 changes. Do not satisfy DCM or metrics through hidden-report or metric-only reshaping without file-level evidence and owner-level cause.

Source of Truth:

The design file `.design/2026-06-03-p13-flutter-surface.md` is a contract source input and decision handoff, not the durable behavior source of truth after implementation. Durable P13 behavior source of truth lives in `docs/implementation/p13_flutter_surface.md`. Public constructor, API wrapper clarification, and behavioral compatibility live in `docs/contracts/public_api_v1.md`. Resource session lifecycle, `SurfaceResourceSessionLifecycle`, resolver, dirty invalidation, app-key, no-dispose, and no-IO rules live in `docs/contracts/resources.md` and `docs/contracts/cache_policy.md`. Pointer normalization, pointer session cleanup, raw Flutter routing wording, and pending-line preservation live in `docs/contracts/interaction_engine.md` and interaction code. Frame capture, asset binding, surface-owned painter adapter clarification, immutable painter output, preview routing, and opacity/no-saveLayer policy live in `docs/contracts/frame_rendering.md` and `lib/src/frame/**`. Release readiness for P13 proof lives in `docs/verification/release_gates.md`. Test and guardrail proof inventories live in `docs/verification/tests.md`, `docs/verification/guardrails.md`, and `docs/verification/guardrail_design_patterns.md`. Architecture ownership and import direction live in `docs/architecture/**`, architecture graph tooling, and guardrails. Donor use and forbidden donor structures live in `docs/_registry/donors.yaml`. Generated docs and generated graph views are outputs, not independent owners.

Compatibility:

Keep the public root import path and `CanvasSurface` constructor source-compatible: `runtime`, nullable `resourceResolver`, `selectionStyle`, `gridStyle`, `interactive`, and `key` remain. `CanvasSurface` remains a `StatefulWidget`. Same-runtime second active attach throws exactly `StateError('CanvasRuntime already has an active CanvasSurface.')`. Different runtimes can host simultaneous active surfaces. `interactive=false` remains active and still paints. `interactive=true` resumes only for subsequent pointer events; no synthetic event replay is allowed. Rejected attach creates no session, resolver, cache, pointer, paint, or listener side effects. Surface never disposes app-owned `ui.Image`. Existing root-barrel public smoke remains append-only.

Order Constraints:

Unit 0 must close source-of-truth, guardrail, owner-DAG, graph, test-path drift, API wrapper closure, and runtime-bridge closure before behavior units rely on P13 proof surfaces. Unit 1 must add token attach/detach behavior on the already-created surface owner and runtime-surface port before session, paint, or pointer units. Unit 2 must add session lifecycle after the attach gate and before resolver-backed paint. Unit 3 must add image bridge and painter migration after session lifecycle. Unit 4 must route pointer events after token-checked bridge operations exist. Unit 5 must add interactive false lifecycle cleanup after pointer routing and token identity exist. Unit 6 appends public smoke and runs final graph/docs/guardrail verification after behavior units. If a DCM dependency report later provides file-level violations, implementation must stop behavior work and fix the owning boundary before continuing.

Temporal Surface Closure:

Only the currently active surface token may route pointer events, install or drop session state, trigger interactive-disabled cleanup, build frames, or clear runtime attachment. Synchronous callback surfaces are Flutter pointer callbacks, `didUpdateWidget`, `dispose`, `ValueListenableBuilder` rebuild, synchronous resolver callback, runtime dirty invalidation, runtime dispose, and synchronous runtime mutation guards. The runtime-surface port owns token checks; interaction owns cleanup classification; resources own resolver/cache/drop; frame owns capture/binding; runtime mutation guard rejects resolver reentrancy. Public observation order is: accepted attach before session creation before session install before paint/pointer; pointer cleanup updates preview/session before public runtime state publication; dirty invalidation reaches active session before resourceVisual publication; changed interaction/edit commits keep existing state-before-action delivery ordering. Expected rejection/no-mutation signals are exact second-active `StateError`, non-finite pointer ignored before runtime, stale token detach/routing no-op, resolver reentrant mutation `StateError`, and `interactive=false` no-active-route silent no-op unless cleanup changes preview.

All-Or-Nothing Failure Boundary:

The irreversible point is accepted `attachSurface(token)` marking the runtime active for that token. Fallible work before that point is runtime disposed check, bridge lookup, and same-runtime second-active rejection. Session construction and session install are fallible after attach; if either fails, the surface must call `drop()` on the new session if it exists, detach the token, and rethrow. Later widget build, frame capture, resolver callback, and pointer routing occur only after active token/session setup; their failures must not leave a second active surface, stale resolver attachment, or another surface's session cleared. Rejected attach failure projection is exact `StateError`, no session object, no resolver call, no cache, no pointer route, no paint/frame build, no listener leak, and existing active surface remains active.

## Execution Units

### [ ] Unit 0: P13 source-of-truth and enforcement closure

Owner:

`lib/src/surface/canvas_surface_widget.dart`, `lib/src/api/canvas_surface.dart`, `lib/src/api/canvas_runtime_surface_bridge.dart`, `lib/src/api/canvas_runtime.dart`, guardrail tooling, architecture graph metadata/tooling, verification docs, donor registry references, and test ownership paths.

Boundary:

Close every research-listed mismatch that would make P13 unverifiable before behavior implementation: source layout, API wrapper, runtime bridge, obsolete `flutter_bridge` naming, guardrail registry/executor parity, exact owner-DAG edges, boundary checks, docs/verification ids, graph obligations, and focused test inventory locations. This unit may preserve the current passive paint behavior only as migrated surface-owned code behind the new non-root port; it must not implement P13 attach-token behavior, session lifecycle, resolver-backed paint, pointer adapter routing, or interactive false behavior beyond method signatures that later units fill.

Design Decisions:

`D1`, `D2`, `D10`, `D12`.

Donors To Use:

- `direct_flutter_pointer_routing`: use only to name/register the future pointer adapter proof surface and reserve the narrow `handlePointer(Object token, CanvasPointerSample sample)` port method; do not copy routing code in this unit.
- `scene_painter_frame`: adapt only the current passive paint-host migration needed to move `CanvasSurface` out of API without changing paint behavior; do not copy legacy Flutter/node snapshot coupling.
- `scene_render_caches`: use only to confirm render/cache ownership remains frame/session owned in guardrail wording; do not create a surface cache.
- `static_layer_cache`: use only to preserve existing frame/static background ownership and disposal wording; do not create an optional surface cache unless later frame source already requires it.
- `interaction_pointer_host`: adapt only the future active-host token vocabulary into source-of-truth and port signatures; do not copy host facade code.
- `interaction_pointer_session`: use only to preserve interaction-owned pointer-session cleanup proof; do not move session ownership to surface.
- Forbidden donor structures to enforce mechanically: `avoid_scene_controller_facades`, `avoid_interactive_runtime_whole`, `avoid_scene_builder_public_architecture`, `avoid_scene_codec_whole`, `avoid_scene_store_controller_whole`.

Change:

1. Create `lib/src/surface/**` as the production owner for the P13 surface files named in the design.
2. Move the public `CanvasSurface` declaration out of `lib/src/api/canvas_surface.dart` into `lib/src/surface/canvas_surface_widget.dart` with the same constructor fields and current passive paint behavior preserved only as a temporary migrated baseline. The new file must not import `RuntimeRoot`, store, edit, selection, interaction internals, resource internals other than later concrete `SurfaceResourceSession`, root public barrel, legacy package paths, or `lib/src/flutter_bridge/**`.
3. Convert `lib/src/api/canvas_surface.dart` in this unit to wrapper exports only:
   - `export '../contracts/public/canvas_surface_styles.dart';`
   - `export '../surface/canvas_surface_widget.dart' show CanvasSurface;`
   - no imports, class declarations, `State<CanvasSurface>`, `CustomPaint`, frame painter references, resource implementation references, runtime root references, or Flutter implementation helpers.
4. Add `lib/src/api/canvas_runtime_surface_bridge.dart` as the non-public runtime-surface bridge with an `Expando` from `CanvasRuntime` to a final surface port object. The bridge must not be exported by `lib/iwb_canvas_engine.dart`.
5. Attach the runtime-surface port from `CanvasRuntime` construction and detach it from `CanvasRuntime.dispose()`. The bridge must return a surface port, never `RuntimeRoot`.
6. Replace production `CanvasSurface` usage of `canvasRuntimeFrameRootForSurface` with the new surface port. `canvas_runtime_frame_bridge.dart` may remain only for non-surface consumers; `CanvasSurface` must not call a root-returning bridge.
7. Add `lib/src/contracts/internal/surface_resource_session_lifecycle.dart` with `abstract interface class SurfaceResourceSessionLifecycle implements ResourceSessionInvalidationSink` and exactly `void drop();`. It must not expose `beginFrameResourcePass`, `resolveImage`, `replaceResolver`, `CanvasResourceResolver`, `ResourceImageResolveRequest`, or `ResourceImageResolveResult`.
8. The Unit 0 port shape must reserve only the final allowed responsibilities from the design, including `installSurfaceResourceSession(Object token, SurfaceResourceSessionLifecycle session)`. Operations whose behavior belongs to later units must either delegate to the existing resource-free behavior needed for passive paint or be present as token-aware signatures that later units complete; no extra port methods are allowed.
9. Remove the temporary API-to-frame painter allowlist for `lib/src/api/canvas_surface.dart` in the same unit after the wrapper conversion makes the API file no longer import frame painters.
10. Migrate focused P13 proof naming from `test.flutter_bridge.*` to `test.surface.*` in source-of-truth docs and guardrail/test metadata. Existing `test/flutter_bridge/**` wrappers must either be moved by the behavior unit that adds real assertions or removed after equivalent `test/surface/**` proof exists; duplicate live proof surfaces are forbidden.
11. Replace durable `lib/src/flutter_bridge/` path recognition in guardrails with `lib/src/surface/` where the rule is P13 surface-owned. No production or test guardrail may require `lib/src/flutter_bridge/**` for P13.
12. Register and route these ids through runner-backed or structurally checked guardrail execution: `surface.pointer_samples_normalized_before_runtime`, `surface.interactive_false_pending_line_preserved`, `resources.app_key_only`, `resources.dirty_no_document_revision`, and `resources.mutation_inside_edit_only`.
13. Update owner-DAG import allowances for exactly the selected surface dependency set: contracts/public, contracts/internal, the non-public runtime-surface bridge, frame paint output/binding/painter helper APIs, and concrete `SurfaceResourceSession`. Keep forbidden checks for store, edit, selection, interaction internals, `RuntimeRoot`, root public barrel, legacy package paths, and `lib/src/flutter_bridge/**`.
14. Preserve the resolver ownership rule: surface widget may type the public `CanvasResourceResolver`; surface painters and frame painters may not own typed resolver references.
15. Keep `flutter.surface` mapped to `lib/src/surface/**` and `flutter.surface.drives_runtime_ports` mapped to delegation through `CanvasRuntime`; do not mark unrelated P10/P12 graph statuses complete in this unit.
16. Do not create placeholder focused test files in Unit 0. Unit 0 owns docs/metadata migration to `test.surface.*`; Units 1 through 5 create or migrate each concrete `test/surface/**` file only when that file receives the behavior assertions required by its unit.
17. Run repository-required DCM checks when this unit is implemented. Do not change code solely for hidden `dcm check-dependencies lib` output unless it gives file-level evidence.

Completion Check:

- `rg -n "test\\.flutter_bridge\\.|lib/src/flutter_bridge|flutter_bridge" docs tool test lib` returns no live P13 source-of-truth or guardrail references except historical completed plan/design/research records explicitly labeled historical.
- `lib/src/api/canvas_surface.dart` is wrapper-export only and contains no `class CanvasSurface`, `State<CanvasSurface>`, `CustomPaint`, `canvasRuntimeFrameRootForSurface`, frame painter imports, resource implementation imports, or `RuntimeRoot`.
- `lib/src/surface/canvas_surface_widget.dart` contains the only production `final class CanvasSurface extends StatefulWidget` declaration.
- `CanvasSurface` production code does not call `canvasRuntimeFrameRootForSurface`, and `lib/src/api/canvas_runtime_surface_bridge.dart` returns a surface port rather than `RuntimeRoot`.
- `dart test test/api_contract/public_exports_complete_test.dart test/api_contract/public_facade_wrapper_compatibility_test.dart test/api_contract/public_api_v1_compiles_as_written_test.dart` passes after the API wrapper/surface-owner migration and proves `CanvasSurface` remains exported and constructible from `package:iwb_canvas_engine/iwb_canvas_engine.dart`, `lib/src/api/canvas_surface.dart` exposes no internal declarations, and public v1 examples still compile as written.
- `dart test test/smoke/public_incremental_smoke_test.dart` passes after Unit 0 and proves the migrated root-barrel `CanvasSurface` still pumps `ValueKey<String>('iwb_canvas_surface.paint_host')` and preserves the existing resource-free passive paint path before P13-specific behavior units begin.
- `lib/src/contracts/internal/surface_resource_session_lifecycle.dart` exists with only `ResourceSessionInvalidationSink` inheritance plus `void drop();`, and the runtime-surface port signature uses `SurfaceResourceSessionLifecycle` for `installSurfaceResourceSession`.
- The temporary API-to-frame painter allowlist for `lib/src/api/canvas_surface.dart` is removed from guardrail tooling.
- `dart run tool/guardrails/run.dart --guardrail=surface.pointer_samples_normalized_before_runtime` and `dart run tool/guardrails/run.dart --guardrail=surface.interactive_false_pending_line_preserved` do not exit with unknown-id status 64.
- `dart run tool/guardrails/run.dart --guardrail=resources.app_key_only`, `dart run tool/guardrails/run.dart --guardrail=resources.dirty_no_document_revision`, and `dart run tool/guardrails/run.dart --guardrail=resources.mutation_inside_edit_only` do not exit with unknown-id status 64.
- `dart test test/guardrails/import_boundaries_test.dart test/guardrails/owner_dag_import_boundaries_test.dart` proves the exact allowed surface edges and forbidden surface imports.
- Unit 0 creates no placeholder `test/surface/**` files without behavior assertions; `find test/surface test/flutter_bridge -type f 2>/dev/null | sort` shows only files that either already contain real assertions or remain historical non-P13 compatibility files with no source-of-truth registration.
- `dart run docs/tool/sync_generated_docs.dart --check` and `dart run docs/tool/check_docs.dart` pass after docs/source updates or, if generated output was stale, pass after regeneration.
- `dart analyze` passes after the Unit 0 Dart code changes.
- `dcm analyze .` passes after the Unit 0 Dart code changes.
- `dcm calculate-metrics lib/src/api lib/src/runtime lib/src/surface tool/guardrails tool/architecture_graph test/guardrails test/architecture_graph` passes after Unit 0, with any intentional metric exception represented only by a localized exact suppression and nearby rationale allowed by repository rules.
- If `dcm check-dependencies lib` exposes file-level dependency violations, implementation stops and records the exact owner-level fix before behavior units; if it remains undisclosed, no metric-only or hidden-report refactor is made.

Depends On:

None.

### [x] Unit 1: Single-active attach gate and surface token lifecycle

Owner:

`lib/src/surface/canvas_surface_widget.dart`, `lib/src/api/canvas_runtime_surface_bridge.dart`, `lib/src/api/canvas_runtime.dart`, and `lib/src/runtime/runtime_root.dart`.

Boundary:

Add active surface token behavior to the already-migrated surface owner and runtime-surface bridge from Unit 0. This unit owns attach/detach token state and exact failure ordering only; it does not own API wrapper closure, resource session policy, resolver-backed paint, pointer adapter semantics, or `interactive=false` cleanup beyond exposing token-checked no-op/delegation points needed by later units.

Design Decisions:

`D2`, `D3`, `D10`.

Donors To Use:

- `direct_flutter_pointer_routing`: do not copy routing code yet; make the already-reserved `handlePointer(Object token, CanvasPointerSample sample)` port method stale-token no-op for Unit 4.
- `interaction_pointer_host`: adapt only the active-host identity concept into a private surface `Object` token and runtime active-slot checks; do not copy legacy host facade or listener wiring.
- `interaction_pointer_session`: use only the session-detach/dispose ownership lesson for token detach no-ops; keep pointer session state in interaction.
- Forbidden donor structures: enforce `avoid_scene_controller_facades` and `avoid_interactive_runtime_whole` by keeping the surface port narrow and non-public.

Change:

1. Add a private unique `Object` token per `CanvasSurface` state instance and store active runtime identity, active port, token, and attachment status.
2. Create or migrate `test/surface/single_active_surface_test.dart` with the behavior assertions named in this unit; do not create it as a placeholder.
3. `CanvasSurfaceState.initState` resolves the Unit 0 runtime-surface port and calls `attachSurface(token)` before doing any later unit work. If attach fails, it lets the exact error escape and does not build frames, create sessions, install listeners, or route pointers.
4. `RuntimeRoot` owns the active surface token slot. `attachSurface(Object token)` throws exactly `StateError('CanvasRuntime already has an active CanvasSurface.')` when a different token is active. Reattaching the identical token is idempotent only for the same state instance.
5. `attachSurface(Object token)` must run before session construction, listener registration, frame build, pointer routing, resolver attachment, or resolver calls.
6. `detachSurface(Object token)` clears only state owned by the identical active token and no-ops for stale tokens. It must not clear another active surface.
7. Runtime identity changes in `didUpdateWidget` detach the old active token before attempting the new attach. If new attach rejects, the old runtime is not reattached.
8. `CanvasRuntime.dispose()` clears any active surface token. Session drop behavior is completed in Unit 2; this unit must leave a clear hook for Unit 2 to drop the installed session handle on dispose.
9. The Unit 0 port remains narrow and exposes no extra operations beyond the final design list. Unit 1 may fill token checks for `handleSurfaceInteractiveDisabled`, `handlePointer`, `buildSurfaceMainFrame`, and `buildSurfaceOverlayFrame` as no-op or active-token-required guards for later units, but it must not implement pointer adapter routing, session lifecycle, or resolver-backed paint.

Completion Check:

- `test/surface/single_active_surface_test.dart` proves: first active surface attaches; a second active surface with the same runtime throws exactly `StateError('CanvasRuntime already has an active CanvasSurface.')`; rejected attach produces no session creation, no resolver calls, no pointer route, no frame build, no repaint/listener side effect, and leaves the first active surface usable; after detach another surface can attach; two surfaces with different runtimes mount and paint simultaneously.
- A structural test or guardrail proves `lib/src/surface/**` still does not import `../runtime/runtime_root.dart`, root public barrel, store, edit, selection, interaction internals, or `lib/src/flutter_bridge/**`.
- `dart run tool/architecture_graph/check.dart --phase P13` may still fail before later behavior units only for behavior proof that is not yet implemented; it must not fail because `CanvasSurface` is outside the surface owner or because production surface code obtains `RuntimeRoot`.
- Focused tests for this unit pass when run with `dart test test/surface/single_active_surface_test.dart` and relevant guardrail tests.
- `dart analyze` passes after the Unit 1 Dart code changes.
- `dcm analyze .` passes after the Unit 1 Dart code changes.
- `dcm calculate-metrics lib/src/api lib/src/runtime lib/src/surface test/surface` passes after Unit 1, with any intentional metric exception represented only by a localized exact suppression and nearby rationale allowed by repository rules.

Depends On:

Unit 0.

### [x] Unit 2: SurfaceResourceSession lifecycle and runtime-installed session handle

Owner:

`lib/src/resources/surface_resource_session.dart`, `lib/src/surface/canvas_surface_widget.dart`, `lib/src/api/canvas_runtime_surface_bridge.dart`, `lib/src/runtime/runtime_root.dart`, and `test/surface/surface_resource_session_lifecycle_test.dart`.

Boundary:

Wire one concrete `SurfaceResourceSession` per accepted active surface while keeping resolver/cache/generation/budget/drop policy in resources. Runtime sees only `SurfaceResourceSessionLifecycle`, and surface owns only lifecycle ordering and resolver replacement calls.

Design Decisions:

`D3`, `D4`, `D10`, `D12`.

Donors To Use:

- `scene_render_caches`: adapt only the single-owner lifecycle/reset principle to keep image cache ownership inside `SurfaceResourceSession`; do not copy render cache classes or create a runtime-wide image cache.
- `static_layer_cache`: use only the disposal lifecycle lesson to verify cache/drop behavior; do not add a surface static layer cache unless a frame-owned source already uses it.
- `interaction_pointer_host`: use token identity only to ensure session install/drop applies to the active surface token.
- Forbidden donor structures: `avoid_scene_store_controller_whole` and `avoid_interactive_runtime_whole` prohibit moving descriptor mutation or resolver policy into surface/runtime facades.

Change:

1. Update `SurfaceResourceSession` to implement the Unit 0 `SurfaceResourceSessionLifecycle` contract without changing resolver/cache/generation semantics.
2. Create or migrate `test/surface/surface_resource_session_lifecycle_test.dart` with the behavior assertions named in this unit; do not create it as a placeholder.
3. `CanvasSurfaceState` creates `SurfaceResourceSession(resolver: widget.resourceResolver, mutationGuard: port.resolverMutationGuard)` only after `attachSurface(token)` succeeds.
4. `CanvasSurfaceState` wraps session creation and session installation in one post-attach guarded block with this exact failure projection: if `SurfaceResourceSession(...)` throws before a session instance is assigned, detach the token and rethrow; if `port.installSurfaceResourceSession(token, session)` throws after a session instance exists, call `session.drop()`, detach the token, and rethrow. The session must not be stored as active until install succeeds.
5. `RuntimeRoot` token-guards active session installation and clearing. The installed session handle must be the same handle dirty invalidation uses before public resourceVisual publication.
6. `didUpdateWidget` with the same runtime and changed `resourceResolver` calls `activeSession.replaceResolver(widget.resourceResolver)`; it must not create a second active session or detach the runtime.
7. Detach, dispose, and runtime swap call `drop()` exactly through the active session handle or an idempotent local fallback if runtime dispose already detached the bridge. These paths must not dispose app-owned `ui.Image`.
8. Runtime `dispose()` clears active token and drops the active session handle if present. Later surface detach must not throw only because runtime already disposed or bridge detached.
9. Rejected attach must not create a session object and must not call the resolver.

Completion Check:

- `test/surface/surface_resource_session_lifecycle_test.dart` proves accepted attach creates one session after attach acceptance, rejected attach creates none, post-attach install failure drops the created session and detaches token, resolver swap increments generation and prevents stale result reuse, detach/dispose/runtime swap drop the session/cache without disposing app images, runtime dispose drops the active session, and later surface detach is idempotent.
- A structural rollback proof covers session creation failure without adding a test-only constructor seam: the proof must show the production `SurfaceResourceSession` constructor is creation-infallible for repository-owned purposes because it performs no resolver calls, no mutation-guard calls, no descriptor validation, no I/O, no async work, and no externally supplied callbacks before storing constructor inputs and initializing the private cache. The same source/behavior proof must show the guarded post-attach block encloses both the constructor call and `installSurfaceResourceSession`, so a future constructor change that introduces fallible behavior must also keep token detach on creation failure.
- Resource dirty proof shows dirty target/all invalidation reaches the active installed session before public resourceVisual publication and does not invalidate a detached or stale token session.
- Existing resource tests for sync resolver, resolver swap, dirty invalidation, dropped sessions, app-owned image non-disposal, app-key-only, dirty-no-document-revision, and mutation-inside-edit remain green.
- A structural test proves `SurfaceResourceSessionLifecycle` exposes only invalidation sink plus `drop()` and that the runtime-surface port does not import concrete `SurfaceResourceSession`.
- `dart test test/surface/surface_resource_session_lifecycle_test.dart test/resources/sync_image_resolver_test.dart test/resources/app_owned_image_not_disposed_test.dart` passes.
- `dart analyze` passes after the Unit 2 Dart code changes.
- `dcm analyze .` passes after the Unit 2 Dart code changes.
- `dcm calculate-metrics lib/src/contracts lib/src/resources lib/src/api lib/src/runtime lib/src/surface test/surface test/resources` passes after Unit 2, with any intentional metric exception represented only by a localized exact suppression and nearby rationale allowed by repository rules.

Depends On:

Units 0 and 1.

### [x] Unit 3: Surface paint, image bridge, and painter migration

Owner:

`lib/src/surface/image_bridge.dart`, `lib/src/surface/main_painter.dart`, `lib/src/surface/overlay_painter.dart`, `lib/src/surface/canvas_surface_widget.dart`, runtime-surface frame port methods, frame painter helper APIs, and surface/frame paint tests.

Boundary:

Build and paint immutable frame outputs from the surface without moving frame planning, resource descriptor reads, resolver policy, frame caches, or opacity policy into surface. Main paint may bind image assets through `SurfaceResourceSession`; overlay paint remains resource-free.

Design Decisions:

`D5`, `D6`, `D10`, `D11`, `D12`.

Donors To Use:

- `scene_painter_frame`: adapt only viewport calculation shape, single frame-plan call discipline, and widget paint expectations; do not copy Flutter/node snapshot coupling.
- `scene_render_caches`: adapt only existing cache owner lifecycle expectations by preserving `FrameEngine`/`SurfaceResourceSession` ownership; do not create surface-owned render caches.
- `static_layer_cache`: adapt only existing static background disposal proof through frame owner; do not create a new surface cache unless existing frame implementation already owns it.
- `direct_flutter_pointer_routing`: not used in paint code except preserving paint-host identity needed by pointer host wrapping.
- Forbidden donor structures: `avoid_scene_controller_facades`, `avoid_scene_builder_public_architecture`, and `avoid_scene_codec_whole` prohibit scene facade, builder, or codec shapes in surface paint.

Change:

1. Create `CanvasSurfaceImageBridge` in `lib/src/surface/image_bridge.dart` with `FrameAssetBindingBuilder bindAssets(SurfaceResourceSession session)`. The returned closure calls `PaintAssetBindingService.bind(frame: ..., records: ..., session: session)`.
2. `CanvasSurfaceImageBridge` imports `PaintAssetBindingService`, `FrameAssetBindingBuilder`, and concrete `SurfaceResourceSession`; it must not store or type-own `CanvasResourceResolver`.
3. Move Flutter painter adapter classes to `lib/src/surface/main_painter.dart` and `lib/src/surface/overlay_painter.dart` with primary declarations `MainFramePainter` and `OverlayFramePainter`. They consume `MainFramePaintOutput` and `OverlayFramePaintOutput` respectively.
4. Surface painters delegate record painting to existing frame-owned primitive helper functions. They must not copy frame planning, descriptor reads, resolver calls, cache mutation, live runtime reads, store reads, public document materialization, or ordinary-opacity `Canvas.saveLayer`.
5. Runtime-surface port `buildSurfaceMainFrame` requires active token, builds frame inputs from runtime state, calls `FrameEngine.buildMainFrameWithAssetBindings`, passes through the `FrameAssetBindingBuilder`, and does not import `SurfaceResourceSession`.
6. Runtime-surface port `buildSurfaceOverlayFrame` requires active token, builds overlay frame output, and does not receive resolver/session.
7. Surface build path observes `port.state` through `ValueListenableBuilder`, uses `LayoutBuilder`, derives `paintSize`, passes `Offset.zero & paintSize`, uses `MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0`, builds main and overlay outputs once per build pass, returns `CustomPaint` with `const ValueKey<String>('iwb_canvas_surface.paint_host')`, and uses the surface-owned painters.
8. Empty and resource-free documents must not call resolver. Documents with image records call the app resolver synchronously through the active `SurfaceResourceSession`.
9. Selected-move preview must be reflected in main output; overlay preview variants remain overlay-only.
10. Ordinary element/stroke opacity remains primitive paint alpha; no ordinary opacity path calls `Canvas.saveLayer`. Any future saveLayer-producing effect remains out of scope and requires a new contract.
11. Create or migrate `test/surface/widget_paint_test.dart` and `test/surface/surface_camera_frame_output_test.dart` with the behavior assertions named in this unit; do not create either file as a placeholder.

Completion Check:

- `test/surface/widget_paint_test.dart` proves empty document paint, populated resource-free document paint, image-resource document paint with positive resolver calls, no resolver calls for documents without image records, stable paint host key, selected-move main repaint, overlay-only variants, and resolver repaint after dirty invalidation.
- `test/surface/surface_camera_frame_output_test.dart` proves viewport/DPR/camera-offset frame inputs from the widget path produce expected main/overlay outputs.
- Surface/frame structural tests prove `lib/src/surface/main_painter.dart` and `lib/src/surface/overlay_painter.dart` do not import runtime, store, public API facade, `CanvasResourceResolver`, or resource resolver adapter ownership; they consume immutable frame outputs only.
- Existing no-live-runtime-read painter proof is updated from frame painter paths to surface painter paths and remains green.
- Existing frame opacity/no-saveLayer proof plus a surface painter source/semantic guard proves no ordinary opacity `Canvas.saveLayer` call exists in the surface hot paint path.
- `dart test test/surface/widget_paint_test.dart test/surface/surface_camera_frame_output_test.dart test/frame/no_live_runtime_read_in_painters_test.dart` passes.
- `dart analyze` passes after the Unit 3 Dart code changes.
- `dcm analyze .` passes after the Unit 3 Dart code changes.
- `dcm calculate-metrics lib/src/frame lib/src/runtime lib/src/surface test/surface test/frame` passes after Unit 3, with any intentional metric exception represented only by a localized exact suppression and nearby rationale allowed by repository rules.

Depends On:

Units 0, 1, and 2.

### [x] Unit 4: Flutter pointer adapter routing and finite admission

Owner:

`lib/src/surface/pointer_adapter.dart`, `lib/src/surface/canvas_surface_widget.dart`, runtime-surface pointer port method, and pointer adapter focused tests.

Boundary:

Convert Flutter pointer events to public `CanvasPointerSample` at the surface boundary and route them through the active token to runtime. Do not make surface a gesture recognizer, interaction state owner, world normalizer, cleanup coordinator, or commit owner.

Design Decisions:

`D2`, `D7`, `D10`.

Donors To Use:

- `direct_flutter_pointer_routing`: copy only direct event-to-sample routing shape for down/move/up/cancel; do not copy legacy scene view facade.
- `interaction_pointer_host`: adapt finite admission, active host route, and terminal callback discipline into `CanvasSurfacePointerAdapter`; do not copy legacy Flutter host facade.
- `interaction_pointer_session`: use only to preserve session lifecycle ownership in `InteractionEngine`; surface must not own pointer session state.
- Forbidden donor structures: `avoid_interactive_runtime_whole` and `avoid_scene_controller_facades` prohibit copying legacy callback graphs or controller facades.

Change:

1. Create `final class CanvasSurfacePointerAdapter` in `lib/src/surface/pointer_adapter.dart`.
2. Create or migrate `test/surface/pointer_adapter_finite_normalization_test.dart` with the behavior assertions named in this unit; do not create it as a placeholder.
3. Implement routing with Flutter `Listener`, not `GestureDetector`, `MouseRegion`, gesture recognizers, or synthetic gesture interpretation.
4. When `interactive == false`, the surface must not wrap the paint host in a pointer adapter and no Flutter pointer event may call the runtime port.
5. When `interactive == true`, route exactly these event phases:
   - `PointerDownEvent` -> `CanvasPointerLifecyclePhase.down`
   - `PointerMoveEvent` -> `CanvasPointerLifecyclePhase.move`
   - `PointerUpEvent` -> `CanvasPointerLifecyclePhase.up`
   - `PointerCancelEvent` -> `CanvasPointerLifecyclePhase.cancel`
6. Use `event.pointer` as `pointerId`, `event.localPosition` as view-space `position`, `event.kind` as pointer kind, and `event.timeStamp.inMilliseconds` as `timestampMs` only when non-negative. If timestamp is negative, omit `timestampMs`.
7. Reject non-finite `localPosition.dx` or `.dy` before constructing `CanvasPointerSample` and before calling `port.handlePointer`.
8. Do not transform by camera offset in surface. Runtime/interaction normalization remains the only view-to-world conversion.
9. `port.handlePointer(token, sample)` no-ops for stale tokens and delegates to existing runtime pointer handling for the active token.
10. Do not synthesize missing up/cancel events on rebuild. The only synthetic cleanup route remains `handleSurfaceInteractiveDisabled(token)` in Unit 5.
11. Preserve paint host identity and layout when wrapping with the pointer adapter.

Completion Check:

- `test/surface/pointer_adapter_finite_normalization_test.dart` uses Flutter pointer events and proves finite down/move/up/cancel route to runtime with the exact public phase/pointerId/kind/view-position/timestamp mapping; non-finite events create no sample, no runtime call, no preview, no state tick, no repaint, no edit, and no action.
- The same test proves a Flutter event at local position with a non-zero runtime camera offset produces public committed/preview world facts through interaction normalization, not surface transformation.
- A stale-token test proves callbacks fired after runtime swap/dispose no-op and cannot mutate or clear another active surface.
- A structural guard proves `lib/src/surface/pointer_adapter.dart` uses `Listener` and contains no `GestureDetector`, `MouseRegion`, gesture recognizer routing, interaction internals, or world-normalization code.
- `dart run tool/guardrails/run.dart --guardrail=surface.pointer_samples_normalized_before_runtime` passes and includes both semantic sequence and behavioral seam proof.
- `dart test test/surface/pointer_adapter_finite_normalization_test.dart` passes.
- `dart analyze` passes after the Unit 4 Dart code changes.
- `dcm analyze .` passes after the Unit 4 Dart code changes.
- `dcm calculate-metrics lib/src/api lib/src/runtime lib/src/surface tool/guardrails test/surface test/guardrails` passes after Unit 4, with any intentional metric exception represented only by a localized exact suppression and nearby rationale allowed by repository rules.

Depends On:

Units 0, 1, and 3.

### [x] Unit 5: Interactive false cleanup, runtime swap cleanup, and state isolation

Owner:

`lib/src/surface/canvas_surface_widget.dart`, runtime-surface interactive-disabled port method, `RuntimeRoot` token-checked cleanup, interaction cleanup integration tests, and surface interactive false tests.

Boundary:

Make `interactive=false` a surface routing and cleanup switch only. Surface triggers runtime cleanup for active routed pointers but never clears previews directly, mutates interaction mode, edits documents, changes selection, mutates resources, or replays events.

Design Decisions:

`D3`, `D8`, `D10`.

Donors To Use:

- `interaction_pointer_host`: adapt true-to-false active host cleanup ordering; do not copy legacy host facade.
- `interaction_pointer_session`: adapt session detach/dispose expectations only through existing interaction cleanup; do not move pointer session state to surface.
- `direct_flutter_pointer_routing`: use only to confirm no pointer route occurs while `interactive == false`.
- Forbidden donor structures: `avoid_interactive_runtime_whole` and `avoid_scene_controller_facades` prohibit widget-owned runtime/session managers.

Change:

1. `didUpdateWidget` with same runtime and `interactive` true-to-false calls `port.handleSurfaceInteractiveDisabled(token)` synchronously before the next build can admit more events.
2. Create or migrate `test/surface/interactive_false_pointer_routing_test.dart`, `test/surface/interactive_false_active_session_cancel_test.dart`, `test/surface/interactive_false_pending_line_preserved_test.dart`, and `test/surface/interactive_false_state_isolation_test.dart` with the behavior assertions named in this unit; do not create any of these files as placeholders.
3. `didUpdateWidget` runtime swap first runs old-runtime cleanup when old `interactive` was true, then detaches the old token/session, then attaches the new runtime using Unit 1/2 ordering.
4. `dispose()` calls `port.handleSurfaceInteractiveDisabled(token)` before detach when current `interactive` is true.
5. `port.handleSurfaceInteractiveDisabled(token)` no-ops for stale tokens. For the active token it delegates to runtime/interaction cleanup and publishes public runtime state only when interaction cleanup reports `publicStateNeeded`.
6. When no active routed pointer owns pending line state, pending line start/preview is preserved and no document/selection/resource/mode mutation occurs.
7. When an active routed pointer owns preview/session state, cleanup cancels only that active route and publishes the expected preview state when needed.
8. Toggling `interactive` back to true resumes routing only for future Flutter pointer events; it does not synthesize replay, up, or cancel events.
9. Runtime swap and dispose cleanup must not clear another active surface's token/session or pending state.

Completion Check:

- `test/surface/interactive_false_pointer_routing_test.dart` proves Flutter pointer events while false produce no pointer route, no preview, no document mutation, no selection mutation, no resource mutation, no mode mutation, no action, and still paint the document.
- `test/surface/interactive_false_active_session_cancel_test.dart` uses WidgetTester pointer gestures to prove true-to-false cancels an active routed pointer session through runtime/interaction cleanup and publishes only the expected preview state when cleanup changes preview.
- `test/surface/interactive_false_pending_line_preserved_test.dart` proves non-owned pending line start/line preview is preserved across false update and runtime swap cleanup, with revision and document/selection/resource invariants.
- `test/surface/interactive_false_state_isolation_test.dart` proves active cleanup and no-active cleanup do not mutate runtime mode, committed document, selection, or resources and do not deliver actions.
- `dart run tool/guardrails/run.dart --guardrail=surface.interactive_false_pending_line_preserved` passes and includes semantic ordering plus behavioral seam proof.
- `dart test test/surface/interactive_false_pointer_routing_test.dart test/surface/interactive_false_active_session_cancel_test.dart test/surface/interactive_false_pending_line_preserved_test.dart test/surface/interactive_false_state_isolation_test.dart` passes.
- `dart analyze` passes after the Unit 5 Dart code changes.
- `dcm analyze .` passes after the Unit 5 Dart code changes.
- `dcm calculate-metrics lib/src/api lib/src/runtime lib/src/interaction lib/src/surface tool/guardrails test/surface test/guardrails` passes after Unit 5, with any intentional metric exception represented only by a localized exact suppression and nearby rationale allowed by repository rules.

Depends On:

Units 0, 1, 2, and 4.

### [x] Unit 6: Public smoke, docs, architecture graph, and final P13 verification

Owner:

`test/smoke/public_incremental_smoke_test.dart`, public Flutter consumer harness integration, docs/verification updates, generated docs, architecture graph generated views, guardrail runner integration, and final verification command surface.

Boundary:

Append external public consumer proof and close generated/source-of-truth verification after behavior units. This unit does not add new behavior seams; it proves public root-barrel usability and final repository consistency.

Design Decisions:

`D1`, `D2`, `D3`, `D4`, `D5`, `D6`, `D7`, `D8`, `D9`, `D10`, `D11`, `D12`.

Donors To Use:

- `direct_flutter_pointer_routing`: use in smoke only through real Flutter pointer events, not direct runtime `tools.handlePointer`.
- `scene_painter_frame`: use in smoke only through mounted `CanvasSurface` paint host and visible `CustomPaint`, not internal frame imports.
- `scene_render_caches`: use only indirectly by verifying public repaint/resource behavior does not require public cache access.
- `static_layer_cache`: use only indirectly by verifying ordinary paint remains public-surface compatible; do not expose cache APIs.
- `interaction_pointer_host`: use only through public widget interaction path in smoke.
- `interaction_pointer_session`: use only through public runtime interaction outcomes in smoke.
- Forbidden donor structures: final guardrails must continue rejecting scene controller facade, whole interactive runtime, scene builder public architecture, whole scene codec, and whole scene store controller shapes.

Change:

1. Append exactly one P13 smoke scenario to `test/smoke/public_incremental_smoke_test.dart` after the current P12 eraser/context scenario. Do not replace or weaken earlier smoke steps.
2. Name the appended smoke scenario `public consumer uses CanvasSurface pointer and resource bridge`.
3. The P13 smoke must run through `runFlutterConsumerTest` and import only:
   - `dart:ui` as needed for resolver return type;
   - Flutter widgets/test packages;
   - `package:iwb_canvas_engine/iwb_canvas_engine.dart`.
4. The P13 smoke must not import `package:iwb_canvas_engine/src/...`.
5. Extend the smoke `_surfaceHost` helper only as needed to pass optional `resourceResolver` while preserving `const ValueKey<String>('iwb_canvas_surface.paint_host')`.
6. The P13 smoke must create a runtime with a document containing at least one appKey `CanvasImageResource`, at least one `CanvasImageElement` referencing that resource, and at least one ordinary selectable shape for pointer interactions.
7. The P13 smoke must use a public `CanvasResourceResolver` spy that returns `null`; focused resource tests own app-owned image no-dispose proof.
8. The P13 smoke must assert the existing resource-free surface scenario still produces zero resolver calls.
9. The P13 smoke must assert the new image-resource scenario calls the resolver through `CanvasSurface` paint.
10. The P13 smoke must pump a replacement `resourceResolver` and assert the new resolver is used instead of stale resolver results.
11. The P13 smoke must assert null resolver results produce bounded public behavior without throwing.
12. The P13 smoke must set draw mode/style through public runtime APIs, then use `WidgetTester` Flutter pointer gestures on the `CanvasSurface` paint host rather than direct `runtime.tools.handlePointer`.
13. The P13 smoke must assert that the Flutter gesture creates the expected public preview, action, or document outcome through the public runtime/document/action surface.
14. The P13 smoke must pump `interactive=false`, send a Flutter pointer gesture, and assert no pointer route changes document, preview, actions, selection, mode, or resources.
15. The P13 smoke must exercise pending-line preservation through Flutter pointer events where practical: first tap creates `CanvasPendingLineStartPreview`, then pumping the same surface with `interactive=false` preserves the pending line preview and causes no document/action mutation. If implementation makes this public smoke path impossible, the implementer must stop and cite the exact design/repository contradiction instead of silently falling back to direct runtime pointer calls.
16. The P13 smoke must not include same-runtime second active surface rejection; that direct proof remains in `test/surface/single_active_surface_test.dart`.
17. Update `docs/implementation/p13_flutter_surface.md` to rename focused test paths/ids from `test/flutter_bridge` to `test/surface`, preserve public smoke and guardrail ids, and record the narrow runtime-surface bridge if implementation changes bridge shape.
18. Update `docs/contracts/public_api_v1.md` to preserve constructor compatibility and clarify that the public API wrapper exports the surface-owned implementation.
19. Update `docs/contracts/resources.md` to clarify `SurfaceResourceSessionLifecycle` for runtime invalidation/disposal/drop and preserve concrete `SurfaceResourceSession` ownership under resources with active surface lifecycle under surface/runtime token.
20. Update `docs/contracts/frame_rendering.md` to clarify that Flutter `CustomPainter` adapters are surface-owned consumers of frame-owned outputs while frame keeps capture/planning/cache/asset binding and `PaintAssetBindingService` remains the concrete `SurfaceResourceSession` asset-binding receiver.
21. Update `docs/contracts/interaction_engine.md` only for current wording: replace remaining durable "Flutter bridge" raw routing wording with "surface pointer adapter" where it describes raw Flutter routing ownership; do not rewrite behavior.
22. Update `docs/contracts/cache_policy.md` only as needed to ensure P13 tests cite the existing `ImageResolveCache` row; do not change cache row shape unless implementation genuinely changes the owning source.
23. Update `docs/verification/tests.md`, `docs/verification/guardrails.md`, `docs/verification/guardrail_design_patterns.md`, and `docs/verification/release_gates.md` to register new/migrated `test.surface.*` ids, P13 guardrail proof, public smoke proof, and release-gate expectations.
24. Update `docs/architecture/02_package_boundaries.md`, `docs/architecture/architecture_graph.yaml`, durable P13 diagrams listed in `docs/implementation/p13_flutter_surface.md` when actual implementation changes their bridge/file naming, generated docs, and generated graph views to reflect final P13 behavior and ownership. Do not treat `.design/` diagrams as durable replacements.
25. Run final graph checks for P13. If P13 graph checks report unrelated P10/P12 status drift that was not caused by this step, stop and report the repository contradiction instead of repairing it inside P13.
26. Run all repository-required checks for Dart, DCM, focused tests, guardrails, architecture graph, and docs.
27. After implementation, focused verification, final graph/docs/guardrail checks, unit review, and final P13 proof all pass, update roadmap status in the same implementation change: mark Step 51 checked in `PLAN.md` and mark every completed `### [x] Unit N` checkbox in `plan/step_51_p13_flutter_surface.md`. Do not mark these checkboxes before proof exists.

Completion Check:

- `test/smoke/public_incremental_smoke_test.dart` appends the scenario named `public consumer uses CanvasSurface pointer and resource bridge` after the P12 eraser/context scenario.
- The appended smoke imports only `dart:ui` as needed, Flutter widget/test packages, and `package:iwb_canvas_engine/iwb_canvas_engine.dart`; it contains no `package:iwb_canvas_engine/src/...` import.
- The appended smoke pumps `CanvasSurface` with `const ValueKey<String>('iwb_canvas_surface.paint_host')`, a document with appKey image resource, image element, and ordinary selectable shape, and a public null-returning `CanvasResourceResolver` spy.
- The appended smoke proves zero resolver calls for the existing resource-free paint scenario, positive resolver calls through surface paint for the P13 image-resource scenario, replacement `resourceResolver` use instead of stale results, and bounded null-result behavior without throwing.
- The appended smoke uses public runtime APIs to set draw mode/style and uses `WidgetTester` Flutter pointer gestures on the `CanvasSurface` paint host, not `runtime.tools.handlePointer`, for P13-specific routing proof.
- The appended smoke proves the Flutter gesture creates the expected public preview/action/document outcome, proves `interactive=false` Flutter gestures do not change document, preview, actions, selection, mode, or resources, and proves pending-line preservation through Flutter pointer events where practical or stops on a cited design/repository contradiction.
- The appended smoke does not include same-runtime second active surface rejection.
- `dart test test/smoke/public_incremental_smoke_test.dart` passes.
- `docs/implementation/p13_flutter_surface.md`, `docs/contracts/public_api_v1.md`, `docs/contracts/resources.md`, `docs/contracts/frame_rendering.md`, `docs/contracts/interaction_engine.md`, `docs/contracts/cache_policy.md`, `docs/verification/tests.md`, `docs/verification/guardrails.md`, `docs/verification/guardrail_design_patterns.md`, `docs/verification/release_gates.md`, `docs/architecture/02_package_boundaries.md`, `docs/architecture/architecture_graph.yaml`, and any changed durable P13 diagrams reflect the final P13 source-of-truth updates required by the design.
- `dart analyze` passes.
- `dcm analyze .` passes.
- `dcm calculate-metrics lib/src/api lib/src/contracts lib/src/resources lib/src/runtime lib/src/frame lib/src/interaction lib/src/surface tool/guardrails tool/architecture_graph test/surface test/smoke test/resources test/frame test/guardrails test/architecture_graph` passes or reports only justified localized exceptions; no metric-only split/wrapper refactor is made.
- Focused tests for all P13 behavior pass: `dart test test/surface test/resources test/frame`.
- Required guardrails pass for the named P13/resource ids and import boundaries.
- `dart run tool/architecture_graph/check.dart --phase P13` passes.
- `dart run tool/architecture_graph/generate_views.dart --phase P13 --check` passes.
- `dart run docs/tool/sync_generated_docs.dart --check` passes.
- `dart run docs/tool/check_docs.dart` passes.
- `dart test test/api_contract/public_exports_complete_test.dart test/api_contract/public_facade_wrapper_compatibility_test.dart test/api_contract/public_api_v1_compiles_as_written_test.dart test/smoke/public_incremental_smoke_test.dart` passes and proves no constructor, root barrel, facade wrapper, or public smoke compatibility break after final P13 behavior.
- The final implementation diff marks `PLAN.md` Step 51 checked and marks each completed `### [x] Unit N` checkbox in `plan/step_51_p13_flutter_surface.md` only after the required implementation, verification, review, and proof evidence exists.

Depends On:

Units 0 through 5.
