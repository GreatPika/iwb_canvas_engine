language: russian

# Шаг 8.2. Подготовить `TxnContext` и `document.dart` к operation-oriented apply

## Цель шага

После `8.1` operation contract уже должен иметь одного owner-а, но executor
останется пустой оболочкой, если low-level apply semantics по-прежнему будут
разбросаны по ad hoc branches в writer коде и не будут опираться на
канонические txn/document helpers.

Задача подшага: довести `TxnContext` и `document.dart` до формы, в которой
executor может применять canonical operations без snapshot diff, без второго
derived state и без дублирования node/document mutation logic.

## Что уже подтверждено по текущему состоянию

1. [txn_context.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/txn_context.dart)
   уже является owner-ом mutable write-state:
   `workingScene`, `workingSelection`, `idGeneratorState`, `revisionState`,
   `allNodeIds`, `nodeLocator` и materialization counters.
2. [document.dart](/Users/blackpika/iwb_canvas_engine/lib/src/model/document.dart)
   уже владеет pure low-level scene/node helpers:
   `txnNodeFromSpec(...)`, `txnApplyNodePatch(...)`,
   `txnInsertNodeInScene(...)`, `txnEraseNodeFromScene(...)`,
   `txnSceneFromSnapshot(...)`, `txnBuildNodeLocator(...)`.
3. [scene_writer.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/scene_writer.dart)
   уже делегирует scene-mutating methods в
   [mutation_executor.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/mutation_executor.dart),
   поэтому drift шага теперь находится не в writer-local apply loops, а в
   не до конца выровненной границе owner-ов между `TxnContext`,
   `document.dart` и executor-ом.
4. [mutation_executor.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/mutation_executor.dart)
   уже содержит orchestration и часть low-level scene apply semantics, включая
   bulk delete, clear-scene и replace-scene paths.
5. `ChangeSet` уже собирается из runtime mutation facts и не требует полного
   сравнения "до/после", что важно сохранить как single source of truth.

## Зафиксированные решения (без повторного обсуждения в реализации)

1. `TxnContext` остаётся owner-ом mutable runtime state и commit-facing views.
   Executor не заводит отдельные коллекции node ids, locator или selection.
2. `document.dart` остаётся owner-ом pure mutation primitives над
   `Scene`/`nodeLocator`, которые не владеют `ChangeSet`, selection и allocator
   bookkeeping.
3. `mutation_executor.dart` остаётся owner-ом orchestration, preconditions и
   `ChangeSet` bookkeeping; шаг `8.2` не должен переносить эти обязанности в
   `document.dart`.
4. `TxnContext` остаётся owner-ом layer-index bookkeeping, `allNodeIds`,
   `nodeLocator` materialization, `txnEnsureContentLayer(...)` и
   `txnAdoptScene(...)`; шаг `8.2` не переносит этот runtime-owned state в
   model-layer.
5. Bulk delete становится канонической low-level семантикой для удаления
   нескольких узлов; single delete может делегировать в неё, но не наоборот.
6. `ChangeSet` продолжает фиксироваться прямо по фактам mutation apply, а не
   вычисляться из полного rebuild или snapshot diff.
7. `writeDocumentReplace(...)` и `txnAdoptScene(...)` сохраняют txn-owned
   allocator/runtime state contract из шагов `7.2` и `7.3`; replaceScene не
   должен переизобретать id/revision owner-ов.
8. Structural mutations не имеют права зависеть от "наличия удалённых node ids"
   как единственного признака изменения. Удаление пустых content layers,
   materialization background layer и любые другие scene-shape changes должны
   помечаться как реальные structural changes.
9. Structural write paths обязаны сохранять copy-on-write semantics: mutation
   не должна менять `_baseScene` до commit и не должна зависеть от случайных
   defensive-copy эффектов конструкторов как от неявного инварианта.
10. Семантика `clearSceneKeepBackground` фиксируется окончательно:
    - целевое runtime-состояние после apply:
      `backgroundLayer != null` и `scene.layers.isEmpty`;
    - `removedNodeIds` содержит только реально удалённые узлы из content
      layers и может быть пустым;
    - `didStructuralClear == true`, если был удалён хотя бы один content layer
      или был материализован отсутствующий `backgroundLayer`;
    - `didStructuralClear == false` только если сцена уже находилась в целевом
      состоянии до операции.
11. Канонические low-level helper-ы шага фиксируются окончательно:
    - `document.dart` получает bulk owner `txnEraseNodesFromScene(...)`;
    - single delete делегирует в bulk helper;
    - `document.dart` получает pure helper
      `txnClearSceneKeepBackground(...)`;
    - replace-scene path остаётся разделённым:
      `txnSceneFromSnapshot(...)` в `document.dart`,
      `txnAdoptScene(...)` в `TxnContext`.

## Граница шага

- In:
  - executor-ready apply helpers в `TxnContext`;
  - canonical delete/patch/replace-scene primitives;
  - `ChangeSet`-friendly low-level mutation semantics;
  - cleanup writer-owned ad hoc apply code там, где им должен владеть model/txn.
- Out:
  - финальный executor boundary и operation family;
  - public `SceneWriteTxn` surface;
  - controller commit/store lifecycle.

## Точная реализация, которую должен описывать код

1. `TxnContext` предоставляет executor-у все необходимые mutable/runtime
   helpers для apply без прямого обращения к store.
2. `TxnContext` остаётся owner-ом runtime-state helpers для:
   - ensure layer;
   - adopt scene;
   - locator/allNodeIds/materialization bookkeeping;
   - commit-facing views для executor/controller.
3. `document.dart` содержит канонические pure low-level primitives для:
   - insert node;
   - patch node;
   - bulk delete node(s) внутри уже выбранного runtime-owned scene;
   - clear scene shape на уровне `scene + locator`;
   - snapshot-to-scene conversion без store/runtime side effects.
4. `mutation_executor.dart` использует эти helpers, но остаётся owner-ом:
   - preconditions;
   - selection updates;
   - allocator/revision wiring;
   - `ChangeSet` bookkeeping.
5. Delete нескольких узлов больше не должен жить только как ad hoc loop внутри
   `SceneWriter`; bulk path должен иметь одного объяснимого owner-а на
   txn/model boundary.
6. `txnApplyNodePatch(...)` остаётся owner-ом node-specific no-op aware apply,
   включая recompute derived text layout и patch-type runtime semantics.
7. `TxnContext` commit-facing helpers
   (`txnAllNodeIdsForCommit(...)`, `txnNodeLocatorForCommit(...)` и связанные
   materialization paths) должны оставаться пригодными для executor commit
   preparation без повторного full rebuild, когда он не нужен.
8. В коде явно зафиксированы и покрыты тестами три regression-sensitive
   инварианта:
   - вставка content layer не ломает locator для последующего delete в той же
     транзакции;
   - structural clear коммитится даже если удалялись только пустые слои или
     материализовался только background layer;
   - structural delete/clear не мутирует pre-transaction base scene.
9. `txnClearSceneKeepBackground(...)` возвращает immutable result со строго
   следующей семантикой:
   - `removedNodeIds`: ids реально удалённых content nodes;
   - `didStructuralClear`: изменился ли scene shape по зафиксированному
     контракту шага;
   - helper не трогает `ChangeSet`, selection и allocator state.
10. `txnEraseNodesFromScene(...)` принимает уже выбранный runtime-owned `scene`
    и актуальный `nodeLocator`, удаляет только существующие deletable content
    nodes, поддерживает корректные locator indexes и возвращает immutable
    snapshot удалённых ids в deterministic order.

## Последовательность реализации (только действия)

[ ] Зафиксировать в коде owner-границы шага:
    `TxnContext` для runtime state, `document.dart` для pure helpers,
    `MutationExecutor` для orchestration и `ChangeSet`.
[ ] Ввести в `document.dart` канонические pure helper-ы
    `txnEraseNodesFromScene(...)` и `txnClearSceneKeepBackground(...)`.
[ ] Перевести single delete path на делегацию в bulk helper.
[ ] Проверить, что patch/insert/replace-scene helpers и runtime helpers
    полностью покрывают executor apply stage без snapshot diff.
[ ] Уточнить `TxnContext` helpers так, чтобы executor и controller могли
    готовить commit candidate без дублирования locator/id bookkeeping.
[ ] Реализовать зафиксированную семантику `clearSceneKeepBackground` для
    structural changes без удалённых node ids и выровнять tests вокруг неё.
[ ] Добавить regression tests на locator-shift-before-delete, structural clear
    без node removals и отсутствие мутаций `_baseScene`.
[ ] Обновить tests на low-level apply semantics и `ChangeSet` bookkeeping.

## Критерии приёмки

[ ] Executor использует один согласованный набор txn/document helpers и не
    дублирует mutation semantics вторым competing engine.
[ ] Bulk delete имеет одного owner-а и не выражен только как writer-local loop
    или несколькими несогласованными branches.
[ ] `ChangeSet` по-прежнему описывает mutation facts напрямую, без snapshot
    diff owner-а.
[ ] Replace/adopt path не ломает allocator/revision contracts из шага `7`.
[ ] Structural clear коммитится как реальное structural change даже без
    removed node ids.
[ ] Structural clear удаляет пустые content layers и эмитит
    `didStructuralClear == true`, если scene shape изменился.
[ ] Locator остаётся корректным после вставки слоя и последующего удаления в
    рамках одной транзакции.
[ ] Structural apply paths сохраняют copy-on-write contract и не мутируют
    pre-transaction scene.

## Тестовый контур шага

[ ] `test/controller/internal/change_set_txn_context_test.dart`
[ ] `test/controller/internal/scene_writer_test.dart`
[ ] `test/controller/internal/mutation_executor_test.dart`
[ ] `test/model/document_model_test.dart`
[ ] `test/controller/commands/scene_commands_test.dart`
[ ] `test/controller/internal/spatial_index_cache_test.dart`
[ ] `test/controller/scene_invariants_test.dart`
[ ] Новый targeted test на locator-shift-before-delete / structural-clear-no-nodes / base-scene-COW
