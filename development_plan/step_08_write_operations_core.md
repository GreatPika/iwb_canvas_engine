language: russian

# Шаг 8. Ввести ядро операций записи через подшаги 8.1-8.7

## Диагностические метрики

Этот блок нужен как диагностический радар после изменений шага, а не как
отдельный критерий готовности. Шаг должен упростить write hot path через
единый исполнитель операций, а не просто перераспределить длинные методы по
новым файлам.

- Смотреть в первую очередь `cyclomatic-complexity` и `source-lines-of-code`.
- Дополнительно смотреть `maximum-nesting-level` в commit/apply/postcheck
  маршрутах.
- Контрольные файлы:
  - `lib/src/controller/mutation_executor.dart`
  - `lib/src/controller/scene_controller.dart`
  - `lib/src/controller/scene_writer.dart`
  - `lib/src/controller/txn_context.dart`

## Почему шаг открыт повторно

Повторный прогон диагностических метрик после закрытия `8.4` показал, что
базовая архитектура write-core действительно выровнена, но часть hot path
осталась слишком крупной и ветвистой именно в тех owner-ах, которые шаг `8`
должен был довести до устойчивой формы.

Текущие watchpoints:

1. `SceneControllerCore._txnWriteCommit(...)`:
   - `cyclomatic-complexity = 19`
   - `source-lines-of-code = 144`
2. `MutationExecutor._apply(...)`:
   - `cyclomatic-complexity = 14`
3. `MutationExecutor._runPostcheck(...)`:
   - `cyclomatic-complexity = 15`
4. `MutationExecutor._deleteNodesBulk(...)`:
   - `cyclomatic-complexity = 12`
   - `source-lines-of-code = 42`
5. `TxnContext.txnEnsureContentLayer(...)`:
   - `cyclomatic-complexity = 12`
6. `TxnContext.txnResolveMutableNode(...)`:
   - `source-lines-of-code = 44`
7. `TxnContext._txnBaseNodeById(...)`:
   - `cyclomatic-complexity = 12`

Это означает, что шаг `8` нельзя считать полностью закрытым: часть сложности не
исчезла, а лишь сменила форму и owner-а. Поэтому umbrella-шаг расширяется ещё
на три подшага, которые закрывают именно controller/executor/txn hot path без
переноса этой работы в шаг `9`.

## Цель шага

После шагов `3.x-7.x` boundary, policy, id allocation и revision contract уже
достаточно выровнены, чтобы закрыть следующий системный drift: write-path всё
ещё размазан между несколькими owner-ами одновременно:

- `SceneWriter` смешивает public txn-surface, runtime preconditions, direct
  apply и `ChangeSet` bookkeeping;
- `SceneControllerCore._txnWriteCommit(...)` смешивает commit orchestration,
  normalize/postcheck, invariant precheck, spatial prepare и post-commit
  effects;
- `TxnContext` и `document.dart` уже содержат полезные stateful primitives, но
  у них нет одного явного executor-boundary, который собирает write operation
  в канонический pipeline.

Этот umbrella-шаг нужен, чтобы не пытаться одним документом одновременно
решить семь разных задач:

- зафиксировать контракт операций и границу `mutation_executor.dart`;
- подготовить `TxnContext` и `document.dart` к operation-oriented apply;
- перевести `SceneWriter` на executor без изменения public `SceneWriteTxn`;
- сузить `SceneControllerCore` до commit/store owner-а с ясной dispose
  семантикой.
- схлопнуть giant commit branch в controller до одного internal plan;
- довести executor routing до устойчивых operation families и убрать
  формальный postcheck;
- упростить `TxnContext` hot primitives так, чтобы они не держали лишнюю
  сложность и index-shift bookkeeping.

## Как разбит этап

### Шаг 8.1

`development_plan/step_08_1_mutation_op_contract_and_executor_boundary.md`

Владелец решения по:

- списку canonical write operations;
- роли `lib/src/controller/mutation_op.dart` как внутреннего контракта
  операций;
- роли `lib/src/controller/mutation_executor.dart` как единственного
  owner-а operation pipeline;
- явной границе между executor lifecycle и controller commit lifecycle.

### Шаг 8.2

`development_plan/step_08_2_txn_apply_semantics_and_document_helpers.md`

Владелец переноса low-level apply semantics для:

- `lib/src/controller/txn_context.dart`;
- `lib/src/model/document.dart`;
- delete/patch/replaceScene primitives, через которые executor должен мутировать
  runtime state;
- `ChangeSet`-friendly apply helpers без snapshot-diff owner-а.

### Шаг 8.3

`development_plan/step_08_3_scene_writer_executor_adoption.md`

Владелец migration `SceneWriter` для:

- перевода scene-mutating write methods на executor;
- зачистки локальных policy/selection/signal дубликатов в writer boundary;
- безопасного read-only представления txn selection;
- сохранения `SceneWriteTxn` как public seam без нового external API.

### Шаг 8.4

`development_plan/step_08_4_scene_controller_commit_pipeline.md`

Владелец commit/runtime lifecycle для:

- `lib/src/controller/scene_controller.dart`;
- финального postcheck-before-commit contract;
- wiring executor result в store/spatial/signals/repaint paths;
- fail-fast dispose semantics во время write.

### Шаг 8.5

`development_plan/step_08_5_controller_commit_plan_and_branch_collapse.md`

Владелец closure для:

- giant commit branch в `lib/src/controller/scene_controller.dart`;
- одного internal commit plan поверх prepared result и buffered side effects;
- схлопывания signal-only / repaint-only / state-commit веток без второго
  owner-а commit semantics.

### Шаг 8.6

`development_plan/step_08_6_executor_operation_family_cleanup.md`

Владелец closure для:

- `lib/src/controller/mutation_executor.dart`;
- operation-family routing вместо одного giant apply/postcheck switch-а;
- bulk delete hot path без смешения routing, erase и bookkeeping в одном теле.

### Шаг 8.7

`development_plan/step_08_7_txn_context_hot_path_primitives.md`

Владелец closure для:

- `lib/src/controller/txn_context.dart`;
- упрощения mutable layer/node resolution primitives;
- удаления лишнего layer-index bookkeeping и дублированного base-node resolve.

## Карта переноса деталей из исходного шага 8

1. Создание `lib/src/controller/mutation_op.dart`, точный список операций
   включая layer/document lifecycle cases и общий pipeline
   `preconditions -> apply -> postcheck -> changeSet -> commit preparation`
   переносится в `8.1`.
2. Подготовка `TxnContext` и `document.dart` к bulk delete / patch /
   replace-scene apply semantics переносится в `8.2`.
3. Перевод `scene_writer.dart` на общий исполнитель, cleanup selection/signal
   copies и безопасное представление `selectedNodeIds` переносится в `8.3`.
4. Перевод `SceneControllerCore.write(...)` на executor result, запрет
   `dispose()` во время write и cleanup commit hot path переносится в `8.4`.
5. Дополнительное сужение giant commit branch через один internal commit plan
   и явные branch kinds переносится в `8.5`.
6. Финальная зачистка executor hot path, включая bulk delete и postcheck
   contract, переносится в `8.6`.
7. Финальная зачистка `TxnContext` hot primitives и layer/node bookkeeping
   переносится в `8.7`.

## Уже принятые архитектурные решения

1. Public seam не меняется: `SceneWriteTxn` остаётся единственным публичным
   write-contract; `mutation_op.dart` и `mutation_executor.dart` остаются
   internal-only деталями controller layer.
2. `MutationExecutor` владеет только operation lifecycle:
   - `preconditions`
   - `apply`
   - `postcheck`
   - `changeSet finalization`
   - `commit preparation`
   Но он не владеет store apply, signal emission, notify scheduling или
   spatial cache ownership.
3. `TxnContext` остаётся единственным mutable source of truth для write-state.
   Нельзя вводить второй working scene / selection / locator state внутри
   executor-а.
4. `document.dart` и связанные model helpers остаются owner-ами low-level node
   mutation semantics над `Scene` и `nodeLocator`, а `TxnContext` остаётся
   owner-ом runtime-owned state и commit-facing views. Executor координирует
   операции, а не дублирует node-specific mutation logic.
5. Канонический operation set шага `8` обязан покрывать все scene-mutating
   writer methods:
   - `writeLayerEnsure(...)`
   - `writeNodeInsert(...)`
   - `writeNodePatch(...)`
   - `writeNodeTransformSet(...)`
   - `writeNodeErase(...)`
   - `writeDeleteSelection(...)`
   - `writeClearSceneKeepBackgroundResult(...)`
   - `writeDocumentReplace(...)`
   - `writeBackgroundColor(...)`
   - `writeGridEnable(...)`
   - `writeGridCellSize(...)`
   - `writeCameraOffset(...)`
   - `writeSelectionTranslate(...)`
   - `writeSelectionTransform(...)`
6. Selection-only операции
   (`writeSelectionReplace`, `writeSelectionToggle`, `writeSelectionClear`,
   `writeSelectionSelectAll`) в шаге `8` не переводятся в `mutation_op.dart`.
   Они остаются writer-owned и будут отдельно доводиться в шаге `9`, чтобы не
   раздувать write-core ложной универсальностью.
7. `SceneWriter.selectedNodeIds` после шага должен быть стабильным read-only
   view на txn selection, а не fresh materialization на каждом чтении.
8. `writeSignalEnqueue(...)` сохраняет ровно одну defensive copy там, где
   write-boundary принимает внешний iterable. Убирать safety-barrier полностью
   ради микропроизводительности нельзя.
9. `dispose()` во время активного `write(...)` запрещён и должен завершаться
   fail-fast ошибкой. Отложенный dispose lifecycle в шаг `8` не вводится.
10. `clearSceneKeepBackground` считается structural mutation всякий раз, когда
    меняется scene shape: удаляются content layers, материализуется background
    layer или выполняется любая иная structural clear-side effect, даже если
    removed node ids пуст.
11. Write-core обязан явно сохранять copy-on-write contract: structural apply
    helpers не должны мутировать pre-transaction scene.
12. Канонические helper owner-ы фиксируются окончательно:
    - `TxnContext`: runtime-owned state, layer bookkeeping, adopt/commit views;
    - `document.dart`: pure low-level apply helpers над `scene + locator`;
    - `MutationExecutor`: orchestration, preconditions, selection, `ChangeSet`;
    - `SceneControllerCore`: prepared-result commit, spatial/signals/repaint.
13. Дополнительная closure работа `8.5-8.7` не должна переносить commit или
    apply ownership в новый сервис, registry, visitor framework или отдельный
    derived change model. Если вводятся новые типы, они должны быть либо
    private value objects, либо narrow helpers рядом с текущим owner-ом.
14. `SceneControllerCore` закрывает giant commit branch через один internal
    commit plan, собранный из prepared result, buffered signals и repaint flag.
    Второй owner decision tree поверх тех же данных не допускается. Этот plan
    хранит только decision data и committed refs; он не владеет одноразовыми
    side effects вроде already-drained signals или prepared spatial commit.
15. `MutationExecutor` сохраняет data-only `MutationOp` contract. Поведение не
    переезжает в op-классы через visitor/virtual dispatch; closure строится
    через устойчивые operation families внутри owner-а executor-а для всего
    lifecycle `preconditions -> apply -> postcheck`.
16. Postcheck в executor допустим только там, где он реально проверяет
    op-local post-apply invariant или contract. Selection/grid normalization,
    store invariants и spatial preparation остаются вне executor. Формальный
    switch, который лишь повторно делает `txnEnsureActive()`, не считается
    корректным final design.
17. `TxnContext` не получает второй locator/index cache ради closure метрик.
    Если нужно убрать index-shift bookkeeping, это делается через более
    подходящую identity (`LayerId` вместо layer index) или reuse существующих
    helpers, а не через дублирование derived state.
18. Если `TxnContext` переходит на tracking cloned content layers по `LayerId`,
    это допустимо только при сохранении invariant-а уникальности content-layer
    ids внутри scene.

## Общие правила для всех подшагов

1. Один owner собирает operation pipeline. Нельзя оставлять часть preconditions
   в `SceneWriter`, часть apply в executor, а часть postcheck снова
   разбрасывать по controller hot path без явной границы владения.
2. Нельзя строить новый write-core через snapshot diff или второй derived
   change model. `ChangeSet` должен по-прежнему собираться из runtime mutation
   facts, а не из сравнения "до/после" полного документа.
3. Step `8.x` не должен расширять public API. Если в ходе рефакторинга
   меняется только internal architecture, `README.md`, `API_GUIDE.md`,
   `ARCHITECTURE.md` и `CHANGELOG.md` обновляются только при фактическом
   user-visible contract change.
4. Selection/grid normalization, invariant precheck и controller commit должны
   выполняться только после того, как operation apply уже закончен, но до того,
   как store получает committed state.
5. `dispose()` и error-path не имеют права оставлять half-committed store,
   partially emitted signals или partially applied spatial commit.
6. Если какой-либо подшаг меняет `tool/invariant_registry.dart`, этот подшаг
   обязан прогонять `dart run tool/check_invariant_coverage.dart`.

## Критерии готовности umbrella-шага

1. Для шагов `8.1`, `8.2`, `8.3`, `8.4`, `8.5`, `8.6`, `8.7` существуют
   отдельные step-файлы с
   собственной целью, границей ответственности, критериями приёмки и тестовым
   контуром.
2. В описании подшагов не осталось пересечений по владению:
   - `8.1` отвечает за контракт операций и executor boundary;
   - `8.2` отвечает за txn/document apply semantics;
   - `8.3` отвечает за adoption в `SceneWriter`;
   - `8.4` отвечает за controller commit lifecycle и dispose contract;
   - `8.5` отвечает за commit plan и branch collapse в controller;
   - `8.6` отвечает за executor operation-family hot path;
   - `8.7` отвечает за txn hot primitives и bookkeeping cleanup.
3. План явно фиксирует полный coverage scene-mutating writer methods,
   включая `writeLayerEnsure(...)`, `writeNodeTransformSet(...)` и
   `writeClearSceneKeepBackgroundResult(...)`.
4. План явно фиксирует, что selection-only write methods не входят в
   `mutation_op.dart` в рамках шага `8`, а signals/repaint/store apply
   остаются controller-owned lifecycle.
5. После завершения `8.x` write-path больше не зависит от неформального
   смешения responsibility между `SceneWriter`, `SceneControllerCore`,
   `TxnContext` и `document.dart`.
6. Диагностические watchpoints umbrella-шага для
   `scene_controller.dart`, `mutation_executor.dart` и `txn_context.dart`
   либо закрыты по `cyclomatic-complexity` / `source-lines-of-code`, либо сам
   прежний watchpoint-owner исчез как owner соответствующей зоны
   ответственности.

## Чеклист выполнения

[x] Переформулировать шаг `8` как umbrella-этап и вынести реализацию в `8.1`,
    `8.2`, `8.3`, `8.4`.
[x] В `8.1` зафиксировать final operation set и executor boundary без
    разрастания public surface.
[x] В `8.2` довести `TxnContext` и `document.dart` до executor-ready apply
    semantics без snapshot diff owner-а.
[x] В `8.3` перевести `SceneWriter` на executor и убрать лишние selection /
    signal materializations.
[x] В `8.4` переписать controller commit pipeline так, чтобы commit всегда
    выполнялся только после postcheck и fail-fast dispose semantics.
[x] Для `8.2` и `8.4` зафиксировать regression coverage на locator-shift перед
    delete, structural clear без removed nodes и сохранение base-scene COW.
[x] В `8.5` ввести один internal commit plan и убрать giant branch из
    `_txnWriteCommit(...)` без нового commit owner-а.
[ ] В `8.6` схлопнуть executor apply/postcheck до устойчивых operation
    families и убрать формальный postcheck dispatch.
[ ] В `8.7` убрать лишний layer-index bookkeeping и упростить node/layer hot
    primitives в `TxnContext` без второго runtime cache.
