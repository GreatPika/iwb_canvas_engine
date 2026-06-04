# Change Contract

## Goal

Add seamless inline text editing as an official public integration path: applications can mount `CanvasTextEditingOverlay` beside `CanvasSurface`, inspect or start runtime-owned text edit sessions from context-action requests, rely on frame-measured geometry for paint/hit/edit bounds, and commit through the existing guarded text command path without app-owned visibility mutation or duplicate overlay text measurement.

## Source Inputs

- Design: `.design/2026-06-04-inline-text-editing-contract.md`
- Research: `.research/2026-06-04-inline-text-editing-contract.md`
- Phase: none
- PLAN: `PLAN.md`
- Other: `docs/implementation/p13_flutter_surface.md`, `docs/contracts/public_api_v1.md`, `docs/contracts/interaction_engine.md`, `docs/contracts/frame_rendering.md`, `docs/contracts/geometry.md`, `docs/contracts/cache_policy.md`, `docs/architecture/01_runtime_ownership.md`, `docs/architecture/02_package_boundaries.md`, `docs/architecture/architecture_graph.yaml`, `docs/verification/guardrails.md`, `docs/verification/tests.md`, `docs/_registry/public_api_v1.yaml`, `tool/guardrails/src/guardrail_registry.dart`, `tool/guardrails/src/guardrail_executor.dart`

## Classification

Profile: BEHAVIOR_CHANGE

Obligations: BUG_FIX, SEAM_MIGRATION, PUBLIC_API_CHANGE

## Decision Trace

| Source decision | Contract location | Execution unit / proof surface |
|---|---|---|
| `D1` Double tap remains a context-action trigger; text editing start is app/config-owned. | `Boundaries.In Scope`, `Boundaries.Compatibility`, Unit 3, Unit 5 | Interaction/runtime tests assert context request delivery alone leaves `activeSession` null; surface tests assert auto-start only when `CanvasTextEditingOverlay.inlineEditOnDoubleTap` is enabled. |
| `D2` Runtime owns text edit candidates, active session state, guard identity, live text geometry, commit, dismiss, and cleanup. | `Boundaries.Owner`, Unit 3 | Runtime lifecycle tests cover candidate lookup, start, live update, commit, dismiss, stale/load/dispose cleanup, read-only dismissal, and public `activeSession` publication. |
| `D3` `EditableText` lives only in the Flutter surface integration helper. | `Boundaries.Dependency/import direction`, Unit 5, Unit 7 | Surface widget tests prove the official overlay uses `EditableText`; structural guardrail `surface.editable_text_surface_only` fails if core owners import it. |
| `D4` Frame owns the single measured text layout source and cache; geometry and runtime live-edit geometry consume immutable measured metrics through a required typed internal port and no longer compute text metrics. | `Boundaries.Source of Truth`, Unit 1, Unit 3, Unit 7 | Frame/geometry/runtime numeric tests prove render paint, paint bounds, hit bounds, selection bounds, edit bounds, live edit geometry, and overlay placement share one measured layout; structural guardrail `text.single_measured_layout_source` fails on formula-based text bounds. |
| `D5` Active editing hides original text through runtime/frame paint suppression, not document visibility mutation. | `Boundaries.State/data ownership`, Unit 4, Unit 6 | Frame output tests prove active text records and selection decoration are absent; runtime/example tests assert document revision and `CanvasTextElement.isVisible` remain unchanged. |
| `D6` Session commit delegates to existing guarded `commitTextEdit`/`EditKernel` path and stale commit rejection never mutates the document. | `Temporal Surface Closure`, `All-Or-Nothing Failure Boundary`, Unit 3, Unit 4 | Runtime/interaction tests inspect document text, action stream, request facts, and active session state for success, no-op, stale, and validation failures; Unit 4 suppression tests inspect paint restoration after those exits. |
| `D7` Official overlay is replaceable; custom overlays consume session geometry/style and do not calculate bounds. | `Boundaries.Compatibility`, Unit 2, Unit 5, Unit 6 | Public smoke/custom overlay test imports the root barrel and builds from `CanvasTextEditingPort.activeSession`, session `geometry`, and session `style` without app geometry helpers. |
| `D8` Runtime enforces single-active admission and read-only policy for official and custom overlays. | `Temporal Surface Closure`, Unit 3, Unit 5 | Runtime tests prove conflicting start returns null without replacement/consumption/mutation and `setReadOnly(true)` dismisses active editing without commit; overlay tests observe the same port policy. |
| Design public symbol constraint: export exactly `CanvasTextEditSession`, `CanvasTextEditGeometry`, `CanvasTextEditStyle`, `CanvasTextEditingPort`, and `CanvasTextEditingOverlay` for this feature. | `Boundaries.In Scope`, `Boundaries.Compatibility`, Unit 2, Unit 5 | Unit 2 declares/exports the four non-widget public contract names and no candidate-token type; Unit 5 declares/exports `CanvasTextEditingOverlay` and final API/registry proof sees exactly the five feature names. |
| Design sequencing: frame-owned measured layout precedes public overlay proof; example migration and duplicate-measurement retirement happen after official overlay proof. | `Boundaries.Order Constraints`, Units 1 through 7 | Unit dependencies require measured layout first, public/runtime port second, suppression third, overlay fourth, example migration fifth, and docs/guardrails after durable behavior exists. |

## Evidence

- `.design/2026-06-04-inline-text-editing-contract.md:13` / disposition: design is `READY_FOR_CONTRACT` -> write a full step contract, not a blocker.
- `.design/2026-06-04-inline-text-editing-contract.md:17` / product outcome: apps mount an official overlay beside `CanvasSurface` while double tap remains a context-action request -> scope must cover public overlay integration and app/config-owned start policy.
- `.design/2026-06-04-inline-text-editing-contract.md:32` / non-goal: `EditableText`, focus, IME, cursor, and Flutter lifecycle must not enter core runtime/interaction/frame/geometry/store owners -> surface owns the widget helper and guardrails must enforce import direction.
- `.design/2026-06-04-inline-text-editing-contract.md:35` / non-goal: original canvas text must not be hidden by mutating `CanvasTextElement.isVisible` -> frame/runtime suppression is required.
- `.design/2026-06-04-inline-text-editing-contract.md:41` / classification: selected profile is `BEHAVIOR_CHANGE` -> user-visible editing behavior and public integration proof are required.
- `.design/2026-06-04-inline-text-editing-contract.md:42` / obligations: `BUG_FIX`, `SEAM_MIGRATION`, and `PUBLIC_API_CHANGE` are locked -> execution units must cover layout mismatch, seam migration, and public export/source-of-truth updates.
- `.design/2026-06-04-inline-text-editing-contract.md:162` / selected form candidate: runtime owns sessions, frame/geometry share one measured layout owner, and surface provides `CanvasTextEditingOverlay` -> owner split is fixed.
- `.design/2026-06-04-inline-text-editing-contract.md:186` / selected form: Candidate B is chosen -> do not redesign as an app-only patch or core-owned automatic editor.
- `.design/2026-06-04-inline-text-editing-contract.md:192` / owner table: public contract declarations live under `lib/src/contracts/public/**` with API wrapper exports -> Unit 2 owns public declarations and exports.
- `.design/2026-06-04-inline-text-editing-contract.md:193` / owner table: runtime plus existing request registry/command path owns candidates, active session state, commit, dismiss, and cleanup -> Unit 3 owns runtime behavior.
- `.design/2026-06-04-inline-text-editing-contract.md:194` / owner table: frame owns measured layout and geometry consumes immutable measured metrics -> Unit 1 owns layout singularity and geometry migration.
- `.design/2026-06-04-inline-text-editing-contract.md:195` / owner table: surface owns `CanvasTextEditingOverlay` with `EditableText` -> Unit 5 owns Flutter integration.
- `.design/2026-06-04-inline-text-editing-contract.md:202` / API sketch: `CanvasTextEditGeometry` fields include paint/edit bounds, transform, and max width -> Unit 2 public API must expose geometry sufficient for custom overlays.
- `.design/2026-06-04-inline-text-editing-contract.md:216` / API sketch: `CanvasTextEditStyle` fields mirror text style inputs -> Unit 2 and Unit 5 must avoid app style reconstruction.
- `.design/2026-06-04-inline-text-editing-contract.md:240` / API sketch: `CanvasTextEditSession` carries request/element guard facts, initial/live text, geometry, style, active/stale state, update, commit, and dismiss -> Unit 3 must implement session lifecycle around these facts.
- `.design/2026-06-04-inline-text-editing-contract.md:260` / API sketch: `CanvasTextEditingPort` exposes `activeSession`, `readOnly`, candidate lookup, start, read-only, and dismiss methods -> Unit 2 and Unit 3 must expose and back this port.
- `.design/2026-06-04-inline-text-editing-contract.md:277` / API sketch: `CanvasTextEditingOverlay` is a `StatefulWidget` with runtime, auto-start, max-height, cursor, selection, and controls hooks -> Unit 5 must lock these integration knobs.
- `.design/2026-06-04-inline-text-editing-contract.md:297` / candidate policy: candidate lookup must not suppress paint, take focus, consume request, mutate document, or publish `activeSession` -> Unit 3 must prove candidate lookup is observation-only.
- `.design/2026-06-04-inline-text-editing-contract.md:299` / single-active policy: conflicting starts return null without replacement, request consumption, suppression, or mutation -> Unit 3 must prove no implicit dismiss-and-replace.
- `.design/2026-06-04-inline-text-editing-contract.md:314` / suppression state: starting a session does not edit the document and frame planning receives transient paint suppression input -> Unit 4 owns suppression before painter consumption.
- `.design/2026-06-04-inline-text-editing-contract.md:318` / suppression rules: suppression must match guard facts and exclude original text record/selection decoration without removing hit/context spatial membership -> Unit 4 must test all affected frame outputs and spatial compatibility.
- `.design/2026-06-04-inline-text-editing-contract.md:329` / shared layout: Frame is sole measured text layout owner and may expose immutable metrics through an internal port -> Unit 1 must keep calculation/cache frame-owned.
- `.design/2026-06-04-inline-text-editing-contract.md:331` / geometry rule: text elements must stop calculating dimensions from text length and consume measured metrics instead -> Unit 1 must retire `_textBounds` formula for text.
- `.design/2026-06-04-inline-text-editing-contract.md:346` / invariant: render paint, paint bounds, selection bounds, hit bounds, edit bounds, and overlay placement derive from one measured layout result -> Units 1 and 5 need direct numeric proof, not screenshots alone.
- `.design/2026-06-04-inline-text-editing-contract.md:354` / negative proof: old formula, duplicate overlay `TextPainter`, and style divergence must fail structural tests -> Unit 7 owns guardrail implementation.
- `.design/2026-06-04-inline-text-editing-contract.md:358` / multiline policy: live text updates recompute edit bounds and overlay grows by default, enabling internal scroll only with `maxEditorHeight` -> Unit 5 must prove growth and optional scroll policy.
- `.design/2026-06-04-inline-text-editing-contract.md:364` / read-only policy: runtime enforces read-only for official and custom overlays and dismisses active edit without commit when enabled -> Unit 3 owns policy, Unit 5 observes it.
- `.design/2026-06-04-inline-text-editing-contract.md:381` / decision D1: start policy belongs to app/config after context request delivery -> Unit 3 and Unit 5 proof must distinguish request delivery from edit start.
- `.design/2026-06-04-inline-text-editing-contract.md:382` / decision D2: runtime session ownership is locked -> Unit 3 owns session behavior.
- `.design/2026-06-04-inline-text-editing-contract.md:383` / decision D3: `EditableText` belongs only to surface helper -> Unit 5 and Unit 7 enforce dependency direction.
- `.design/2026-06-04-inline-text-editing-contract.md:384` / decision D4: frame owns measured layout and geometry consumes immutable metrics -> Unit 1 owns source-of-truth migration.
- `.design/2026-06-04-inline-text-editing-contract.md:385` / decision D5: active editing suppresses original text via runtime/frame, not visibility mutation -> Unit 4 and Unit 6 own retirement of the old example behavior.
- `.design/2026-06-04-inline-text-editing-contract.md:386` / decision D6: commit delegates to existing guarded command path -> Unit 3 must not create a second commit path.
- `.design/2026-06-04-inline-text-editing-contract.md:387` / decision D7: custom overlays consume session geometry/style -> Unit 5 and public smoke prove replacement path.
- `.design/2026-06-04-inline-text-editing-contract.md:388` / decision D8: read-only and single-active policy are runtime-enforced -> Unit 3 must prove official/custom overlays cannot bypass policy.
- `.design/2026-06-04-inline-text-editing-contract.md:508` / source-of-truth impact: public API docs must add the new names and replace the current "engine does not store active text-input session" statement -> Unit 7 owns docs update.
- `.design/2026-06-04-inline-text-editing-contract.md:516` / guardrail impact: `text.single_measured_layout_source`, `text.no_overlay_textpainter_measurement`, and `surface.editable_text_surface_only` are mandatory guardrails -> Unit 7 owns runner-backed checks.
- `.design/2026-06-04-inline-text-editing-contract.md:521` / verification source-of-truth: `docs/verification/tests.md` must add focused proof ids for layout equality, overlay measurement exclusion, and surface-only `EditableText` imports -> Unit 7 owns verification inventory updates.
- `.design/2026-06-04-inline-text-editing-contract.md:528` / verification impact: proof spans geometry, frame, interaction, runtime, surface, API contract, smoke, example, structural guardrails, docs, and generated outputs -> units must not rely on one broad smoke.
- `.design/2026-06-04-inline-text-editing-contract.md:545` / verification strategy: frame-owned layout metrics and geometry/frame equality precede editing UI -> Unit 1 must land before overlay implementation.
- `.design/2026-06-04-inline-text-editing-contract.md:556` / handoff: required profile is `BEHAVIOR_CHANGE` -> classification is preserved.
- `.design/2026-06-04-inline-text-editing-contract.md:557` / handoff: required obligations are `BUG_FIX`, `SEAM_MIGRATION`, and `PUBLIC_API_CHANGE` -> classification is preserved.
- `.design/2026-06-04-inline-text-editing-contract.md:560` / constraints: no visibility mutation, no automatic double-tap edit, no implicit dismiss-and-replace, runtime read-only, no `EditableText` outside surface helper, commit through guarded command path, stale rejection restores paint without mutation -> boundaries and completion checks must preserve these constraints.
- `.research/2026-06-04-inline-text-editing-contract.md:13` / current state: rendered text layout and geometry bounds have two separate sources -> Unit 1 must migrate text bounds to frame-owned measured layout before exposing edit geometry.
- `.research/2026-06-04-inline-text-editing-contract.md:15` / current state: double tap emits a context request and the app chooses what to do -> Unit 3 must preserve context-action behavior.
- `.research/2026-06-04-inline-text-editing-contract.md:17` / current state: example overlay positions from app-owned bounds and remeasures height with a separate `TextPainter` -> Unit 5 and Unit 6 must retire duplicate app measurement.
- `lib/src/frame/render_family_caches.dart:104` / current frame layout: production text render constructs a `TextPainter` -> Unit 1 can extend the existing frame text layout owner rather than adding a second owner.
- `lib/src/frame/render_family_caches.dart:120` / current frame layout: text layout uses `layout(maxWidth: row.maxWidth ?? double.infinity)` -> Unit 1 must preserve max-width semantics.
- `lib/src/frame/main_frame_record_painter.dart:140` / paint path: text paint reads cached `TextPainter` -> Unit 1 must keep rendering tied to the shared measured layout result.
- `lib/src/frame/main_frame_record_painter.dart:150` / paint path: current local width comes from `painter.width` -> Unit 1 must align geometry and edit bounds with actual measured paint width.
- `lib/src/geometry/geometry_policy.dart:25` / geometry owner: `GeometryPolicy.boundsFor` owns bounds derivation -> Unit 1 must keep generic bounds assembly in geometry while removing text metric calculation from geometry.
- `lib/src/geometry/geometry_policy.dart:328` / current formula: `_textBounds` computes text dimensions from text length/font size/max width/line height -> Unit 1 and Unit 7 must retire or make this unreachable for text elements.
- `lib/src/geometry/spatial_entry.dart:41` / spatial paint membership: paint uses `paintBoundsWorld` -> Unit 1 measured bounds must feed paint admission.
- `lib/src/geometry/spatial_entry.dart:65` / spatial hit membership: hit uses `hitBoundsWorld` -> Unit 1 measured bounds must feed hit candidates.
- `lib/src/geometry/spatial_entry.dart:86` / spatial context membership: context uses hit bounds -> Unit 1 measured bounds must feed context-action target lookup.
- `lib/src/frame/render_element_record.dart:151` / render record boundary: records are built from `GeometryPolicy.boundsFor` -> Unit 1 must keep frame records consuming one geometry handoff.
- `lib/src/frame/render_element_record.dart:239` / text rows: text render rows carry text layout fields -> Unit 1 and Unit 3 can derive layout keys/style from committed/live row facts.
- `lib/src/frame/frame_cache.dart:193` / cache key: `TextLayoutCacheKey` includes text, style, direction, max width, and line height -> Unit 1 should reuse one cache key for render/edit geometry.
- `lib/src/frame/frame_cache.dart:295` / cache entry: text layout cache stores a `TextPainter` -> Unit 1 can extend cache entries with immutable metrics.
- `docs/contracts/cache_policy.md:44` / cache ownership: `TextLayoutCache` is owned by Frame -> Unit 1 source of truth is Frame, not a shared geometry/frame calculator.
- `lib/src/contracts/public/canvas_element.dart:138` / public text element: text element declaration exists -> Unit 2 can expose session text/style from public element facts.
- `lib/src/contracts/public/canvas_element.dart:203` / public fields: text, font size, color, align, direction, bold, italic, underline, font family, max width, and line height are public -> Unit 2 `CanvasTextEditStyle` must preserve these fields.
- `lib/src/contracts/public/canvas_element.dart:164` / text validation: construction validates max text length -> Unit 3 commit must reuse existing validation order through command guard path.
- `docs/contracts/public_api_v1.md:88` / public registry contract: root barrel exports the names listed in `docs/_registry/public_api_v1.yaml` -> Unit 2 and Unit 7 must update registry/docs together.
- `docs/contracts/public_api_v1.md:505` / surface API: `CanvasSurface` is a public `StatefulWidget` -> Unit 5 can add adjacent overlay instead of changing `CanvasSurface` into an editor owner.
- `docs/contracts/public_api_v1.md:538` / surface interactivity: `interactive=false` disables pointer routing only -> Unit 3 read-only policy must be a separate text editing port policy.
- `docs/contracts/public_api_v1.md:1493` / command boundary: command mutations go through `EditKernel` with rollback/stale/dispose checks -> Unit 3 must delegate commit instead of mutating from overlay.
- `docs/contracts/public_api_v1.md:1503` / stale guard: `commitTextEdit` rejects stale live request ids on missing/generation/revision/family changes -> Unit 3 must preserve stale protection for sessions.
- `docs/contracts/public_api_v1.md:1512` / validation order: `commitTextEdit` validates new text before request consumption and mutation -> Unit 3 completion must prove validation order.
- `docs/contracts/public_api_v1.md:1518` / atomic install: changed text commits run through `EditKernel` and emit after atomic install -> `All-Or-Nothing Failure Boundary` remains the existing command path.
- `docs/contracts/public_api_v1.md:2359` / context request event: accepted context targets emit one async `CanvasContextActionRequested` -> Unit 3 must preserve this event as the double-tap surface.
- `docs/contracts/public_api_v1.md:2367` / app decision: app decides menu versus text editor for text targets -> Unit 3 and Unit 5 must not make runtime double tap unconditional edit.
- `docs/contracts/public_api_v1.md:2370` / hide policy: app overlay may visually cover/hide but must not mutate target element to hide it -> Unit 4 and Unit 6 retire visibility mutation.
- `docs/contracts/public_api_v1.md:2375` / request commit: request-originated changes commit through `CanvasCommandPort.commitTextEdit` -> Unit 3 session commit is a thin guarded facade.
- `docs/contracts/public_api_v1.md:2381` / programmatic edit compatibility: direct `CanvasEdit.updateElement(CanvasTextElementUpdate)` remains available -> inline editing port must not replace non-request programmatic edits.
- `docs/contracts/public_api_v1.md:2386` / current docs: engine currently says it does not store active text-input session -> Unit 7 must update source-of-truth docs because this contract changes ownership.
- `docs/contracts/interaction_engine.md:383` / request registry: context request emission records live guard facts in `InteractionRequestRegistry` -> Unit 3 starts sessions from live request ids.
- `docs/contracts/interaction_engine.md:397` / current registry boundary: registry is not an active text-input session -> Unit 3 must add a separate runtime session owner rather than overloading request registry.
- `lib/src/contracts/public/canvas_runtime.dart:183` / public command seam: `CanvasCommandPort` owns command mutations -> Unit 3 keeps commit at the command boundary.
- `lib/src/contracts/public/canvas_runtime.dart:186` / command API: `commitTextEdit` accepts request id and new text -> Unit 3 session commit can delegate without a new mutation primitive.
- `lib/src/api/canvas_runtime.dart:49` / runtime event: public runtime exposes `contextActionRequests` -> Unit 5 official overlay can observe double-tap requests when auto-start is enabled.
- `lib/src/api/canvas_runtime.dart:54` / runtime dispose: dispose delegates to root and detaches bridges -> Unit 3 clears active sessions on dispose.
- `lib/src/api/canvas_surface.dart:1` / surface facade: surface API facade exports surface styles and widget -> Unit 5 exports `CanvasTextEditingOverlay` from the surface API path.
- `lib/iwb_canvas_engine.dart:15` / root barrel: runtime API is exported from root -> Unit 2 exposes `CanvasRuntime.textEditing` to public consumers.
- `lib/iwb_canvas_engine.dart:16` / root barrel: surface API is exported from root -> Unit 5 exposes `CanvasTextEditingOverlay` to public consumers.
- `docs/_registry/public_api_v1.yaml:1` / registry: machine-readable inventory owns Public API v1 exported-name contract -> Unit 2 adds the four non-widget contract names and Unit 5 adds the widget name when `CanvasTextEditingOverlay` exists.
- `docs/verification/guardrails.md:106` / guardrails: guardrails are blocking executable rules -> Unit 7 must add runner-backed structural proof instead of prose-only guidance.
- `tool/guardrails/src/guardrail_registry.dart:1` / guardrail registry: registry owns guardrail ids/suites -> Unit 7 must add new text/surface guardrail ids.
- `tool/guardrails/src/guardrail_executor.dart:77` / guardrail routing: executor maps guardrail ids to proof routes -> Unit 7 must add executable routes.
- `lib/src/api/canvas_runtime_surface_bridge.dart:29` / bridge shape: surface uses a narrow runtime-to-surface bridge -> Unit 5 may add a narrow text editing bridge without exposing `RuntimeRoot`.
- `lib/src/surface/canvas_surface_widget.dart:14` / surface owner: `CanvasSurface` implementation lives under `lib/src/surface/**` -> Unit 5 places overlay implementation under surface, not core.
- `lib/src/surface/main_painter.dart:59` / painter boundary: painter consumes immutable frame output -> Unit 4 must suppress active edit text before painter consumption.
- `docs/architecture/01_runtime_ownership.md:63` / interaction owner: `InteractionEngine` owns request guard facts but must not store Flutter editor state -> Unit 3 keeps guard facts in interaction and session state in runtime.
- `docs/architecture/01_runtime_ownership.md:71` / runtime owner: `RuntimeRoot` owns public runtime state publication -> Unit 3 publishes active session state from runtime.
- `docs/architecture/02_package_boundaries.md:184` / public package boundary: root barrel exports only API facades, public declarations live under contracts/public -> Unit 2 file placement and exports must follow this pattern.
- `docs/architecture/02_package_boundaries.md:248` / test placement: tests mirror production ownership folders -> Unit tests should land under geometry, frame, interaction, runtime, surface, API contract, smoke, and example areas.
- `docs/contracts/frame_rendering.md:125` / painter isolation: painters do not live-read runtime -> Unit 4 cannot check active edit state inside `CustomPainter.paint`.
- `docs/contracts/frame_rendering.md:145` / frame facade: `FrameEngine` orchestrates painter input assembly -> Unit 4 suppression belongs in frame planning/output.
- `docs/contracts/geometry.md:62` / context eligibility: context-action eligibility is separate from selection hit eligibility -> Unit 3 preserves context actions while edit start remains app/config-owned.
- `docs/contracts/geometry.md:94` / text hit: text hit uses local bounds -> Unit 1 must make local text bounds measured, not formula-based.
- `docs/contracts/geometry.md:139` / paint admission: invisible elements are not painted through paint admission -> Unit 4 must add active-edit suppression distinct from `isVisible`.
- `docs/architecture/architecture_graph.yaml:79` / graph phase: P13 is the Flutter surface phase -> architecture graph checks for the public surface overlay use P13 when graph files or generated graph views change.
- `docs/architecture/architecture_graph.yaml:482` / graph owner: `flutter.surface` is the surface owner for Flutter widget integration -> `CanvasTextEditingOverlay` graph changes belong to P13 surface checks rather than an unresolved phase.
- `example/lib/src/canvas_example_view_model.dart:625` / current example: example starts text editing directly from every context request -> Unit 6 migrates default behavior to configurable official overlay or public custom-port path.
- `example/lib/src/canvas_example_view_model.dart:642` / current example: example updates document visibility to hide text -> Unit 6 must remove this behavior.
- `example/lib/src/canvas_text_edit_overlay.dart:10` / current overlay: text overlay is example-owned -> Unit 5 moves official helper to public surface layer.
- `example/lib/src/canvas_text_edit_overlay.dart:63` / current placement: overlay computes view position from target bounds and camera offset -> Unit 5 must use session geometry/transform instead.
- `example/lib/src/canvas_text_edit_overlay.dart:154` / duplicate measurement: overlay uses a separate `TextPainter` for editor height -> Unit 5, Unit 6, and Unit 7 must forbid duplicate overlay measurement.
- `test/interaction/fixtures/text_edit_stale_commit_guard_fixture.dart:53` / existing proof: stale text edit requests are already tested -> Unit 3 should extend this proof surface rather than invent a second stale guard.
- `test/interaction/fixtures/text_edit_stale_commit_guard_fixture.dart:191` / no-op behavior: same-text commits retire the request privately -> Unit 3 preserves no-op session commit behavior.
- `test/interaction/fixtures/text_edit_stale_commit_guard_fixture.dart:234` / changed commit: changed text commit publishes an action -> Unit 3 preserves existing action semantics.
- `test/interaction/fixtures/text_edit_stale_commit_guard_fixture.dart:328` / validation order: validation happens before request consumption -> Unit 3 preserves validation order.
- `example/test/canvas_example_screen_test.dart:439` / current proof: multiline overlay tests exist only in example -> Unit 5 moves proof to public surface/runtime tests.

## Boundaries

Owner:

Frame owns measured text layout calculation/cache and immutable local measured layout outputs: painter/equivalent render primitive, local paint/hit/selection/edit metrics, text style values, and line/box metrics. A required internal measured-text-layout port exposes this owner-owned measurement to geometry and runtime live-edit geometry without letting either owner construct a second text measurer or import concrete frame cache state. Geometry owns generic bounds assembly, hit padding, transform application, world paint/hit/context/edit bounds, and spatial/hit/context bounds derived from those measured local text metrics, but does not compute text dimensions. Runtime owns `CanvasTextEditingPort`, active text edit session state, candidate admission, read-only policy, live text geometry publication through the required measured-layout port, commit/dismiss, suppression admission token, and cleanup. `InteractionRequestRegistry` remains the request guard fact owner. Public contracts/API facades own the public contract names and root-barrel export surface. Surface owns `CanvasTextEditingOverlay`, `EditableText`, focus/cursor/selection controls, and overlay widget lifecycle. Example owns demo app integration only. Guardrail tooling and docs own durable enforcement/source-of-truth updates. `PLAN.md` and this file own planning state only.

In Scope:

Create and export `CanvasTextEditSession`, `CanvasTextEditGeometry`, `CanvasTextEditStyle`, `CanvasTextEditingPort`, and `CanvasTextEditingOverlay`. Expose `CanvasRuntime.textEditing`. Add an inactive candidate state through `sessionCandidateFor`/`startFromContextAction` without adding a public candidate-token type. Use one frame-owned measured local layout result plus geometry-owned bounds assembly for text render paint, paint bounds, hit bounds, context bounds, selection bounds, edit bounds, live edit geometry, and overlay placement. Retire formula-based text bounds for text elements and duplicate overlay `TextPainter` measurement. Preserve double tap as `CanvasContextActionRequested`; official overlay may auto-start only when configured. Add runtime single-active and read-only policy. Suppress original active-edit text in frame output without mutating `CanvasTextElement.isVisible` or removing hit/context membership. Implement `CanvasTextEditingOverlay` with `EditableText`, multiline growth, optional max-height scroll, cursor/selection hooks, and custom-overlay replacement through the public port. Migrate the example from example-owned session/visibility mutation/duplicate measurement to the public overlay or public custom-overlay path. Update public API docs/registry, interaction/frame/geometry/architecture docs, guardrails, generated docs, and graph views when changed.

Out of Scope:

Do not make double tap an unconditional runtime edit command. Do not put `EditableText`, focus ownership, IME policy, cursor painting, or Flutter widget lifecycle into runtime, interaction, frame, geometry, store, or command owners. Do not add a second public candidate-token type, a second text commit primitive, app-calculated edit geometry, app-owned sync glue, background geometry synchronizers, committed active-session document state, or a general canvas-wide read-only policy. Do not replace direct programmatic `CanvasEdit.updateElement(CanvasTextElementUpdate)` for non-request edits. Do not hide active text by mutating `CanvasTextElement.isVisible`. Do not silently revive formula-based text bounds as fallback; any fallback must be explicit, bounded, and tested. Do not rely on screenshots alone as proof for layout equality or suppression.

Source of Truth:

The design file is the contract source input and decision handoff. The research note is the current-state evidence source. Durable public API meaning belongs in `docs/contracts/public_api_v1.md` and `docs/_registry/public_api_v1.yaml`. Text layout ownership belongs in `docs/contracts/cache_policy.md` and `docs/contracts/frame_rendering.md`. Bounds/hit/context/edit geometry meaning belongs in `docs/contracts/geometry.md`. Request/candidate/session separation belongs in `docs/contracts/interaction_engine.md` and runtime ownership docs. Package placement and dependency direction belong in `docs/architecture/01_runtime_ownership.md`, `docs/architecture/02_package_boundaries.md`, and `docs/architecture/architecture_graph.yaml` if graph nodes/edges change. Structural enforcement belongs in `tool/guardrails/**`, `docs/verification/guardrails.md`, `docs/verification/tests.md`, and generated verification indexes. The measured layout cache is derived state for local text metrics only, not an independent world-bounds geometry source of truth.

Compatibility:

Existing public context-action request delivery remains compatible: a double tap emits a context request and applications decide whether to show a menu, start inline editing, open a toolbar, or ignore it. Existing guarded `CanvasCommandPort.commitTextEdit` behavior, no-op handling, stale rejection, validation order, action payload semantics, and direct programmatic text updates remain compatible. Existing public API and schema formats must not break except for additive public symbols and docs/registry updates. `CanvasSurface.interactive` continues to control pointer routing only; inline text read-only policy lives on `CanvasTextEditingPort`. Custom overlays can replace the official overlay by consuming session geometry/style; they cannot bypass runtime read-only or single-active policy.

Dependency/import direction:

Public declarations live under `lib/src/contracts/public/**`; API facades under `lib/src/api/**`; root barrel exports only public API facades. Runtime may consume public/internal contracts and interaction guard facts but must not import surface widgets. Frame owns measured layout calculation/cache. Geometry may consume an immutable internal measured-layout value/port but must not import concrete frame cache state or surface widgets. Surface may import Flutter widgets and public runtime API and may use a narrow runtime bridge. `EditableText` is allowed under `lib/src/surface/**`, example, and tests only. Example imports the package public barrel and example-local files, not `lib/src/**` or legacy code.

Order Constraints:

First add the frame-owned local measured text layout metrics, the required internal measured-layout port, and migrate geometry/spatial/frame consumers to measured text bounds. Then add public API declarations, exports, registry entries, and API contract tests for the four non-widget public contract names and `CanvasRuntime.textEditing`. Then implement runtime text editing port/session lifecycle, candidate lookup, single-active/read-only policy, live geometry through the required measured-layout port, and guarded commit/dismiss cleanup. Then wire active edit suppression into frame planning/output before painter consumption. Then implement and export the official surface overlay, add the fifth public registry entry, and prove public custom-overlay replacement. Then migrate the example away from app-owned visibility mutation and duplicate measurement. Finally update durable docs/architecture/guardrails/generated outputs and run all required verification. Formula bounds, example-owned visibility hiding, and duplicate overlay measurement may be retired in the unit that installs the replacement path, but the step is not complete until Unit 7 installs structural guardrails that would catch those old paths if reintroduced.

Temporal Surface Closure:

The temporal invariant is that context request delivery is observable before edit start, and active edit publication plus the runtime suppression token happen only when runtime admission accepts a still-live candidate; frame paint suppression is applied later by Unit 4 from that accepted token. Synchronous callback surfaces include `CanvasRuntime.contextActionRequests` listeners, `CanvasTextEditingPort.activeSession` listeners, `CanvasTextEditingOverlay` text/focus/dismiss callbacks, app menu/manual start callbacks, `setReadOnly`, live text updates, commit/dismiss calls, load, dispose, and existing action/context streams. Guard owners are runtime text editing port plus `InteractionRequestRegistry` and existing command guard path. Allowed public observation order is: double tap -> context request -> optional candidate lookup with no mutation/suppression token/public active state -> accepted start publishes active session and runtime suppression token -> frame planning suppresses paint from that token -> live text updates publish derived session geometry without document mutation -> commit validates/stale-checks/prepares through existing command path before request consumption and document mutation -> success clears session/token and emits existing action semantics; stale/failed commit clears or restores transient runtime state without document/action mutation, with paint restoration proven by Unit 4. Conflicting start returns null and leaves current session/request/document/runtime suppression token unchanged. `setReadOnly(true)` dismisses active editing without commit and clears the runtime suppression token; Unit 4 proves canvas rendering restores from committed state. Dismiss clears transient state without document revision or action.

All-Or-Nothing Failure Boundary:

The irreversible document mutation point remains the existing `EditKernel` atomic install behind `CanvasCommandPort.commitTextEdit`. Fallible work before that point includes text validation, request liveness, element existence, generation, element revision, family, controller epoch, runtime disposed/load epoch, and candidate/session active identity checks. Later action delivery follows existing command finalization semantics. Active edit suppression cleanup is transient and failure-contained because Unit 3 clears the runtime suppression token and Unit 4 removes only frame/painter overlay state, restoring rendering from committed document. Failure projection before the irreversible point is false/no-op result, no document text or visibility mutation, no edit action, request/session state consumed or retained exactly as specified by the existing guard semantics, runtime suppression token cleared/retained according to the session lifecycle, and frame paint restoration proven by Unit 4.

## Execution Units

### [x] Unit 1: Frame-measured text layout and geometry migration

Owner:

`lib/src/frame/**` text layout cache/render row owners, a required immutable internal measured-layout contract under `lib/src/contracts/internal/**`, `lib/src/geometry/**` bounds/spatial/hit consumers, and focused frame/geometry/runtime-facing port tests.

Boundary:

Produce one measured local text layout result and a required internal port that geometry and runtime can consume for committed and live text measurement while keeping world-bounds assembly in geometry. This unit does not expose public text editing sessions, start runtime sessions, suppress active text, or build Flutter editor widgets.

Change:

Extend the frame-owned text layout cache/policy so a text layout entry contains the laid-out painter or equivalent render primitive plus immutable measured local layout metrics: local paint/hit/selection/edit bounds, style values used by render/overlay, and line/box metrics sufficient for multiline growth and future selection bounds. Keep the text measurement calculation and cache in Frame. Add a required typed internal measured-layout port/value that can measure committed text rows and runtime live-edit text from the same frame-owned policy/cache key inputs. Geometry and runtime may consume this port but must not construct a `TextPainter`, import concrete frame cache state, or calculate text dimensions from formulas. The port is synchronous for a given text/style/maxWidth/lineHeight/direction input and returns an explicit failure value only for bounded, tested measurement failure; no silent formula fallback is allowed. Migrate `GeometryPolicy` text bounds to consume measured local metrics and apply generic geometry policy for transform, hit padding, context bounds, paint bounds, hit bounds, edit bounds, and world-bounds assembly. Retire or make unreachable the text-length/font-size formula path for text elements once measured geometry tests pass in this unit; Unit 7 later adds structural guardrails as final reintroduction proof.

Completion Check:

Focused frame/geometry/runtime-facing port tests prove direct numeric outcomes for single-line, multiline, maxWidth, lineHeight, direction, align, transform, and hit-padding cases: rendered text painter dimensions, measured local bounds, render record paint bounds, spatial paint bounds, spatial hit/context bounds, selection bounds, edit bounds, and live-edit text measurements all derive from the same measured local layout result after geometry-owned transform/hit-padding/world assembly. Tests fail if geometry or runtime constructs a second text measurer, computes text dimensions from `text.length * fontSize`, if Frame stores pre-transformed world text bounds as its text-layout source of truth, if the measured-layout port returns a silent formula fallback, or if paint uses a different style/key than measured geometry. Existing hit/context/selection tests remain passing with measured text bounds. Owner-scoped metrics checks include `dcm calculate-metrics lib/src/frame`, `dcm calculate-metrics lib/src/contracts/internal`, and `dcm calculate-metrics lib/src/geometry`.

Depends On:

None.

### [x] Unit 2: Public text editing API declarations and exports

Owner:

`lib/src/contracts/public/**`, `lib/src/api/**`, `lib/iwb_canvas_engine.dart`, `docs/_registry/public_api_v1.yaml` for the four non-widget contract names, public API contract tests, and smoke compile fixtures.

Boundary:

Declare and export the additive non-widget public contract surface for inline text editing. This unit does not implement runtime admission behavior, overlay widgets, measured layout internals, or example migration beyond compile/API proof.

Change:

Add `CanvasTextEditGeometry`, `CanvasTextEditStyle`, `CanvasTextEditSession`, and `CanvasTextEditingPort` as public declarations. Add `CanvasRuntime.textEditing` in the public runtime facade. Export these four non-widget declarations through API wrappers and root barrel according to package boundary rules. Add the four non-widget feature names to `docs/_registry/public_api_v1.yaml`: `CanvasTextEditSession`, `CanvasTextEditGeometry`, `CanvasTextEditStyle`, and `CanvasTextEditingPort`; Unit 5 owns the fifth name, `CanvasTextEditingOverlay`, when the widget declaration exists. Do not add a public candidate-token type. Lock constructor/getter/method signatures to the design shape, including inactive candidate state, request/element guard facts, initial/live text, geometry, style, `isActive`, `isStale`, `updateText`, `commit`, `dismiss`, `activeSession`, `readOnly`, candidate lookup, start, read-only, and dismiss-active methods.

Completion Check:

Public API contract tests compile against the root barrel and prove the four non-widget names are exported with the documented signatures, `CanvasRuntime.textEditing` is visible, implementation internals remain hidden, and no extra public candidate-token type is required for candidate inspection/start. `docs/_registry/public_api_v1.yaml` contains those four names in this unit, while Unit 5 owns the fifth widget name and final five-name export proof. Existing public API compile-as-written tests remain passing. Owner-scoped metrics checks include `dcm calculate-metrics lib/src/contracts/public` and `dcm calculate-metrics lib/src/api`.

Depends On:

Unit 1 for final geometry fields and measured-layout contract shape.

### [x] Unit 3: Runtime text editing port, sessions, and guarded lifecycle

Owner:

`lib/src/runtime/**`, `lib/src/interaction/**` only where request guard integration is required, public runtime facade backing, and focused runtime/interaction tests.

Boundary:

Back `CanvasTextEditingPort` with runtime-owned candidate/session state, a runtime suppression token, and existing interaction request guard facts. This unit does not build the Flutter overlay, compute text metrics outside Unit 1, or apply frame paint suppression outside Unit 4.

Change:

Implement `sessionCandidateFor` and `startFromContextAction` for text context requests using immutable public text snapshots, live request guard facts, measured geometry/style from the required Unit 1 measured-layout port, and inactive `CanvasTextEditSession` values. Candidate lookup must not consume requests, publish a runtime suppression token, publish `activeSession`, take focus, or mutate documents. Implement `start` with runtime-enforced read-only and single-active admission: accept only still-live text candidates when no different session is active, return the current session idempotently for the same request id, and return null for conflicting starts without replacement, request consumption, runtime suppression-token change, or document mutation. Accepted start publishes active session plus the runtime suppression token consumed by Unit 4. Implement live text update and geometry publication by remeasuring live text through the same required Unit 1 port; runtime must not construct a second text measurer or formula fallback. Implement `commit` as a thin facade over existing `CanvasCommandPort.commitTextEdit`, preserving validation order, stale behavior, no-op behavior, changed-action behavior, and atomic install semantics. Implement `dismiss`, `dismissActive`, stale rejection cleanup, `setReadOnly(true)` dismissal without commit, load cleanup, and dispose cleanup for active session plus runtime suppression token.

Completion Check:

Runtime/interaction tests prove: context request delivery alone leaves `activeSession.value == null`; text candidate lookup returns inactive session data with request id, element id, revisions/generation, initial text, measured geometry, and style without consuming request, publishing a runtime suppression token, or mutating document; non-text or stale requests yield null; start accepts a still-live candidate when read-only is false and publishes active session plus runtime suppression token; same request start is idempotent; different active request start returns null and leaves active session, request facts, runtime suppression token, document revision/text, and action stream unchanged; read-only start returns null without active-session publication, suppression token, or mutation; `setReadOnly(true)` dismisses active editing and clears the token without commit/action/revision; live text update changes session geometry by using the required measured-layout port and not document state; commit success/no-op/stale/validation failure delegate to existing guard semantics and inspect document, action payload, request facts, active session state, and runtime suppression token only. A focused runtime test or structural assertion fails if runtime constructs `TextPainter`, calculates text dimensions directly, or bypasses the Unit 1 measured-layout port. Frame paint suppression/restoration proof belongs to Unit 4. Load and dispose clear sessions and follow existing disposed behavior. Existing `commitTextEdit` stale guard fixtures remain passing and are extended rather than bypassed. Owner-scoped metrics checks include `dcm calculate-metrics lib/src/runtime` and `dcm calculate-metrics lib/src/interaction` when touched.

Depends On:

Unit 1, Unit 2.

### [x] Unit 4: Active edit paint suppression in frame output

Owner:

Runtime-to-frame planning input, `lib/src/frame/**` main frame planning/output owners, selection decoration planning if needed, and frame/runtime suppression tests.

Boundary:

Suppress the original active text record and selection decoration before immutable painter output is consumed. This unit does not mutate documents, remove hit/context spatial membership, or implement overlay widgets.

Change:

Represent active edit suppression as transient runtime/frame input keyed by request id, element id, generation, element revision, family, and controller/load epoch. During frame planning, suppress only the matching active text element while guard facts remain valid. Exclude the ordinary text render record and selection decoration for that element from `MainFramePaintOutput` before `MainFramePainter` receives records. Do not mutate `CanvasTextElement.isVisible`, do not alter committed document text, do not remove the element from hit/context spatial indexes solely because editing is active, and restore ordinary rendering by clearing active session state on commit, dismiss, stale rejection, successful load, read-only dismissal, or dispose.

Completion Check:

Frame/runtime tests inspect immutable frame output directly: with an active session, the matching text record and its selection decoration are absent while non-active records remain, hit/context lookup still finds the text target where geometry admits it, and document revision/text/visibility are unchanged. Tests prove stale guard mismatch disables suppression and restores ordinary text paint. Commit, dismiss, stale rejection, read-only dismissal, load, and dispose paths restore canvas rendering from committed state without document visibility mutation. Painter tests prove no live runtime read is introduced into `CustomPainter.paint`. Owner-scoped metrics checks include `dcm calculate-metrics lib/src/frame` and `dcm calculate-metrics lib/src/runtime` when touched.

Depends On:

Unit 3.

### [x] Unit 5: Public Flutter text editing overlay

Owner:

`lib/src/surface/**`, `lib/src/api/canvas_surface.dart`, `lib/iwb_canvas_engine.dart`, `docs/_registry/public_api_v1.yaml` for `CanvasTextEditingOverlay`, surface/API contract tests, surface widget tests, and public custom-overlay smoke tests.

Boundary:

Implement and export the official Flutter integration helper that consumes `CanvasTextEditingPort`. This unit owns `EditableText`, focus/cursor/selection controls, widget lifecycle, camera/view placement, optional auto-start, and the fifth public feature name. It does not own runtime policy, measured layout calculation, command mutation, or document visibility.

Change:

Add `CanvasTextEditingOverlay` as a public `StatefulWidget` under the surface integration layer, export it through the surface API facade and root barrel, and add `CanvasTextEditingOverlay` as the fifth feature name in `docs/_registry/public_api_v1.yaml`. It observes `runtime.textEditing`, listens to context-action requests only when `inlineEditOnDoubleTap` is true, starts sessions through the runtime port, renders active sessions with `EditableText`, positions and sizes from session `CanvasTextEditGeometry`, applies session `CanvasTextEditStyle`, forwards cursor color, selection color, and `TextSelectionControls`/theme hooks, and handles commit/dismiss/focus cleanup through session methods. Default multiline behavior grows to `editBoundsWorld` without internal scrolling when `maxEditorHeight == null`; when `maxEditorHeight` is provided, clamp visible height and enable internal scroll as an app-selected policy. Custom overlays remain supported by consuming `CanvasTextEditingPort.activeSession`, geometry, and style without using this widget.

Completion Check:

Surface/API tests prove `CanvasTextEditingOverlay` is exported from the root barrel, `docs/_registry/public_api_v1.yaml` now contains exactly the five feature names, and implementation internals remain hidden. Surface widget tests prove the overlay uses `EditableText`, auto-starts from text context requests only when `inlineEditOnDoubleTap == true`, does not auto-start when disabled, observes runtime read-only policy, positions and sizes from session geometry without app-side `TextPainter` measurement, applies style fields from session style, commits through session/command path, dismisses without mutation, and disposes focus/controller/listeners without post-dispose effects. Multiline tests prove Enter/live updates increase session edit bounds and overlay host height with no internal scroll by default, and max-height tests prove clamped height plus internal scroll only when `maxEditorHeight` is set. A public smoke/custom-overlay test imports the root barrel and builds a replacement overlay from `CanvasTextEditingPort.activeSession`, `geometry`, and `style` only. Owner-scoped metrics checks include `dcm calculate-metrics lib/src/surface`.

Depends On:

Unit 2, Unit 3, Unit 4.

### [x] Unit 6: Example migration to public inline editing

Owner:

`example/**`, example tests, and example-specific structural checks where needed.

Boundary:

Migrate the example app to consume the official public text editing path or public custom-overlay path. This unit does not add engine-only behavior or use internal APIs to paper over missing public surface.

Change:

Remove example-owned `CanvasExampleTextEditSession`, example-owned visibility hiding/restoration, duplicate overlay `TextPainter` height measurement, and app-calculated edit bounds/camera placement. Integrate `CanvasTextEditingOverlay` beside `CanvasSurface` for the default path or implement a custom example overlay using only `CanvasTextEditingPort.activeSession`, session geometry, and session style. Keep text options and request-originated commit behavior through public APIs. If public API parity is missing, stop and create a separate owner-level contract instead of importing internals or mutating visibility.

Completion Check:

Example widget/view-model tests prove double tap text editing works through the public overlay or custom public port, committed text changes through the guarded session/command path, dismiss leaves document text and visibility unchanged, stale commit leaves the document unchanged and restores paint, multiline growth uses session geometry, and no example code hides text through `isVisible: false` for inline editing. Structural checks fail if example inline editing imports `lib/src/**`, legacy code, reintroduces `CanvasExampleTextEditSession`, constructs a duplicate overlay `TextPainter` for edit height, or calculates edit placement from context target bounds plus camera offset. Existing example workflows remain passing. Example verification includes the focused example tests affected by text editing.

Depends On:

Unit 5.

### [x] Unit 7: Durable docs, guardrails, generated outputs, and final verification

Owner:

`docs/contracts/public_api_v1.md`, `docs/contracts/interaction_engine.md`, `docs/contracts/geometry.md`, `docs/contracts/frame_rendering.md`, `docs/contracts/cache_policy.md` if changed, `docs/architecture/01_runtime_ownership.md`, `docs/architecture/02_package_boundaries.md`, `docs/architecture/architecture_graph.yaml` and generated graph views if architecture nodes/edges change, `docs/verification/guardrails.md`, `docs/verification/tests.md`, `docs/_registry/sections.yaml`, `tool/guardrails/src/**`, generated docs/indexes, and repository verification commands.

Boundary:

Update durable source-of-truth documentation and executable structural enforcement after the behavior exists. This unit does not create a new standalone behavior document and does not mark implementation units complete without proof.

Change:

Update public API docs and registry for the five new public names, candidate/start policy, read-only policy, stale behavior, custom overlay replacement, and the new runtime-owned active session state. Update interaction docs to preserve context-action ownership while naming text candidate/session separation. Update geometry docs to describe frame-measured local text metrics with geometry-owned world paint/hit/context/edit/selection bounds. Update frame docs to name measured local text layout/cache ownership, immutable metrics handoff, and active-edit suppression in frame output. Update runtime/package architecture docs and P13 architecture graph/generated views if new nodes/edges are introduced. Add runner-backed guardrails `text.single_measured_layout_source`, `text.no_overlay_textpainter_measurement`, and `surface.editable_text_surface_only` through registry, executor routes, check implementations, docs, and section registry/generated indexes. Update `docs/verification/tests.md` with focused test/proof ids for text layout equality, overlay measurement exclusion, and surface-only `EditableText` imports. Regenerate generated docs only through the owning tools.

Completion Check:

Guardrail tests and `dart run tool/guardrails/run.dart` prove the new structural checks fail on formula-based text bounds, duplicate public/example overlay `TextPainter` measurement, and `EditableText` imports outside surface/example/tests. `docs/verification/tests.md` contains focused proof ids for text layout equality, overlay measurement exclusion, and surface-only `EditableText` imports, and generated verification indexes are current. Documentation checks pass: `dart run docs/tool/sync_generated_docs.dart --check` and `dart run docs/tool/check_docs.dart`, after regeneration if needed. Architecture checks pass when `docs/architecture/architecture_graph.yaml`, generated graph views, or architecture-owned surface/API seams change: `dart run tool/architecture_graph/check.dart --phase P13` and `dart run tool/architecture_graph/generate_views.dart --phase P13 --check`. Repository code checks pass after Dart changes: `dart analyze`, `dcm analyze .`, focused tests for changed behavior, and owner-scoped `dcm calculate-metrics` for changed production/test/tool scopes. Docs diff review can trace every durable behavior to an existing source-of-truth owner, not this planning contract alone.

Depends On:

Units 1 through 6.
