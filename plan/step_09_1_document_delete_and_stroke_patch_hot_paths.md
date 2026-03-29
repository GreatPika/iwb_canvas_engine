language: russian

# Шаг 9.1. Довести low-level delete и stroke patch semantics в `document.dart`

## Цель шага

После шага `8.x` executor уже умеет проводить bulk delete и node patch через
правильные owner-ы, но low-level слой всё ещё остаётся хрупким, если
`document.dart` продолжает:

- повторно сканировать всю сцену там, где верхний слой уже знает targeted ids;
- держать отдельные и частично дублирующие single/bulk delete маршруты;
- прятать stroke points no-op semantics внутри giant patch function без явного
  owner-решения по `pointsRevision`.

Задача подшага: сделать `document.dart` точным owner-ом low-level delete и
stroke patch semantics, чтобы верхние слои больше не платили лишними
проходами, копиями и неявными no-op mutation paths.

## Что уже подтверждено по текущему состоянию

1. [document.dart](/Users/blackpika/iwb_canvas_engine/lib/src/model/document.dart)
   сейчас содержит step-owned watchpoints:
   - `txnApplyNodePatch(...)`: `cyclomatic-complexity = 39`,
     `source-lines-of-code = 181`
   - `txnFindNodeByLocator(...)`: `cyclomatic-complexity = 12`
   - `txnEraseNodesFromScene(...)`: `cyclomatic-complexity = 10`,
     `source-lines-of-code = 36`
2. `txnEraseNodesFromScene(...)` принимает только `Set<NodeId>` и сам
   повторно обходит все content layers, даже если caller уже отфильтровал
   deletable ids и знает их locator-based placement.
3. `txnEraseNodeFromScene(...)` и `txnEraseNodesFromScene(...)` оба владеют
   index-shift repair логикой, то есть single и bulk delete уже сегодня несут
   частично дублирующую low-level ответственность.
4. `txnApplyNodePatch(...)` dry-run и real apply держит в одном giant switch все
   node kinds сразу, а stroke points ветка по сути завязана на generic
   `_txnSetOffsets(...)`.
5. `pointsRevision` принадлежит
   [nodes.dart](/Users/blackpika/iwb_canvas_engine/lib/src/core/nodes.dart)
   через `_RevisionedOffsetList`, но текущий план шага `9` ещё не фиксирует
   явно, как low-level patch path обязан вести себя на no-op и real-change для
   stroke points.

## Зафиксированные решения (без повторного обсуждения в реализации)

1. `document.dart` остаётся единственным owner-ом low-level delete/patch
   semantics над `Scene + nodeLocator`. `SceneWriter` и `MutationExecutor`
   могут готовить remove plan, но не дублируют сам erase algorithm.
2. Для удаления остаются только два канонических маршрута:
   - targeted locator-driven erase для уже подготовленного набора removals;
   - whole-scene structural clear для `txnClearSceneKeepBackground(...)`.
   Другой full-scene delete path в low-level слое не допускается.
3. Single-node delete и bulk delete обязаны переиспользовать одни и те же
   targeted low-level primitives. Нельзя держать второй independent branch с
   отдельной логикой locator repair.
4. Подготовка deletable ids и low-level erase разводятся окончательно:
   - caller отвечает за то, какие ids действительно удаляются;
   - `document.dart` отвечает за точное удаление и repair locator state.
   После подготовки `document.dart` больше не должен повторно сканировать
   несвязанные слои только ради поиска тех же ids.
5. Stroke points patch получает явную owner-semantics:
   - сначала сравнивается длина;
   - потом сравниваются элементы;
   - real apply меняет points ровно один раз;
   - no-op не меняет список;
   - no-op не меняет `pointsRevision`;
   - no-op не создаёт новый список.
6. `pointsRevision` не синхронизируется отдельным ad hoc кодом в
   `document.dart`. Его owner по-прежнему `StrokeNode` /
   `_RevisionedOffsetList`, а low-level patch path лишь не должен вызывать
   мутацию на no-op.
7. `txnApplyNodePatch(...)` после шага сохраняет роль dispatcher-а, но
   step-owned stroke geometry semantics выносится в narrow helper вместо
   дальнейшего роста giant switch-а.
8. Канонический low-level primitive этого подшага называется
   `txnErasePreparedNodesFromScene(...)`. `txnEraseNodeFromScene(...)` и
   `txnEraseNodesFromScene(...)` после шага остаются только thin adapter-ами
   над этим primitive; write hot paths с уже подготовленным locator-based
   remove plan обязаны вызывать именно `txnErasePreparedNodesFromScene(...)`.

## Граница шага

- In:
  - targeted low-level erase primitives;
  - переиспользование этих primitives single/bulk delete path;
  - stroke points patch/no-op semantics;
  - устранение step-owned delete/patch drift в `document.dart`.
- Out:
  - selection/signal semantics `SceneWriter`;
  - command-specific signal names;
  - redesign snapshot conversion helpers вне delete/patch зоны.

## Точная реализация, которую должен описывать код

1. Low-level delete больше не начинается с `Set<NodeId>` как единственного
   входа, если caller уже знает locator placement удаляемых узлов. Канонический
   helper `txnErasePreparedNodesFromScene(...)` принимает prepared targeted
   removals, сгруппированные по layer owner.
2. `txnEraseNodeFromScene(...)` становится thin wrapper над
   `txnErasePreparedNodesFromScene(...)`, а не держит отдельный алгоритм
   удаления и locator repair.
3. `txnEraseNodesFromScene(...)` становится thin adapter-ом, который при
   необходимости готовит targeted removals и затем делегирует в
   `txnErasePreparedNodesFromScene(...)`; hidden hot-path owner остаётся только
   у prepared primitive.
4. Low-level erase не переопределяет deletability semantics. Если caller уже
   подготовил deletable ids/entries, erase не делает вторую owner-проверку
   несвязанных узлов.
5. Whole-scene clear semantics остаётся только у
   `txnClearSceneKeepBackground(...)`; targeted delete path не должен
   деградировать в scene-wide algorithm.
6. Stroke points ветка `txnApplyNodePatch(...)` выносится в отдельный narrow
   helper с явным сравнением:
   - `next.length != current.length` означает real change;
   - при равной длине сравниваются элементы по порядку;
   - points list мутируется только при real change.
7. No-op patch stroke points после шага не должен:
   - вызывать `clear()/addAll()` на `stroke.points`;
   - менять `pointsRevision`;
   - аллоцировать replacement list.

## Последовательность реализации (только действия)

[x] Ввести канонический targeted low-level erase helper поверх
    `Scene + nodeLocator`.
[x] Перевести single и bulk delete на один и тот же low-level erase path.
[x] Убрать из low-level bulk delete скрытый full-scene rescan для уже
    подготовленного targeted набора.
[x] Вынести stroke points patch semantics в отдельный narrow helper.
[x] Зафиксировать через tests, что no-op stroke patch не трогает
    `pointsRevision` и не делает лишнюю мутацию списка.
[x] Повторно прогнать
    `dcm calculate-metrics lib/src/model/document.dart --report-all`
    и зафиксировать итоговые watchpoints этого owner-а в результате шага.

## Критерии приёмки

[x] В `document.dart` не остаётся двух независимых low-level delete algorithms
    для single и bulk erase.
[x] Targeted delete path больше не навязывает full-scene scan, если верхний
    слой уже подготовил remove plan через locator.
[x] Step-owned quadratic/delete drift удалён: после подготовки deletable
    targets low-level erase не повторяет те же поиски по документу.
[x] Stroke points no-op patch не меняет список и не меняет `pointsRevision`.
[x] Реальное изменение stroke points по-прежнему приводит к корректному
    revision bump через owner `_RevisionedOffsetList`.
[x] Giant `txnApplyNodePatch(...)` перестаёт наращивать step-owned complexity
    именно за счёт stroke points semantics.
[x] Повторная диагностика
    `dcm calculate-metrics lib/src/model/document.dart --report-all`
    приложена к результату шага; для step-owned watchpoints
    `txnApplyNodePatch(...)`, `txnFindNodeByLocator(...)`,
    `txnErasePreparedNodesFromScene(...)` и `txnEraseNodesFromScene(...)` не
    остаётся необъяснённых превышений.

## Тестовый контур шага

[x] `test/model/document_model_test.dart`
[x] `test/controller/internal/mutation_executor_test.dart`
[x] `test/render/render_geometry_cache_test.dart`
[x] `test/render/scene_stroke_path_cache_test.dart`
[x] Новые targeted tests для locator-driven bulk delete и no-op stroke patch
[x] Повторная диагностика:
    `dcm calculate-metrics lib/src/model/document.dart --report-all`

## Result metrics

- `txnApplyNodePatch(...)`: `cyclomatic-complexity = 2`,
  `source-lines-of-code = 6`
- `txnFindNodeByLocator(...)`: `cyclomatic-complexity = 12`
- `txnErasePreparedNodesFromScene(...)`: `cyclomatic-complexity = 4`,
  `source-lines-of-code = 20`
- `txnEraseNodesFromScene(...)`: `cyclomatic-complexity = 6`,
  `source-lines-of-code = 24`

### Metric note

- `txnEraseNodesFromScene(...)` ушёл ниже step-owned watchpoint-а и теперь
  остаётся thin adapter-ом, который готовит locator-driven removals и
  делегирует в canonical primitive.
- `txnErasePreparedNodesFromScene(...)` теперь остаётся thin orchestrator-ом:
  per-layer validation, erase и locator reindex вынесены в узкие helper-ы, а
  публичный primitive сохранил ownership low-level delete semantics.
- `txnApplyNodePatch(...)` теперь сведен к dispatcher-у над common patch и
  typed helper-ами по node kind; giant switch больше не держит patch-apply
  semantics внутри одного hot path.
- `txnFindNodeByLocator(...)` не менялся по форме в рамках 9.1; его
  превышение осталось стабильным и не связано с delete/stroke drift, который
  закрывался этим подшагом.
