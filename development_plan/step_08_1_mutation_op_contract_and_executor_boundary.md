language: russian

# Шаг 8.1. Зафиксировать контракт операций и границу `mutation_executor`

## Цель шага

Сначала нужно принять одно решение по operation model, иначе весь шаг `8`
останется расплывчатым: сейчас write-path уже фактически имеет операции, но они
выражены как прямые imperative branches в `SceneWriter` и `_txnWriteCommit(...)`
вместо явного internal contract.

Задача подшага: ввести `lib/src/controller/mutation_op.dart` и
`lib/src/controller/mutation_executor.dart`, определить канонический набор
scene-mutating operations и зафиксировать, где заканчивается executor pipeline,
а где начинается controller commit lifecycle.

## Что уже подтверждено по текущему состоянию

1. [scene_writer.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/scene_writer.dart)
   сейчас сам выполняет preconditions, direct apply и `ChangeSet` bookkeeping
   в `writeNodeInsert(...)`, `writeNodePatch(...)`, `writeNodeErase(...)`,
   `writeNodeTransformSet(...)`,
   `writeSelectionTranslate(...)`, `writeSelectionTransform(...)`,
   `writeDeleteSelection(...)`, `writeDocumentReplace(...)`,
   `writeBackgroundColor(...)`, `writeGridEnable(...)`,
   `writeGridCellSize(...)`, `writeCameraOffset(...)`,
   `writeLayerEnsure(...)` и `writeClearSceneKeepBackgroundResult()`.
2. [scene_controller.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/scene_controller.dart)
   в `_txnWriteCommit(...)` уже собирает commit-time pipeline:
   selection/grid normalization, invariant precheck, spatial prepare, signal
   commit и store apply.
3. `ChangeSet` уже существует как runtime mutation ledger и не требует
   snapshot diff, но сейчас заполняется вручную из многих write-method branches.
4. Selection-only методы и signal enqueue уже имеют отдельную семантику и не
   обязаны становиться частью того же operation family.

## Рекомендуемое решение

Рекомендуемый вариант: сделать `mutation_op.dart` sealed internal contract для
канонических scene-mutating intent-ов, а `mutation_executor.dart` сделать одним
owner-ом operation pipeline, который возвращает подготовленный commit candidate,
но не коммитит store сам.

Почему это лучший вариант:

1. Он убирает главный drift: логика preconditions/apply/postcheck больше не
   размазывается по `SceneWriter` и `SceneControllerCore`.
2. Он не меняет public `SceneWriteTxn`, поэтому архитектурный шаг не тянет за
   собой лишний public API churn.
3. Он использует уже существующие `TxnContext` и `ChangeSet` как runtime
   source of truth вместо нового derived orchestration state.

Принятое решение по operation set:

1. `EnsureLayerOp`
2. `InsertNodeOp`
3. `PatchNodeOp`
4. `SetNodeTransformOp`
5. `DeleteNodeOp`
6. `DeleteNodesBulkOp`
7. `ClearSceneKeepBackgroundOp`
8. `ReplaceSceneOp`
9. `SetBackgroundColorOp`
10. `SetGridEnabledOp`
11. `SetGridCellSizeOp`
12. `SetCameraOffsetOp`
13. `TransformSelectionOp`
14. `TranslateSelectionOp`

Selection-only write methods и signal enqueue в этот список не входят.

Принятое решение по границе executor-а:

1. `MutationExecutor` принимает:
   - `TxnContext`
   - operation instance
   - зависимости runtime-layer, которые реально нужны для pre/post checks
2. `MutationExecutor` возвращает result, в котором уже зафиксированы:
   - факт `changed` / no-op;
   - обновлённый `ChangeSet`;
   - commit candidate data, необходимая controller commit-phase.
3. `MutationExecutor` не:
   - пишет в store;
   - не эмитит committed signals;
   - не трогает `notifyListeners`;
   - не владеет `SceneRenderState` lifecycle.

Почему именно так:

1. Если executor сам пишет в store, он начинает дублировать роль
   `SceneControllerCore` и размывает owner-а lifecycle-effects.
2. Если executor не возвращает commit candidate, controller вынужден повторно
   читать txn state и заново решать, что именно коммитить. Это снова создаёт
   двойной orchestration owner.
3. Отдельный operation set полезен только если он выражает устойчивые
   mutation intent-ы, а не каждую мелкую helper-функцию или selection-only
   toggle. Иначе `mutation_op.dart` быстро станет псевдо-командным слоем.

## Граница шага

- In:
  - `lib/src/controller/mutation_op.dart`;
  - `lib/src/controller/mutation_executor.dart`;
  - точный список canonical scene-mutating operations;
  - граница между executor result и controller commit lifecycle.
- Out:
  - конкретная low-level реализация patch/delete helpers в `document.dart`;
  - полный cleanup selection-only command semantics;
  - store apply и post-commit signal/notify lifecycle.

## Точная реализация, которую должен описывать код

1. `mutation_op.dart` вводит internal operation family только для
   scene-mutating intent-ов из списка выше.
2. Каждая operation несёт только свои входы и не хранит дублирующий runtime
   state из `TxnContext`.
3. `mutation_executor.dart` выполняет pipeline в одном owner-е:
   - `preconditions`
   - `apply`
   - `postcheck`
   - `changeSet finalization`
   - `commit preparation`
4. `postcheck` выполняется после `apply`, потому что часть runtime invariants
   зависит от уже изменённого txn-state.
5. Commit preparation формирует candidate поверх текущего `TxnContext`, но не
   пишет его в store.
6. Selection-only методы `SceneWriter` остаются вне `mutation_op.dart` и не
   требуют adapter-обёрток "ради единообразия".

## Последовательность реализации (только действия)

[ ] Создать `lib/src/controller/mutation_op.dart` с финальным internal
    operation set.
[ ] Создать `lib/src/controller/mutation_executor.dart` как owner operation
    pipeline и commit-candidate preparation.
[ ] Зафиксировать в шаге и тестах, что selection-only methods и
    `writeSignalEnqueue(...)` не входят в `mutation_op.dart`.
[ ] Зафиксировать в коде boundary: executor готовит commit candidate, а store
    apply остаётся в `SceneControllerCore`.

## Критерии приёмки

[ ] `mutation_op.dart` выражает ровно canonical scene-mutating operations, а не
    произвольные helper branches.
[ ] `mutation_executor.dart` становится одним owner-ом operation lifecycle.
[ ] Граница между executor и controller commit lifecycle описана явно и не
    требует повторного чтения txn-state "на глаз".
[ ] Selection-only write methods и signals не размывают operation contract.

## Тестовый контур шага

[ ] `test/controller/internal/change_set_txn_context_test.dart`
[ ] `test/controller/internal/scene_writer_test.dart`
[ ] `test/controller/core/scene_controller_commit_atomicity_test.dart`
[ ] Новый targeted test для `lib/src/controller/mutation_executor.dart`
