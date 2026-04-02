language: russian

# Шаг 74. Ввести семантическую модель `public/internal/bridge` для import boundaries

## 1. Change Mandate

Этот шаг переводит import-boundary enforcement с решения только по `fromLayer -> toLayer` на решение по `fromLayer -> targetSurfaceKind`, чтобы доступ в чужой `internal/**` был запрещён как архитектурный класс, а подтверждённые internal bridge-поверхности были выражены явно и проверялись отдельным правилом.

## 2. Change Boundary

### Included in the Change

- Введение семантической классификации resolved target surfaces: `public`, `internal`, `bridge`.
- Привязка решения import-boundary policy к `targetSurfaceKind`, а не только к `targetLayer`.
- Выражение подтверждённых canonical bridge-поверхностей в `contract/internal/**` как explicit `bridge` descriptors с точным списком friend layers.
- Замена current special-case `view -> interactive/internal/**` на общее semantic rule.
- Расширение sandbox regression-матрицы import-boundary tooling для `public/internal/bridge` по package, relative, export и top-level barrel forms.
- `PLAN.md` и `plan/step_74_cross_layer_internal_import_guardrails.md`.

### Not Included in the Change

- Любая работа по `check_invariant_coverage.dart`, `tool/invariant_registry.dart`, `check_guardrails.dart`, `.github/workflows/ci.yaml` или `VERIFICATION.md`.
- Любая массовая перепривязка инвариантов `render / write / model`.
- Любая смена controller-specific structure rules для `controller/commands/**` и `controller/internal/**`.
- Любое расширение bridge-правил на директорию `contract/internal/**` целиком.
- Любая попытка выражать `bridge` через source-file exceptions, naming conventions или комментарии вместо одной machine-readable policy surface.

## 3. File Map and Analysis Areas

### Implementation Files

- `tool/src/import_boundaries/import_boundary_policy.dart`
- `tool/src/import_boundaries/directive_boundary_checker.dart`

### Test Files

- `test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart`
- `test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart`
- `test/tool/import_boundaries/import_boundaries_external_packages_tool_test.dart`
- `test/tool/import_boundaries/import_boundaries_layout_tool_test.dart`

### Fixture and Supporting Data Files

- `test/tool/support/guardrails_tool_test_support.dart`
- `test/tool/support/tool_process_test_support.dart`
- `PLAN.md`
- `plan/step_74_cross_layer_internal_import_guardrails.md`

### Analysis Area

- `tool/src/import_boundaries/**`
- `test/tool/import_boundaries/**`
- `lib/src/**`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific slice and its verification cannot be closed.

### File Change Rule

- Каждый изменённый implementation file должен быть привязан к конкретному slice.
- Каждый новый или изменённый sandbox scenario должен доказывать либо разрешённую surface form, либо запрещённую surface form.
- Любой новый diagnostic assertion должен быть привязан к конкретной violation category нового semantic rule.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. Верхнеуровневый layer DAG остаётся действующим правилом для `public` surface и не заменяется новой моделью.
2. Semantic model import surfaces ограничена тремя значениями: `public`, `internal`, `bridge`.
3. Любой resolved target под `/<layer>/internal/**` считается `internal`, если он не совпадает с exact `bridge` descriptor-ом.
4. `Bridge` precedence выше generic `internal`, потому что подтверждённые bridge surfaces физически лежат под `contract/internal/**`.
5. `Same-layer -> same-layer/internal/**` остаётся разрешённой формой.
6. Подтверждённые bridge surfaces ограничены exact target paths `lib/src/contract/internal/node_boundary_schema.dart` и `lib/src/contract/internal/snapshot_fast_path.dart`.
7. Friend layers для обеих подтверждённых bridge surfaces ограничены `model` и `serialization`; broad layer-to-directory exceptions запрещены.
8. Current controller-specific path rules для `controller/commands/**` и `controller/internal/**` сохраняют приоритет и не переписываются через новую surface taxonomy.
9. Current `PublicExportBoundaryResolver` продолжает быть источником resolved targets для top-level `lib/*.dart` barrel re-exports.
10. Current special-case `view -> interactive/internal/**` должен исчезнуть как отдельная ветка и быть покрыт общим semantic rule.

## 5. Result Requirements

1. `tool/check_import_boundaries.dart` принимает решение по resolved target surface kind, а не только по `targetLayer`.
2. Любой межслойный доступ в чужой `internal/**`, который не классифицирован как `bridge`, автоматически отклоняется независимо от того, разрешён ли соответствующий верхнеуровневый layer DAG.
3. Подтверждённые bridge surfaces разрешают доступ только owner layer и friend layers `model` и `serialization`.
4. Same-layer imports в собственный `internal/**` остаются зелёными.
5. Current `public` imports, которые не лежат под `internal/**`, продолжают проверяться только через existing layer DAG и не становятся ложными нарушениями.
6. Diagnostic output различает минимум две semantic violation categories: `cross-layer internal boundary violation` и `bridge boundary violation`.
7. Top-level `lib/*.dart` barrel re-exports, раскрытые current resolver-ом в foreign `internal/**`, отклоняются по той же semantic policy, что и direct package/relative imports.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Текущая policy знает только allowlist верхнеуровневых layer dependencies и не содержит отдельной semantic dimension для target surface.
- Текущий checker содержит отдельный hardcoded special-case только для `view -> interactive/internal/**`.
- В текущем дереве подтверждены межслойные импорты в `contract/internal/**` из `model/**` и `serialization/**`.
- Подтверждённые target paths этих bridge-импортов: `lib/src/contract/internal/node_boundary_schema.dart` и `lib/src/contract/internal/snapshot_fast_path.dart`.
- Текущие consumer files этих bridge surfaces находятся под `lib/src/model/**` и `lib/src/serialization/scene_codec.dart`.

### 6.2 Target Verification Units

- `dart run tool/run_tool_tests.dart test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart test/tool/import_boundaries/import_boundaries_external_packages_tool_test.dart test/tool/import_boundaries/import_boundaries_layout_tool_test.dart`
- `dart run tool/check_import_boundaries.dart`

### 6.3 Protected States, Data, or Structures

- Текущая матрица разрешённых верхнеуровневых layer dependencies.
- Current public imports `view -> interactive/**`, которые идут в публичные файлы, а не в `interactive/internal/**`.
- Текущие canonical bridge-импорты в `contract/internal/node_boundary_schema.dart` и `contract/internal/snapshot_fast_path.dart`.
- Controller-specific structure guardrails для `controller/commands/**` и `controller/internal/**`.
- Current layout handling для approved/deleted/unapproved top-level `lib/src` entries.
- Current external package policy by layer.

### 6.4 Allowed Semantic Change Zones

- Semantic classification resolved target path into `public/internal/bridge`.
- Exact bridge descriptor structure and matching rules.
- Decision order inside `DirectiveBoundaryChecker` after resolution.
- Diagnostic wording and category split for new semantic violations.
- Sandbox scenarios, покрывающие semantic matrix `public/internal/bridge`.

### 6.5 Recognition Forms That Must Be Supported Within This Change

- direct package import into foreign `internal/**`;
- relative import into foreign `internal/**`;
- export into foreign `internal/**`;
- top-level `lib/*.dart` barrel re-export resolved to foreign `internal/**`;
- same-layer import into own `internal/**`;
- friend-layer import into exact `bridge` target under `contract/internal/**`;
- non-friend import into exact `bridge` target under `contract/internal/**`.

### 6.6 Allowed Forms That Do Not Count as Violations

- Same-layer imports in `internal/**` of the same top-level layer.
- Existing allowed `public` imports where the target is not under `internal/**`.
- Exact `bridge` imports to `contract/internal/node_boundary_schema.dart` and `contract/internal/snapshot_fast_path.dart` only from `model`, `serialization`, or `contract`.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- Semantic classification must run only after target URI has been resolved to a repo-relative path or classified as external/non-repo.
- Classification order is fixed:
  1. if target is not a resolved `lib/src/**` file, keep current external/layout behavior;
  2. resolve `targetLayer`;
  3. if resolved path matches an exact `bridge` descriptor, classify as `bridge`;
  4. else if resolved path starts with `/<targetLayer>/internal/`, classify as `internal`;
  5. else classify as `public`.
- Policy decision order inside the general-layer path is fixed:
  1. external package policy;
  2. layout / unresolved `lib/src` handling;
  3. semantic surface classification;
  4. `internal` policy;
  5. `bridge` policy;
  6. `public` policy through existing `isAllowedLayerDependency(...)`.
- `PublicExportBoundaryResolver` must continue to expand top-level `lib/*.dart` barrels before semantic classification so that re-export bypasses are checked by the same rule surface as direct imports.
- `Bridge` decision must check exact target path and allowed importer layers; source-file-specific or URI-string-specific exceptions are forbidden.
- Diagnostic wording must expose the semantic reason for rejection, not degrade to a generic layer DAG message when the rejected target is `internal` or `bridge`.

### 6.8 Prohibited

- Расширять bridge-доступ до уровня `model -> contract/internal/**` или `serialization -> contract/internal/**` целиком.
- Оставлять общий rule неявным через набор layer-specific special-cases.
- Определять `bridge` по имени файла, префиксу URI, комментариям или расположению consumer-а вместо exact resolved target descriptor.
- Менять текущие controller structure guardrails в том же шаге.
- Ослаблять существующие sandbox assertions, чтобы провести новую semantic policy без точной диагностики.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice closes a failure scenario, diagnostic output confirming the trigger point must be attached.
7. If a slice changes an analysis rule, negative and positive scenarios must be covered where applicable to the subject of the change.
8. Scope expansion is forbidden until the mandatory slices are closed.

## 8. Vertical Slices

### Slice 1. [ ] Surface Taxonomy Policy

#### Slice Contract

`import_boundary_policy.dart` описывает resolved target surfaces через одну semantic taxonomy `public/internal/bridge`, где `bridge` выражен exact descriptors для двух подтверждённых `contract/internal/**` поверхностей и не расширяется на директорию целиком.

#### Change

Ввести в `import_boundary_policy.dart` machine-readable target-surface model с точным классификатором:
- `public` для resolved `lib/src/**` targets вне `internal/**` и вне exact bridge descriptors;
- `internal` для resolved `/<layer>/internal/**`, не совпадающих с bridge descriptors;
- `bridge` только для `lib/src/contract/internal/node_boundary_schema.dart` и `lib/src/contract/internal/snapshot_fast_path.dart`.
В том же файле зафиксировать friend layers `model` и `serialization` для обеих bridge surfaces.

#### Verification

- `dart run tool/run_tool_tests.dart test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart`

#### Fixtures Used

- `test/tool/support/guardrails_tool_test_support.dart`
- `test/tool/support/tool_process_test_support.dart`

#### Positive Scenarios

- `interactive/** -> interactive/internal/**` классифицируется как same-layer `internal` и разрешается.
- `view/** -> interactive/scene_controller.dart` классифицируется как `public` и остаётся разрешённым.
- `model/** -> contract/internal/snapshot_fast_path.dart` классифицируется как `bridge` и разрешается.
- `serialization/** -> contract/internal/node_boundary_schema.dart` классифицируется как `bridge` и разрешается.

#### Negative Scenarios

- `model/** -> contract/internal/unlisted_internal.dart` не должен считаться `bridge`.
- `view/** -> contract/internal/node_boundary_schema.dart` не должен считаться разрешённым friend bridge access.

#### Closure Evidence

- Green run of the listed verification.
- Regression matrix in the slice verification distinguishes `bridge` from generic `internal`.

### Slice 2. [ ] Semantic Enforcement Order

#### Slice Contract

`DirectiveBoundaryChecker` применяет semantic taxonomy после resolution и до generic layer DAG decision, сохраняет приоритет controller-specific rules и выдаёт отдельные diagnostics для `internal` и `bridge` нарушений.

#### Change

Переписать general-layer branch в `directive_boundary_checker.dart` так, чтобы:
- current controller-specific early-return для `controller/commands/**` и `controller/internal/**` оставался неизменным;
- current hardcoded `view -> interactive/internal/**` special-case исчез;
- rejected foreign `internal` targets выдавали diagnostic category `cross-layer internal boundary violation`;
- rejected `bridge` targets от non-friend layers выдавали diagnostic category `bridge boundary violation`;
- generic `layer DAG violation` применялся только к `public` surfaces.

#### Verification

- `dart run tool/run_tool_tests.dart test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart`

#### Fixtures Used

- `test/tool/support/guardrails_tool_test_support.dart`
- `test/tool/support/tool_process_test_support.dart`

#### Positive Scenarios

- Current controller structure violations продолжают определяться своей existing category и не переписываются как surface-taxonomy violations.
- Current allowed `view -> interactive/public` imports остаются зелёными и не деградируют в `bridge` или `internal` diagnostics.

#### Negative Scenarios

- `view/** -> interactive/internal/**` отклоняется как `cross-layer internal boundary violation`.
- `render/** -> controller/internal/**` отклоняется как `cross-layer internal boundary violation`.
- `view/** -> contract/internal/node_boundary_schema.dart` отклоняется как `bridge boundary violation`.

#### Closure Evidence

- Green run of the listed verifications.
- Negative scenarios prove distinct semantic diagnostics instead of generic layer DAG failure.

### Slice 3. [ ] Full Regression Matrix For Resolved Forms

#### Slice Contract

Sandbox regression matrix доказывает semantic policy `public/internal/bridge` на всех поддерживаемых resolved forms и подтверждает, что реальное дерево репозитория остаётся зелёным.

#### Change

Расширить `import_boundaries_layer_dag_tool_test.dart` так, чтобы матрица покрывала:
- direct package imports;
- relative imports;
- direct exports;
- top-level `lib/*.dart` barrel re-exports, раскрытые через current resolver;
- same-layer `internal`;
- friend `bridge`;
- non-friend `bridge`;
- foreign non-bridge `internal`.

#### Verification

- `dart run tool/run_tool_tests.dart test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart test/tool/import_boundaries/import_boundaries_external_packages_tool_test.dart test/tool/import_boundaries/import_boundaries_layout_tool_test.dart`
- `dart run tool/check_import_boundaries.dart`

#### Fixtures Used

- `test/tool/support/guardrails_tool_test_support.dart`
- `test/tool/support/tool_process_test_support.dart`

#### Positive Scenarios

- Relative same-layer import into own `internal/**` проходит.
- Barrel-resolved import в allowed `public` target проходит.
- Barrel-resolved or direct import в allowed `bridge` target from friend layer проходит.

#### Negative Scenarios

- Relative import в foreign `internal/**` отклоняется как `cross-layer internal boundary violation`.
- Export or barrel-resolved import в foreign `internal/**` отклоняется тем же semantic rule.
- Direct or barrel-resolved import в `bridge` target от non-friend layer отклоняется как `bridge boundary violation`.

#### Closure Evidence

- Green run of the listed verifications.
- Real-tree run of `tool/check_import_boundaries.dart` stays green with the semantic taxonomy in place.

## 9. Final Verification

- `dart run tool/run_tool_tests.dart test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart test/tool/import_boundaries/import_boundaries_external_packages_tool_test.dart test/tool/import_boundaries/import_boundaries_layout_tool_test.dart`
- `dart run tool/check_import_boundaries.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
