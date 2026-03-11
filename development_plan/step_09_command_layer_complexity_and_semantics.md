language: russian

# Шаг 9. Довести command-layer до правильной сложности и семантики через подшаги 9.1-9.3

## Диагностические метрики

Этот блок нужен как диагностический радар после изменений шага, а не как
отдельный критерий готовности. Цель шага не в косметическом снижении метрик, а
в том, чтобы command-layer перестал тянуть лишние проходы, копии и no-op
mutation paths.

- Смотреть в первую очередь `cyclomatic-complexity` и `source-lines-of-code`.
- Дополнительно смотреть `maximum-nesting-level` на путях
  transform/delete/update.
- Контрольные файлы:
  - `lib/src/controller/commands/draw_commands.dart`
  - `lib/src/controller/commands/scene_commands.dart`
  - `lib/src/controller/scene_writer.dart`
  - `lib/src/model/document.dart`
- Полезный сигнал после шага: no-op и bulk paths выражены явно, а write
  commands перестают опираться на full snapshot rebuild и лишние копии.

Текущие watchpoints, подтверждённые аудитом:

1. [document.dart](/Users/blackpika/iwb_canvas_engine/lib/src/model/document.dart)
   держит основные step-owned hotspots:
   - `txnApplyNodePatch(...)`: `cyclomatic-complexity = 39`,
     `source-lines-of-code = 181`
   - `txnFindNodeByLocator(...)`: `cyclomatic-complexity = 12`
   - `txnEraseNodesFromScene(...)`: `cyclomatic-complexity = 10`,
     `source-lines-of-code = 36`
2. [scene_writer.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/scene_writer.dart)
   не пробивает критические пороги, но держит лишнюю hot-path работу в:
   - `writeSelectionSelectAll(...)`: `cyclomatic-complexity = 5`,
     `maximum-nesting-level = 3`, `source-lines-of-code = 20`
   - `writeSignalEnqueue(...)`: двойная copy/freeze цепочка
     `List.of(...) -> freezeList(...)`
3. [draw_commands.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/commands/draw_commands.dart)
   и
   [scene_commands.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/commands/scene_commands.dart)
   не выглядят проблемными по голым числам, но содержат owner-semantics drift:
   - bulk erase реализован как цикл single-delete;
   - scalar settings signalятся через `writer.snapshot` before/after, то есть
     через full snapshot materialization вместо точного mutation result.
4. Не все большие функции
   [document.dart](/Users/blackpika/iwb_canvas_engine/lib/src/model/document.dart)
   входят в область шага `9`. `txnNodeFromSnapshot(...)`,
   `txnNodeToSnapshot(...)` и `txnNodeFromSpec(...)` остаются вне этого этапа и
   не должны размывать критерии готовности command-layer closure.

## Цель шага

После шага `8.x` write-core и executor boundary уже выровнены, но следующий
drift всё ещё не закрыт: command-layer остаётся архитектурно "между слоями" и
из-за этого продолжает делать лишнюю работу сразу в трёх owner-зонах:

- `document.dart` всё ещё смешивает low-level patch/delete semantics с лишними
  проходами и неявной no-op логикой для stroke points;
- `SceneWriter` всё ещё держит selection/signal hot path без явного
  internal-result seam для command adapters;
- `DrawCommands` и `SceneCommands` всё ещё выводят changed semantics через
  snapshot diff или repeated single-write paths вместо точного writer result.

Этот umbrella-шаг нужен, чтобы не пытаться одним документом одновременно
решить три разные задачи:

- довести `document.dart` до канонических low-level delete/patch hot paths;
- зафиксировать `SceneWriter` как owner selection/signal boundary без лишних
  копий и неявных semantics;
- перевести internal command adapters на точные writer-owned results без
  расширения public `SceneWriteTxn`.

## Как разбит этап

### Шаг 9.1

`development_plan/step_09_1_document_delete_and_stroke_patch_hot_paths.md`

Владелец closure для:

- `lib/src/model/document.dart`;
- low-level delete semantics без full-scene rescan для уже подготовленных
  targeted removals;
- stroke points patch/no-op semantics и их связи с `pointsRevision`;
- устранения step-owned quadratic/delete drift в model hot path.

### Шаг 9.2

`development_plan/step_09_2_scene_writer_selection_and_signal_hot_path.md`

Владелец closure для:

- `lib/src/controller/scene_writer.dart`;
- selection-only methods как writer-owned boundary;
- одного internal-result seam для command adapters без изменения public
  `SceneWriteTxn`;
- signal buffering contract без лишней copy/freeze работы.

### Шаг 9.3

`development_plan/step_09_3_command_adapters_exact_signal_and_input_semantics.md`

Владелец closure для:

- `lib/src/controller/commands/draw_commands.dart`;
- `lib/src/controller/commands/scene_commands.dart`;
- command-specific signal semantics поверх точных writer results;
- canonical draw/settings command behavior без snapshot diff и single-delete
  loops.

## Карта переноса деталей из исходного шага 9

1. `document.dart`:
   - все пути удаления переводятся на канонический bulk/targeted owner-path;
   - убираются квадратичные маршруты удаления;
   - delete-path перестаёт навязывать full document scan для маленького target
     set;
   - patch stroke points сначала сравнивает длину и элементы, копирует/мутирует
     только на реальном изменении и не трогает `pointsRevision` на no-op.
   Всё это переносится в `9.1`.
2. `scene_writer.dart`:
   - оптимизация `writeDeleteSelection()`;
   - оптимизация `writeSelectionSelectAll()`;
   - оптимизация `writeSelectionTransform()`;
   - оптимизация `writeSignalEnqueue(...)`;
   - фиксация transform order;
   - фиксация семантики empty selection replacement.
   Всё это переносится в `9.2`.
3. `draw_commands.dart`:
   - `writeDrawStroke(...)` закрепляет одну каноническую политику точек;
   - intermediate raw list semantics больше не протекает наружу как
     полу-владелец ownership policy;
   - `writeEraseNodes(...)` переходит на bulk delete;
   - draw commands возвращают `NodeId`, а не `String`.
   Всё это переносится в `9.3`.
4. `scene_commands.dart`:
   - `writeBackgroundColorSet(...)`
   - `writeGridEnabledSet(...)`
   - `writeGridCellSizeSet(...)`
   - `writeCameraOffsetSet(...)`
   перестают строить full snapshot до/после, начинают опираться на exact
   writer result, сравнивают уже нормализованное значение и не шлют ложные
   сигналы. Всё это переносится в `9.3`.

## Уже принятые архитектурные решения

1. Public write seam не расширяется: `SceneWriteTxn` сохраняет текущий public
   contract и не получает новые методы только ради internal command adapters.
2. `MutationExecutor` остаётся owner-ом scene/node/settings/transform mutation
   lifecycle, уже закреплённым в шаге `8`. Шаг `9` не переносит эти мутации
   обратно в commands или в `SceneWriter`.
3. `document.dart` остаётся единственным owner-ом low-level patch/delete
   semantics над `Scene + nodeLocator`. Верхние слои могут готовить targeted
   remove plan, но не дублируют сам low-level erase.
4. `SceneWriter` остаётся owner-ом:
   - selection-only state changes;
   - buffered signal boundary;
   - internal command-facing result seam на самом `SceneWriter`.
5. `DrawCommands` и `SceneCommands` остаются thin internal adapters controller
   layer. Новый command service, registry, visitor framework или parallel
   signal owner не вводятся.
6. Multi-node delete получает один канонический bulk path. После шага `9`
   нельзя оставлять в command-layer цикл single-delete как substitute для bulk
   semantics.
7. Empty normalized selection replacement остаётся no-op. Очистка selection
   живёт только в явном `writeSelectionClear()`.
8. Transform composition order фиксируется окончательно как
   `delta.multiply(existingTransform)`. Обратный порядок не допускается ни в
   writer boundary, ни в command expectations.
9. Scalar settings commands работают с уже нормализованным effective value.
   Если requested input после нормализации коммитится в то же значение, это
   считается no-op и не должно приводить к ложному signal/revision drift.
10. Signal buffering сохраняет ровно один защитный immutable barrier на
    публичном boundary. Лишняя вторая копия для уже internal-owned payload
    после шага `9` не допускается.

## Общие правила для всех подшагов

1. Нельзя выводить `changed` semantics через `writer.snapshot` before/after или
   через полный snapshot diff на hot path. Источник истины должен быть exact
   writer/mutation result.
2. Нельзя добавлять sync glue между commands, writer и document. Если верхнему
   слою нужен факт изменения, он получает его от owner-а результата, а не
   пересчитывает ещё раз по другому представлению данных.
3. Full-scene scan допустим только там, где операция по смыслу действительно
   scene-wide (`select all`, `clear scene`). Для targeted delete/patch path
   такой scan не должен быть скрытым обязательным шагом.
4. Если для internal command adapters вводятся новые helper-ы или result-типы,
   они остаются narrow и internal-only рядом с текущим owner-ом. Новый
   кросс-слойный abstraction layer не вводится.
5. Шаг `9` не должен размывать зону ответственности шага `8`: selection-only
   методы не переезжают в `MutationOp` registry, а commands не начинают
   напрямую владеть scene mutation semantics.
6. Шаг `9` нельзя считать закрытым без повторного прогона диагностических
   метрик по step-owned owner-ам и фиксации результатов в umbrella-файле и
   соответствующем substep-файле.

## Критерии готовности umbrella-шага

1. Для шагов `9.1`, `9.2`, `9.3` существуют отдельные step-файлы с
   собственной целью, границей ответственности, критериями приёмки и тестовым
   контуром.
2. В описании подшагов не осталось пересечений по владению:
   - `9.1` отвечает за low-level delete/patch hot path в `document.dart`;
   - `9.2` отвечает за writer-owned selection/signal boundary;
   - `9.3` отвечает за internal command adapters и signal/input semantics.
3. Исходные требования шага `9`, включая `## Диагностические метрики`, не
   потеряны и разложены по owner-ам без дублирования.
4. После реализации command-layer больше не опирается на full snapshot rebuild
   для scalar setter semantics и не использует repeated single-delete loop как
   bulk owner path.
5. No-op stroke/delete/settings/selection paths после реализации не создают
   ложных сигналов, лишних копий и скрытых revision изменений.
6. Повторная диагностика
   `dcm calculate-metrics lib/src/controller/commands/draw_commands.dart lib/src/controller/commands/scene_commands.dart lib/src/controller/scene_writer.dart lib/src/model/document.dart --report-all`
   приложена к результату шага, а для step-owned watchpoints не остаётся
   необъяснённых превышений или незафиксированных переносов ownership.

## Чеклист выполнения

[x] Переформулировать шаг `9` как umbrella-этап и вынести реализацию в `9.1`,
    `9.2`, `9.3`.
[x] В `9.1` довести `document.dart` до targeted delete и точной stroke
    patch/no-op semantics без скрытых full-scene scan path.
[x] В `9.2` зафиксировать `SceneWriter` как owner selection/signal boundary с
    одним internal-result seam и без лишней copy/freeze работы.
[x] В `9.3` перевести `DrawCommands` и `SceneCommands` на exact writer results
    без snapshot diff и single-delete loops.
[x] Повторно прогнать aggregate diagnostics:
    `dcm calculate-metrics lib/src/controller/commands/draw_commands.dart lib/src/controller/commands/scene_commands.dart lib/src/controller/scene_writer.dart lib/src/model/document.dart --report-all`
    и зафиксировать итоговые watchpoints в step `9` и `9.1-9.3`.

## Результат шага

- `document.dart`, `SceneWriter`, `DrawCommands` и `SceneCommands` закрыты по
  owner-границам без нового orchestration слоя.
- Command-layer больше не использует snapshot diff для scalar settings и не
  держит bulk erase как цикл single-delete.
- `DrawCommands` и `SceneCommands` работают через `SceneWriter`-typed internal
  runner и опираются на exact writer results для signal/no-op decision.

## Итоговые watchpoints

- `draw_commands.dart`:
  - `writeEraseNodes(...)`: `cyclomatic-complexity = 2`,
    `maximum-nesting-level = 2`, `source-lines-of-code = 7`
  - `writeDrawStroke(...)`: `cyclomatic-complexity = 1`,
    `maximum-nesting-level = 1`, `number-of-parameters = 4` (`NEAR`),
    `source-lines-of-code = 19`
  - `writeDrawLine(...)`: `cyclomatic-complexity = 1`,
    `maximum-nesting-level = 1`, `number-of-parameters = 4` (`NEAR`),
    `source-lines-of-code = 16`
- `scene_commands.dart`:
  - `writeSelectionReplace(...)`: `cyclomatic-complexity = 2`,
    `maximum-nesting-level = 2`, `source-lines-of-code = 9`
  - `writeDeleteSelection(...)`: `cyclomatic-complexity = 2`,
    `maximum-nesting-level = 2`, `source-lines-of-code = 10`
  - `writeClearScene(...)`: `cyclomatic-complexity = 3`,
    `maximum-nesting-level = 2`, `source-lines-of-code = 11`
  - scalar setter commands остаются `BELOW` по всем диагностируемым порогам
- `scene_writer.dart` и `document.dart` остаются в рамках уже зафиксированных
  closure шагов `9.2` и `9.1`; новых drift по aggregate diagnostics не
  появилось.
