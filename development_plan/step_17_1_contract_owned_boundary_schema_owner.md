language: russian

# Шаг 17.1. Ввести одного contract-owned owner-а boundary field schema

## 1. Change Mandate

Этот шаг вводит одного private contract-owned owner-а boundary field schema в
`contract/**`, переводит на него `snapshot/spec/patch` и validated fast path-ы
и удаляет parallel handwritten field tables без изменения public API.

## 2. Change Boundary

### Included in the Change

- Один private schema-owned assembly для common node fields и
  family-specific boundary fields в contract seam.
- Перевод `lib/src/contract/node_patch.dart`,
  `lib/src/contract/node_spec.dart` и `lib/src/contract/snapshot.dart` на thin
  consumption этого owner-а.
- Перевод validated fast path-ов на тот же owner без второго handwritten
  mapping.
- Удаление legacy parallel field-group implementations, которые новый owner
  заменяет в contract seam.

### Not Included in the Change

- `lib/src/model/**`
- `lib/src/serialization/**`
- JSON transport semantics
- Runtime `Scene <-> SceneSnapshot` mapping
- `controller/**`, `interactive/**`, `render/**`, `view/**`

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/contract/internal/node_patch_fast_path.part.dart`
- `lib/src/contract/internal/node_spec_fast_path.part.dart`
- `lib/src/contract/internal/snapshot_fast_path.part.dart`
- `lib/src/contract/node_patch.dart`
- `lib/src/contract/node_spec.dart`
- `lib/src/contract/snapshot.dart`

### Test Files

- `test/contract/contract_layer_smoke_test.dart`
- `test/contract/owned_collections_test.dart`
- `test/contract/runtime_contract_interfaces_test.dart`
- `test/contract/validated_fast_path_contract_test.dart`
- `test/contract/validated_internal_helpers_test.dart`
- `test/public_api/node_patch_semantics_test.dart`
- `test/public_api/snapshot_immutability_test.dart`
- `test/public_api/validated_boundary_value_test.dart`

### Fixture and Supporting Data Files

- `analysis_options.yaml`

### Analysis Area

- `lib/src/contract/**`
- `test/contract/**`
- `test/public_api/**`
- `analysis_options.yaml`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every new or modified supporting file must be tied to a specific
  verification or metric gate.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. Новый schema owner остаётся private и contract-owned; он не экспортируется
   как public runtime service.
2. Новый schema owner может зависеть только от contract-side validated / value
   primitives и leaf runtime types; зависимости на `model/**` и
   `serialization/**` запрещены.
3. Public contract types остаются явными; этот шаг не заменяет
   `ImageNodeSpec`, `TextNodeSnapshot`, `RectNodePatch` и связанные типы одним
   generic nullable payload object.
4. `schemaVersion = 5` и внешний JSON contract этим шагом не меняются.
5. Primitive validation ownership не переносится в новый generic parser;
   validated fast path-ы продолжают работать с already-validated values.
6. Шаг закрывается только если в contract seam не осталось второго handwritten
   field table для тех же `snapshot/spec/patch` families.

## 5. Result Requirements

1. В contract seam существует ровно один owner common и family-specific
   boundary field semantics для `snapshot/spec/patch`.
2. Public constructors `snapshot/spec/patch` сохраняют текущие accepted inputs
   и output semantics.
3. Validated fast path-ы продолжают строить идентичные already-validated
   boundary values через тот же schema-owned path.
4. Новые owner-ы и step-owned methods не создают новых `HIGH`/`VERY HIGH`
   нарушений по configured metrics из `analysis_options.yaml`.
5. Повторный clone inventory по `lib/src/contract` больше не содержит baseline
   boundary families, дублировавшиеся между `snapshot`, `node_spec`,
   `node_patch` и их fast path-ами.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Анализ ограничен contract seam, где уже подтверждены:
  - family cluster внутри `lib/src/contract/node_patch.dart` для
    `CommonNodePatch` и type-specific `*NodePatch`;
  - отдельный family cluster внутри
    `lib/src/contract/internal/node_patch_fast_path.part.dart` для
    `*NodePatchFromValidated`;
  - cross-file cluster между `lib/src/contract/node_spec.dart` и
    `lib/src/contract/snapshot.dart`.
- В анализе должны быть учтены configured DCM hotspots validated fast path-ов:
  - `textNodePatchFromValidated(...) = 12` по `number-of-parameters`;
  - `textNodeSpecFromValidated(...) = 19` по `number-of-parameters`;
  - `textNodeSnapshotFromValidated(...) = 21` по `number-of-parameters`.
- Public constructors и internal validated builders уже сосуществуют в этом
  seam; migration должна консолидировать ownership внутри `contract/**`, а не
  переносить его в downstream consumers.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/contract/internal/node_patch_fast_path.part.dart lib/src/contract/internal/node_spec_fast_path.part.dart lib/src/contract/internal/snapshot_fast_path.part.dart lib/src/contract/node_patch.dart lib/src/contract/node_spec.dart lib/src/contract/snapshot.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib/src/contract`
- MCP test runner: `test/contract/contract_layer_smoke_test.dart test/contract/owned_collections_test.dart test/contract/runtime_contract_interfaces_test.dart test/contract/validated_fast_path_contract_test.dart test/contract/validated_internal_helpers_test.dart`
- MCP test runner: `test/public_api/node_patch_semantics_test.dart test/public_api/snapshot_immutability_test.dart test/public_api/validated_boundary_value_test.dart`

### 6.3 Protected States, Data, or Structures

- Public contract types and their explicit constructor surface.
- `schemaVersion = 5` and the external JSON contract.
- Contract-side validated / value primitives.
- Already-validated fast path behavior and accepted inputs of
  `snapshot/spec/patch`.

### 6.4 Allowed Semantic Change Zones

- Один private schema-owned assembly для common node fields и
  family-specific boundary fields.
- Thin private helpers или direct constructor consumption, производные от
  этого owner-а, в `node_patch.dart`, `node_spec.dart` и `snapshot.dart`.
- Validated fast path assembly, который использует тот же owner и собирает
  только already-validated boundary values.
- Новый helper file только внутри `lib/src/contract/internal/**`, если без
  него нельзя закрыть конкретный slice.

### 6.8 Prohibited

- Экспортировать новый schema owner как public runtime service.
- Вводить зависимости schema owner-а на `model/**` или `serialization/**`.
- Заменять explicit contract types generic nullable payload object-ом.
- Переносить primitive validation ownership в новый generic parser.
- Оставлять параллельно schema-owned declaration и legacy handwritten
  field-group implementation для одной и той же family.
- Закрывать шаг, если legacy helper всё ещё кодирует ту же field family даже
  при зелёных тестах.

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

### Slice 1. [x] Private contract boundary schema owner

#### Slice Contract

В contract seam существует один private owner, который описывает common node
fields и family-specific boundary fields для `snapshot/spec/patch`.

#### Change

Ввести private schema-owned assembly в пределах `lib/src/contract/**` с
разрешёнными зависимостями и без изменения public export surface.

#### Verification

- `dcm calculate-metrics lib/src/contract/internal/node_patch_fast_path.part.dart lib/src/contract/internal/node_spec_fast_path.part.dart lib/src/contract/internal/snapshot_fast_path.part.dart lib/src/contract/node_patch.dart lib/src/contract/node_spec.dart lib/src/contract/snapshot.dart --report-all`
- MCP test runner: `test/contract/contract_layer_smoke_test.dart test/contract/validated_internal_helpers_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- File diff shows that the owner stays private inside `lib/src/contract/**`
  and does not change the public export surface.

### Slice 2. [x] Public contract types consume the schema owner

#### Slice Contract

`NodePatch`, `NodeSpec` и `SceneSnapshot` больше не поддерживают duplicate
field tables и получают boundary field semantics из одного schema-owned path.

#### Change

Перевести `lib/src/contract/node_patch.dart`,
`lib/src/contract/node_spec.dart` и `lib/src/contract/snapshot.dart`, включая
related helpers, на thin consumption schema owner-а и удалить заменённые
legacy implementations.

#### Verification

- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib/src/contract`
- MCP test runner: `test/contract/contract_layer_smoke_test.dart test/contract/owned_collections_test.dart test/contract/runtime_contract_interfaces_test.dart`
- MCP test runner: `test/public_api/node_patch_semantics_test.dart test/public_api/snapshot_immutability_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- Clone inventory no longer shows the replaced duplicate family across
  `node_patch.dart`, `node_spec.dart`, and `snapshot.dart`.

### Slice 3. [x] Validated fast paths share the same schema-owned path

#### Slice Contract

Validated fast path-ы используют тот же schema owner и не держат второй
handwritten mapping для already-validated boundary values.

#### Change

Перевести
`lib/src/contract/internal/node_patch_fast_path.part.dart`,
`lib/src/contract/internal/node_spec_fast_path.part.dart` и
`lib/src/contract/internal/snapshot_fast_path.part.dart` на тот же owner и
удалить duplicate mapping. Особое внимание приложить к
`commonNodePatchFromValidated(...)`,
`textNodePatchFromValidated(...)`,
`textNodeSpecFromValidated(...)`,
`textNodeSnapshotFromValidated(...)`,
`_validateNodeSpecCommonFields(...)` и
`_validateNodeSnapshotCommonFields(...)`.

#### Verification

- `dcm calculate-metrics lib/src/contract/internal/node_patch_fast_path.part.dart lib/src/contract/internal/node_spec_fast_path.part.dart lib/src/contract/internal/snapshot_fast_path.part.dart lib/src/contract/node_patch.dart lib/src/contract/node_spec.dart lib/src/contract/snapshot.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib/src/contract`
- MCP test runner: `test/contract/validated_fast_path_contract_test.dart test/contract/validated_internal_helpers_test.dart`
- MCP test runner: `test/public_api/validated_boundary_value_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- No legacy helper remains that encodes the same field family in parallel with
  the schema-owned path.

## 9. Final Verification

- `dcm calculate-metrics lib/src/contract/internal/node_patch_fast_path.part.dart lib/src/contract/internal/node_spec_fast_path.part.dart lib/src/contract/internal/snapshot_fast_path.part.dart lib/src/contract/node_patch.dart lib/src/contract/node_spec.dart lib/src/contract/snapshot.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib/src/contract`
- MCP test runner: `test/contract/contract_layer_smoke_test.dart test/contract/owned_collections_test.dart test/contract/runtime_contract_interfaces_test.dart test/contract/validated_fast_path_contract_test.dart test/contract/validated_internal_helpers_test.dart`
- MCP test runner: `test/public_api/node_patch_semantics_test.dart test/public_api/snapshot_immutability_test.dart test/public_api/validated_boundary_value_test.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
