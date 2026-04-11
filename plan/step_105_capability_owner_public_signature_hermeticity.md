language: english

# Change Contract

## 1. Change Mandate
This change fixes the public runtime surface so capability owners remain
controller-owned public contracts rather than directly constructible assembly
types, and exported signatures become mechanically hermetic against
`internal/**` and non-exported helper types.

## 2. Change Boundary

### Included in the Change
- Public runtime capability-owner contracts for interaction, selection, and
  scene access.
- Internal assembly of those capability owners inside the existing interactive
  graph.
- Repository-local guardrails for exported public signature hermeticity.
- Public documentation and changelog updates for the capability-owner access
  contract.

### Not Included in the Change
- New runtime capabilities, new controller entrypoints, or behavioral changes
  to pointer handling, selection semantics, or scene mutation semantics.
- Reordering or redesigning the existing interactive graph beyond the changes
  required to internalize capability-owner construction.
- New public entrypoints or new package barrels.
- Changes to serialization, rendering, geometry, or commit-pipeline behavior
  except where the existing public runtime surface must keep working through
  `SceneController`.

## 3. File Map and Analysis Areas

### Implementation Files
- `lib/src/interactive/scene_controller_interaction.dart`
- `lib/src/interactive/scene_controller_selection.dart`
- `lib/src/interactive/scene_controller_scene.dart`
- `lib/src/interactive/internal/scene_controller_graph.dart`
- `tool/check_guardrails.dart`
- `tool/src/guardrails/guardrails_runner.dart`
- `tool/src/guardrails/public_signature_hermeticity_guardrails.dart`
- `tool/invariant_registry.dart`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`

### Test Files
- `test/contract/runtime_contract_interfaces_test.dart`
- `test/entrypoints/basic_smoke_test.dart`
- `test/tool/public_capability_owner_contract_tool_test.dart`
- `test/tool/guardrails/guardrails_public_signature_hermeticity_tool_test.dart`

### Fixture and Supporting Data Files
- `test/tool/support/guardrails_tool_test_support.dart`
- `test/tool/support/tool_process_test_support.dart`

### Analysis Area
- `lib/src/interactive/**`
- `tool/src/guardrails/**`
- `tool/invariant_registry.dart`
- `test/contract/runtime_contract_interfaces_test.dart`
- `test/entrypoints/basic_smoke_test.dart`
- `test/tool/public_capability_owner_contract_tool_test.dart`
- `test/tool/guardrails/**`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`

### Outside the Change Boundary
- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule
- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every new or modified fixture must be tied to a specific verification.
- Every newly proposed file or directory name must comply with the global
  `AGENTS.md` section `### File naming`.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `SceneControllerInteraction`, `SceneControllerSelection`, and
   `SceneControllerScene` remain public types but stop being directly
   constructible public assembly surfaces.
2. The supported external access path for those capability owners remains
   `controller.interaction`, `controller.selection`, and `controller.scene`.
3. Capability-owner assembly stays inside the existing `SceneController` graph;
   this step must not introduce a second public assembly path.
4. Public signature hermeticity is enforced by a dedicated repository-local
   guardrail instead of relying on documentation or symbol-name goldens alone.
5. The change must use the existing single public package entrypoint
   `lib/iwb_canvas_engine.dart`.

## 5. Result Requirements

1. The public runtime surface exposes `SceneControllerInteraction`,
   `SceneControllerSelection`, and `SceneControllerScene` only as controller-
   owned capability contracts; direct public construction is no longer part of
   the supported surface.
2. External code that imports only `package:iwb_canvas_engine/iwb_canvas_engine.dart`
   can still use the interaction, selection, and scene capabilities through an
   ordinary `SceneController`.
3. Exported public signatures reachable from `lib/iwb_canvas_engine.dart` do
   not expose types declared under `lib/src/**/internal/**` and do not expose
   helper types that are not themselves exported by the public entrypoint.
4. `tool/check_guardrails.dart` fails when an exported public signature leaks
   an internal or non-exported helper type and passes for equivalent signatures
   that stay within the public entrypoint contract or SDK/framework types.
5. `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, and `CHANGELOG.md` reflect
   that capability owners are obtained from `SceneController` and are not a
   separate direct-construction contract.

## 6. Implementation Specification

### 6.1 Analysis Scope
- Reuse the current interactive graph assembly in
  `lib/src/interactive/internal/scene_controller_graph.dart`.
- Keep the public capability-owner declarations in their existing files under
  `lib/src/interactive/`.
- Keep top-level public export ownership in `lib/iwb_canvas_engine.dart`
  unchanged unless a verification in this contract explicitly requires a
  change.
- Reuse `package:analyzer`-based repository tooling patterns already used by
  the guardrails and public-surface tools.

### 6.2 Target Verification Units
- Runtime/public-entrypoint coverage in:
  - `test/contract/runtime_contract_interfaces_test.dart`
  - `test/entrypoints/basic_smoke_test.dart`
- Temp-package public-entrypoint contract coverage in:
  - `test/tool/public_capability_owner_contract_tool_test.dart`
- Guardrail regression coverage in:
  - `test/tool/guardrails/guardrails_public_signature_hermeticity_tool_test.dart`
- Final repository verification through the canonical command required by
  `AGENTS.md` for code changes.

### 6.3 Protected States, Data, or Structures
- The existing public method names and behavior exposed through
  `controller.interaction`, `controller.selection`, and `controller.scene`.
- The existing `MoveCommitDeltaResolver` public typedef.
- The existing single public barrel `lib/iwb_canvas_engine.dart`.
- The existing guardrail runner entrypoint `tool/check_guardrails.dart`.

### 6.4 Allowed Semantic Change Zones
- Capability-owner type shape and construction visibility.
- Internal capability-owner implementation helpers needed for graph assembly.
- Interactive graph wiring for capability-owner creation.
- Analyzer-backed public-signature hermeticity checks.
- Invariant registry and guardrail regression scaffolding for the new
  hermeticity rule.
- Public documentation and changelog statements about capability-owner usage.

### 6.5 Recognition Forms That Must Be Supported Within This Change
- Public unnamed constructors with internal-typed parameters.
- Public named constructors with internal-typed parameters.
- Public methods whose parameter or return types resolve to internal or
  non-exported helper types.
- Public getters and setters whose exposed type resolves to an internal or
  non-exported helper type.
- Public top-level functions and typedefs exported from the public entrypoint
  whose signature resolves to an internal or non-exported helper type.

### 6.6 Allowed Forms That Do Not Count as Violations
- Exported public signatures that reference SDK, Flutter framework, or other
  package-surface types that are exported by
  `lib/iwb_canvas_engine.dart`.
- Non-exported helper implementations that stay hidden behind exported public
  contracts.
- Private constructors, private methods, and private helper declarations that
  are not part of the exported public signature surface.

### 6.7 Requirements for Resolution of Links and Structural Analysis
- The hermeticity guardrail must resolve the actual exported surface from
  `lib/iwb_canvas_engine.dart` rather than scanning arbitrary `lib/src/**`
  files without export context.
- Signature analysis must use resolved Dart element/type information rather
  than string matching on source text.
- A signature type counts as allowed only if it resolves to:
  - a Dart SDK type;
  - a Flutter/framework type;
  - a type declared in the same exported library and visible through the
    public entrypoint;
  - a type declared in another library that is exported through the public
    entrypoint.
- A signature type counts as a violation if it resolves to:
  - a declaration in any `lib/src/**/internal/**` path;
  - a declaration in `lib/src/**` that is not exported through
    `lib/iwb_canvas_engine.dart`.

### 6.8 Prohibited
- Do not solve the API leak by adding `@internal` while keeping the same
  public constructors.
- Do not introduce `part` files or a second public barrel to hide direct
  construction.
- Do not widen the guardrail to unrelated architectural concerns in the same
  slice.
- Do not rely on `tool/check_public_api_surface.dart` symbol-name goldens as
  the only proof for public-signature correctness.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification
   exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice closes a failure scenario, diagnostic output confirming the
   trigger point must be attached.
7. If a slice changes an analysis rule, negative and positive scenarios must
   be covered where applicable to the subject of the change.
8. Scope expansion is forbidden until the mandatory slices are closed.
9. The plan must be detailed enough that the implementing agent has no
   material branch in how to execute a slice.
10. Every newly proposed file or directory name must comply with the global
    `AGENTS.md` section `### File naming` before the slice is considered
    valid.
11. If any implementation detail would require a second public access path for
    capability owners, the slice must stop and preserve the locked
    `SceneController`-owned access model.

## 8. Vertical Slices

### Slice 1. [ ] Internalize capability-owner assembly

#### Slice Contract
`SceneController` continues to expose working interaction, selection, and
scene capability owners through the public barrel, while direct public
construction is removed from those public contracts.

#### Change
- Convert `SceneControllerInteraction`, `SceneControllerSelection`, and
  `SceneControllerScene` into constructor-free public contract types in their
  existing files.
- Internalize capability-owner construction behind non-exported
  implementations used by the interactive graph; do not create a second public
  owner type or a second public assembly path.
- Update `lib/src/interactive/internal/scene_controller_graph.dart` to create
  capability owners through the hidden implementation path instead of calling
  public constructors.
- Preserve the current public capability method names and their runtime
  behavior.
- Update runtime/public-entrypoint tests so they continue to prove that an
  external caller using only the public barrel can use the controller-owned
  capabilities.
- Add a temp-package public-entrypoint contract test that proves a consumer
  using only `package:iwb_canvas_engine/iwb_canvas_engine.dart` can use
  `controller.interaction`, `controller.selection`, and `controller.scene`,
  while direct construction of the capability-owner types no longer compiles.

#### Verification
- `flutter test test/contract/runtime_contract_interfaces_test.dart`
- `flutter test test/entrypoints/basic_smoke_test.dart`
- `flutter test test/tool/public_capability_owner_contract_tool_test.dart`

#### Positive Scenarios
- `SceneController` still returns working capability-owner objects through
  `interaction`, `selection`, and `scene`.
- Public-barrel consumers can still call representative capability methods
  without importing `src/**`.

#### Negative Scenarios
- A temporary-package consumer that imports only the public barrel and attempts
  to instantiate `SceneControllerInteraction`, `SceneControllerSelection`, or
  `SceneControllerScene` fails to compile.

#### Closure Evidence
- Green run of the listed runtime/public-entrypoint verifications.
- Diagnostic output from the temporary-package negative scenario proving the
  public construction failure point.

### Slice 2. [ ] Enforce hermetic public signatures and publish the contract

#### Slice Contract
The repository mechanically rejects exported public signatures that leak
internal or non-exported helper types, and the public documentation matches
the controller-owned capability-owner contract.

#### Change
- Add `tool/src/guardrails/public_signature_hermeticity_guardrails.dart` and
  wire it into `tool/src/guardrails/guardrails_runner.dart`.
- Add a new invariant entry in `tool/invariant_registry.dart` for public
  signature hermeticity and reference it from `tool/check_guardrails.dart` and
  the regression test file.
- Add `test/tool/guardrails/guardrails_public_signature_hermeticity_tool_test.dart`
  with positive and negative sandbox scenarios that cover capability-owner-like
  leaks and allowed public signatures.
- Extend `test/tool/support/guardrails_tool_test_support.dart` only as needed
  to build deterministic sandbox fixtures for the new guardrail.
- Update `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, and `CHANGELOG.md`
  to state that capability owners are obtained from `SceneController` and are
  not directly constructed.

#### Verification
- `flutter test test/tool/guardrails/guardrails_public_signature_hermeticity_tool_test.dart`
- `dart run tool/check_guardrails.dart`

#### Fixtures Used
- `test/tool/support/guardrails_tool_test_support.dart`

#### Positive Scenarios
- An exported capability-owner contract whose public signatures use only
  public-barrel or SDK/framework types passes the new guardrail.
- A hidden helper implementation that stays outside the exported public
  signature surface does not trigger the guardrail.

#### Negative Scenarios
- An exported public constructor with an `internal/**` parameter type fails the
  guardrail.
- An exported public method, getter, setter, or typedef whose signature uses a
  non-exported helper type fails the guardrail.

#### Closure Evidence
- Green run of the listed guardrail verifications.
- Diagnostic output from the negative sandbox scenarios proving the trigger
  point for hermeticity violations.

## 9. Final Verification

- `flutter test test/contract/runtime_contract_interfaces_test.dart`
- `flutter test test/entrypoints/basic_smoke_test.dart`
- `flutter test test/tool/public_capability_owner_contract_tool_test.dart`
- `flutter test test/tool/guardrails/guardrails_public_signature_hermeticity_tool_test.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/run_verification_preset.dart run --preset required_code_change --changed-paths-file=<prepared-path-list>`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
