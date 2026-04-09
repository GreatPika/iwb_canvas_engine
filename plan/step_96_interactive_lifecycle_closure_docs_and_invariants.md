# Change Contract

## 1. Change Mandate

This change closes the interactive lifecycle sequence by aligning repository
docs, invariant registry, proof markers, and roadmap state with steps `92-95`.

## 2. Change Boundary

### Included in the Change

- source-of-truth doc updates for the final interactive lifecycle shape
- invariant-registry additions for interruption semantics, draw-style
  snapshotting, and pointer-session detachment
- proof-marker alignment in the tests that act as primary invariant proofs
- roadmap updates that reflect the split `92-96` sequence and this closure

### Not Included in the Change

- reopening production owner changes from steps `92-95`
- any new interactive runtime behavior beyond repo-local documentation and
  enforcement closure
- any new standalone closure tool outside the existing guardrail and invariant
  coverage pipelines

## 3. File Map and Analysis Areas

### Implementation Files

- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`
- `PLAN.md`
- `tool/invariant_registry.dart`

### Test Files

- `test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart`
- `test/interactive/core/scene_controller_interactive_line_tool_flow_test.dart`
- `test/view/scene_view_interactive_test.dart`
- `test/tool/support/guardrails_tool_test_support.dart`

### Fixture and Supporting Data Files

- `VERIFICATION.md`
- `plan/step_92_session_routed_input_boundary.md`
- `plan/step_93_interactive_runtime_lifecycle_reason_split.md`
- `plan/step_94_draw_style_snapshot_and_pending_line_ownership.md`
- `plan/step_95_pointer_session_detach_contract_and_host_ordering.md`
- `plan/step_96_interactive_lifecycle_closure_docs_and_invariants.md`

### Analysis Area

- `VERIFICATION.md`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`
- `PLAN.md`
- `tool/invariant_registry.dart`
- `tool/check_guardrails.dart`
- `tool/check_invariant_coverage.dart`
- `test/interactive/**`
- `test/view/**`
- `test/tool/support/**`
- `plan/step_92*.md`
- `plan/step_93*.md`
- `plan/step_94*.md`
- `plan/step_95*.md`
- `plan/step_96*.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which the listed
  verification cannot be closed.

### File Change Rule

- Every modified documentation file must describe the final interactive
  lifecycle shape or remove stale wording from the pre-split step `92`.
- Every modified proof file must be tied to an invariant title or proof-marker
  alignment required by this closure.
- Every newly proposed file or directory name must comply with the global
  `AGENTS.md` section `### File naming`.

## 4. Locked Decisions

1. Steps `92-95` define the production owner graph for this sequence; this
   step does not reopen them as its main subject.
2. Manual public pointer input remains on `SceneControllerInteraction`.
3. Session-routed input uses an internal tokenized path and does not return to
   the public facade.
4. Interaction-config interruption, external mutation interruption, session
   detachment, and dispose remain distinct lifecycle reasons.
5. Active draw style is captured on gesture start, and pending line remains
   draw-local latent state with owner provenance.
6. View hosts detach sessions before replacement or disposal.

## 5. Result Requirements

1. `README.md`, `API_GUIDE.md`, and `ARCHITECTURE.md` describe one consistent
   interactive lifecycle shape matching steps `92-95`.
2. `tool/invariant_registry.dart` explicitly records invariants for
   interruption semantics, draw-style snapshotting, and pointer-session
   detachment with primary proofs that already exist in the repository.
3. The primary proof files contain matching `// INV:` markers for the new
   invariant ids.
4. `PLAN.md` reflects the split `92-96` sequence instead of the removed large
   step `92`.
5. `CHANGELOG.md` contains the corresponding `## Unreleased` user-visible
   note for the lifecycle closure.

## 6. Implementation Specification

### 6.1 Analysis Scope

- The existing large step `92` bundled runtime, view, draw, docs, and
  invariant closure into one contract; this step converts the closure portion
  into the final source-of-truth update after production changes land.
- `tool/invariant_registry.dart` already acts as the repository source of truth
  for enforced invariant ids and proof ownership.
- `PLAN.md` must describe the new step sequence `92-96` so future work no
  longer depends on the removed oversized step file.

### 6.2 Target Verification Units

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dcm calculate-metrics lib/src/interactive/internal/pointer_session_token.dart lib/src/interactive/scene_controller_interaction.dart lib/src/interactive/internal/scene_controller_interaction_runtime.dart lib/src/interactive/internal/interactive_runtime.dart lib/src/interactive/internal/interactive_pointer_normalizer.dart lib/src/interactive/internal/interactive_gesture_machine.dart lib/src/interactive/internal/interactive_draw_gesture_session.dart lib/src/interactive/internal/interactive_draw_line_engine.dart lib/src/interactive/internal/scene_controller_pointer_session.dart lib/src/interactive/internal/scene_controller_scene_view_runtime.dart lib/src/view/scene_view_interactive_pointer_host.dart --report-all`
- `dart run tool/check_tool_test_trigger_surface.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_tool_tests.dart`
- MCP shard preset `core`
- MCP shard preset `model_contract`
- MCP shard preset `controller_internal`
- MCP shard preset `controller`
- MCP shard preset `render_view`
- MCP shard preset `interactive`
- MCP shard preset `example`
- MCP re-run of `test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart`
- MCP re-run of `test/interactive/core/scene_controller_interactive_line_tool_flow_test.dart`
- MCP re-run of `test/view/scene_view_interactive_test.dart`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`

### 6.3 Protected States, Data, or Structures

- invariant registry id ownership and proof mapping
- release-ready wording in repository source-of-truth docs
- roadmap sequencing for the interactive lifecycle closure

### 6.4 Allowed Semantic Change Zones

- release-facing wording about the final interactive lifecycle taxonomy
- invariant ids and proof ownership for the lifecycle closure
- roadmap descriptions for steps `92-96`

### 6.5 Requirements for Resolution of Links and Structural Analysis

- Update `tool/invariant_registry.dart` with exactly these new invariants:
  `INV-ENG-INTERACTIVE-INTERRUPTION-SEMANTICS`,
  `INV-ENG-INTERACTIVE-DRAW-STYLE-SNAPSHOT`, and
  `INV-ENG-VIEW-POINTER-SESSION-DETACH`.
- Primary proofs must remain:
  `test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart`,
  `test/interactive/core/scene_controller_interactive_line_tool_flow_test.dart`,
  and `test/view/scene_view_interactive_test.dart`.
- `INV-ENG-INTERACTIVE-CANCEL-STATE-RESET` remains pointer-cancel-specific and
  must not be widened to cover all interruption reasons.

### 6.6 Prohibited

- reopening production owner work from steps `92-95`
- introducing parallel invariant ids for the same closure facts
- leaving `PLAN.md` with the removed oversized step `92` entry

## 7. Execution Rules

1. This step starts only after steps `92-95` are implementation-complete.
2. Proof-marker alignment and invariant-registry additions must land in the
   same change as the documentation updates.
3. The roadmap update must describe the split `92-96` sequence without
   reintroducing a parent aggregation step.
4. Preparatory doc edits without green invariant coverage do not close the
   step.

## 8. Vertical Slices

### Slice 1. [x] Documentation, Invariants, And Roadmap Closure

#### Slice Contract

Repository-local docs, invariants, and roadmap state describe and enforce the
interactive lifecycle taxonomy, draw-style snapshot contract, and
pointer-session detachment contract introduced by steps `92-95`.

#### Change

Update `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, and `CHANGELOG.md` so
they describe the final shape:

- manual public pointer input remains on `SceneControllerInteraction`
- session-routed input uses an internal tokenized path
- interaction-config interruption, external mutation interruption,
  session detachment, and dispose are distinct lifecycle reasons
- active draw style is captured on gesture start
- pending line is draw-local latent state with owner provenance
- view hosts detach sessions before replacement/disposal

Update `tool/invariant_registry.dart` with the exact invariant ids fixed in
this contract and add matching `// INV:` markers in the primary proof files.

Update `PLAN.md` so the interactive lifecycle sequence is represented by steps
`92-96` and no longer references the removed oversized step file.

#### Verification

- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_tool_tests.dart`
- MCP re-run of `test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart`
- MCP re-run of `test/interactive/core/scene_controller_interactive_line_tool_flow_test.dart`
- MCP re-run of `test/view/scene_view_interactive_test.dart`

#### Closure Evidence

- green run of the listed verifications
- updated invariant registry entries and matching proof markers
- updated release-ready docs and `## Unreleased` changelog entry
- `PLAN.md` updated to the split `92-96` sequence

## 9. Final Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dcm calculate-metrics lib/src/interactive/internal/pointer_session_token.dart lib/src/interactive/scene_controller_interaction.dart lib/src/interactive/internal/scene_controller_interaction_runtime.dart lib/src/interactive/internal/interactive_runtime.dart lib/src/interactive/internal/interactive_pointer_normalizer.dart lib/src/interactive/internal/interactive_gesture_machine.dart lib/src/interactive/internal/interactive_draw_gesture_session.dart lib/src/interactive/internal/interactive_draw_line_engine.dart lib/src/interactive/internal/scene_controller_pointer_session.dart lib/src/interactive/internal/scene_controller_scene_view_runtime.dart lib/src/view/scene_view_interactive_pointer_host.dart --report-all`
- `dart run tool/check_tool_test_trigger_surface.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_tool_tests.dart`
- MCP shard preset `core`
- MCP shard preset `model_contract`
- MCP shard preset `controller_internal`
- MCP shard preset `controller`
- MCP shard preset `render_view`
- MCP shard preset `interactive`
- MCP shard preset `example`
- MCP re-run of `test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart`
- MCP re-run of `test/interactive/core/scene_controller_interactive_line_tool_flow_test.dart`
- MCP re-run of `test/view/scene_view_interactive_test.dart`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- The slice is closed.
- Final verification has passed.
