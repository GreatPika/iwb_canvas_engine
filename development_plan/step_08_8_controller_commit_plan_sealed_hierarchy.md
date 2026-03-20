language: russian

# Change Contract

## 1. Change Mandate
This change migrates the controller commit plan in `scene_controller.dart` from a single nullable-field carrier with `branchKind` to a sealed branch hierarchy that makes each commit branch representable only by its own type.

## 2. Change Boundary

### Included in the Change
- Замена internal `_ControllerCommitPlan` на sealed-иерархию private branch types в `scene_controller.dart`.
- Перевод `_buildControllerCommitPlan(...)` на возврат branch-specific plan types.
- Перевод `_executeControllerCommitPlan(...)` с `branchKind` switch и `as`-кастов на type-based pattern matching.
- Механическая адаптация private helper-сигнатур внутри той же commit зоны controller.

### Not Included in the Change
- Изменение публичного API controller, writer или других package entrypoints.
- Переработка commit pipeline вне `scene_controller.dart`.
- Изменение runtime поведения, commit semantics, signal delivery order или repaint policy.
- Ввод новых external owner-ов, service layer или второго commit abstraction поверх controller.

## 3. File Map and Analysis Areas

### Implementation Files
- `lib/src/controller/scene_controller.dart`

### Test Files
- `test/controller/core/scene_controller_commit_atomicity_test.dart`
- `test/controller/core/scene_controller_commit_failures_test.dart`
- `test/controller/core/scene_controller_signals_delivery_test.dart`
- `test/controller/core/scene_controller_commit_effects_test.dart`

### Analysis Area
- `lib/src/controller/scene_controller.dart`
- `test/controller/core/**`

### Outside the Change Boundary
- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific slice and its verification cannot be closed.

### File Change Rule
- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. Рефактор остаётся локальным для `lib/src/controller/scene_controller.dart`.
2. Публичный API и runtime behavior controller не меняются.
3. `_ControllerCommitBranchKind` и nullable branch-specific поля должны быть удалены из commit plan model.
4. Каждая commit branch model-ится отдельным private final class в sealed-иерархии `_ControllerCommitPlan`.
5. `_buildControllerCommitPlan(...)` возвращает branch-specific plan type вместо named-конструкторов одного nullable carrier-а.
6. `_executeControllerCommitPlan(...)` dispatch-ит по типу плана, а не по `branchKind`.
7. Runtime `as`-касты branch payload-ов в controller commit execution не допускаются.

## 5. Result Requirements

1. В коде больше не существует `_ControllerCommitBranchKind`.
2. `_ControllerCommitPlan` больше не содержит nullable payload fields, валидные только для части веток commit-а.
3. `noEffects`, `effectsOnly` и `stateCommit` представлены отдельными private final subtypes одного sealed base type.
4. `_executeControllerCommitPlan(...)` использует exhaustive type-based dispatch по plan subtype.
5. В controller commit execution отсутствуют `as MutationCommitCandidate`, `as Set<NodeId>` и `as int`, используемые для branch payload extraction.
6. Commit semantics для `noEffects`, `effectsOnly` и `stateCommit` остаются эквивалентны текущему поведению.

## 6. Implementation Specification

### 6.1 Analysis Scope
- Проверять только current commit plan assembly и execution path в `scene_controller.dart`.
- Считать подтверждёнными только три текущие ветки commit-а: `noEffects`, `effectsOnly`, `stateCommit`.
- Сохранять существующий ownership: controller остаётся owner-ом store apply, invariant precheck и post-commit effects.

### 6.2 Target Verification Units
- `test/controller/core/scene_controller_commit_atomicity_test.dart`
- `test/controller/core/scene_controller_commit_failures_test.dart`
- `test/controller/core/scene_controller_signals_delivery_test.dart`
- `test/controller/core/scene_controller_commit_effects_test.dart`
- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test shard `test/controller/core`
- MCP test shard `test/controller/core test/controller/commands` plus controller-root `*_test.dart` files

### 6.3 Protected States, Data, or Structures
- `_applyCommittedStore(...)` остаётся единственной точкой записи committed runtime state в store.
- Prepared result executor-а остаётся единственным источником committed `scene`, `allNodeIds`, `nodeLocator`, `idGeneratorState` и `revisionState`.
- Текущие поля `changeSet` и `initialPhases` сохраняются как общая base-часть commit plan.
- Signal delivery order и repaint notification semantics не меняются.

### 6.4 Allowed Semantic Change Zones
- Внутренняя модель branch-specific commit payload-ов.
- Internal dispatch между `noEffects`, `effectsOnly` и `stateCommit`.
- Private helper signatures, если это нужно для передачи typed branch payload-ов без runtime cast.

### 6.8 Prohibited
- Повторное введение enum-discriminator поверх sealed-иерархии.
- Сохранение nullable branch payload fields в base `_ControllerCommitPlan`.
- Вынесение этой зоны в новый файл, service или helper-owner без необходимости для closure данного шага.
- Изменение наблюдаемой commit semantics ради упрощения типовой модели.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice closes a failure scenario, diagnostic output confirming the trigger point must be attached.
7. Scope expansion is forbidden until the mandatory slices are closed.

## 8. Vertical Slices

### Slice 1. [x] Sealed Commit Plan Model

#### Slice Contract
`scene_controller.dart` uses a sealed `_ControllerCommitPlan` hierarchy where each commit branch has its own representable payload type and impossible cross-branch states are not representable in the model.

#### Change
Заменить `_ControllerCommitBranchKind` и single `_ControllerCommitPlan` carrier с nullable branch payload fields на sealed base type с private final subtypes для `noEffects`, `effectsOnly` и `stateCommit`.

#### Verification
- `flutter analyze`
- `dcm analyze .`

#### Positive Scenarios
- `noEffects` branch создаётся без branch-specific payload fields.
- `effectsOnly` branch хранит только payload, нужный для signal/repaint effects.
- `stateCommit` branch хранит только committed state payload и revision data.

#### Negative Scenarios
- Нельзя представить `stateCommit` без required committed payload.
- Нельзя извлечь branch payload через nullable base field, потому что такого поля больше нет.

#### Closure Evidence
- Green run of the listed verifications.
- Код `scene_controller.dart` больше не содержит `_ControllerCommitBranchKind` и nullable branch payload fields в `_ControllerCommitPlan`.

### Slice 2. [x] Typed Commit Plan Execution

#### Slice Contract
Controller commit execution dispatches by sealed plan subtype and no longer depends on runtime `as`-casts to recover branch payload.

#### Change
Перевести `_buildControllerCommitPlan(...)` на возврат branch-specific plan types и заменить `_executeControllerCommitPlan(...)` на exhaustive type-based dispatch с typed handoff в `_executeEffectsOnlyCommitPlan(...)` и `_executeStateCommitPlan(...)`.

#### Verification
- `flutter analyze`
- `test/controller/core`
- `test/controller/core test/controller/commands` plus controller-root `*_test.dart` files

#### Positive Scenarios
- `effectsOnly` path выполняется без `branchKind` switch и без runtime cast к `int`.
- `stateCommit` path выполняется без runtime cast к `MutationCommitCandidate`, `Set<NodeId>` и revision payload-ам.
- Existing controller commit tests keep current observable semantics green.

#### Negative Scenarios
- Branch dispatch не зависит от отдельного enum discriminator.
- Private helper signatures не принимают nullable branch payload там, где subtype already guarantees presence.

#### Closure Evidence
- Green run of the listed verifications.
- Код `scene_controller.dart` не содержит runtime `as`-кастов для branch payload extraction в controller commit execution.

## 9. Final Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test shard `test/controller/core`
- MCP shard `test/controller/core test/controller/commands` plus controller-root `*_test.dart` files

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
