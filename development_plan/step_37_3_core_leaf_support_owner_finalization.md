language: russian

# Шаг 37.3. Довести `text_layout`, `action_events` и `id_generator` до leaf support owner-ов

## 1. Change Mandate

Этот шаг доводит leaf support seams в `core` до focused owner-ов without
moving support semantics into higher layers or introducing metric-only
abstractions.

## 2. Change Boundary

### Included in the Change

- Text-layout support ownership in `lib/src/core/text_layout.dart`.
- Action payload parsing support ownership in `lib/src/core/action_events.dart`.
- Generated-id allocation support ownership in `lib/src/core/id_generator.dart`.
- Minimal consumer adaptation required to consume the final leaf support shape.

### Not Included in the Change

- Node-family and node-local support work targeted by `37.1-37.2`.
- Reopening render cache, model import, controller transaction, or interactive
  production ownership beyond direct adaptation required by this step.
- Public contract changes for `ActionCommitted`, `EditTextRequested`, or
  generated ids.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/core/text_layout.dart`
- `lib/src/core/action_events.dart`
- `lib/src/core/id_generator.dart`

### Test Files

- `test/core/action_events_test.dart`
- `test/core/id_generator_test.dart`
- `test/render/scene_text_layout_cache_test.dart`
- `test/model/scene_builder_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/controller/commands/scene_commands_test.dart`
- `test/controller/core/scene_controller_copy_on_write_test.dart`

### Fixture and Supporting Data Files

- `analysis_options.yaml`
- `development_plan/step_37_3_core_leaf_support_owner_finalization.md`

### Analysis Area

- `lib/src/core/text_layout.dart`
- `lib/src/core/action_events.dart`
- `lib/src/core/id_generator.dart`
- `test/core/action_events_test.dart`
- `test/core/id_generator_test.dart`
- `test/render/scene_text_layout_cache_test.dart`
- `test/model/scene_builder_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/controller/commands/scene_commands_test.dart`
- `test/controller/core/scene_controller_copy_on_write_test.dart`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to one leaf-support slice.
- Every modified test must be tied to one listed verification.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `TextNode.size` remains derived from text layout inputs.
2. `ActionCommitted` published payloads remain immutable snapshots.
3. Generated-id policy remains internal runtime ownership in
   `src/core/id_generator.dart`.
4. Leaf support semantics do not move into render, model, controller, or
   interactive owners.

## 5. Result Requirements

1. Text layout normalization, style construction, and measurement use one
   focused core-local support owner shape instead of the current parameter-heavy
   surface.
2. Action payload parsing no longer keeps duplicated scalar coercion or mixed
   immutable-payload-plus-parser ownership in the current handwritten form.
3. Generated node/layer id allocation no longer keeps duplicated allocation
   loops in the current handwritten form.
4. Existing model, serialization, controller, and render consumers remain
   behaviorally equivalent.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `text_layout.dart` currently keeps two `HIGH` parameter-count hotspots in
  `buildTextStyleForTextLayout(...)` and `measureTextLayoutSize(...)`.
- `action_events.dart` currently keeps a confirmed clone cluster around
  `tryMoveLayerIndices(...)`,
  `tryDrawStyle(...)`,
  and duplicated `tryInt(...)`.
- `id_generator.dart` currently keeps an exact clone pair between
  `generateNextNodeId(...)` and `generateNextLayerId(...)`.
- These are leaf support seams; they do not justify reopening higher-layer
  owner boundaries.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/core/text_layout.dart lib/src/core/action_events.dart lib/src/core/id_generator.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/core`
- MCP test runner: `test/core/action_events_test.dart test/core/id_generator_test.dart`
- MCP test runner: `test/render/scene_text_layout_cache_test.dart`
- MCP test runner:
  `test/model/scene_builder_test.dart test/serialization/scene_codec_validation_test.dart`
- MCP test runner:
  `test/controller/commands/scene_commands_test.dart test/controller/core/scene_controller_copy_on_write_test.dart`
- `dart run tool/check_import_boundaries.dart`

### 6.3 Protected States, Data, or Structures

- Derived text-size semantics.
- Immutable action payload exposure.
- Generated-id allocation and uniqueness semantics.
- Existing render, model, serialization, and controller consumers of these leaf
  support seams.

### 6.4 Allowed Semantic Change Zones

- Text-layout request, normalization, style, and measurement support.
- Action payload scalar coercion and delta parsing support.
- Generated-id allocation loop and formatting support.
- Minimal consumer adaptation required to use the final leaf support shape.

### 6.8 Prohibited

- Moving text-layout semantics into render cache owners.
- Moving generated-id ownership into controller or model layers.
- Broadening public action payload contracts to reduce parsing complexity.
- Hiding the same leaf hotspot behind cosmetic wrappers or alias helpers.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification
   exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice closes a failure scenario, diagnostic output confirming the
   trigger point must be attached.
7. If a slice changes an analysis rule, negative and positive scenarios must be
   covered where applicable to the subject of the change.
8. Scope expansion is forbidden until the mandatory slices are closed.

## 8. Vertical Slices

### Slice 1. [x] Text-layout leaf support owner is finalized

#### Slice Contract

Text-layout support no longer keeps the current parameter-heavy surface in the
same handwritten form.

#### Change

Свести text-layout normalization, style, and measurement to one focused
core-local support owner path and перевести existing consumers на него.

#### Verification

- `dcm calculate-metrics lib/src/core/text_layout.dart --report-all`
- MCP test runner: `test/render/scene_text_layout_cache_test.dart`
- MCP test runner:
  `test/model/scene_builder_test.dart test/serialization/scene_codec_validation_test.dart`
- MCP test runner: `test/controller/core/scene_controller_copy_on_write_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- Derived text-size semantics remain green after the support-owner finalization.

### Slice 2. [x] Action payload parsing owner is finalized

#### Slice Contract

Action payload parsing no longer keeps the current duplicated scalar coercion
shape in `action_events.dart`.

#### Change

Свести scalar coercion and payload parse helpers in `action_events.dart` к one
focused support owner path without changing immutable payload exposure.

#### Verification

- `dcm calculate-metrics lib/src/core/action_events.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/core`
- MCP test runner: `test/core/action_events_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- The replaced `action_events.dart` helper cluster is no longer present in the
  same handwritten form.

### Slice 3. [x] Generated-id allocation owner is finalized

#### Slice Contract

Generated node/layer id allocation no longer keeps duplicated allocation loops
in `id_generator.dart`.

#### Change

Свести generated-id allocation loops to one focused support owner path while
preserving the current internal formatting policy and uniqueness behavior.

#### Verification

- `dcm calculate-metrics lib/src/core/id_generator.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/core`
- MCP test runner: `test/core/id_generator_test.dart`
- MCP test runner: `test/controller/commands/scene_commands_test.dart`
- `dart run tool/check_import_boundaries.dart`

#### Closure Evidence

- Green run of the listed verifications.
- The replaced `id_generator.dart` allocation pair is no longer present in the
  same handwritten form.

## 9. Final Verification

- `dcm calculate-metrics lib/src/core/text_layout.dart lib/src/core/action_events.dart lib/src/core/id_generator.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/core`
- MCP test runner: `test/core/action_events_test.dart test/core/id_generator_test.dart`
- MCP test runner: `test/render/scene_text_layout_cache_test.dart`
- MCP test runner:
  `test/model/scene_builder_test.dart test/serialization/scene_codec_validation_test.dart`
- MCP test runner:
  `test/controller/commands/scene_commands_test.dart test/controller/core/scene_controller_copy_on_write_test.dart`
- `dart run tool/check_import_boundaries.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
