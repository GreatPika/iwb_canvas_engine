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
   уже владеет low-level mutation helpers:
   `txnNodeFromSpec(...)`, `txnApplyNodePatch(...)`,
   `txnInsertNodeInScene(...)`, `txnEraseNodeFromScene(...)`,
   `txnSceneFromSnapshot(...)`, `txnBuildNodeLocator(...)`.
3. [scene_writer.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/scene_writer.dart)
   сейчас всё ещё держит ad hoc bulk semantics поверх этих helpers, например в
   `writeDeleteSelection(...)`.
4. `ChangeSet` уже собирается из runtime mutation facts и не требует полного
   сравнения "до/после", что важно сохранить как single source of truth.

## Зафиксированные решения (без повторного обсуждения в реализации)

1. `TxnContext` остаётся owner-ом mutable runtime state и commit-facing views.
   Executor не заводит отдельные коллекции node ids, locator или selection.
2. `document.dart` остаётся owner-ом node/document apply semantics.
   `mutation_executor.dart` не дублирует `txnApplyNodePatch(...)` и не вводит
   второй patch engine.
3. Bulk delete становится канонической low-level семантикой для удаления
   нескольких узлов; single delete может делегировать в неё, но не наоборот.
4. `ChangeSet` продолжает фиксироваться прямо по фактам mutation apply, а не
   вычисляться из полного rebuild или snapshot diff.
5. `writeDocumentReplace(...)` и `txnAdoptScene(...)` сохраняют txn-owned
   allocator/runtime state contract из шагов `7.2` и `7.3`; replaceScene не
   должен переизобретать id/revision owner-ов.

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
2. `document.dart` содержит канонические low-level primitives для:
   - ensure layer;
   - insert node;
   - patch node;
   - delete node(s);
   - clear scene while keeping background contract;
   - replace scene / adopt scene.
3. Delete нескольких узлов больше не должен жить только как ad hoc loop внутри
   `SceneWriter.writeDeleteSelection(...)`; bulk path должен иметь одного
   объяснимого owner-а на txn/model boundary.
4. `txnApplyNodePatch(...)` остаётся owner-ом node-specific no-op aware apply,
   включая recompute derived text layout и patch-type runtime semantics.
5. `TxnContext` commit-facing helpers
   (`txnAllNodeIdsForCommit(...)`, `txnNodeLocatorForCommit(...)` и связанные
   materialization paths) должны оставаться пригодными для executor commit
   preparation без повторного full rebuild, когда он не нужен.

## Последовательность реализации (только действия)

[ ] Вынести bulk delete semantics из writer-local ad hoc loops в canonical
    txn/model helper.
[ ] Проверить, что patch/insert/replace-scene helpers в `document.dart`
    полностью покрывают executor apply stage без snapshot diff.
[ ] Уточнить `TxnContext` helpers так, чтобы executor мог готовить commit
    candidate без дублирования locator/id bookkeeping.
[ ] Обновить tests на low-level apply semantics и `ChangeSet` bookkeeping.

## Критерии приёмки

[ ] Executor может применять canonical operations только через txn/document
    helpers без второго mutation engine.
[ ] Bulk delete имеет одного owner-а и не выражен только как writer-local loop.
[ ] `ChangeSet` по-прежнему описывает mutation facts напрямую, без snapshot
    diff owner-а.
[ ] Replace/adopt path не ломает allocator/revision contracts из шага `7`.

## Тестовый контур шага

[ ] `test/controller/internal/change_set_txn_context_test.dart`
[ ] `test/controller/internal/scene_writer_test.dart`
[ ] `test/model/document_model_test.dart`
[ ] `test/controller/scene_invariants_test.dart`
[ ] Новый targeted test на bulk delete / replace-scene apply helper
