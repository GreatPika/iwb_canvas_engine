# Change Contract

## Goal

Port the legacy Flutter example into a runnable rebuilt root example that preserves the legacy user-facing canvas workflows through the public package API only, including the cat image asset workflow, while keeping all application UI, resolver, dialog, and inline editor responsibilities outside engine source.

## Source Inputs

- Design: `.design/2026-06-03-legacy-example-full-parity-port.md`
- Research: `.research/2026-06-03-example-full-parity-before-p14.md`
- Phase: none
- PLAN: `PLAN.md`
- Other: `docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md`, `docs/contracts/public_api_v1.md`, `docs/contracts/resources.md`, `docs/verification/guardrails.md`, `docs/verification/release_gates.md`, `docs/verification/tests.md`, `analysis_options.yaml`, `pubspec.yaml`, `lib/iwb_canvas_engine.dart`, `lib/src/api/canvas_runtime.dart`, `lib/src/surface/canvas_surface_widget.dart`, `lib/src/api/canvas_codec.dart`, `tool/guardrails/src/core_boundary_checks.dart`, `test/api_contract/app_next_engine_adapter_compile_fixture_test.dart`, `test/smoke/public_incremental_smoke_test.dart`, `legacy/iwb_canvas_engine/pubspec.yaml`, `legacy/iwb_canvas_engine/lib/src/contract/scene_defaults.dart`, `legacy/iwb_canvas_engine/example/lib/**`, `legacy/iwb_canvas_engine/example/pubspec.yaml`, `legacy/iwb_canvas_engine/image/cat.png`

## Classification

Profile: BEHAVIOR_CHANGE

Obligations: SEAM_MIGRATION

## Decision Trace

| Source decision | Contract location | Execution unit / proof surface |
|---|---|---|
| `D1` The rebuilt example is a root public-consumer Flutter example, not an engine-side adapter or test-only fixture. | `Boundaries.Owner`, `Boundaries.In Scope`, `Boundaries.Compatibility` | Unit 1 creates root `example/` app/package surfaces and proves it runs/analyzes as a public consumer. |
| `D2` Example code imports only `package:iwb_canvas_engine/iwb_canvas_engine.dart` for engine access. | `Boundaries.Dependency/import direction`, `Boundaries.Source of Truth`, Unit 7 | Unit 7 structural scan rejects `lib/src`, `legacy`, retired symbols, and extra engine imports under `example/**` and example tests. |
| `D3` Replace `SceneController` ownership with app-owned `CanvasRuntime` lifecycle and public ports. | `Boundaries.Owner`, `Boundaries.State/data ownership`, Unit 2 | Unit 2 view-model tests prove owned/injected runtime lifecycle, listener cancellation, public state projection, and port-based mode/tool/selection/camera/document edits. |
| `D4` Replace `SceneView` with public `CanvasSurface`; keep pending-line marker as an app overlay derived from public preview state. | `Boundaries.In Scope`, Unit 3 | Unit 3 widget tests prove screen composition, `CanvasSurface` construction, pointer interaction, dock controls, and pending-line overlay projection from public preview. |
| `D5` Keep resource bytes, physical cat image transfer, image disposal, and resolver implementation app-owned. | `Boundaries.State/data ownership`, `Boundaries.Source of Truth`, Unit 1, Unit 4 | Unit 1 transfers `legacy/iwb_canvas_engine/image/cat.png` to `example/image/cat.png` and declares Flutter asset key `image/cat.png`; Unit 4 tests asset load, resolver return, sample image insertion/rendering, and app-owned disposal/no engine IO. |
| `D6` Preserve inline text editing through app overlay hiding and public `commitTextEdit`, not by mutating target visibility. | `Boundaries.Temporal Surface Closure`, Unit 1, Unit 5 | Unit 1 keeps overlay math dependency-free by default with Flutter `Matrix4` primitives; Unit 5 tests context request delivery, overlay focus/controller lifetime, no visibility patch before commit, commit result handling, dismiss/no-op cleanup, and text style control edits. |
| `D7` Preserve JSON import/export workflow using schema v1 document JSON; old legacy scene JSON payload compatibility is not required. | `Boundaries.Compatibility`, `Boundaries.All-Or-Nothing Failure Boundary`, Unit 6 | Unit 6 tests export dialog JSON/copy, last-export import prefill, valid schema v1 load, invalid input snackbar, and no document mutation on decode failure. |
| `D8` Verification must include example-specific parity tests and structural import/retired-symbol checks because existing core guardrails do not scan example code. | `Boundaries.Order Constraints`, Unit 7 | Unit 7 adds or updates the exact test/guardrail surfaces and runs repository-required analyze, DCM, focused tests, docs checks when docs change, and release checks only when release/guardrail/benchmark surfaces are changed or claimed complete. |
| User requirement on 2026-06-03: do not forget the cat photo transfer. | `Boundaries.In Scope`, Unit 1, Unit 4 | Unit 1 completion fails unless `example/image/cat.png` exists and is declared as asset key `image/cat.png`; Unit 4 completion fails unless the app resolver can load and render that asset. |
| Research inventory `Add Sample` workflow. | `Boundaries.In Scope`, Unit 3, Unit 4, Unit 7 | Unit 3 exposes the UI command; Unit 4 adds public rect, text `New Note`, and cat image elements; Unit 7 verifies the full sample workflow, not only image insertion. |
| Research inventory startup/default parity. | `Boundaries.State/data ownership`, Unit 1, Unit 2 | Unit 1 constructs and tests explicit next-owned defaults for two content layers, palette, background, grid, camera, pointer policy, and clear-selection-on-draw configuration. |

## Evidence

- `.design/2026-06-03-legacy-example-full-parity-port.md:13` / disposition: design is `READY_FOR_CONTRACT` -> write a full step contract, not a blocker.
- `.design/2026-06-03-legacy-example-full-parity-port.md:17` / product outcome: the rebuilt example must be runnable and prove public-package API usability -> root example app/package is in scope, not only test fixtures.
- `.design/2026-06-03-legacy-example-full-parity-port.md:21` / parity list: startup, rendering, pointer interaction, tools, camera/grid/background, cat image, JSON, clear, pending line, text editing, dialogs, snackbars, and cleanup are preserved -> execution units must cover every visible workflow.
- `.design/2026-06-03-legacy-example-full-parity-port.md:30` / non-goal: legacy controller/view/spec/patch/codec shapes must not be reintroduced -> structural retired-symbol proof is mandatory.
- `.design/2026-06-03-legacy-example-full-parity-port.md:33` / non-goal: no application adapter abstraction inside engine package -> example code belongs under `example/**`, not `lib/**`.
- `.design/2026-06-03-legacy-example-full-parity-port.md:34` / release-boundary limit: missing engine behavior blocks instead of being patched through internals -> implementation must stop on public API gaps.
- `.design/2026-06-03-legacy-example-full-parity-port.md:37` / JSON scope: old legacy exported JSON compatibility is not promised -> Unit 6 uses schema v1 workflow parity only.
- `.design/2026-06-03-legacy-example-full-parity-port.md:44` / classification: selected profile is `BEHAVIOR_CHANGE` with `SEAM_MIGRATION` -> units must prove user-visible app behavior and legacy seam replacement.
- `.design/2026-06-03-legacy-example-full-parity-port.md:381` / selected form: Candidate A is root public-consumer app with app-owned UI, runtime lifecycle, asset loading, resolver, dialogs, and text overlay -> owner boundary is fixed.
- `.design/2026-06-03-legacy-example-full-parity-port.md:384` / import rule: only engine import is the public barrel -> Unit 7 must mechanically enforce import direction.
- `.design/2026-06-03-legacy-example-full-parity-port.md:386` / selected form: default document must preserve equivalent layers, palette, background, grid, and camera defaults -> Unit 1 must name and test those next-owned defaults directly.
- `.design/2026-06-03-legacy-example-full-parity-port.md:393` / text edit decision: overlay hides/covers visually and commits through `CanvasCommandPort.commitTextEdit` -> Unit 5 must reject legacy visibility mutation.
- `.design/2026-06-03-legacy-example-full-parity-port.md:398` / JSON decision: export/import uses `encodeCanvasDocumentToJson` and `decodeCanvasDocumentFromJson` plus public load/replace -> Unit 6 owns schema v1 workflow.
- `.design/2026-06-03-legacy-example-full-parity-port.md:413` / decision trace: D1 maps root example ownership to app/package setup and import proof -> Unit 1 and Unit 7 carry that decision.
- `.design/2026-06-03-legacy-example-full-parity-port.md:417` / decision trace: D5 maps cat image/resource ownership to asset/resolver service and resource widget test -> Unit 1 and Unit 4 must include physical asset transfer and resolver proof.
- `.design/2026-06-03-legacy-example-full-parity-port.md:420` / decision trace: D8 maps verification gaps to tests and structural proof -> Unit 7 owns example-specific checks.
- `.design/2026-06-03-legacy-example-full-parity-port.md:426` / outcome-proof fit: compile or screenshot alone misses command effects and error paths -> completion checks must use focused widget/view-model tests.
- `.design/2026-06-03-legacy-example-full-parity-port.md:481` / temporal closure: request-originated text editing order is request delivery, overlay display, optional edit, command commit, then overlay cleanup -> Unit 5 completion check must name that order.
- `.design/2026-06-03-legacy-example-full-parity-port.md:490` / failure boundary: JSON decode is fallible before runtime load and invalid input projects snackbar with no mutation -> Unit 6 must prove all-or-nothing import.
- `.research/2026-06-03-example-full-parity-before-p14.md:13` / legacy inventory: legacy app starts Material app, owns/accepts controller, renders `SceneView`, exposes controls, loads cat image, imports/exports JSON, and owns inline editor UI -> parity source must drive the app/widget/view-model units.
- `.research/2026-06-03-example-full-parity-before-p14.md:17` / portability: port must rewrite around `CanvasRuntime` and `CanvasDocument`, carry over UI widgets, and use public ports only -> copying controller-facing code is out of scope.
- `.research/2026-06-03-example-full-parity-before-p14.md:34` / retired symbols: legacy example used `SceneController`, `SceneView`, `PatchField`, `NodeSpec`, and legacy codec helpers -> Unit 7 retired-symbol quarantine is required.
- `.research/2026-06-03-example-full-parity-before-p14.md:40` / capability inventory: every legacy user-facing behavior is accounted for -> completion proof must reference the full inventory rather than a partial smoke path.
- `.research/2026-06-03-example-full-parity-before-p14.md:45` / startup defaults: legacy view model created a default controller with two layers, clear-selection-on-draw, and pointer settings -> Unit 1 must map those facts to `CanvasDocument` and `CanvasRuntimeConfig`.
- `.research/2026-06-03-example-full-parity-before-p14.md:54` / Add Sample inventory: legacy `Add Sample` adds a rect, text note, and image -> Unit 4 must implement all three through public APIs.
- `.research/2026-06-03-example-full-parity-before-p14.md:62` / SceneDefaults mapping: legacy defaults for pen colors, background colors, grid sizes, default background, and grid color must move to public document/background/grid/palette DTOs -> Unit 1 must not rely on legacy files at runtime.
- `.research/2026-06-03-example-full-parity-before-p14.md:143` / asset requirements: rebuilt root lacks `vector_math`, root asset declaration, and the only inspected cat asset is in `legacy/iwb_canvas_engine/image/cat.png` -> Unit 1 must settle example dependency/asset ownership and transfer the cat image.
- `.research/2026-06-03-example-full-parity-before-p14.md:149` / public consumer harness: external consumer proof imports only the public barrel -> example proof can reuse that boundary pattern.
- `.research/2026-06-03-example-full-parity-before-p14.md:159` / missing proof: complete dock UI, camera UI, dialogs, sample asset service, text options, overlay focus/dismiss, and runnable root example lack current proof -> Units 3 through 7 must add direct app proof.
- `.research/2026-06-03-example-full-parity-before-p14.md:192` / public access: external adapter proof compiles without `src/**`, legacy symbols, or internals -> Unit 7 must scan root example sources for the same constraints.
- `.research/2026-06-03-example-full-parity-before-p14.md:194` / resource ownership: descriptors are committed document state, but bytes/images and resolution are app-owned and surface-session-bound -> Unit 4 keeps image IO/resolution outside engine.
- `.research/2026-06-03-example-full-parity-before-p14.md:195` / text ownership: text editor UI is application-owned after context request delivery -> Unit 5 owns Flutter focus/controller lifetime.
- `.research/2026-06-03-example-full-parity-before-p14.md:196` / release-boundary constraint: release proof and packaging are not a feature phase -> implementation must not add engine feature behavior inside this example-port step.
- `.research/2026-06-03-example-full-parity-before-p14.md:200` / JSON open question resolved by design: old scene JSON compatibility was open, while public API exposes schema v1 -> contract preserves schema v1 workflow only.
- `docs/contracts/public_api_v1.md:103` / public API ban: legacy public symbols are not exported -> example code must use next-owned public names.
- `docs/contracts/public_api_v1.md:127` / public consumer rule: external adapter proof imports only public barrel -> root example must use the same engine access boundary.
- `docs/contracts/public_api_v1.md:136` / public consumer fixture: compile without `src/**`, legacy symbols, or internal runtime classes -> structural proof must catch bypasses beyond analyzer success.
- `docs/contracts/public_api_v1.md:317` / request id policy: no public interaction request id generator -> example must consume engine-delivered requests, not fabricate them.
- `docs/contracts/public_api_v1.md:505` / surface contract: `CanvasSurface` is the public widget -> Unit 3 replaces `SceneView` with that widget.
- `docs/contracts/public_api_v1.md:788` / codec contract: public schema helpers encode/decode `CanvasDocument` JSON -> Unit 6 uses rebuilt document JSON.
- `docs/contracts/public_api_v1.md:1478` / command contract: `CanvasCommandPort.commitTextEdit` is public -> Unit 5 commits text through the command port.
- `docs/contracts/public_api_v1.md:2360` / app text policy: applications commit request-originated text changes through `CanvasCommandPort.commitTextEdit` -> Unit 5 must not patch visibility/text directly for a request-originated edit.
- `docs/contracts/resources.md:67` / resource session: each active `CanvasSurface` creates a concrete session -> app supplies resolver, while surface/session owns active cache lifecycle.
- `docs/contracts/resources.md:112` / attach order: `CanvasSurface` creates session only after successful attach -> Unit 4 uses public resolver construction without engine IO.
- `docs/contracts/resources.md:117` / image ownership: surface/session drop clears cache without disposing app-owned images -> Unit 4 tests app-owned image disposal policy.
- `docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md:20` / release scope: no app adapters inside engine package -> example adaptation cannot live under `lib/**`.
- `docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md:120` / release exit: no legacy imports -> Unit 7 must include example sources in legacy import proof.
- `docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md:137` / release limit: no new feature behavior -> public API gaps are contract blockers, not internal patches.
- `docs/verification/guardrails.md:169` / integration surface guardrail: external app-adapter compile fixture imports only public barrel and proves public surface enough while adapter is not in package -> root example proof should preserve that boundary.
- `docs/verification/guardrails.md:185` / core guardrail: legacy imports are forbidden -> root example must not import `legacy/**`.
- `docs/verification/guardrails.md:247` / fixture proof: compile fixture checks root barrel import, no `src/**`, no legacy symbols, and required operation families -> Unit 7 can model example structural scan on this pattern.
- `docs/verification/release_gates.md:235` / release gate: `AppCanvasPort`, `LegacyEngineAdapter`, and `NextEngineAdapter` must not be present in engine package -> example must avoid those package-source abstractions.
- `docs/verification/tests.md:443` / consumer tests: external behavior tests prove ordinary users can import public barrel and execute behavior -> public-consumer proof is a required verification surface.
- `docs/verification/tests.md:579` / smoke scope: public incremental smoke proves coarse public compatibility -> example-specific UI parity still needs focused proof.
- `docs/verification/tests.md:765` / P13 surface tests: surface behavior already covers active surface/resource/pointer policies -> example should consume `CanvasSurface`, not duplicate surface internals.
- `lib/iwb_canvas_engine.dart:1` / root barrel: public API exports from the package root -> example engine import target is fixed.
- `lib/src/api/canvas_runtime.dart:26` / runtime declaration: `CanvasRuntime` is the public runtime facade -> view model replaces legacy controller with runtime.
- `lib/src/api/canvas_runtime.dart:41` / runtime ports: runtime exposes edit, selection, tool, command, camera, resources, preview, actions, context requests, ids, and disposal -> example workflows can route through public ports.
- `lib/src/surface/canvas_surface_widget.dart:14` / surface declaration: `CanvasSurface` is the public widget -> Unit 3 uses it as the render/pointer child.
- `lib/src/surface/canvas_surface_widget.dart:108` / attach implementation: surface attach owns active resource session setup -> example passes resolver to surface instead of managing frame resource lifecycle.
- `lib/src/api/canvas_codec.dart:18` / encode helper: schema v1 JSON encode operates on `CanvasDocument` -> export workflow uses rebuilt document JSON.
- `lib/src/api/canvas_codec.dart:26` / decode helper: schema v1 JSON decode returns `CanvasDocument` -> import workflow decodes before load/replace.
- `test/api_contract/app_next_engine_adapter_compile_fixture_test.dart:20` / fixture test: import lines and retired symbols are checked mechanically -> Unit 7 structural proof should mirror this for example code.
- `test/smoke/public_incremental_smoke_test.dart:18` / public smoke: generated consumer source imports Flutter and the public barrel -> example proof can reuse public-consumer compile assumptions.
- `test/smoke/public_incremental_smoke_test.dart:920` / public surface smoke: public consumer already exercises `CanvasSurface` pointer/resource bridge -> Unit 3 and Unit 4 can focus on app-specific mapping and asset workflow.
- `pubspec.yaml:10` / root dependencies: rebuilt root depends on Flutter and has no root asset declaration in the inspected area -> Unit 1 must add the appropriate example asset/dependency ownership instead of assuming the legacy asset is available.
- `legacy/iwb_canvas_engine/image/cat.png` / asset file: physical cat image exists only in the legacy package path -> Unit 1 must copy it to `example/image/cat.png`.
- `legacy/iwb_canvas_engine/example/pubspec.yaml:12` / legacy example package: legacy example depended on package by path -> rebuilt example should remain an ordinary consumer.
- `legacy/iwb_canvas_engine/example/pubspec.yaml:21` / legacy Material config: example enables Material design assets/icons -> Unit 1 must set `flutter.uses-material-design: true`.
- `legacy/iwb_canvas_engine/lib/src/contract/scene_defaults.dart:7` / legacy palette: pen colors are black, red, blue, green, orange, and purple -> Unit 1 maps these values into public `CanvasPalette`.
- `legacy/iwb_canvas_engine/lib/src/contract/scene_defaults.dart:16` / legacy background: default background color is white -> Unit 1 maps this into public `CanvasBackground`.
- `legacy/iwb_canvas_engine/lib/src/contract/scene_defaults.dart:24` / legacy grid sizes: grid palette is `10`, `20`, `40`, and `80` -> Unit 1 maps these values into public `CanvasPalette.gridSizes`.
- `legacy/iwb_canvas_engine/lib/src/contract/scene_defaults.dart:25` / legacy grid color: grid color is `Color(0x1F000000)` -> Unit 1 maps this into public `CanvasGrid`.
- `legacy/iwb_canvas_engine/example/lib/ui/canvas_example/view_models/canvas_example_view_model.dart:17` / legacy startup: default controller is created when none is injected -> Unit 1/2 must create or inject `CanvasRuntime` with matching app-owned lifecycle.
- `legacy/iwb_canvas_engine/example/lib/ui/canvas_example/view_models/canvas_example_view_model.dart:19` / legacy layers: startup creates `layer-auto-0` and `layer-auto-1` -> Unit 1 maps those to public `CanvasLayerId` values.
- `legacy/iwb_canvas_engine/example/lib/ui/canvas_example/view_models/canvas_example_view_model.dart:24` / legacy draw config: clear-selection-on-draw is enabled -> Unit 1 maps this to `CanvasRuntimeConfig.clearSelectionOnDrawModeEnter`.
- `legacy/iwb_canvas_engine/example/lib/ui/canvas_example/view_models/canvas_example_view_model.dart:25` / legacy pointer policy: tap slop `16`, double-tap slop `32`, and max delay `450` are configured -> Unit 1 maps these to `CanvasPointerPolicy`.
- `legacy/iwb_canvas_engine/example/lib/ui/canvas_example/view_models/canvas_example_view_model.dart:127` / legacy export: old workflow used `encodeSceneToJson` -> Unit 6 maps export to schema v1 helper, not legacy codec.
- `legacy/iwb_canvas_engine/example/lib/ui/canvas_example/view_models/canvas_example_view_model.dart:139` / legacy import: old workflow used `decodeSceneFromJson` and replace -> Unit 6 maps import to schema v1 decode plus public load.
- `legacy/iwb_canvas_engine/example/lib/ui/canvas_example/view_models/canvas_example_view_model.dart:287` / legacy sample: `Add Sample` creates three nodes -> Unit 4 must create public rect, text, and image elements.
- `legacy/iwb_canvas_engine/example/lib/ui/canvas_example/view_models/canvas_example_view_model.dart:288` / legacy sample rect: rect is `140x90` with blue fill/stroke -> Unit 4 must preserve visible rect behavior with public element DTOs.
- `legacy/iwb_canvas_engine/example/lib/ui/canvas_example/view_models/canvas_example_view_model.dart:298` / legacy sample text: text content is `New Note` at font size `20` and black color -> Unit 4 must preserve text note insertion.
- `legacy/iwb_canvas_engine/example/lib/ui/canvas_example/view_models/canvas_example_view_model.dart:308` / legacy sample image: image uses `sample-cat` and size `120x180` -> Unit 4 must preserve the sample cat image descriptor/element behavior.
- `legacy/iwb_canvas_engine/example/lib/ui/canvas_example/view_models/canvas_example_view_model.dart:392` / legacy text hide: old editor hid target by visibility patch -> Unit 5 must forbid that mechanism.
- `legacy/iwb_canvas_engine/example/lib/ui/canvas_example/widgets/canvas_controls_dock.dart:156` / dock: legacy dock owns mode, tools, actions, grid, background, import/export, and clear UI -> Unit 3 must preserve dock workflow.
- `legacy/iwb_canvas_engine/example/lib/data/services/sample_image_asset_service.dart:16` / image service: legacy service tried package and local cat asset keys -> Unit 4 narrows the rebuilt example to app-owned asset key `image/cat.png` for copied file `example/image/cat.png`.
- `tool/guardrails/src/core_boundary_checks.dart:391` / guardrail implementation: `core.no_legacy_imports` is implemented as a concrete scan -> Unit 7 must either extend existing scan coverage for example paths or add a focused example scan.

## Boundaries

Owner:

Root `example/**` owns the Flutter app shell, view model, screen widgets, dock, dialogs, clipboard/snackbar flows, sample image asset service, resolver implementation, inline text overlay, text options UI, app-owned decoded images, and app-specific test fixtures. Engine source under `lib/**` owns only the already-public runtime, surface, DTO, port, codec, and resource-session behavior it exposes. Verification tooling and tests own structural example import/retired-symbol proof. `PLAN.md` and this file own planning state only.

In Scope:

Create a runnable root example app/package. Transfer `legacy/iwb_canvas_engine/image/cat.png` to `example/image/cat.png` and declare it as Flutter asset key `image/cat.png` so the example can load it as an app-owned asset. Preserve legacy workflows from the research inventory: startup, surface rendering, pointer interaction, move/draw mode switching, pencil/marker/line/eraser, draw colors, selection actions, camera controls, grid/background controls, Add Sample rect/text/cat image insertion and rendering, schema v1 JSON export/import with copy/error UI, clear canvas, pending-line indicator, text options, inline text editing, dialogs, snackbars, and cleanup. Rewrite controller-facing app code around `CanvasRuntime`, `CanvasSurface`, public DTOs, public ports, and schema v1 helpers. Add focused example widget/view-model/service tests and structural import/retired-symbol checks.

Out of Scope:

Do not reintroduce `SceneController`, `SceneView`, `SceneSnapshot`, `ContentLayerSnapshot`, `PointerInputSettings`, `CanvasMode`, legacy `DrawTool`, `EditTextRequested`, `NodeId`, `TextNodeSnapshot`, `TextNodePatch`, `CommonNodePatch`, `PatchField`, `NodeSpec`, `RectNodeSpec`, `TextNodeSpec`, `ImageNodeSpec`, `Transform2D`, `encodeSceneToJson`, `decodeSceneFromJson`, legacy facade shapes, or old payload compatibility. Do not add `AppCanvasPort`, `LegacyEngineAdapter`, `NextEngineAdapter`, or an application adapter abstraction under `lib/**`. Do not import `lib/src/**` or `legacy/**` from example code. Do not add engine feature behavior, public API expansion, schema migration, file picker/image picker/network IO, undo/redo/zoom/keyboard shortcut features, or old scene JSON translation in this step. If public API parity is missing, stop implementation and create a separate blocker/contract for the owning engine layer.

Production `lib/**` changes are out of scope for this example-port step. Non-example changes are limited to tests, guardrail/tooling, docs/verification, root `PLAN.md`, and generated docs only when needed to make the example boundary mechanically enforceable. Any required production engine or public API change is a blocker for this step and must move to a separate owner-level contract before implementation continues.

Source of Truth:

The design file is the contract source input and decision handoff. The research note is the parity inventory source input for this step. Durable public engine behavior remains owned by `docs/contracts/public_api_v1.md`, `docs/contracts/resources.md`, and the implementation under `lib/**`. The runnable example behavior and app-owned cat asset are owned by `example/**` after implementation. Verification ownership for public-consumer and retired-symbol proof lives in repository tests/guardrails and `docs/verification/**` if those verification surfaces are updated. The copied asset `example/image/cat.png` and Flutter asset key `image/cat.png` are the runtime image source for the example; `legacy/iwb_canvas_engine/image/cat.png` is historical donor input only after the copy exists.

Compatibility:

The rebuilt example must be source-compatible as an ordinary package consumer through `package:iwb_canvas_engine/iwb_canvas_engine.dart`. User-visible workflow parity is required, but legacy implementation mechanisms and old JSON payload compatibility are intentionally not preserved. JSON compatibility is schema v1 `CanvasDocument` workflow parity only: export JSON, copy it, import valid schema v1 JSON, replace/load the document, and show a snackbar/error without mutation on invalid input. Existing public API signatures, schema formats, release gates, and production guardrails must not be weakened.

Dependency/import direction:

Allowed: `example/** -> package:iwb_canvas_engine/iwb_canvas_engine.dart`, Flutter SDK, Dart SDK, and example-local files/assets. `example/pubspec.yaml` dependency baseline is `flutter` from SDK plus `iwb_canvas_engine: { path: ../ }`, with `flutter.uses-material-design: true` and `flutter.assets` declaring `image/cat.png`. Default: do not add `vector_math`; implement overlay transforms with Flutter `Matrix4`/rendering primitives already available to the example. Conditional exception: add `vector_math` only to `example/pubspec.yaml` if a focused overlay test demonstrates the Flutter-only implementation cannot preserve the legacy transform behavior without materially worse clarity. Forbidden: `example/** -> lib/src/**`, `example/** -> legacy/**`, `lib/** -> example/**`, legacy package imports, and app adapter abstractions in package source.

Order Constraints:

Unit 1 establishes runnable app/package, asset declaration, physical cat image transfer, and default document/startup before behavior units depend on them. Unit 2 establishes runtime/view-model ownership before widgets bind controls. Unit 3 builds screen/surface/dock/pending preview on top of the view model. Unit 4 adds sample image service/resolver after asset and surface boundaries exist. Unit 5 adds text options and inline edit after context-request/runtime projection exists. Unit 6 adds JSON dialogs after schema v1 runtime load/export ownership exists. Unit 7 adds or finalizes structural proof, docs/verification updates if needed, and final repository checks after the example surfaces exist. If any unit finds a missing public engine capability, implementation stops before patching around internals.

Temporal Surface Closure:

The relevant temporal invariant is that app callbacks and public runtime/surface callbacks must not create hidden engine mutations outside the accepted public port operation. Synchronous callback surfaces are Flutter button/menu callbacks, pointer events routed by `CanvasSurface`, view-model listeners on public runtime state/preview/action/context-request surfaces, dialog submit/cancel callbacks, clipboard callback completion, asset bundle load completion, resolver calls during paint, inline text overlay focus/text/dismiss callbacks, and view-model disposal. Public observation order is startup/default document -> runtime/view-model projection -> surface build -> user callback -> public port/codec operation -> runtime publication or bounded UI error -> app notification. Request-originated text editing order is context request delivery -> app overlay display -> optional user edit -> `CanvasCommandPort.commitTextEdit` -> overlay cleanup. The expected rejection/no-mutation signal is no target visibility patch before text commit, no direct document mutation from the surface/example UI, no runtime load on invalid JSON, and no post-dispose listener effects.

All-Or-Nothing Failure Boundary:

For JSON import, schema v1 decode/validation is fallible and must complete before the irreversible runtime load/replace point; invalid input projects snackbar/error UI and leaves the prior document unchanged. For text commit, the irreversible point is accepted `CanvasCommandPort.commitTextEdit`; unknown/stale/no-op results are contained to app UI cleanup/error handling without manual document mutation. For the user-facing Add Sample command, cat asset load/decode and app resolver readiness are fallible and must complete before the irreversible document mutation that adds the rect, text, resource descriptor, and image element group; asset/decode failure projects a bounded UI state or snackbar and leaves the document unchanged. For disposal, subscription and app-owned image cleanup must complete without disposing engine-owned state when the runtime was injected.

## Execution Units

### [x] Unit 1: Root example package, startup, default document, and cat asset

Owner:

`example/**`, `example/pubspec.yaml` asset/dependency declarations, `legacy/iwb_canvas_engine/image/cat.png` as donor input, `example/image/cat.png` as copied runtime asset, and app startup/default-document tests.

Boundary:

Establish the example as a runnable public consumer with its own Flutter entry point, package/dependency shape, default `CanvasDocument`, and transferred cat image asset. This unit must not implement full dock behavior, inline editing, JSON dialogs, or sample image insertion beyond the default app shell needed for later units.

Change:

Create the rebuilt root example app/package and startup surface. Create `example/pubspec.yaml` with Flutter SDK dependency, `iwb_canvas_engine: { path: ../ }`, `flutter.uses-material-design: true`, and `flutter.assets: [image/cat.png]`; add `vector_math` only under the conditional exception in `Dependency/import direction`. Construct the explicit equivalent default document through public DTOs: two empty content layers `CanvasLayerId('layer-auto-0')` and `CanvasLayerId('layer-auto-1')`; `CanvasCamera.origin`; `CanvasBackground(color: Color(0xFFFFFFFF), grid: CanvasGrid(enabled: false, cellSize: 10.0, color: Color(0x1F000000)))`; `CanvasPalette` with pen colors `0xFF000000`, `0xFFE53935`, `0xFF1E88E5`, `0xFF43A047`, `0xFFFB8C00`, `0xFF8E24AA`, background colors `0xFFFFFFFF`, `0xFFFFF9C4`, `0xFFBBDEFB`, `0xFFC8E6C9`, and grid sizes `10`, `20`, `40`, `80`. Construct the runtime with `CanvasRuntimeConfig(clearSelectionOnDrawModeEnter: true, pointerPolicy: CanvasPointerPolicy(tapSlop: 16, doubleTapSlop: 32, doubleTapMaxDelayMs: 450))` unless implementation proves a public API incompatibility, which blocks this step rather than silently changing parity. Copy the physical cat image from `legacy/iwb_canvas_engine/image/cat.png` to `example/image/cat.png`. Keep engine access through the public barrel only. Use Flutter `Matrix4`/rendering primitives for overlay transforms by default; do not add `vector_math` unless the conditional exception in `Dependency/import direction` is proven.

Completion Check:

A focused Flutter startup/pump test for the real example app proves the root example starts, builds the first screen, constructs a `CanvasRuntime` from public DTOs, and exposes the initial surface state without relying on compile-only or screenshot-only proof. Direct startup/default tests assert the runtime document has exactly layers `layer-auto-0` and `layer-auto-1`, camera origin, white background, disabled grid with cell size `10.0` and color `0x1F000000`, the explicit pen/background/grid-size palette above, `clearSelectionOnDrawModeEnter == true`, and pointer policy values `16`, `32`, and `450`. A separate package-boundary compile/import check may prove public-consumer import shape, but it cannot satisfy the startup behavior claim by itself. An asset/pubspec check fails unless `example/pubspec.yaml` contains `flutter.uses-material-design: true`, declares asset key `image/cat.png`, and `image/cat.png` loads through Flutter asset APIs from copied file `example/image/cat.png`. Example package verification includes `(cd example && flutter pub get)`, `(cd example && flutter analyze)`, and the focused startup/asset Flutter tests under the example package or an explicitly equivalent repository-root test command.

Depends On:

None.

### [x] Unit 2: Example view model runtime and public port mapping

Owner:

Example view model/application state files and their focused tests.

Boundary:

Replace legacy `SceneController` ownership with app-owned or injected `CanvasRuntime` lifecycle and public port calls. This unit owns app state projection and command methods, not widget layout, resource image IO, or dialogs.

Change:

Build the app view model around `CanvasRuntime`, `CanvasDocument`, runtime state/listeners, preview/action/context-request streams, and public edit/selection/tool/command/camera/resource/id ports. Preserve legacy mode/tool/color/selection/camera/grid/background/clear behavior through next-owned public APIs. Own subscriptions, app projection state, last-export placeholder state, and disposal policy; dispose only owned runtimes and app-owned resources.

Completion Check:

View-model tests prove owned runtime creation/disposal, injected runtime non-disposal, listener cancellation/no effects after dispose, default state projection, move/draw mode changes, pencil/marker/line/eraser selection, draw color changes, selection actions, camera pan/reset/indicator state, grid/background edits, and clear canvas behavior through public runtime state/document observations. The test fails if the view model imports legacy symbols, calls `src/**`, mutates engine internals, or patches only a UI flag without changing the public runtime outcome.

Depends On:

Unit 1.

### [x] Unit 3: Screen, CanvasSurface, controls dock, and pending preview

Owner:

Example screen/widgets for surface composition, controls dock, camera controls, pending-line overlay, and widget tests.

Boundary:

Compose the Flutter UI around the view model and public `CanvasSurface`. This unit owns visible controls and projection of public preview/state into widgets; it does not own sample image loading, inline text editor internals, or JSON dialogs beyond command entry points.

Change:

Port the legacy screen layout, camera controls, mode/tool dock, draw color controls, grid/background controls, selection actions, visible Add Sample command entry point, clear action, and pending-line indicator. Replace `SceneView` with `CanvasSurface(runtime: ..., resourceResolver: ...)`; derive pending-line marker from public preview state. Keep the app UI dense and usable without adding marketing or landing surfaces. Unit 3 only wires the Add Sample UI callback to the view-model command surface; Unit 4 owns the document/resource/rendering effects.

Completion Check:

Widget tests exercise the rendered screen with a public runtime: `CanvasSurface` is mounted, pointer gestures reach public runtime behavior, mode/tool/color/grid/background/camera/selection/clear controls invoke view-model commands and produce observable public state/document changes, the Add Sample control is visible and invokes the view-model Add Sample command entry point with a spy/fake command surface, and a pending line preview renders the app-owned indicator from public preview state. Unit 3 does not prove Add Sample document mutation; Unit 4 owns that proof. The proof fails if any widget imports `SceneView`, `SceneController`, `legacy/**`, or `lib/src/**`.

Depends On:

Unit 2.

### [x] Unit 4: Add Sample objects, cat image resolver, rendering, and disposal

Owner:

Example sample image service, app resolver, Add Sample command, asset tests, resource widget tests, and app-owned image cleanup.

Boundary:

Own all app image bytes, asset bundle loading, decoded `ui.Image` lifetime, resolver mapping, and Add Sample object insertion UI. Engine code receives only public resource descriptors and the app resolver passed to `CanvasSurface`.

Change:

Implement the rebuilt sample image asset service against copied asset `example/image/cat.png` using Flutter asset key `image/cat.png`; do not use the legacy `packages/iwb_canvas_engine/image/cat.png` key because the rebuilt example owns the asset as an app asset. Add a public Add Sample flow that first ensures cat asset decode/resolver readiness, then inserts all three legacy-visible objects through public DTOs/ports as one user-facing command result: a `140x90` rect with `Colors.blue.withValues(alpha: 0.2)` fill, `Colors.blue` stroke, and stroke width `2`; a text note with content `New Note`, font size `20`, and `Colors.black87`; and a resource-backed cat image with id/key equivalent to `sample-cat` and visible size `120x180`. Preserve the legacy offset/seed behavior closely enough that repeated Add Sample actions create distinct, visible groups rather than overlapping the same ids/position. Add an app resolver that returns the decoded cat image to `CanvasSurface`. If cat asset load/decode fails, show bounded UI/snackbar state and leave the document unchanged for that Add Sample invocation.

Completion Check:

Service tests prove `image/cat.png` loads from copied file `example/image/cat.png`, the legacy `packages/iwb_canvas_engine/image/cat.png` key is not required for the rebuilt example, decode failures are reported without document mutation, and app-owned images are disposed by the example lifecycle rather than by `CanvasSurface`/engine. Widget or view-model tests prove successful Add Sample adds a public rect element with `140x90` size, `Colors.blue.withValues(alpha: 0.2)` fill, `Colors.blue` stroke, and stroke width `2`; a public text element containing `New Note` with font size `20` and `Colors.black87`; a public resource descriptor and image element for `sample-cat`; unique ids/offsets across repeated invocations; and `CanvasSurface` asks the app resolver for that descriptor so the rendered path uses the decoded cat image. Failure-path tests prove cat load/decode failure leaves the prior document unchanged and projects only the bounded UI/snackbar error. A file/asset assertion fails if `legacy/iwb_canvas_engine/image/cat.png` was not copied to `example/image/cat.png` or if `image/cat.png` is not declared.

Depends On:

Unit 1, Unit 3.

### [x] Unit 5: Text options and inline text editing

Owner:

Example text options panel, inline text overlay, app editor state, view-model text commands, and focused tests.

Boundary:

Preserve text-style controls and request-originated inline editing as application UI over public runtime requests. This unit must not mutate target visibility to hide text and must not fabricate interaction request ids.

Change:

Port selected text controls for bold, italic, underline, alignment, font size, line height, and color through public element update/edit behavior. Listen to public context action requests, open app-owned `TextField` overlay/focus/controller state for text targets, visually cover or hide the target through overlay UI only, commit changed text through `CanvasCommandPort.commitTextEdit`, and clean up overlay state on accepted/no-op/stale/unknown/dismiss paths.

Completion Check:

Widget/view-model tests prove selected text style controls change the public document through valid public updates. Inline edit tests prove double-tap/context request delivery opens the overlay, focus/controller are app-owned, no visibility patch or runtime load occurs before commit, changed text calls `commitTextEdit` and updates the public document only on accepted commit, stale/unknown/no-op results do not manually mutate the document, dismiss closes the overlay without mutation, and disposal clears overlay state/listeners.

Depends On:

Unit 2, Unit 3.

### [x] Unit 6: Schema v1 JSON export/import dialogs and error projection

Owner:

Example import/export dialog widgets, clipboard/snackbar integration, view-model JSON workflow, and focused tests.

Boundary:

Preserve the user-facing JSON workflow using rebuilt schema v1 `CanvasDocument` JSON only. This unit does not add legacy scene JSON compatibility or a migration bridge.

Change:

Implement export dialog generation from the current public document through `encodeCanvasDocumentToJson`, copy action, import dialog prefilled from last export, valid import through `decodeCanvasDocumentFromJson` followed by public `runtime.edits.loadDocument`, and invalid input error/snackbar without document mutation.

Completion Check:

Widget/view-model tests prove export dialog contains schema v1 document JSON, copy action sends the exported text to clipboard, import dialog pre-fills the last export, valid schema v1 JSON replaces the runtime document through public load, invalid JSON and legacy scene JSON payloads show a bounded snackbar/error and leave the previous document unchanged. The test fails if `encodeSceneToJson`, `decodeSceneFromJson`, or legacy scene payload translation appears in example code.

Depends On:

Unit 2, Unit 3.

### [x] Unit 7: Example parity proof, structural guardrails, docs, and final checks

Owner:

Example tests, public-consumer/structural test surfaces, guardrail tooling if coverage must be extended, verification docs if new guardrail/test ids are introduced, and final repository verification.

Boundary:

Make the example port enforceable. This unit owns proof coverage and source-of-truth updates caused by new verification behavior; it does not add new user-facing features.

Change:

Add or update the example parity test inventory so the full research capability list is covered by focused tests from Units 1 through 6. Add a structural scan modeled after the external app-adapter fixture test that covers `example/**` and example tests for exactly one public engine import path, no `lib/src/**`, no `legacy/**`, no retired legacy symbols/codecs/specs/patches/controllers/views, and no application-adapter responsibility under production `lib/**`. Add a mechanical no-production-lib check that evaluates the step diff file list with `git diff --name-only -- lib` during uncommitted review or the equivalent committed step range during final review and fails if any production `lib/**` path appears; if such a change is needed, implementation stops for a separate engine contract. Update `docs/verification/**`, generated docs, guardrail registry/executor, or release-gate docs only if new durable verification ids or meanings are introduced. Run the repository-required checks for code, focused tests, scoped DCM metrics, documentation if docs changed, and release/architecture checks only if their surfaces are touched.

Completion Check:

The structural test fails on injected example imports of `lib/src/**`, `legacy/**`, `SceneController`, `SceneView`, `NodeSpec`, `NodePatch`, `PatchField`, `encodeSceneToJson`, or `decodeSceneFromJson`. The same proof fails if this step adds or modifies production `lib/**` files, which prevents any engine-side application adapter from being introduced under a different name. Focused tests from Units 1 through 6 cover every research-listed visible workflow: startup/default document parity, rendering, pointer interaction, modes, draw tools, colors, selection, camera, grid/background, Add Sample rect/text/cat image insertion/rendering, JSON export/import/copy/error, clear, pending line, text options, inline editing, dialogs, snackbars, and lifecycle cleanup. Baseline final commands for the example port are `dart analyze`, `(cd example && flutter pub get)`, `(cd example && flutter analyze)`, `dcm analyze .`, scoped `dcm calculate-metrics` for changed production/test/tool/example owners, and focused Flutter/Dart tests for the example plus the structural scan. Run documentation checks if docs changed. Run release-closure commands only if implementation also claims release readiness/closure or changes release/guardrail/benchmark surfaces; those conditional commands are `dart test test/api_contract/app_next_engine_adapter_compile_fixture_test.dart`, `dart test test/benchmarks/required_cases_test.dart`, `dart test test/guardrails/blocking_suite_test.dart`, and `dart run tool/guardrails/run.dart`, plus explicit release-gate 37 proof that `AppCanvasPort`, `LegacyEngineAdapter`, and `NextEngineAdapter` are not present in engine package source. If architecture graph ownership or release-gate closure is touched, run `dart run tool/architecture_graph/check.dart --phase P14` and `dart run tool/architecture_graph/generate_views.dart --phase P14 --check`.

Depends On:

Units 1, 2, 3, 4, 5, and 6.
