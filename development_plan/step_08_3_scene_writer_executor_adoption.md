language: russian

# Шаг 8.3. Перевести `SceneWriter` на executor и зачистить write-boundary drift

## Цель шага

После `8.1` и `8.2` executor и low-level helpers уже должны существовать, но
пока `SceneWriter` остаётся одновременно и public txn-surface, и местом, где
реально исполняется большая часть scene mutation logic.

Задача подшага: сохранить `SceneWriter` как тонкий `SceneWriteTxn` seam, но
перевести scene-mutating methods на `MutationExecutor`, убрать локальные
дубликаты runtime-policy и закрепить безопасные read-only views на txn-state.

## Что уже подтверждено по текущему состоянию

1. [scene_writer.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/scene_writer.dart)
   уже делегирует scene-mutating methods в
   [mutation_executor.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/mutation_executor.dart),
   но ещё не доведён до полностью тонкого boundary seam.
2. `selectedNodeIds` сейчас возвращается как `Set<NodeId>.unmodifiable(...)`,
   то есть materialization выполняется на каждом чтении getter-а.
3. `snapshot` каждый раз строится через `txnSceneToSnapshot(_ctx.workingScene)`,
   что допустимо как boundary snapshot semantics, но не должно смешиваться с
   executor apply path.
4. `writeSignalEnqueue(...)` уже делает defensive copy `nodeIds`, и эту границу
   безопасности нельзя случайно потерять при cleanup hot path.
5. `SceneWriter` пока сам создаёт `MutationExecutor`, поэтому dependency
   boundary между writer/executor ещё не выражена явно.

## Зафиксированные решения (без повторного обсуждения в реализации)

1. `SceneWriter` остаётся реализацией `SceneWriteTxn`; шаг `8` не создаёт
   второй public writer facade.
2. Scene-mutating methods `SceneWriter` делегируют в `MutationExecutor`.
3. Selection-only methods остаются writer-owned в шаге `8`:
   - `writeSelectionReplace(...)`
   - `writeSelectionToggle(...)`
   - `writeSelectionClear(...)`
   - `writeSelectionSelectAll(...)`
4. `selectedNodeIds` становится стабильным read-only view на txn selection и
   не materialize-ится заново на каждом getter call.
5. `writeSignalEnqueue(...)` сохраняет один defensive copy для входящего
   `nodeIds`, но не вводит дополнительных downstream копий "про запас".
6. Writer не повторяет policy, если у неё уже есть owner:
   - scene-level normalization остаётся commit-time responsibility;
   - node/document mutation semantics остаются у txn/model helpers;
   - scene-level input normalization не дублирует `ScenePolicy`.

## Граница шага

- In:
  - executor adoption в `SceneWriter`;
  - cleanup лишних materialization/copy points в writer boundary;
  - стабилизация read-only txn views;
  - удаление writer-local drift для scene-mutating methods.
- Out:
  - command-layer cleanup и re-shaping public command methods;
  - controller commit/store lifecycle;
  - selection-command complexity outside writer seam.

## Точная реализация, которую должен описывать код

1. `SceneWriter` конструируется с `TxnContext` и `MutationExecutor`, а не
   исполняет scene-mutating operations напрямую.
2. Для операций из `8.1` writer делает только boundary-роль:
   - принимает входы из `SceneWriteTxn`;
   - вызывает executor;
   - возвращает semantic result (`bool`, `int`, `NodeId`, `void`) без
     повторного runtime orchestration.
3. `selectedNodeIds` возвращает один reuse-able read-only view, связанный с
   текущим txn lifecycle.
4. `snapshot` остаётся boundary snapshot getter-ом и не становится owner-ом
   commit/change reasoning.
5. `writeSignalEnqueue(...)` по-прежнему безопасен для внешнего mutable input и
   не зависит от того, как executor организует mutation pipeline.

## Последовательность реализации (только действия)

[ ] Перевести scene-mutating methods `SceneWriter` на вызовы executor-а.
[ ] Вынести создание `MutationExecutor` из writer constructor, чтобы writer
    принимал готовую зависимость и оставался тонким seam.
[ ] Оставить selection-only methods в `SceneWriter` и явно не протаскивать их в
    `mutation_op.dart`.
[ ] Заменить per-read materialization `selectedNodeIds` на стабильный read-only
    txn view.
[ ] Перепроверить `writeSignalEnqueue(...)`, чтобы cleanup hot path не убрал
    boundary safety-copy.

## Критерии приёмки

[ ] `SceneWriter` больше не является главным owner-ом scene mutation pipeline и
    не создаёт executor как скрытую внутреннюю инфраструктуру.
[ ] Public `SceneWriteTxn` surface не меняется.
[ ] `selectedNodeIds` не создаёт новый immutable set на каждом чтении.
[ ] Writer не дублирует policy и apply semantics, у которых уже есть owner.

## Тестовый контур шага

[ ] `test/controller/internal/scene_writer_test.dart`
[ ] `test/controller/core/scene_controller_writer_lifecycle_test.dart`
[ ] `test/controller/core/scene_controller_commit_effects_test.dart`
[ ] `test/controller/commands/scene_commands_test.dart`
