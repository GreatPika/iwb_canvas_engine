language: russian

# Шаг 18.4. Сжать scene value validation matrix без второго owner-а primitive rules

## 1. Change Mandate

Этот шаг сжимает matrix в `scene_value_validation` без ввода второго owner-а
primitive validation rules outside current validated and schema-owned sources.

## 2. Change Boundary

### Included in the Change

- `lib/src/model/scene_value_validation.dart`
- `lib/src/model/scene_value_validation_node.part.dart`
- `lib/src/model/scene_value_validation_palette_grid.part.dart`
- `lib/src/model/scene_value_validation_primitives.part.dart`
- `lib/src/model/scene_value_validation_top_level.part.dart`

### Not Included in the Change

- Contract-side validated primitives ownership
- SceneBuilder decode helper ownership
- Runtime orchestration and render/view work

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/model/scene_value_validation.dart`
- `lib/src/model/scene_value_validation_node.part.dart`
- `lib/src/model/scene_value_validation_palette_grid.part.dart`
- `lib/src/model/scene_value_validation_primitives.part.dart`
- `lib/src/model/scene_value_validation_top_level.part.dart`

### Test Files

- `test/model/scene_value_validation_primitives_test.dart`
- `test/model/scene_builder_test.dart`
- `test/public_api/validated_boundary_value_test.dart`

### Fixture and Supporting Data Files

- `analysis_options.yaml`
- `development_plan/step_18_4_scene_value_validation_matrix_compression.md`

### Analysis Area

- `lib/src/model/scene_value_validation*`
- `test/model/scene_value_validation_primitives_test.dart`
- `test/model/scene_builder_test.dart`
- `test/public_api/validated_boundary_value_test.dart`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to one validation slice.
- Every modified test must be tied to one listed verification.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. Primitive validation ownership stays in existing validated helpers and must
   not fork into a second private ruleset.
2. This step may compress combinators and repeated validator shapes but must
   not redefine the underlying primitive limits.
3. Public validation behavior stays equivalent on the boundary.

## 5. Result Requirements

1. Validation seam no longer keeps the current repeated matrix across node,
   palette/grid, and primitive validation bodies for the migrated families.
2. Primitive validation ownership remains single-owned and explicit.
3. Validation behavior stays equivalent for the existing boundary inputs.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Current confirmed clone inventory for `lib` contains a validation-family
  cluster across:
  - `scene_value_validation_node.part.dart`
  - `scene_value_validation_palette_grid.part.dart`
  - `scene_value_validation_primitives.part.dart`
- Current confirmed pair inventory shows exact repetition between
  `sceneValidatePaletteSnapshot(...)`, `sceneValidatePalette(...)`,
  `_sceneValidateTextFields(...)`, and primitive size / double validation
  helpers.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/model/scene_value_validation.dart lib/src/model/scene_value_validation_node.part.dart lib/src/model/scene_value_validation_palette_grid.part.dart lib/src/model/scene_value_validation_primitives.part.dart lib/src/model/scene_value_validation_top_level.part.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib/src/model`
- MCP test runner: `test/model/scene_value_validation_primitives_test.dart test/model/scene_builder_test.dart`
- MCP test runner: `test/public_api/validated_boundary_value_test.dart`

### 6.3 Protected States, Data, or Structures

- Existing validated primitive helpers and limits.
- Boundary-visible validation behavior.
- Error attribution shape of the current validation seam.

### 6.4 Allowed Semantic Change Zones

- Validation combinator ownership inside `scene_value_validation*.part.dart`
- Family-specific validation helpers for node and palette/grid seams
- Top-level wiring between validation helpers

### 6.8 Prohibited

- Creating a second primitive validation owner.
- Reopening decode/import or contract constructor work in this step.
- Leaving the replaced validation matrix bodies in parallel with the new
  compact path.

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

### Slice 1. [x] One compact owner exists for repeated validation combinators

#### Slice Contract

Repeated validation combinators are compacted inside `scene_value_validation`
without redefining primitive rule ownership.

#### Change

Свести repeated optional / size / double validation combinators to one compact
validation path inside the owned seam.

#### Verification

- `dcm calculate-metrics lib/src/model/scene_value_validation.dart lib/src/model/scene_value_validation_primitives.part.dart --report-all`
- MCP test runner: `test/model/scene_value_validation_primitives_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- Primitive-facing combinators no longer keep the replaced duplicate bodies.

### Slice 2. [x] Node and palette/grid validators consume the same compact path

#### Slice Contract

Node validators and palette/grid validators consume the same compact
combinators without preserving the current matrix of repeated bodies.

#### Change

Перевести `scene_value_validation_node.part.dart`,
`scene_value_validation_palette_grid.part.dart`, and top-level wiring on the
compact validation path and remove the replaced duplicates.

#### Verification

- `dcm calculate-metrics lib/src/model/scene_value_validation_node.part.dart lib/src/model/scene_value_validation_palette_grid.part.dart lib/src/model/scene_value_validation_top_level.part.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib/src/model`
- MCP test runner: `test/model/scene_value_validation_primitives_test.dart test/model/scene_builder_test.dart`
- MCP test runner: `test/public_api/validated_boundary_value_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- Validation clone inventory no longer shows the replaced node / palette-grid
  family in the same form.

## 9. Final Verification

- `dcm calculate-metrics lib/src/model/scene_value_validation.dart lib/src/model/scene_value_validation_node.part.dart lib/src/model/scene_value_validation_palette_grid.part.dart lib/src/model/scene_value_validation_primitives.part.dart lib/src/model/scene_value_validation_top_level.part.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib/src/model`
- MCP test runner: `test/model/scene_value_validation_primitives_test.dart test/model/scene_builder_test.dart`
- MCP test runner: `test/public_api/validated_boundary_value_test.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
