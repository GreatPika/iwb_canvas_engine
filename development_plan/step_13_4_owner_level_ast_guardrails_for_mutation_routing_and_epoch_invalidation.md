language: russian

# Change Contract

## 1. Change Mandate

Изменение фиксирует шаг `13.4`: статический guardrail отвечает только за
controller mutation routing и owner-state bypass, а proof для
`epoch invalidation` остаётся в runtime-тестах и invariant-backed
verification.

## 2. Change Boundary

### Included in the Change

- Переписывание controller mutation guardrails в
  `tool/src/guardrails/controller_api_guardrails.dart`, чтобы tool проверял
  canonical routing seams и owner-state bypass вместо name-based mutation
  prefixes и raw `controllerEpoch` token presence.
- Изменение runner surface только там, где это требуется для сохранения
  контракта `tool/check_guardrails.dart` после сужения controller guardrail.
- Обновление targeted tool tests для controller guardrails в
  `test/tool/guardrails/guardrails_controller_api_tool_test.dart`.
- Сохранение proof для `epoch invalidation` в тех runtime verification units,
  которые уже владеют replace-scene и cache-reset behavior.

### Not Included in the Change

- Import topology, package boundaries, public/export rules и mutable type leak
  scan вне controller routing guardrail.
- Новые invariant ids, restructuring invariant registry или proof-coverage
  policy.
- Full-project interprocedural или whole-package semantic analysis.
- Static AST proof для `epoch invalidation` внутри
  `tool/src/guardrails/controller_api_guardrails.dart`.

## 3. File Map and Analysis Areas

### Implementation Files

- `tool/src/guardrails/controller_api_guardrails.dart`
- `tool/src/guardrail_support/guardrail_context.dart`
- `tool/check_guardrails.dart`

### Test Files

- `test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `test/controller/core/scene_controller_commit_effects_test.dart`
- `test/view/scene_view_test.dart`
- `test/view/scene_view_interactive_test.dart`

### Fixture and Supporting Data Files

- `test/tool/support/guardrails_tool_test_support.dart`

### Analysis Area

- `lib/src/controller/**`
- `lib/src/interactive/scene_controller_interactive.dart`
- `tool/src/guardrails/**`
- `test/tool/guardrails/**`
- `test/controller/core/**`
- `test/view/**`

### Outside the Change Boundary

- Любые файлы вне перечисленных зон.
- Исключение допустимо только для точечного изменения, без которого нельзя
  закрыть конкретный slice и его verification.

### File Change Rule

- Каждый изменённый implementation file должен быть привязан к конкретному
  slice.
- Каждый новый или изменённый test должен быть привязан к конкретному
  verification.
- Каждый новый или изменённый fixture должен быть привязан к конкретному
  verification.
- Любые untied changes считаются выходом за scope этого change.

## 4. Locked Decisions

1. Шаг `13.4` владеет только controller mutation-routing и owner-state bypass
   guardrails под `tool/check_guardrails.dart`.
2. Static controller guardrails не владеют semantic proof для
   `epoch invalidation`.
3. `epoch invalidation` доказывается runtime-тестами и invariant-backed
   checks вокруг replace-scene и cache invalidation behavior.
4. Mutation safety доказывается через canonical routing seams и protected
   owner-state analysis, а не через mutating-looking symbol prefixes.
5. File-level allow-lists запрещены для controller mutation ownership.
6. Analysis остаётся bounded на `lib/src/controller/**` и
   `lib/src/interactive/scene_controller_interactive.dart`.
7. Whole-project interprocedural data-flow находится вне scope этого шага.

## 5. Result Requirements

1. Любой public controller или interactive entrypoint, который может мутировать
   committed scene или controller-owned state, падает guardrail-ом, если он не
   маршрутизирует mutation через canonical write seam и не принадлежит allowed
   semantic mutation zone.
2. Direct, alias-based, cascade-based и helper-hidden bypass к protected owner
   state падают controller guardrail-ом вне allowed mutation zones.
3. Public interactive methods, которые меняют только interactive-local state,
   остаются валидными и не падают сами по себе.
4. `tool/src/guardrails/controller_api_guardrails.dart` больше не использует
   raw symbol prefixes или наличие `controllerEpoch` token как proof
   correctness.
5. Replace-scene proof для `epoch invalidation` остаётся покрыт зелёными
   runtime-тестами и `dart run tool/check_invariant_coverage.dart`.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Controller guardrail scan обязан покрывать все Dart files под
  `lib/src/controller/**`.
- Scan обязан дополнительно покрывать
  `lib/src/interactive/scene_controller_interactive.dart`.
- Candidate entrypoints: public top-level functions и public class methods,
  включая getters, setters и operators, объявленные внутри scan scope.

### 6.2 Target Verification Units

- `test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `test/controller/core/scene_controller_commit_effects_test.dart`
- `test/view/scene_view_test.dart`
- `test/view/scene_view_interactive_test.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dcm calculate-metrics tool/src/guardrails/controller_api_guardrails.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart --report-all`

### 6.3 Protected States, Data, or Structures

- `SceneControllerCore._store` и mutable members, достижимые из `_store`.
- `TxnContext` как transaction-owned mutable surface.
- `TxnContext.changeSet`.
- `TxnContext.workingSelection`.
- `TxnContext.idGeneratorState`.
- `TxnContext.revisionState`.
- Mutable scene aliases, полученные из protected controller или transaction
  state.

### 6.4 Allowed Semantic Change Zones

- Public controller и interactive entrypoints, которые делегируют напрямую в
  canonical write seams.
- Transaction-owned mutation zones в `SceneWriter` и `MutationExecutor`.
- Committed-store apply и commit bookkeeping zones внутри
  `SceneControllerCore`.
- Interactive-local-only state updates внутри `SceneControllerInteractive`,
  которые не мутируют committed scene или controller-owned transaction state.

### 6.5 Recognition Forms That Must Be Supported Within This Change

- direct bypass;
- alias-based bypass;
- cascade-based bypass;
- local-function bypass;
- private helper bypass;
- function-expression invocation bypass.

### 6.6 Allowed Forms That Do Not Count as Violations

- Public interactive methods, которые меняют только interactive-local fields,
  gesture/session coordinators или notify scheduling state.
- Public entrypoints, которые делегируют напрямую в `_core.write(...)`,
  `_core.writeReplaceScene(...)`, `_core.commands.write*` или `_writeRunner(...)`.
- Read-only public entrypoints внутри scan scope.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- Controller guardrail analysis обязан использовать analyzer-resolved
  declarations и invocations; parse-only token presence и `toSource()` string
  matching запрещены как proof mechanisms.
- Declaration identity обязана различать class methods, top-level functions,
  local functions и function expressions.
- Resolution может следовать только по locally reachable helpers и
  function-expression calls, которые нужны для классификации текущего
  candidate entrypoint внутри bounded scan scope.
- Ownership proof обязан выводиться из declaration-level semantic zones и
  protected-state reachability, а не из file names или symbol prefixes.

### 6.8 Prohibited

- Возвращать static `epoch invalidation` rule внутрь
  `tool/src/guardrails/controller_api_guardrails.dart`.
- Использовать raw `controllerEpoch` token presence как proof valid epoch path.
- Использовать `write*` или `txn*` prefixes как единственный proof safe
  mutation routing.
- Возвращать file-level allow-lists для controller mutation ownership.
- Раздувать реализацию до whole-package или whole-project interprocedural
  analysis.

## 7. Execution Rules

1. Один slice закрывает один новый verifiable change contract.
2. У каждого slice должен быть свой verification.
3. Slice считается закрытым только в том изменении, где его verification уже
   существует и его run зелёный.
4. Подготовительные изменения сами по себе не считаются закрытым slice.
5. Следующий slice запрещён, пока предыдущий не закрыт.
6. Если slice закрывает failure scenario, к нему должен быть приложен
   diagnostic output с trigger point.
7. Если slice меняет analysis rule, должны быть покрыты negative и positive
   scenarios там, где это применимо к subject этого change.
8. Расширение scope запрещено, пока не закрыты обязательные slices.

## 8. Vertical Slices

### Slice 1. Replace Name-Based Controller Routing Heuristics

#### Slice Contract

Controller guardrail классифицирует controller-wide public entrypoints по
resolved routing и allowed semantic zones, а не по mutation-looking symbol
prefixes и raw `controllerEpoch` token checks.

#### Change

Переписать candidate-entrypoint scan и routing classification в
`tool/src/guardrails/controller_api_guardrails.dart`; расширить
`tool/src/guardrail_support/guardrail_context.dart` только если это требуется
для resolved analysis.

#### Verification

- `dart run tool/run_tool_tests.dart`

#### Fixtures Used

- `test/tool/support/guardrails_tool_test_support.dart`

#### Positive Scenarios

- controller-wide scan по-прежнему пропускает interactive-only setter.
- direct canonical routing через `_core.write(...)` или `_core.commands.write*`
  остаётся зелёным.

#### Negative Scenarios

- новый neutral public mutator под `lib/src/controller/**` падает tool-ом.
- unrelated write-prefixed sink в interactive entrypoint не считается
  canonical routing seam.

#### Closure Evidence

- зелёный run `dart run tool/run_tool_tests.dart`;
- diagnostic output с failure point для negative scenarios.

### Slice 2. Close Store, ChangeSet, and Selection Bypasses

#### Slice Contract

Direct и alias-hidden mutation для `_store`, `changeSet` и
`workingSelection` падают controller guardrail-ом вне allowed semantic
mutation zones.

#### Change

Добавить protected owner-state detection для `_store`,
`TxnContext.changeSet` и `TxnContext.workingSelection`, включая direct
mutation, alias-based mutation и cascade mutation.

#### Verification

- `dart run tool/run_tool_tests.dart`

#### Fixtures Used

- `test/tool/support/guardrails_tool_test_support.dart`

#### Positive Scenarios

- canonical mutation через `SceneWriter`, `MutationExecutor` и committed store
  apply zones остаётся зелёной.

#### Negative Scenarios

- direct `_store` mutation вне committed-store apply zone падает.
- alias-based `ctx.changeSet` mutation через `txnTrack*` падает.
- alias-based или cascade-based `ctx.workingSelection` mutation падает.

#### Closure Evidence

- зелёный run `dart run tool/run_tool_tests.dart`;
- diagnostic output с owner-state bypass failure point для negative scenarios.

### Slice 3. Close Allocator, TxnContext, and Helper-Hidden Bypasses

#### Slice Contract

Mutation или mutation-capable access к `TxnContext`, `idGeneratorState`,
`revisionState`, local helpers и function-expression calls падают вне allowed
semantic mutation zones.

#### Change

Расширить protected owner-state detection на `TxnContext`,
`TxnContext.idGeneratorState`, `TxnContext.revisionState`, local helper calls и
function-expression invocations, которые нужны для bounded helper resolution.

#### Verification

- `dart run tool/run_tool_tests.dart`

#### Fixtures Used

- `test/tool/support/guardrails_tool_test_support.dart`

#### Positive Scenarios

- allowed transaction-owned helpers остаются зелёными внутри `SceneWriter`,
  `MutationExecutor` и `SceneControllerCore` commit zones.

#### Negative Scenarios

- alias-based mutation `ctx.idGeneratorState` падает.
- alias-based mutation `ctx.revisionState` падает.
- mutation, спрятанная в local helper или `FunctionExpressionInvocation`,
  падает.

#### Closure Evidence

- зелёный run `dart run tool/run_tool_tests.dart`;
- diagnostic output с helper-hidden bypass failure point для negative
  scenarios.

### Slice 4. Move Epoch Proof to Runtime Verification

#### Slice Contract

Controller guardrail больше не владеет static `epoch invalidation` proof, а
replace-scene epoch behavior остаётся доказан runtime-тестами и invariant
coverage.

#### Change

Убрать static epoch-token proof из
`tool/src/guardrails/controller_api_guardrails.dart`, обновить
`tool/check_guardrails.dart` только там, где это требуется invariant
ownership, и оставить proof для `epoch invalidation` в runtime verification
units, которые уже владеют replace-scene и cache-reset behavior.

#### Verification

- `dart run tool/run_tool_tests.dart`
- `dart run tool/check_invariant_coverage.dart`
- `MCP test shard test/controller/core`
- `MCP test shard test/view`

#### Positive Scenarios

- replace-scene по-прежнему увеличивает epoch и очищает selection в
  controller-core runtime tests.
- `SceneViewCore` cache invalidation на epoch change остаётся зелёной.
- `SceneViewInteractive` cache invalidation на epoch change остаётся зелёной.
- controller guardrail больше не падает только из-за отсутствия raw
  `controllerEpoch` token в файле.

#### Closure Evidence

- зелёный run всех перечисленных verifications;
- invariant coverage output, показывающий, что
  `INV-ENG-EPOCH-INVALIDATION` остаётся покрытым после scope change.

### Slice 5. Final Controller-Guardrail Closure

#### Slice Contract

Суженный controller guardrail и runtime epoch proof одновременно зелёные под
targeted regression pack и step-owned metrics gate.

#### Change

Закрыть оставшиеся targeted controller-guardrail regressions и прогнать
step-owned metrics check для implementation и tool-test files.

#### Verification

- `dart run tool/run_tool_tests.dart`
- `dcm calculate-metrics tool/src/guardrails/controller_api_guardrails.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart --report-all`

#### Closure Evidence

- зелёный run всех перечисленных verifications;
- metrics output, показывающий, что step-owned files остаются в пределах
  active thresholds.

## 9. Final Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `MCP test shard test/core`
- `MCP test shard test/model test/serialization test/contract test/public_api test/entrypoints`
- `MCP test shard test/controller/internal`
- `MCP test shard test/controller/core test/controller/commands` plus
  controller-root `*_test.dart` files
- `MCP test shard test/render test/view`
- `MCP test shard test/interactive`
- `MCP test shard example/test` with MCP root `example/`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`
- `dart run tool/run_tool_tests.dart`
- `dcm calculate-metrics tool/src/guardrails/controller_api_guardrails.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart --report-all`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
