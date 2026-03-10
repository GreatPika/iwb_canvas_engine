language: russian

# Шаг 8. Ввести ядро операций записи через подшаги 8.1-8.4

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
решить четыре разные задачи:

- зафиксировать контракт операций и границу `mutation_executor.dart`;
- подготовить `TxnContext` и `document.dart` к operation-oriented apply;
- перевести `SceneWriter` на executor без изменения public `SceneWriteTxn`;
- сузить `SceneControllerCore` до commit/store owner-а с ясной dispose
  семантикой.

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
   и scene mutation semantics. Executor координирует операции, а не дублирует
   node-specific mutation logic.
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

1. Для шагов `8.1`, `8.2`, `8.3`, `8.4` существуют отдельные step-файлы с
   собственной целью, границей ответственности, критериями приёмки и тестовым
   контуром.
2. В описании подшагов не осталось пересечений по владению:
   - `8.1` отвечает за контракт операций и executor boundary;
   - `8.2` отвечает за txn/document apply semantics;
   - `8.3` отвечает за adoption в `SceneWriter`;
   - `8.4` отвечает за controller commit lifecycle и dispose contract.
3. План явно фиксирует полный coverage scene-mutating writer methods,
   включая `writeLayerEnsure(...)`, `writeNodeTransformSet(...)` и
   `writeClearSceneKeepBackgroundResult(...)`.
4. План явно фиксирует, что selection-only write methods не входят в
   `mutation_op.dart` в рамках шага `8`, а signals/repaint/store apply
   остаются controller-owned lifecycle.
5. После завершения `8.x` write-path больше не зависит от неформального
   смешения responsibility между `SceneWriter`, `SceneControllerCore`,
   `TxnContext` и `document.dart`.

## Чеклист выполнения

[ ] Переформулировать шаг `8` как umbrella-этап и вынести реализацию в `8.1`,
    `8.2`, `8.3`, `8.4`.
[ ] В `8.1` зафиксировать final operation set и executor boundary без
    разрастания public surface.
[ ] В `8.2` довести `TxnContext` и `document.dart` до executor-ready apply
    semantics без snapshot diff owner-а.
[ ] В `8.3` перевести `SceneWriter` на executor и убрать лишние selection /
    signal materializations.
[ ] В `8.4` переписать controller commit pipeline так, чтобы commit всегда
    выполнялся только после postcheck и fail-fast dispose semantics.
