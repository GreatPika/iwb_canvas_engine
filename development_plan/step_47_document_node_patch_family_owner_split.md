language: russian

# Шаг 47. Разрезать `document_node_patch` на explicit family-local patch owner-ы

## 1. Change Mandate

Этот шаг закрывает residual document patch seam после step `43`: вместо одного
large `document_node_patch.dart`, который одновременно валидирует target-kind,
применяет common patch fields и держит family-local mutation logic, слой
должен прийти к thin dispatcher/validation facade над explicit common and
family-local patch owners.

## 2. Change Boundary

### Included in the Change

- `lib/src/model/document.dart`
- `lib/src/model/document_node_patch.dart`
- `lib/src/model/document_node_patch_common.dart`
- `lib/src/model/document_node_patch_image.dart`
- `lib/src/model/document_node_patch_text.dart`
- `lib/src/model/document_node_patch_stroke.dart`
- `lib/src/model/document_node_patch_line.dart`
- `lib/src/model/document_node_patch_rect.dart`
- `lib/src/model/document_node_patch_path.dart`
- Guardrail pinning directly tied to the new patch-owner graph:
  `tool/src/guardrails/model_architecture_guardrails.dart`
  and
  `test/tool/guardrails/guardrails_model_architecture_tool_test.dart`

### Not Included in the Change

- Contract patch schema validation and fast-path owners in `contract/**`
- `document_locator.dart`, `document_scene_edit.dart`, and
  `document_selection.dart`
- Builder decode ownership from step `45`
- Mapping support cleanup from step `46`
- Public API surface changes in `lib/iwb_canvas_engine.dart`

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/model/document.dart`
- `lib/src/model/document_node_patch.dart`
- `lib/src/model/document_node_patch_common.dart`
- `lib/src/model/document_node_patch_image.dart`
- `lib/src/model/document_node_patch_text.dart`
- `lib/src/model/document_node_patch_stroke.dart`
- `lib/src/model/document_node_patch_line.dart`
- `lib/src/model/document_node_patch_rect.dart`
- `lib/src/model/document_node_patch_path.dart`
- `tool/src/guardrails/model_architecture_guardrails.dart`

### Test Files

- `test/model/document_model_test.dart`
- `test/controller/internal/scene_writer_test.dart`
- `test/controller/internal/mutation_executor_test.dart`
- `test/controller/core/scene_controller_copy_on_write_test.dart`
- `test/controller/commands/scene_commands_test.dart`
- `test/controller/scene_controller_randomized_txn_test.dart`
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart`

### Fixture and Supporting Data Files

- `development_plan/model_target_architecture.md`
- `development_plan/step_43_document_txn_facade_and_focused_owner_split.md`
- `development_plan/step_47_document_node_patch_family_owner_split.md`

### Analysis Area

- `lib/src/model/document.dart`
- `lib/src/model/document_node_patch*.dart`
- `tool/src/guardrails/model_architecture_guardrails.dart`
- `test/model/document_model_test.dart`
- `test/controller/internal/scene_writer_test.dart`
- `test/controller/internal/mutation_executor_test.dart`
- `test/controller/core/scene_controller_copy_on_write_test.dart`
- `test/controller/commands/scene_commands_test.dart`
- `test/controller/scene_controller_randomized_txn_test.dart`
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied either to patch dispatch,
  common patch helpers, or one explicit node-family patch owner.
- Changes in `document.dart` are limited to direct patch delegation.
- Every modified guardrail or tool test must pin one internal patch-owner
  boundary.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `document.dart` remains the canonical downstream txn facade for node patch
   application.
2. `document_node_patch.dart` may remain as the internal dispatcher/validation
   facade, but it must no longer be the single owner of all family mutation
   bodies.
3. Contract-side patch shapes and validation remain single-owned in
   `contract/**`; this step changes runtime mutation ownership only.
4. `dryRun` semantics remain part of the patch seam contract and must stay
   behaviorally equivalent across all family owners.
5. Text size recomputation remains a single-owned text-patch concern and must
   not be duplicated across common or non-text patch owners.
6. The exact post-step-`48` target graph and accepted residual policy are
   fixed in `development_plan/model_target_architecture.md`; this step may
   refine only the document patch seam inside that target.

## 5. Result Requirements

1. `document_node_patch.dart` becomes a thin dispatcher/validation facade over
   explicit common patch helpers and family-local patch owner modules.
2. One explicit family-local patch owner exists for each supported node family:
   `image`,
   `text`,
   `stroke`,
   `line`,
   `rect`,
   and `path`.
3. One explicit common patch owner exists for shared field assignment helpers
   and common-node patch application; it must not absorb family-specific patch
   logic.
4. `dcm calculate-metrics` no longer reports the current `HIGH`
   `_txnApplyCommonPatch(...)` hotspot in `document_node_patch.dart`.
5. `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
   no longer reports the current patch-family matrix in the same form.
6. `txnApplyNodePatch(...)` remains behaviorally equivalent for:
   changed vs no-op patches,
   `dryRun`,
   type mismatch,
   id mismatch,
   text layout recomputation,
   and stroke point replacement semantics.
7. `tool/check_guardrails.dart` rejects non-model imports or re-exports of the
   new internal patch owner modules introduced by this step.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Step `43` already turned `document.dart` into a thin txn facade, but
  `document_node_patch.dart` still remains at `450` lines and owns validation,
  common field mutation, and all family-specific patch bodies.
- Current `dcm` output still reports `_txnApplyCommonPatch(...)` at `42`
  source lines as a `HIGH` hotspot.
- Current clone inventory for `lib/src/model` still contains a live
  patch-family cluster centered on `document_node_patch.dart`.
- The patch seam is consumed broadly through controller/runtime flows, so this
  step must preserve runtime semantics instead of chasing cosmetic signature
  compression.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/model/document.dart lib/src/model/document_node_patch.dart lib/src/model/document_node_patch_common.dart lib/src/model/document_node_patch_image.dart lib/src/model/document_node_patch_text.dart lib/src/model/document_node_patch_stroke.dart lib/src/model/document_node_patch_line.dart lib/src/model/document_node_patch_rect.dart lib/src/model/document_node_patch_path.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_guardrails.dart`
- MCP test runner:
  `test/model/document_model_test.dart`
- MCP test runner:
  `test/controller/internal/scene_writer_test.dart test/controller/internal/mutation_executor_test.dart`
- MCP test runner:
  `test/controller/core/scene_controller_copy_on_write_test.dart test/controller/commands/scene_commands_test.dart`
- MCP test runner:
  `test/controller/scene_controller_randomized_txn_test.dart`
- `dart run tool/run_tool_tests.dart`

### 6.3 Protected States, Data, or Structures

- `NodePatch` runtime semantics, including id/target-kind validation.
- `dryRun` behavior and no-op detection.
- Text layout recomputation after patch application.
- Stroke-point mutation semantics and `OwnedList` replacement rules.

### 6.4 Allowed Semantic Change Zones

- Physical file boundaries and imports inside the document patch seam.
- Direct delegation from `document.dart` to the internal patch dispatcher.
- Guardrail and tool-test pinning for new internal patch owners.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- `document.dart` remains the only canonical downstream entrypoint for runtime
  patch application; family patch modules are implementation-only.
- The replacement graph must not invent a new generic `helpers` or `utils`
  bucket that hides family patch bodies under a broader name.
- Common patch helpers may own shared assignment primitives and common-node
  field application only; text, stroke, and other type-specific semantics stay
  with their family owners.

### 6.8 Prohibited

- Moving contract patch validation into the model layer.
- Keeping the current family patch bodies in `document_node_patch.dart` while
  only adding wrappers.
- Changing runtime patch behavior solely to satisfy metrics or clone tooling.
- Reopening unrelated document-local owners to compensate for this seam.

## 7. Execution Rules

1. This step starts only after step `46` is closed or explicitly deferred.
2. Slice `2` is forbidden until slice `1` is closed and verified.
3. This step closes only if the patch seam becomes explicit by owner and the
   dispatcher file becomes thinner in a meaningful way.
4. Scope expansion into contract patch schema or other document owners is
   forbidden.

## 8. Vertical Slices

### Slice 1. [x] Extract common patch helpers and shrink the dispatcher

#### Slice Contract

Shared patch-field application lives in a common patch owner, not in the
dispatcher file.

#### Change

Move `_txnApplyCommonPatch(...)`, `_txnSet(...)`, `_txnSetNullable(...)`, and
other genuinely shared patch primitives into an explicit common owner module,
and keep `document_node_patch.dart` focused on target-kind validation and
family dispatch.

#### Verification

- `dcm calculate-metrics lib/src/model/document_node_patch.dart lib/src/model/document_node_patch_common.dart --report-all`
- MCP test runner:
  `test/model/document_model_test.dart`

#### Closure Evidence

- `document_node_patch.dart` no longer owns the common patch hotspot.
- The common patch owner contains only genuinely shared patch primitives.
- `txnApplyNodePatch(...)` remains green for common-field patch cases.

### Slice 2. [x] Move family patch application into explicit owner modules

#### Slice Contract

Each node family owns its runtime patch behavior in one dedicated module.

#### Change

Split `image`, `text`, `stroke`, `line`, `rect`, and `path` patch application
into dedicated internal modules, keeping text-size recomputation in the text
owner and stroke-point replacement in the stroke owner.

#### Verification

- `dcm calculate-metrics lib/src/model/document.dart lib/src/model/document_node_patch.dart lib/src/model/document_node_patch_common.dart lib/src/model/document_node_patch_image.dart lib/src/model/document_node_patch_text.dart lib/src/model/document_node_patch_stroke.dart lib/src/model/document_node_patch_line.dart lib/src/model/document_node_patch_rect.dart lib/src/model/document_node_patch_path.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
- `dart run tool/check_guardrails.dart`
- MCP test runner:
  `test/controller/internal/scene_writer_test.dart test/controller/internal/mutation_executor_test.dart`
- MCP test runner:
  `test/controller/core/scene_controller_copy_on_write_test.dart test/controller/commands/scene_commands_test.dart`
- MCP test runner:
  `test/controller/scene_controller_randomized_txn_test.dart`

#### Closure Evidence

- Every supported node family has one explicit patch owner module.
- The current patch-family clone matrix no longer appears in the same form.
- Downstream controller/document patch flows remain green through the listed
  proof surface.

## 9. Final Verification Checklist

- [x] `dcm calculate-metrics lib/src/model/document.dart lib/src/model/document_node_patch.dart lib/src/model/document_node_patch_common.dart lib/src/model/document_node_patch_image.dart lib/src/model/document_node_patch_text.dart lib/src/model/document_node_patch_stroke.dart lib/src/model/document_node_patch_line.dart lib/src/model/document_node_patch_rect.dart lib/src/model/document_node_patch_path.dart --report-all`
- [x] `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
- [x] `dart run tool/check_import_boundaries.dart`
- [x] `dart run tool/check_guardrails.dart`
- [x] MCP test runner:
      `test/model/document_model_test.dart`
- [x] MCP test runner:
      `test/controller/internal/scene_writer_test.dart test/controller/internal/mutation_executor_test.dart`
- [x] MCP test runner:
      `test/controller/core/scene_controller_copy_on_write_test.dart test/controller/commands/scene_commands_test.dart`
- [x] MCP test runner:
      `test/controller/scene_controller_randomized_txn_test.dart`
- [x] `dart run tool/run_tool_tests.dart`
