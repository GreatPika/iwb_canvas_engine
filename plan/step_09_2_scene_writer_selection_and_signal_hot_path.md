language: russian

# Шаг 9.2. Зафиксировать `SceneWriter` как owner selection/signal hot path

## Цель шага

После `9.1` low-level delete/patch primitives уже должны быть безопасными, но
command-layer всё ещё останется рыхлым, если `SceneWriter` продолжит смешивать
selection boundary, exact change semantics для internal commands и лишнюю
signal copy/freeze работу без явного owner-решения.

Задача подшага: довести `SceneWriter` до устойчивой формы, где он остаётся
единственным owner-ом selection-only transitions и buffered signal boundary,
но при этом даёт internal command adapters точные mutation results без
расширения public `SceneWriteTxn`.

## Что уже подтверждено по текущему состоянию

1. [scene_writer.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/scene_writer.dart)
   уже владеет selection-only методами и стабильным read-only view
   `selectedNodeIds`, но не даёт internal commands отдельного writer-local seam
   для exact result semantics.
2. `writeSelectionReplace(...)` уже реализует важную семантику: empty
   normalized selection считается no-op и не очищает текущее состояние.
3. `writeSelectionSelectAll(...)` сейчас:
   - сканирует все content layers;
   - материализует новый `HashSet`;
   - потом отдельно сравнивает его с текущим selection set.
4. `writeDeleteSelection(...)` сейчас отправляет `_ctx.workingSelection` в
   `DeleteNodesBulkOp(...)`, который сам создаёт новый immutable set-снимок.
5. `writeSignalEnqueue(...)` делает `List<NodeId>.of(nodeIds)`, а
   [BufferedSignal](/Users/blackpika/iwb_canvas_engine/lib/src/controller/internal/signal_event.dart)
   потом снова вызывает `freezeList(...)`, то есть internal command paths платят
   двойной copy/freeze cost.
6. Transform order уже покрыт tests как `delta.multiply(existingTransform)`,
   но в шаге `9` этот порядок ещё не закреплён как explicit writer contract.

## Зафиксированные решения (без повторного обсуждения в реализации)

1. `SceneWriter` остаётся owner-ом:
   - selection-only state transitions;
   - buffered signal boundary;
   - internal command-facing result seam на самом `SceneWriter`.
   Commands не мутируют selection напрямую и не минуют writer ради signal path.
2. Public `SceneWriteTxn` не расширяется новыми методами только ради удобства
   internal commands. Любой дополнительный result/helper surface остаётся
   internal-only методом/типом рядом с `SceneWriter`; новый internal interface
   только ради command adapters не вводится.
3. Selection-only methods не переезжают в `MutationOp` registry. Шаг `9` не
   отменяет разделение ответственности, принятое в шаге `8`.
4. Empty normalized selection replacement остаётся no-op. Очистка selection
   выражается только через `writeSelectionClear()`.
5. Transform composition order фиксируется как
   `delta.multiply(existingTransform)`. Другой порядок не допускается.
6. `writeSignalEnqueue(...)` сохраняет ровно один defensive freeze barrier на
   публичной boundary. Для internal command paths вводится writer-local helper,
   который принимает уже owned `List<NodeId>` и не делает промежуточный
   `List.of(...)` перед обязательным freeze на `BufferedSignal`.
7. `writeSelectionSelectAll(...)` остаётся scene-wide scan path по смыслу
   операции, но этот путь обязан:
   - строить ровно один target set;
   - делать ровно одно equality decision;
   - не создавать второе selection представление "на всякий случай".
8. `writeDeleteSelection(...)` использует канонический bulk delete path поверх
   текущего selection source of truth и не вводит отдельный ad hoc delete loop.

## Граница шага

- In:
  - selection-only methods `SceneWriter`;
  - writer-local internal result seam;
  - signal buffering copy/freeze contract;
  - фиксация empty replace и transform order semantics.
- Out:
  - low-level delete/patch algorithms в `document.dart`;
  - command-specific signal naming в adapters;
  - redesign public `SceneWriteTxn`.

## Точная реализация, которую должен описывать код

1. `SceneWriter` получает narrow internal-only result/helper surface на самом
   классе `SceneWriter` для internal command adapters. Этот surface даёт exact
   changed/effective values без materialization `snapshot`.
2. Public `SceneWriteTxn` сохраняет текущие методы и return types.
3. `writeSelectionReplace(...)` сохраняет текущую empty-normalized-input
   semantics и не превращается в скрытый alias для `writeSelectionClear()`.
4. `writeSelectionSelectAll(...)` делает один scene-wide pass по content nodes,
   собирает один target set и мутирует selection только при реальном отличии.
5. `writeDeleteSelection(...)` использует canonical bulk delete route из шага
   `9.1` и избегает лишней whole-selection materialization поверх уже
   существующего writer-owned selection state.
6. `writeSelectionTransform(...)` сохраняет pre-multiply semantics и не
   добавляет новый слой переписывания transform order на boundary уровне.
7. Public `writeSignalEnqueue(...)` по-прежнему принимает внешний iterable, но
   для internal command paths используется writer-local helper с owned
   `List<NodeId>`, чтобы не платить лишней промежуточной копией.

## Последовательность реализации (только действия)

[x] Добавить narrow internal-only writer result seam для command adapters.
[x] Оставить public `SceneWriteTxn` без новых internal-convenience методов.
[x] Довести `writeSelectionSelectAll(...)` до одного materialized target set и
    одного equality decision.
[x] Перевести `writeDeleteSelection(...)` на канонический bulk delete path из
    `9.1` без ad hoc delete semantics.
[x] Убрать лишнюю промежуточную copy/freeze работу из `writeSignalEnqueue(...)`
    при сохранении immutability boundary.
[x] Закрепить tests на empty selection replacement и transform order как на
    explicit writer contract.
[x] Повторно прогнать
    `dcm calculate-metrics lib/src/controller/scene_writer.dart --report-all`
    и зафиксировать итоговые watchpoints этого owner-а в результате шага.

## Критерии приёмки

[x] `SceneWriter` остаётся единственным owner-ом selection-only mutations и
    signal buffering boundary.
[x] Internal commands получают exact writer results без `snapshot` diff.
[x] `SceneWriteTxn` не расширяется ради internal command convenience.
[x] Empty normalized selection replacement остаётся no-op.
[x] `writeSelectionSelectAll(...)` не делает лишнюю материализацию current vs
    next selection сверх одного target set.
[x] `writeSignalEnqueue(...)` больше не платит лишней промежуточной копией
    поверх обязательного immutability barrier.
[x] Transform order закреплён tests и step contract как
    `delta.multiply(existingTransform)`.
[x] Повторная диагностика
    `dcm calculate-metrics lib/src/controller/scene_writer.dart --report-all`
    приложена к результату шага; для step-owned watchpoints
    `writeSelectionSelectAll(...)` и `writeSignalEnqueue(...)` не остаётся
    необъяснённой hot-path сложности или лишних копий.

## Тестовый контур шага

[x] `test/controller/internal/scene_writer_test.dart`
[x] `test/controller/core/scene_controller_commit_atomicity_test.dart`
[x] `test/controller/scene_controller_randomized_txn_test.dart`
[x] Точечные сценарии:
    - empty normalized selection replacement остаётся no-op
    - select-all не создаёт ложный selection drift
    - signal enqueue не делает двойную copy/freeze работу
[x] Повторная диагностика:
    `dcm calculate-metrics lib/src/controller/scene_writer.dart --report-all`

## Результат шага

- `SceneWriter` получил internal-only seam:
  `writeSelectionReplaceResult(...)`,
  `writeSelectionSelectAllResult(...)`,
  `writeOwnedSignalEnqueue(...)` и точные `...Changed(...)` helpers для
  scene-setting commands.
- Internal commands больше не используют `snapshot` diff для selection/grid/
  camera/background сигналов и не расширяют public `SceneWriteTxn`.
- `writeDeleteSelection(...)` теперь идёт через `DeleteNodesBulkOp.borrowed(...)`
  поверх writer-owned selection source of truth без лишней предварительной
  materialization.

## Метрики и watchpoints

- `dcm calculate-metrics lib/src/controller/scene_writer.dart --report-all`
  после шага:
  - `writeSelectionReplaceResult(...)`: cyclomatic complexity `3`, nesting `1`,
    source lines `17`
  - `writeSelectionSelectAllResult(...)`: cyclomatic complexity `5`, nesting
    `3`, source lines `20`
  - `writeSignalEnqueue(...)`: cyclomatic complexity `1`, nesting `0`,
    source lines `6`
  - `writeOwnedSignalEnqueue(...)`: cyclomatic complexity `1`, nesting `0`,
    source lines `4`
- Дополнительно проверены связанные adapters:
  - `scene_commands.dart`: без `HIGH`, selection/signal helpers остаются в
    пределах порогов
  - `draw_commands.dart`: после схлопывания line segment в record-параметр
    `writeDrawLine(...)` снижен до `number-of-parameters = 4` (`NEAR`, без
    `HIGH`)
