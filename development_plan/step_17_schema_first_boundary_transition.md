language: russian

# Шаг 17. Замкнуть boundary node semantics на один `schema-first` source of truth и переснять baseline через подшаги 17.1-17.5 с подготовительным 17.3.1

## 1. Change Mandate

Этот шаг мигрирует все подтверждённые boundary node semantics в
`contract/model/serialization` на одного private contract-owned owner-а,
удаляет parallel handwritten node-shape mappings из всех подтверждённых hot
zones и фиксирует результат теми же baseline-инструментами, которыми был
доказан исходный drift, без изменения public contract behavior.

## 2. Change Boundary

### Included in the Change

- `17.1`: один private contract-owned owner boundary field schema для
  `snapshot/spec/patch` и validated fast path-ов.
- `17.2`: runtime boundary conversion `Scene <-> SceneSnapshot`,
  `txnNodeFromSnapshot(...)` и `txnNodeFromSpec(...)`.
- `17.3`: `SceneBuilder` JSON decode / import seam, включая одного owner-а
  raw JSON require helpers и adoption schema-owned field descriptions.
- `17.3.1`: shared owner для snapshot `instanceRevision` normalization,
  который нужен encode adoption без split ownership в `scene_codec.dart`.
- `17.4`: `SceneCodec` JSON encode / export seam и removal encode-side
  handwritten node-shape mapping.
- `17.5`: post-migration rebaseline по `lib/**` и roadmap refresh по факту
  оставшихся hot spots.

### Not Included in the Change

- Изменение public API, export surface, `schemaVersion = 5`,
  `schemaVersionsRead = {5}` или внешнего JSON contract-а.
- Перевод `controller/**`, `interactive/**`, `render/**` и `view/**` на
  `schema-first` в рамках этого этапа.
- Лечение residual hot spots вне `contract/model/serialization` внутри
  migration `17.1-17.4` и подготовительного `17.3.1`; они только
  переснимаются и фиксируются в `17.5`.
- Pair-mode clone output как acceptance gate.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/contract/internal/node_patch_fast_path.part.dart`
- `lib/src/contract/internal/node_spec_fast_path.part.dart`
- `lib/src/contract/internal/snapshot_fast_path.part.dart`
- `lib/src/contract/node_patch.dart`
- `lib/src/contract/node_spec.dart`
- `lib/src/contract/snapshot.dart`
- `lib/src/model/document.dart`
- `lib/src/model/document_clone.dart`
- `lib/src/model/scene_builder.dart`
- `lib/src/model/scene_builder_decode_json.part.dart`
- `lib/src/model/scene_builder_json_require.part.dart`
- `lib/src/model/scene_builder_scene_from_snapshot.part.dart`
- `lib/src/model/scene_builder_snapshot_from_scene.part.dart`
- `lib/src/model/scene_snapshot_from_scene.dart`
- `lib/src/serialization/scene_codec.dart`

### Test Files

- `test/contract/contract_layer_smoke_test.dart`
- `test/contract/owned_collections_test.dart`
- `test/contract/runtime_contract_interfaces_test.dart`
- `test/contract/validated_fast_path_contract_test.dart`
- `test/contract/validated_internal_helpers_test.dart`
- `test/model/document_model_test.dart`
- `test/model/scene_builder_test.dart`
- `test/model/scene_structural_limits_test.dart`
- `test/model/scene_value_validation_primitives_test.dart`
- `test/public_api/node_patch_semantics_test.dart`
- `test/public_api/scene_builder_test.dart`
- `test/public_api/snapshot_immutability_test.dart`
- `test/public_api/validated_boundary_value_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/serialization/scene_fixture_test.dart`
- `test/serialization/scene_test.dart`

### Fixture and Supporting Data Files

- `analysis_options.yaml`
- `DEVELOPMENT_PLAN.md`
- `development_plan/step_17_schema_first_boundary_transition.md`
- `development_plan/step_17_1_contract_owned_boundary_schema_owner.md`
- `development_plan/step_17_2_scene_snapshot_boundary_mapping_schema_adoption.md`
- `development_plan/step_17_3_scene_builder_decode_schema_adoption.md`
- `development_plan/step_17_3_1_snapshot_instance_revision_owner_alignment.md`
- `development_plan/step_17_4_scene_codec_encode_schema_adoption.md`
- `development_plan/step_17_5_boundary_migration_rebaseline_and_roadmap.md`

### Analysis Area

- `lib/src/contract/**`
- `lib/src/model/**`
- `lib/src/serialization/**`
- `test/contract/**`
- `test/model/**`
- `test/public_api/**`
- `test/serialization/**`
- `development_plan/step_17*.md`
- `DEVELOPMENT_PLAN.md`
- `analysis_options.yaml`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to exactly one step-owned
  seam.
- Every new or modified test must be tied to a specific verification surface of
  one slice.
- Every new or modified planning document must be tied either to execution
  control of `17.x` or to the measured residual-work output of `17.5`.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. Для boundary field semantics существует ровно один private contract-owned
   schema owner; `model/**` и `serialization/**` могут только потреблять его,
   но не определять параллельный owner тех же node shapes.
2. Public contract types остаются явными; шаг `17` не вводит generic nullable
   payload object вместо `ImageNodeSpec`, `TextNodeSnapshot`,
   `RectNodePatch` и связанных типов.
3. `schemaVersion = 5`, `schemaVersionsRead = {5}` и текущий внешний JSON
   contract остаются без изменения.
4. `SceneSnapshot` остаётся публичной committed boundary model, а runtime
   `Scene` остаётся внутренней mutable model.
5. JSON transport ownership не переносится в schema owner: parse / require /
   `SceneDataException` attribution остаются ownership decode / encode слоёв,
   а schema owner определяет только boundary field families и node-shape
   semantics.
6. `controller`, `interactive`, `render` и `view` не входят в semantic scope
   migration; их residual hot spots только фиксируются в `17.5`.
7. После закрытия конкретного подшага нельзя оставлять schema-owned mapping и
   legacy handwritten mapping параллельно для той semantic surface, которой
   владеет этот подшаг.
8. Новые owner-ы и step-owned methods обязаны оставаться в пределах
   configured порогов из `analysis_options.yaml`.

## 5. Result Requirements

1. Во всех подтверждённых boundary hot zones `contract/model/serialization`
   существует один schema-first source of truth для common и family-specific
   node-shape semantics.
2. В `contract`, runtime conversion, JSON decode/import и JSON encode/export
   не остаётся второго handwritten node-shape mapping рядом со
   schema-owned path в принадлежащем этим seams коде.
3. Public contract behavior остаётся эквивалентным текущему состоянию:
   explicit contract types, `schemaVersion = 5`, JSON field naming,
   supported schema versions, `SceneDataException` attribution, committed role
   `SceneSnapshot` и mutable role `Scene`.
4. Подшаги `17.1-17.4` и подготовительный `17.3.1` закрывают migration
   seam-by-seam без пересечений по ownership, а `17.5` фиксирует
   пост-миграционный baseline и residual work без возврата к старой `16.x`
   программе.
5. Повторный cluster-mode clone inventory и configured DCM baseline по `lib/**`
   подтверждают новую post-schema-first реальность, а не старые предположения
   о duplicate ownership.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Для diagnostics acceptance разрешён только graph / clusters режим:
  `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`.
- Pair-mode вывод не используется как closure evidence для `17.x`.
- Подтверждённый стартовый graph baseline:
  - `clusters = 63`
  - `scannedFiles = 115`
  - `scannedBlocks = 602`
- Подтверждённый стартовый configured DCM baseline:
  - `number-of-parameters = 40`
  - `source-lines-of-code = 21`
  - `cyclomatic-complexity = 5`
  - `maximum-nesting-level = 0`
- Контрольные hot zones, которые нельзя оставлять ничьими:
  - contract family:
    `node_patch_fast_path.part.dart`,
    `node_spec_fast_path.part.dart`,
    `snapshot_fast_path.part.dart`,
    `node_patch.dart`,
    `node_spec.dart`,
    `snapshot.dart`
  - model / serialization family:
    `document.dart`,
    `document_clone.dart`,
    `scene_builder_decode_json.part.dart`,
    `scene_builder_json_require.part.dart`,
    `scene_builder_scene_from_snapshot.part.dart`,
    `scene_snapshot_from_scene.dart`,
    `scene_codec.dart`
- Подтверждённые residual hot spots вне ownership `17.1-17.4` и `17.3.1`,
  которые только переснимаются и явно фиксируются в `17.5`:
  - `lib/src/controller/scene_controller.dart`
  - `lib/src/controller/scene_invariants.dart`
  - `lib/src/core/node_geometry.dart`
  - `lib/src/render/scene_painter.dart`

### 6.2 Target Verification Units

- Scoped Final Verification из:
  - `development_plan/step_17_1_contract_owned_boundary_schema_owner.md`
  - `development_plan/step_17_2_scene_snapshot_boundary_mapping_schema_adoption.md`
  - `development_plan/step_17_3_scene_builder_decode_schema_adoption.md`
  - `development_plan/step_17_3_1_snapshot_instance_revision_owner_alignment.md`
  - `development_plan/step_17_4_scene_codec_encode_schema_adoption.md`
  - `development_plan/step_17_5_boundary_migration_rebaseline_and_roadmap.md`
- Full project code-change validation policy:
  - `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
  - `flutter analyze`
  - `(cd example && flutter analyze lib test)`
  - `dcm analyze .`
  - `dart run tool/check_import_boundaries.dart`
  - `dart run tool/check_public_api_surface.dart`
  - `dart run tool/check_guardrails.dart`
  - `dart run tool/check_invariant_coverage.dart`
  - MCP test shards from the project validation policy
  - `flutter test --coverage --no-pub --exclude-tags=tool`
  - `dart run tool/check_coverage.dart`

### 6.3 Protected States, Data, or Structures

- Public contract types and their explicit constructor surface.
- `schemaVersion = 5`, `schemaVersionsRead = {5}`, JSON field naming, and the
  external JSON contract.
- `SceneSnapshot` as the committed boundary model and `Scene` as the mutable
  runtime model.
- Decode-side ownership of raw JSON parsing and `SceneDataException`
  attribution.
- Encode-side ownership of canonical JSON emission.
- Layer boundaries and residual hot spots outside `contract/model/serialization`.

### 6.4 Allowed Semantic Change Zones

- Contract schema owner and contract-side consumers in `17.1`.
- Runtime boundary conversion in `17.2`.
- JSON decode / import seam in `17.3`.
- Snapshot `instanceRevision` normalization prerequisite in `17.3.1`.
- JSON encode / export seam in `17.4`.
- Post-migration measurement and roadmap refresh in `17.5`.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- `17.1` defines the only owner of boundary field semantics and must close
  before any downstream seam may adopt schema-owned mapping.
- `17.2` owns the entire runtime conversion seam:
  `document.dart`,
  `document_clone.dart`,
  `scene_builder_scene_from_snapshot.part.dart`,
  `scene_builder_snapshot_from_scene.part.dart`,
  `scene_snapshot_from_scene.dart`.
- `17.3` owns the entire decode seam:
  `scene_builder.dart`,
  `scene_builder_decode_json.part.dart`,
  `scene_builder_json_require.part.dart`.
- `17.3.1` owns the shared snapshot revision prerequisite:
  `revision_policy.dart`,
  `document.dart`.
- `17.4` owns the entire encode seam:
  `scene_codec.dart`.
- `17.5` reads the post-migration state and updates planning documents; it does
  not reopen semantic scope from `17.1-17.4` or `17.3.1`.
- If a file belongs to one owner in the matrix above, no parallel slice may
  redefine semantic ownership for that file.

### 6.8 Prohibited

- Оставлять рядом schema-owned declaration и второй handwritten table для той
  же node-family semantics.
- Создавать bridge, sync glue или legacy adapter, который продолжает
  дублировать ту же boundary семантику после закрытия slice.
- Ослаблять `analysis_options.yaml`, добавлять ignore-комментарии или закрывать
  шаг косметическим decomposition без structural consolidation.
- Уносить runtime orchestration, commit semantics, render behavior, cache
  policy или controller invariants в schema layer ради closure metrics.
- Начинать downstream migration seam до зелёного закрытия его upstream
  prerequisite slice.
- Возвращать старую `16.x` seam-by-seam программу как execution path без
  post-step baseline из `17.5`.

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
9. Slice 1 (`17.1`) is mandatory and must close before slices 2, 3, or 4 may
   start.
10. Slice 2 (`17.2`) must close before slice 3 (`17.3`) may start.
11. Slice 3 (`17.3`) must close before slice 3.1 (`17.3.1`) may start.
12. Slice 3.1 (`17.3.1`) must close before slice 4 (`17.4`) may start.
13. Slice 5 (`17.5`) is forbidden until slices 1-4 and 3.1 are closed and
   their Final Verification runs are green.
14. Umbrella step `17` is closed only when slices 1-5 and 3.1 are closed, the
   post-step baseline is explicitly compared with the starting baseline, and
   the project-wide final verification is green.

## 8. Vertical Slices

### Slice 1. [ ] Contract schema owner becomes the only boundary source of truth

#### Slice Contract

`snapshot/spec/patch` и validated fast path-ы используют одного private
contract-owned owner-а boundary field schema без parallel handwritten
field tables.

#### Change

Закрыть `development_plan/step_17_1_contract_owned_boundary_schema_owner.md`
без выхода за границы ownership `17.1`.

#### Verification

- `dcm calculate-metrics lib/src/contract/internal/node_patch_fast_path.part.dart lib/src/contract/internal/node_spec_fast_path.part.dart lib/src/contract/internal/snapshot_fast_path.part.dart lib/src/contract/node_patch.dart lib/src/contract/node_spec.dart lib/src/contract/snapshot.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib/src/contract`
- MCP test runner: `test/contract/contract_layer_smoke_test.dart test/contract/owned_collections_test.dart test/contract/runtime_contract_interfaces_test.dart test/contract/validated_fast_path_contract_test.dart test/contract/validated_internal_helpers_test.dart`
- MCP test runner: `test/public_api/node_patch_semantics_test.dart test/public_api/snapshot_immutability_test.dart test/public_api/validated_boundary_value_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- Contract seam no longer holds a second handwritten field table for the
  migrated `snapshot/spec/patch` families.

### Slice 2. [ ] Runtime conversion consumes the schema-owned boundary path

#### Slice Contract

`Scene <-> SceneSnapshot`, `txnNodeFromSnapshot(...)`, and
`txnNodeFromSpec(...)` consume schema-owned node semantics and no longer define
their own handwritten node-shape mapping.

#### Change

Закрыть `development_plan/step_17_2_scene_snapshot_boundary_mapping_schema_adoption.md`
без выхода за границы ownership `17.2`.

#### Verification

- `dcm calculate-metrics lib/src/model/document.dart lib/src/model/document_clone.dart lib/src/model/scene_builder_scene_from_snapshot.part.dart lib/src/model/scene_builder_snapshot_from_scene.part.dart lib/src/model/scene_snapshot_from_scene.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib/src/model`
- MCP test runner: `test/model/document_model_test.dart test/model/scene_builder_test.dart test/model/scene_structural_limits_test.dart`
- MCP test runner: `test/public_api/scene_builder_test.dart test/public_api/validated_boundary_value_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- Runtime conversion seam no longer keeps a second handwritten node-shape
  mapping next to the schema-owned path.

### Slice 3. [ ] Decode/import keeps transport ownership and drops duplicate semantics

#### Slice Contract

`SceneBuilder` decode/import keeps ownership of raw JSON parsing and
`SceneDataException` attribution, but no longer defines a second handwritten
boundary mapping or duplicate JSON require helper family.

#### Change

Закрыть `development_plan/step_17_3_scene_builder_decode_schema_adoption.md`
без выхода за границы ownership `17.3`.

#### Verification

- `dcm calculate-metrics lib/src/model/scene_builder.dart lib/src/model/scene_builder_decode_json.part.dart lib/src/model/scene_builder_json_require.part.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib/src/model`
- MCP test runner: `test/model/scene_builder_test.dart test/model/scene_value_validation_primitives_test.dart`
- MCP test runner: `test/public_api/scene_builder_test.dart test/public_api/validated_boundary_value_test.dart`
- MCP test runner: `test/serialization/scene_fixture_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- Decode seam no longer contains the migrated duplicate helper family or a
  second handwritten node-shape mapping.

### Slice 3.1. [ ] Snapshot revision ownership is aligned before encode migration

#### Slice Contract

Snapshot `instanceRevision` normalization is owned by one reusable prerequisite
outside the private txn-only body, so `17.4` does not need to reopen revision
ownership when it migrates the encode seam.

#### Change

Закрыть `development_plan/step_17_3_1_snapshot_instance_revision_owner_alignment.md`
без выхода за границы ownership `17.3.1`.

#### Verification

- `dcm calculate-metrics lib/src/core/revision_policy.dart lib/src/model/document.dart --report-all`
- MCP test runner: `test/model/document_model_test.dart`
- MCP test runner: `test/serialization/scene_codec_validation_test.dart test/serialization/scene_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- Snapshot revision normalization no longer lives only in the private txn seam.

### Slice 4. [ ] Encode/export remains the canonical transport owner

#### Slice Contract

`SceneCodec` stays the owner of canonical JSON emission, but no longer defines
its own handwritten node-shape mapping outside the schema-owned path.

#### Change

Закрыть `development_plan/step_17_4_scene_codec_encode_schema_adoption.md`
без выхода за границы ownership `17.4`.

#### Verification

- `dcm calculate-metrics lib/src/serialization/scene_codec.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib/src/serialization`
- MCP test runner: `test/serialization/scene_codec_validation_test.dart test/serialization/scene_fixture_test.dart test/serialization/scene_test.dart`
- MCP test runner: `test/public_api/validated_boundary_value_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- Encode seam no longer encodes a manual common or family-specific field table
  outside the schema-owned path.

### Slice 5. [ ] Rebaseline proves the migration and resets the roadmap

#### Slice Contract

The post-schema-first state of `lib/**` is measured with the same clone/DCM
instruments as the starting baseline, and the roadmap reflects only measured
residual work.

#### Change

Закрыть `development_plan/step_17_5_boundary_migration_rebaseline_and_roadmap.md`
без повторного открытия semantic scope `17.1-17.4`.

#### Verification

- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`
- `dcm calculate-metrics lib`

#### Closure Evidence

- Green run of the listed verifications.
- The output explicitly compares the starting and post-step baselines and the
  roadmap no longer carries stale assumptions about already-removed boundary
  duplication.

## 9. Final Verification

- `dcm calculate-metrics lib/src/contract/internal/node_patch_fast_path.part.dart lib/src/contract/internal/node_spec_fast_path.part.dart lib/src/contract/internal/snapshot_fast_path.part.dart lib/src/contract/node_patch.dart lib/src/contract/node_spec.dart lib/src/contract/snapshot.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib/src/contract`
- `dcm calculate-metrics lib/src/model/document.dart lib/src/model/document_clone.dart lib/src/model/scene_builder_scene_from_snapshot.part.dart lib/src/model/scene_builder_snapshot_from_scene.part.dart lib/src/model/scene_snapshot_from_scene.dart --report-all`
- `dcm calculate-metrics lib/src/model/scene_builder.dart lib/src/model/scene_builder_decode_json.part.dart lib/src/model/scene_builder_json_require.part.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib/src/model`
- `dcm calculate-metrics lib/src/serialization/scene_codec.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib/src/serialization`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`
- `dcm calculate-metrics lib`
- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner: `test/core`
- MCP test runner: `test/model test/serialization test/contract test/public_api test/entrypoints`
- MCP test runner: `test/controller/internal`
- MCP test runner: `test/controller/core test/controller/commands` plus controller-root `*_test.dart` files
- MCP test runner: `test/render test/view`
- MCP test runner: `test/interactive`
- MCP test runner: `example/test` with MCP root `example/`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
