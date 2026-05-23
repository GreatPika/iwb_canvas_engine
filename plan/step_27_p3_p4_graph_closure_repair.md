# Change Contract

## Goal

Close the selected P4 architecture graph by implementing the already-approved P3 diagnostics route and P4 runtime camera ownership obligations, then retire the temporary verification documentation that treats those violations as expected.

## Evidence

- `PLAN.md` / active roadmap: Steps 23 and 24 are checked complete while no later roadmap step owns the remaining P3/P4 closure failures -> this step owns the repair before further phase work depends on the closed graph.
- `docs/architecture/architecture_graph.yaml` / selected-phase obligations: `api.canvas_runtime.exposes_camera`, `api.canvas_runtime.camera.routes_to_runtime_view_camera`, and `codec.schema_v1.failures.report_to_diagnostics` are required by P4/P3, and `runtime.canvas_runtime.camera.closed_phase_placeholder` is forbidden after P4 -> implementation must satisfy these graph facts rather than rephase or remove them.
- `docs/diagrams/generated/actual_vs_expected_diff.mmd` / generated diff: the generated P4 diff reports missing camera delegation links, missing codec-to-diagnostics routing, and an old camera placeholder -> generated diagrams must be updated only after source graph facts are fixed.
- `lib/src/api/canvas_runtime.dart` / public facade: `CanvasRuntime.camera` currently throws `UnimplementedError` while other implemented P4 runtime members delegate through `RuntimeRoot` -> the camera port must become a real runtime-owned facade path.
- `tool/guardrails/src/public_api_placeholder_allowlist.dart` / placeholder enforcement: `CanvasRuntime.camera` remains allowlisted with owner phase `P4` -> closing P4 requires removing this allowlist entry once the facade is implemented.
- `docs/contracts/public_api_v1.md` / camera contract: `CanvasCameraPort` owns the runtime view camera, validates offset values, updates only `state.revisions.viewCamera`, and does not mutate the persisted document camera -> runtime implementation and tests must preserve this compatibility behavior.
- `docs/architecture/01_runtime_ownership.md` / runtime ownership: runtime view camera is owned by `RuntimeRoot/CanvasCameraPort` and is distinct from persisted `CanvasDocument.camera` -> the fix belongs in runtime ownership, not in document storage or edit behavior.
- `docs/contracts/codec_boundary.md` / codec boundary: schema v1 decode validates external data before DTO materialization and has no runtime/store side effects -> diagnostics routing must stay inside the codec/diagnostics boundary and must not introduce runtime coupling.
- `docs/contracts/diagnostics.md` / diagnostics contract: `DiagnosticsHub` is internal, policy-gated, sanitized, and does not add a public stream -> codec failure routing must use internal diagnostics without changing the public exception surface.
- `lib/src/api/canvas_codec.dart` / public codec API: public encode/decode entrypoints have no diagnostics parameter and delegate to schema v1 internals -> compatibility requires public decode to keep the same signatures while internal schema v1 entrypoints carry optional diagnostics injection.
- `tool/architecture_graph/src/actual_graph.dart` and `tool/architecture_graph/src/phase_closure.dart` / graph extraction: selected graph facts are detected from expression-bodied delegation members, public placeholders, member calls, and sensitive throw routes -> implementation must use graph-checkable routes, not behavior that only works at runtime.
- `docs/verification/release_gates.md` and `docs/verification/guardrails.md` / temporary verification policy: the current P4 graph check is documented as expected to fail for camera ownership and codec diagnostics routing -> this exception must be removed after the repair makes strict graph closure pass.
- `docs/README.md` / documentation checks: documentation integrity is checked with `dart run docs/tool/sync_generated_docs.dart --check`, `dart run docs/tool/check_docs.dart`, and P4 generated architecture graph view checks -> documentation updates must pass the repository-local doc tooling, not only the selected graph checker.
- `docs/architecture/01_runtime_ownership.md`, `docs/contracts/public_api_v1.md`, `docs/contracts/codec_boundary.md`, and `docs/contracts/diagnostics.md` / architecture conformance inputs: these prose contracts contain semantic obligations that are broader than graph topology and documentation tooling -> implementation completion requires an explicit code-to-document conformance review with file/line evidence, not only generated graph and docs checks.

## Boundaries

Owner:

P4 camera ownership is owned by `CanvasRuntime` and `RuntimeRoot`. P3 codec failure diagnostics are owned by schema v1 codec/diagnostics internals. Verification exception cleanup is owned by `docs/verification` and generated architecture graph outputs.

In Scope:

- Implement `CanvasRuntime.camera` as a public facade over runtime-owned view camera state.
- Add or extend the runtime owner needed for `CanvasCameraPort.camera`, `offset`, `setOffset`, and `panBy`.
- Preserve persisted document camera semantics: runtime camera changes do not change `readDocument().camera`, document revision, or document projection ownership.
- Validate runtime camera offsets through the existing public value validation/error contract.
- Remove the `CanvasRuntime.camera` P4 public placeholder allowlist entry after implementation.
- Route every schema v1 codec failure path that throws a public data exception through a graph-checkable diagnostics bridge to `DiagnosticsHub`.
- Keep public codec functions parameter-free; pass diagnostics only through internal schema v1/codec-boundary entrypoints.
- Preserve schema v1 wire format, DTO materialization, public exception fields, and no-runtime-side-effect guarantees.
- Update generated architecture graph Mermaid outputs and verification documentation after the strict selected-phase graph is closed.

Out of Scope:

- Changing `docs/architecture/architecture_graph.yaml` required P3/P4 obligations, weakening graph extraction, or reclassifying the existing violations as future work.
- Implementing edit, load replacement, resource runtime, preview, pointer routing, paint, Flutter surface, or action-stream behavior.
- Persisting runtime camera changes into `CanvasDocument.camera` except through later edit/load behavior.
- Adding a public diagnostics stream or changing `CanvasDataException` public shape.
- Adding global mutable diagnostics state or making free public codec decode depend on `RuntimeRoot`.
- Hand-editing generated files under `docs/diagrams/generated/**`.

Source of Truth:

`docs/architecture/architecture_graph.yaml`, `docs/architecture/01_runtime_ownership.md`, `docs/contracts/public_api_v1.md`, `docs/contracts/codec_boundary.md`, `docs/contracts/diagnostics.md`, `docs/verification/release_gates.md`, and `docs/verification/guardrails.md`.

Compatibility:

Public API signatures, schema v1 JSON shape, public DTO shapes, and public exception fields must remain compatible. Existing P3/P4 behavior that is unrelated to camera runtime ownership or codec diagnostic routing must remain unchanged. New diagnostics records must remain internal and policy-gated.

Order Constraints:

Implement runtime camera ownership before removing the camera placeholder allowlist entry. Add the internal diagnostics injection route before converting codec throws to the graph-checkable bridge. Implement codec diagnostics routing before removing the graph-closure exception from verification docs. Regenerate generated architecture diagrams only after code and source documentation agree. Complete the code-to-architecture-document conformance review after code/tests are in place and before final repository-wide verification. Run repository-wide analysis and metrics checks after all code changes are complete.

## Execution Units

### [ ] Unit 1: Runtime-Owned Camera Port

Owner:

`CanvasRuntime` and `RuntimeRoot`.

Boundary:

Public camera facade, runtime-owned view camera state, runtime state publication, and focused runtime/API tests.

Change:

Back `CanvasRuntime.camera` with runtime-owned `CanvasCameraPort` behavior through `RuntimeRoot`. Initialize runtime view camera from the initial document camera, expose `camera` and `offset`, validate `setOffset`/`panBy` offsets with the existing public `CanvasDataException` validation path, increment only `state.revisions.viewCamera` for accepted camera mutations, publish state snapshots, and leave persisted document camera/projection state unchanged. Remove `CanvasRuntime.camera` from the public placeholder allowlist only after the port is implemented.

Completion Check:

`dart test test/runtime` includes a focused camera-port test proving initial runtime camera projection, `setOffset`/`panBy` state publication, `viewCamera` revision increments, unchanged `document` revision, unchanged `readDocument().camera`, and invalid offset rejection with `CanvasDataException`. `dart test test/api_contract/public_api_no_unapproved_placeholders_test.dart` passes without a `CanvasRuntime.camera` allowlist entry. `dart run tool/architecture_graph/check.dart --phase P4` no longer reports `api.canvas_runtime.exposes_camera`, `api.canvas_runtime.camera.routes_to_runtime_view_camera`, or `runtime.canvas_runtime.camera.closed_phase_placeholder`.

Depends On:

None.

### [ ] Unit 2: Schema V1 Failure Diagnostics Route

Owner:

Schema v1 codec and diagnostics internals.

Boundary:

Codec failure construction, internal diagnostics recording, codec/diagnostics tests, and graph-checkable sensitive throw routing.

Change:

Add an internal schema v1 diagnostics injection path without changing public codec signatures: public `decodeCanvasDocument` and `decodeCanvasDocumentFromJson` continue to call schema v1 internals without a hub, while internal schema v1 decode entrypoints accept an optional `DiagnosticsHub`. Implement a graph-checkable `recordSchemaV1FailureDiagnostic(DiagnosticsHub? hub, CanvasDataException exception)` bridge that records sanitized codec diagnostics when a hub is supplied and returns the same exception for throwing. Each schema v1 member that throws `CanvasDataException` must throw through the bridge in the same member so the architecture graph can see the sensitive throw route. Enabled diagnostics are supplied only by internal callers or tests that explicitly construct a `DiagnosticsHub` from a `CanvasDiagnosticPolicy`; there is no global diagnostics state and no runtime/store dependency from codec code. Keep diagnostics policy-gated and internal, keep public exception fields unchanged, keep public free decode behavior compatible, and keep decode failures side-effect-free with respect to runtime/store state.

Completion Check:

Codec and diagnostics tests prove public decode signatures remain parameter-free, public decode without a hub throws the same `CanvasDataException` code/path/message for representative schema v1 failures, internal decode with `DiagnosticsHub(policy: CanvasDiagnosticsSummary or CanvasDiagnosticsVerbose)` records sanitized codec failure details, internal decode without a hub or with disabled policy records nothing, and no runtime/store imports or side effects are introduced. `dart test test/codec test/diagnostics` passes. `dart run tool/architecture_graph/check.dart --phase P4` no longer reports `codec.schema_v1.failures.report_to_diagnostics`.

Depends On:

None.

### [ ] Unit 3: Verification Exception Retirement

Owner:

Architecture graph generated outputs and verification documentation.

Boundary:

Generated graph Mermaid files, diagram catalog if generated tooling changes it, and verification docs that currently describe P4 graph closure as expected to fail.

Change:

After Units 1 and 2 close the strict graph, regenerate architecture graph views for P4 with `dart run tool/architecture_graph/generate_views.dart --phase P4`, then remove the temporary verification text that says P4 graph closure is expected to fail for camera ownership or codec diagnostics routing. Keep the generated files consistent with `docs/architecture/architecture_graph.yaml`, keep the strict selected-phase check documented as a real closure gate, and preserve alignment with the architecture/contract documents named in Source of Truth. Use the same generate-views command with `--check` as the final drift signal.

Completion Check:

`dart run tool/architecture_graph/generate_views.dart --phase P4 --check`, `dart run docs/tool/sync_generated_docs.dart --check`, and `dart run docs/tool/check_docs.dart` pass. `dart run tool/architecture_graph/check.dart --phase P4` exits 0, `docs/diagrams/generated/actual_vs_expected_diff.mmd` contains no violation nodes, and `docs/verification/release_gates.md` plus `docs/verification/guardrails.md` no longer describe the P4 camera/codec graph failures as expected. The implementation leaves the required P3/P4 obligations in `docs/architecture/architecture_graph.yaml`, `docs/architecture/01_runtime_ownership.md`, `docs/contracts/public_api_v1.md`, `docs/contracts/codec_boundary.md`, and `docs/contracts/diagnostics.md` intact; any contradiction between those documents and the implementation is a blocker, not a reason to weaken the documents.

Depends On:

Units 1 and 2.

### [ ] Unit 4: Code-To-Architecture Conformance Review

Owner:

Implementation reviewer for architecture conformance.

Boundary:

Changed production code, changed tests, `docs/architecture/01_runtime_ownership.md`, `docs/contracts/public_api_v1.md`, `docs/contracts/codec_boundary.md`, and `docs/contracts/diagnostics.md`.

Change:

Perform an explicit semantic review of the implementation against the named architecture and contract documents. The review must check that runtime camera ownership, persisted document camera separation, state revision publication, offset validation, codec boundary ownership, diagnostics policy gating, diagnostics sanitization, public exception compatibility, and no runtime/store side effects all match the source documents. This review is not satisfied by `architecture_graph/check.dart`, generated Mermaid checks, `check_docs.dart`, or tests alone.

Completion Check:

Before the step can be marked complete, the implementation handoff or review result includes a PASS/FAIL conformance table with file/line evidence from both the changed code/tests and the four source documents. Every row must either pass or identify a concrete implementation repair. Any mismatch between implementation and those documents is a blocker; do not resolve it by weakening the architecture documents or graph obligations in this step.

Depends On:

Units 1 and 2.

### [ ] Unit 5: Repository-Wide Closure Verification

Owner:

Repository verification commands.

Boundary:

Project analysis, DCM analysis, DCM metrics, focused test suites from the prior units, documentation integrity checks, selected-phase architecture graph closure, and the code-to-architecture conformance review result.

Change:

Run the repository-required checks after the code and documentation repairs are complete, and fix only issues caused by this step inside the owners already named by Units 1 through 3.

Completion Check:

`dart analyze`, `dcm analyze .`, `dcm calculate-metrics .`, `dart test test/runtime test/api_contract/public_api_no_unapproved_placeholders_test.dart test/codec test/diagnostics`, `dart run tool/architecture_graph/check.dart --phase P4`, `dart run tool/architecture_graph/generate_views.dart --phase P4 --check`, `dart run docs/tool/sync_generated_docs.dart --check`, and `dart run docs/tool/check_docs.dart` all pass in the implementation environment. Any metrics suppression added during this step has a nearby plain-language reason and is scoped to the cohesive declaration or file that requires it.

Depends On:

Units 1, 2, 3, and 4.

## Code-To-Architecture Conformance Review

Result: PASS.

| Concern | Source document evidence | Implementation and test evidence | Result |
| --- | --- | --- | --- |
| Runtime camera ownership | `docs/architecture/01_runtime_ownership.md:93` says runtime view camera is owned by `RuntimeRoot/CanvasCameraPort`; `docs/contracts/public_api_v1.md:1748` says `CanvasCameraPort` owns the runtime view camera. | `lib/src/api/canvas_runtime.dart:45` delegates `CanvasRuntime.camera` to `RuntimeRoot`; `lib/src/runtime/runtime_root.dart:51` stores `_viewCamera`; `lib/src/runtime/runtime_root.dart:329` implements `_RuntimeCameraPort`. | PASS |
| Persisted document camera separation | `docs/architecture/01_runtime_ownership.md:102` says persisted camera is committed document content; `docs/contracts/public_api_v1.md:1751` says `readDocument().camera` exposes the persisted document camera. | `lib/src/runtime/runtime_root.dart:231` mutates only `_viewCamera`; `test/runtime/runtime_camera_port_test.dart:35` through `test/runtime/runtime_camera_port_test.dart:57` proves runtime camera changes leave `readDocument().camera` and document revision unchanged. | PASS |
| State revision publication | `docs/architecture/01_runtime_ownership.md:71` says `RuntimeRoot` publishes runtime state; `docs/architecture/01_runtime_ownership.md:96` says view camera is published through `state.revisions.viewCamera`. | `lib/src/runtime/runtime_root.dart:238` increments `_viewCameraRevision`; `lib/src/runtime/runtime_root.dart:274` publishes the runtime state snapshot; `test/runtime/runtime_camera_port_test.dart:46` through `test/runtime/runtime_camera_port_test.dart:57` proves `viewCamera` increments and `document` does not. | PASS |
| Offset validation | `docs/contracts/public_api_v1.md:1746` requires finite x/y within the coordinate range. | `lib/src/runtime/runtime_root.dart:233` constructs `CanvasCamera`, reusing the public value validation path; `test/runtime/runtime_camera_port_test.dart:60` through `test/runtime/runtime_camera_port_test.dart:77` proves invalid offsets throw `CanvasDataException` without state mutation. | PASS |
| Codec boundary ownership | `docs/contracts/codec_boundary.md:43` defines schema v1 decode/encode as `CodecBoundary` ownership; `docs/contracts/codec_boundary.md:56` through `docs/contracts/codec_boundary.md:72` requires validation before DTO materialization and no runtime/store side effects. | `lib/src/api/canvas_codec.dart:21` through `lib/src/api/canvas_codec.dart:27` keeps public decode entrypoints parameter-free; `lib/src/codec/schema_v1_decoder.dart:20` through `lib/src/codec/schema_v1_decoder.dart:69` owns internal schema v1 decode and validation; `test/codec/schema_v1/diagnostics_routing_test.dart:19` through `test/codec/schema_v1/diagnostics_routing_test.dart:31` checks no runtime/store dependency. | PASS |
| Diagnostics policy gating and sanitization | `docs/contracts/diagnostics.md:31` states `DiagnosticsHub` is internal; `docs/contracts/diagnostics.md:33` through `docs/contracts/diagnostics.md:40` requires disabled diagnostics to avoid records and eager details; `docs/contracts/diagnostics.md:69` through `docs/contracts/diagnostics.md:82` requires sanitized bounded details. | `lib/src/codec/schema_v1_diagnostics.dart:13` through `lib/src/codec/schema_v1_diagnostics.dart:31` records only when a hub is supplied and uses `DiagnosticsHub.record`; `test/codec/schema_v1/diagnostics_routing_test.dart:62` through `test/codec/schema_v1/diagnostics_routing_test.dart:115` proves enabled policies record sanitized codec failures while null/disabled diagnostics record nothing. | PASS |
| Public exception compatibility | `docs/contracts/diagnostics.md:57` through `docs/contracts/diagnostics.md:59` says public exceptions expose only code, message, path, and sanitized details; `docs/contracts/codec_boundary.md:50` through `docs/contracts/codec_boundary.md:53` fixes public codec signatures. | `lib/src/codec/schema_v1_diagnostics.dart:4` through `lib/src/codec/schema_v1_diagnostics.dart:7` returns the same `CanvasDataException` for throwing; `test/codec/schema_v1/diagnostics_routing_test.dart:42` through `test/codec/schema_v1/diagnostics_routing_test.dart:59` proves public decode signatures remain parameter-free and public/internal failures match code, message, path, and details. | PASS |
