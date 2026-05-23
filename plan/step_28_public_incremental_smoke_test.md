# Change Contract

## Goal

Add one public incremental smoke test that proves an ordinary external Flutter consumer can decode a small schema v1 document, construct `CanvasRuntime` with that decoded document, observe initial public state, read the public document projection, perform one public selection operation, and observe the updated public state. The change is verification-only and must not change production runtime behavior or public API shape.

## Evidence

- `.design/2026-05-23-public-incremental-smoke-test.md` / disposition: the design is ready for contract and classifies the work as SOURCE_OF_TRUTH_DOCS with no extra obligations -> create an executable verification step plus source-of-truth inventory update, not a production behavior change.
- `.design/2026-05-23-public-incremental-smoke-test.md` / selected form: the selected form is an external consumer behavior smoke through the shared harness -> the test belongs in a smoke-oriented test file using the consumer harness.
- `.design/2026-05-23-public-incremental-smoke-test.md` / scenario: the required P0-P4 scenario is schema map decode, runtime construction, initial `state.value`, `readDocument()`, `selection.setSelection([CanvasElementId('element-a')])`, and updated state assertions -> implement exactly that happy path as the first smoke step.
- `.design/2026-05-23-public-incremental-smoke-test.md` / future expansion rule: future additions must append only public user steps and must not import `src/**`, inspect private revisions, or turn infrastructure-only phases into private smoke probes -> keep the initial test small and document the future extension rule in the test responsibility inventory.
- `.research/2026-05-23-p0-p4-smoke-test-facts.md` / public vertical path: the implemented P0-P4 public path includes codec entrypoints, runtime construction, state observation, `readDocument()`, selection commands, and camera updates -> the smoke can use decode/runtime/state/read/selection without waiting for later phases.
- `.research/2026-05-23-p0-p4-smoke-test-facts.md` / focused coverage: existing tests already cover individual API, codec, runtime, projection, camera, and selection pieces -> the smoke must assert only coarse cross-layer facts and leave detailed diagnostics to focused tests.
- `.research/2026-05-23-p0-p4-smoke-test-facts.md` / later phase pressure: edit, load, resources, geometry/spatial, frame, interaction, draw, eraser/text, Flutter surface, and release readiness arrive later -> exclude unimplemented or infrastructure-only future ports from this step.
- `docs/verification/tests.md` / generated context header: the verification tests document is backed by registry source `docs/_registry/sections.yaml` -> required-test inventory changes must update the registry source and regenerated documentation, not only manual prose.
- `docs/verification/tests.md` / required test inventory: required test files are listed explicitly -> adding a new required smoke test requires adding it to this inventory.
- `docs/verification/tests.md` / test shape rules: external consumer behavior tests prove ordinary consumers can import the root public barrel and must use `test/support/flutter_consumer_test_harness.dart` -> the smoke must use that harness instead of custom temp-package logic.
- `docs/_registry/sections.yaml` / `section_23_tests`: required test ids for `docs/verification/tests.md` are listed under the section registry -> add the new id `test.smoke.public_incremental_smoke` there so generated context and indexes stay aligned.
- `docs/README.md` / checks: documentation updates are checked with `dart run docs/tool/sync_generated_docs.dart --check`, `dart run docs/tool/check_docs.dart`, and `dart run tool/architecture_graph/generate_views.dart --phase P4 --check` -> implementation verification must include these doc checks after registry or verification-doc changes.
- `test/support/flutter_consumer_test_harness.dart` / harness API: feature tests own only `packageName`, `testFileName`, and `testSource`, while the harness owns temp package creation, pub get, `flutter test`, and cleanup -> the new test file should only provide those three inputs.
- `lib/src/api/canvas_codec.dart` / public codec API: `decodeCanvasDocument` accepts a schema map and delegates to schema v1 decode -> schema decoding is the public entry boundary for the smoke.
- `lib/src/api/canvas_runtime.dart` / public runtime API: `CanvasRuntime` accepts an optional initial document and exposes `readDocument`, `state`, and `selection` -> these are the runtime boundaries the smoke should exercise.
- `lib/src/api/canvas_runtime.dart` / current placeholders: `edits`, `tools`, `commands`, `resources`, `preview`, `actions`, and `contextActionRequests` still throw `UnimplementedError` -> do not use later-phase public ports in this step.

## Boundaries

Owner:

`test/smoke/public_incremental_smoke_test.dart` owns the executable smoke scenario. `docs/_registry/sections.yaml` owns the generated required-test id `test.smoke.public_incremental_smoke` for `section_23_tests`. `docs/verification/tests.md` owns the generated context display, the manual path-based Required Test Inventory entry, and the manual responsibility note for this smoke proof.

In Scope:

Add `test/smoke/public_incremental_smoke_test.dart` using `runFlutterConsumerTest`. The generated consumer test source must import only `dart:ui`, `package:flutter_test/flutter_test.dart`, and `package:iwb_canvas_engine/iwb_canvas_engine.dart`. The consumer test must build a small schema v1 map with explicit camera, background, palette, empty resources, empty background layer, one layer, one selectable rect element with id `element-a`, and metadata; decode it with `decodeCanvasDocument`; construct `CanvasRuntime(initialDocument: decodedDocument)`; register `addTearDown(runtime.dispose)`; assert initial public summary/revisions; call `runtime.readDocument()` and assert the decoded camera and element id are visible; call `runtime.selection.setSelection([CanvasElementId('element-a')])`; assert `selectedCount == 1`, `revisions.selection == 1`, `revisions.document == 0`, and the public selected ids contain only `element-a`. Add `test.smoke.public_incremental_smoke` to `docs/_registry/sections.yaml` under `section_23_tests`, regenerate generated documentation and indexes affected by that registry id, manually add `test/smoke/public_incremental_smoke_test.dart` to the path-based Required Test Inventory in `docs/verification/tests.md`, and add the new test responsibility entry to `docs/verification/tests.md`, including that future expansion is append-only through public user steps.

Out of Scope:

Do not change production code, public API declarations, schema semantics, runtime internals, guardrail tooling, consumer harness behavior, CI configuration, benchmarks, unrelated generated navigation, or existing focused tests unless the smoke reveals a real defect and the contract is amended before implementation continues. Generated documentation and indexes may change only as the direct result of adding `test.smoke.public_incremental_smoke` to `section_23_tests`. Do not assert projection cache identity, private revision counters, `RuntimeRoot`, store internals, frame/spatial/geometry internals, invalid input paths, selection edge cases, camera movement, edit/load/resources/tools/actions/context-action placeholders, or later-phase behavior.

Source of Truth:

`.design/2026-05-23-public-incremental-smoke-test.md` is the design input. `docs/_registry/sections.yaml` is the source of truth for the generated required-test id. `docs/verification/tests.md` is the generated/manual verification document that displays generated context, owns the manual path-based Required Test Inventory entry, and owns the test responsibility note. The root public barrel remains the public consumer import boundary.

Compatibility:

No public API, data format, config schema, production behavior, or consumer harness contract may change. The smoke must compile and run from an external generated Flutter package using only the root public barrel plus Flutter/Dart SDK test imports.

Order Constraints:

Create the smoke test before updating the verification inventory so the documented path exists. The smoke scenario order is fixed: build schema map, decode, construct runtime, read initial state, read document projection, perform selection, assert updated public state. After adding the registry test id, regenerate generated documentation before checking docs. Run the focused smoke test before repository-wide analysis, DCM checks, and documentation checks.

## Execution Units

### [ ] Unit 1: Add public consumer smoke proof

Owner:

`test/smoke/public_incremental_smoke_test.dart`

Boundary:

One external consumer behavior test file using `test/support/flutter_consumer_test_harness.dart`; the generated consumer source may import only `dart:ui`, `package:flutter_test/flutter_test.dart`, and `package:iwb_canvas_engine/iwb_canvas_engine.dart`.

Change:

Add a single readable smoke test that calls `runFlutterConsumerTest` with a smoke-specific package name and generated test file name. The generated consumer test must execute the P0-P4 happy path from schema v1 map through `decodeCanvasDocument`, `CanvasRuntime(initialDocument:)`, `addTearDown(runtime.dispose)`, initial `runtime.state.value`, `runtime.readDocument()`, `runtime.selection.setSelection([CanvasElementId('element-a')])`, and updated public state/selected-id assertions. Keep assertions coarse: zero initial revisions, one element, one layer, zero resources, zero selected elements, decoded camera and element id visible through `readDocument()`, then selected count one, selection revision one, document revision zero, and selected ids exactly `element-a`.

Completion Check:

`dart test test/smoke/public_incremental_smoke_test.dart` passes, and the generated consumer test source in `test/smoke/public_incremental_smoke_test.dart` contains no `src/`, `RuntimeRoot`, projection-cache, store-kernel, frame/spatial/geometry internal, edit/load/resource/tool/action/context-action placeholder, invalid-input, or camera-operation assertions.

Depends On:

None.

### [ ] Unit 2: Register smoke proof in verification source of truth

Owner:

`docs/_registry/sections.yaml` and `docs/verification/tests.md`

Boundary:

Required test registry id, generated context/index outputs caused by that id, manual path-based required test inventory, and test responsibility documentation only.

Change:

Add `test.smoke.public_incremental_smoke` to `docs/_registry/sections.yaml` under `section_23_tests`, regenerate generated documentation and indexes affected by that registry id, manually add `test/smoke/public_incremental_smoke_test.dart` to the path-based `### Required Test Inventory` in `docs/verification/tests.md`, and add a concise responsibility entry stating that it proves the public consumer decode-to-runtime-to-selection happy path through the root barrel, uses the shared Flutter consumer harness, intentionally avoids duplicating focused codec/runtime/selection/cache tests, and should be extended only by appending the next real public user step after future phases expose one.

Completion Check:

`docs/_registry/sections.yaml` contains `test.smoke.public_incremental_smoke` in `section_23_tests`; regenerated generated context/index outputs are current; the manual `### Required Test Inventory` in `docs/verification/tests.md` lists `test/smoke/public_incremental_smoke_test.dart`; and `docs/verification/tests.md` contains exactly one responsibility entry for that file that names the public consumer path, the harness boundary, the coarse smoke purpose, and the append-only public-step expansion rule.

Depends On:

Unit 1.

### [ ] Unit 3: Run focused and required code checks

Owner:

Repository verification commands from the root package.

Boundary:

Verification only; no file edits except fixes required by failures within Units 1-2 and consistent with this contract.

Change:

Run the focused smoke test, repository-required code checks, and documentation checks after implementation.

Completion Check:

From the repository root, `dart test test/smoke/public_incremental_smoke_test.dart`, `dart analyze`, `dcm analyze .`, `dcm calculate-metrics .`, `dart run docs/tool/sync_generated_docs.dart --check`, `dart run docs/tool/check_docs.dart`, and `dart run tool/architecture_graph/generate_views.dart --phase P4 --check` all pass, or any failure is reported with the exact failing command and reason before the step is marked complete.

Depends On:

Unit 1 and Unit 2.
