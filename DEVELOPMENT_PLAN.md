
---

# 0) Цель и инварианты

## Цель

Сделать движок **самосогласованным** по цепочке “данные → производные структуры” и **устойчивым** по производительности на больших сценах и на “плохих” данных.

## Инварианты после рефакторинга

1. **Инвариант попадания (hit)**
   Производная геометрия, используемая для грубого отбора кандидатов, определяется **одним источником истины**:
   `nodeHitTestCandidateBoundsWorld(node)`.

2. **Инвариант инвалидации индекса**
   `boundsRevision` означает: *изменились candidate bounds для hit (или структура сцены)*.
   Индекс перестраивается строго по этому инварианту.

3. **Инвариант устойчивости индекса**
   Стоимость добавления одного узла в индекс имеет верхнюю границу: один узел не способен запустить “бесконечный” обход ячеек и взрыв памяти.

4. **Инвариант транзакций**
   Транзакции не делают глубокого клонирования всей сцены при первом изменении. Копируется только то, что реально изменяется.

5. **Инвариант множеств идентификаторов**
   Внутри транзакции рабочие множества изменяемые; нет пересоздания множества на каждом шаге.

---

# [x] 1) Этап 1 — Закрыть класс ошибок “неверная инвалидация hit из-за `hitPadding` и похожих параметров”

## Решение (фиксируем окончательно)

**Не вводим `hitGeometryRevision`.**
Вместо этого делаем “контракт” простым и железобетонным:

* **Единственный** критерий того, что надо ставить `boundsChanged` при изменении узла:
  изменились ли `nodeHitTestCandidateBoundsWorld(node)` до/после изменения.

Это автоматически покрывает `hitPadding` (и любые будущие параметры, которые влияют на candidate bounds через эту функцию).

## Изменения в коде

### [x] 1.1. `lib/src/controller/scene_writer.dart`

Внести правки в местах, где сейчас сравнивается `boundsWorld`:

#### [x] A) `writeNodePatch(NodePatch patch)`

Сейчас:

* берётся `oldBounds = found.node.boundsWorld`
* после патча сравнивается `boundsWorld`

Сделать:

* до патча: `oldCandidate = nodeHitTestCandidateBoundsWorld(node)`
* применить `txnApplyNodePatch(node, patch)`
* после патча: `newCandidate = nodeHitTestCandidateBoundsWorld(node)`
* если `oldCandidate != newCandidate` → `changeSet.txnMarkBoundsChanged(node.id)`
* иначе → `changeSet.txnMarkVisualChanged()` (как сейчас)

#### [x] B) `writeNodeTransformSet({required NodeId nodeId, required Transform2D transform})`

Аналогично: сравнивать **candidate bounds**, не `boundsWorld`.

#### [x] C) `writeSelectionTransform(SelectionTransform transform)`

Внутри цикла по узлам:

* брать `oldCandidate` до изменения
* брать `newCandidate` после изменения
* если отличается → `txnMarkBoundsChanged(node.id)`
* иначе → `txnMarkVisualChanged()`

> `writeSelectionTranslate` уже делает `txnMarkBoundsChanged` безусловно — оставить как есть (это корректно).

### [x] 1.2. `lib/src/controller/change_set.dart`

Текстово зафиксировать смысл (комментарий у поля/метода):

* `boundsChanged` == “изменились hit candidate bounds или структура сцены”.

Это важно, чтобы команда дальше не использовала `boundsChanged` как “изменились boundsWorld для отрисовки”.

## Тесты

### [x] 1.3. Добавить тест: “spatial index invalidates on hitPadding change”

Файл: `test/controller/scene_controller_test.dart` (рядом с тестом про bounds revision)

Сценарий:

1. Создать `SceneControllerV2(initialSnapshot: twoRectSnapshot())`
2. Вызвать `querySpatialCandidates` один раз → `debugSpatialIndexBuildCount == 1`
3. В транзакции:

   * взять узел (например `r1`) и изменить **только `hitPadding`** через `writeNodePatch(...)`
4. Вызвать `querySpatialCandidates` второй раз по области, которая:

   * **не** пересекалась раньше с candidate bounds
   * **пересекается** после увеличения `hitPadding`
5. Ожидания:

   * кандидаты появились
   * `debugSpatialIndexBuildCount == 2`

- [x] **Критерий готовности этапа 1:** изменение `hitPadding` гарантированно приводит к перестройке индекса и корректному попаданию по расширенной зоне.

---

# [x] 2) Этап 2 — Сделать `SceneSpatialIndex` устойчивым к гигантским объектам

## Решение (фиксируем окончательно)

Вводим **двухконтурный индекс**:

* Контур 1: текущая сетка `_cells`
* Контур 2: список “крупных” кандидатов `_largeCandidates`

Порог фиксируем как константу:

* `const int kMaxCellsPerNode = 1024;`
  (это верхняя граница на “раскладку” одного узла по ячейкам; дальше узел уходит в крупные)

## Изменения в коде

### [x] 2.1. `lib/src/core/scene_spatial_index.dart`

#### [x] A) Добавить поле

```dart
final List<SceneSpatialCandidate> _largeCandidates = <SceneSpatialCandidate>[];
```

#### [x] B) Добавить константу

```dart
const int kMaxCellsPerNode = 1024;
```

#### [x] C) Правка `_build(Scene scene)`

После вычисления `startX/endX/startY/endY` для `candidateBounds`:

* посчитать:

  * `dx = (endX - startX + 1)`
  * `dy = (endY - startY + 1)`
  * `cells = dx * dy` (через безопасную проверку, чтобы не переполнить int: сравнивать через `dx > kMaxCellsPerNode` и т.п.)
* если `cells > kMaxCellsPerNode`:

  * добавить candidate в `_largeCandidates`
  * **не** добавлять его в `_cells`
* иначе — текущая логика раскладки по сетке

#### [x] D) Правка `query(Rect worldRect)`

После обхода `_cells`:

* пройти по `_largeCandidates`
* добавить в `unique`, если пересекается с `worldRect` (тем же `_rectsIntersectInclusive`)

### [x] 2.2. `lib/src/input/slices/spatial_index/spatial_index_slice.dart`

Убрать зависимость индекса от `scene.background.grid.cellSize`.

Сейчас:

```dart
SceneSpatialIndex.build(scene, cellSize: scene.background.grid.cellSize)
```

Сделать:

```dart
SceneSpatialIndex.build(scene) // фиксированный cellSize по умолчанию
```

Причина: параметры визуальной сетки не должны менять структуру hit-индекса. Это устраняет скрытую зависимость “вид → ввод”.

## Тесты

### [x] 2.3. Добавить тест: “huge bounds goes to largeCandidates and does not explode”

Добавить в `test/core/...` или `test/controller/...` (удобнее в controller).

Сценарий:

* Создать сцену с одним узлом `RectNode` огромного размера (например `Size(1e9, 1e9)`) и обычным `cellSize` (индексный).
* Вызвать `querySpatialCandidates(Rect.fromLTWH(0,0,10,10))`
* Ожидание: метод завершается быстро и возвращает кандидата (или корректно фильтрует, если политика такая).
* Для детерминированной проверки добавить в `SceneSpatialIndex` **только для тестов**:

  * `@visibleForTesting int get debugLargeCandidateCount => _largeCandidates.length;`
    (без проброса через `SpatialIndexSlice`/`SceneControllerV2`; проверяется unit-тестом индекса).

- [x] **Критерий готовности этапа 2:** один гигантский объект не способен вызвать “взрыв” времени/памяти при построении индекса.

---

# [x] 3) Этап 3 — Убрать квадратичную деградацию на множествах идентификаторов

## Решение (фиксируем окончательно)

Внутри транзакции все рабочие множества — **изменяемые**.

## Изменения в коде

### [x] 3.1. `lib/src/controller/txn_context.dart`

Заменить:

* `txnRememberNodeId`:

```dart
workingNodeIds = <NodeId>{...workingNodeIds, nodeId};
```

на

```dart
workingNodeIds.add(nodeId);
```

* `txnForgetNodeId`:
  пересборку множества заменить на:

```dart
workingNodeIds.remove(nodeId);
```

Проверить, что `workingNodeIds` создаётся как `Set.from(_store.allNodeIds)` (это уже делается в `SceneControllerV2._txnWriteBegin()`).

### [x] 3.2. `lib/src/controller/change_set.dart`

Сейчас ChangeSet тоже пересобирает наборы через `{...}`.

Переписать `txnTrackAdded / txnTrackRemoved / txnTrackUpdated` так, чтобы:

* использовать `add/remove` на существующих сетах,
* не создавать новые Set на каждом вызове.

- [x] **Критерий готовности этапа 3:** пакетные вставки/удаления перестают деградировать квадратично (проверяется тестом/микробенчем: 1000 операций add/remove в одной транзакции не вызывают лавинообразного роста времени).

---

# [x] 4) Этап 4 — Убрать глубокое клонирование сцены и внедрить копирование при записи

Это самый важный этап для “больших сцен”.

## Решение (фиксируем окончательно)

`TxnContext` перестаёт делать `txnCloneScene(_baseScene)`.

Вместо этого:

1. При первом изменении создаётся **поверхностная копия** `Scene`:

* копируются `camera/background/palette`,
* копируется список слоёв как список ссылок,
* **узлы не клонируются**.

2. Перед любой модификацией узла:

* клонируется **только нужный слой** (поверхностно: список узлов копируется как список ссылок),
* клонируется **только нужный узел** (глубоко, через `txnCloneNode`),
* затем патч/изменение применяется к клону.

## Изменения в коде

### [x] 4.1. `lib/src/model/document_clone.dart`

Добавить две функции:

#### [x] A) `txnCloneSceneShallow(Scene scene)`

Возвращает новый `Scene`, где:

* `layers: scene.layers` (важно: `Scene` сам делает `List.from`, то есть список слоёв будет новым)
* `camera/background/palette` — **новые объекты** (как сейчас в `txnCloneScene`, но без клонирования слоёв и узлов)

#### [x] B) `txnCloneLayerShallow(Layer layer)`

Возвращает новый `Layer`, где:

* `nodes: layer.nodes` (через конструктор `Layer` это станет новым списком ссылок)
* `isBackground` копируется

### [x] 4.2. `lib/src/controller/txn_context.dart`

#### [x] A) Заменить `txnEnsureMutableScene()`

Сделать:

* если `_mutableScene == null` → `_mutableScene = txnCloneSceneShallow(_baseScene)`

#### [x] B) Добавить внутренние поля

* `final Set<int> _clonedLayerIndexes = <int>{};`
* `final Set<NodeId> _clonedNodeIds = <NodeId>{};`

#### [x] C) Добавить методы

1. `Layer txnEnsureMutableLayer(int layerIndex)`

* вызвать `txnEnsureMutableScene()`
* если `layerIndex` не в `_clonedLayerIndexes`:

  * заменить `_mutableScene!.layers[layerIndex]` на `txnCloneLayerShallow(oldLayer)`
  * добавить `layerIndex` в `_clonedLayerIndexes`
* вернуть слой

2. `({SceneNode node, int layerIndex, int nodeIndex}) txnResolveMutableNode(NodeId id)`

* найти узел в `workingScene` через `txnFindNodeById`
* вызвать `txnEnsureMutableLayer(layerIndex)`
* если `id` не в `_clonedNodeIds`:

  * клонировать узел через `txnCloneNode(oldNode)`
  * заменить элемент в `layer.nodes[nodeIndex]`
  * добавить `id` в `_clonedNodeIds`
* вернуть (node, layerIndex, nodeIndex) уже из мутабельной сцены

3. Для операций удаления/вставки узлов:

* перед изменением `layer.nodes` обязательно вызвать `txnEnsureMutableLayer(layerIndex)`

### [x] 4.3. `lib/src/controller/scene_writer.dart`

Переписать методы так, чтобы **никогда не мутировать узлы из базовой сцены**.

Конкретно:

* В местах, где сейчас делается:

  * `found = txnFindNodeById(_ctx.workingScene, id)`
  * `scene = _ctx.txnEnsureMutableScene()`
  * `foundInMutable = txnFindNodeById(scene, id)`
  * `txnApply... (foundInMutable.node ...)`

Заменить на:

* `final found = _ctx.txnResolveMutableNode(id);`
* работать только с `found.node`

Обязательные правки:

1. `writeNodePatch`
2. `writeNodeTransformSet`
3. `writeNodeCreate`
   Перед `scene.layers[layerIndex].nodes.add(node)` вызвать `_ctx.txnEnsureMutableLayer(layerIndex)`
4. `writeNodeErase`
   Для каждого слоя, где есть удаляемые узлы:

   * `_ctx.txnEnsureMutableLayer(layerIndex)`
   * удалить из `layer.nodes` (после чего проставить changeSet)
5. `writeSelectionTranslate / writeSelectionTransform`
   Перед изменением каждого узла получать его через `txnResolveMutableNode`.

## Тесты и контроль корректности

### [x] 4.4. Добавить отладочную статистику клонирования (для тестов и регрессий)

Добавить в `TxnContext` счётчики:

* `int debugSceneShallowClones`
* `int debugLayerShallowClones`
* `int debugNodeClones`

Пробросить их в `SceneControllerV2` аналогично `debugLastChangeSet`.

### [x] 4.5. Тест: “camera move does not clone layers/nodes”

* сделать `writeCameraOffset(...)`
* ожидать: `debugLayerShallowClones == 0`, `debugNodeClones == 0`

### [x] 4.6. Тест: “node patch clones exactly one layer and one node”

* патчить один узел (например opacity)
* ожидать: `debugLayerShallowClones == 1`, `debugNodeClones == 1`

- [x] **Критерий готовности этапа 4:** при изменении одного узла не происходит глубокого клонирования всей сцены; при изменениях вида не клонируются слои/узлы.

---

# [x] 5) Итоговая карта изменений “что и где”

- [x] `lib/src/controller/scene_writer.dart`

* [x] Перевести `boundsChanged` на сравнение `nodeHitTestCandidateBoundsWorld`
* [x] Перейти на `_ctx.txnResolveMutableNode(...)` перед любыми мутациями узлов
* [x] Перед вставкой/удалением узлов — `_ctx.txnEnsureMutableLayer(...)`

- [x] `lib/src/controller/txn_context.dart`

* `workingNodeIds.add/remove` вместо пересоздания
* `txnEnsureMutableScene()` → поверхностное клонирование сцены
* Добавить копирование при записи для слоя и узла

- [x] `lib/src/controller/change_set.dart`

* Убрать пересоздание Set, перейти на `add/remove`

- [x] `lib/src/core/scene_spatial_index.dart`

* `_largeCandidates`
* порог `kMaxCellsPerNode = 1024`
* логика build/query с “крупными объектами”

- [x] `lib/src/input/slices/spatial_index/spatial_index_slice.dart`

* строить индекс без зависимости от `scene.background.grid.cellSize`

- [x] `lib/src/model/document_clone.dart`

* `txnCloneSceneShallow`
* `txnCloneLayerShallow`

- [x] Тесты:

* [x] hitPadding → инвалидация индекса
* [x] huge bounds → крупные кандидаты
* [x] view change → не клонируются узлы/слои
* [x] patch одного узла → клонируется 1 слой + 1 узел

---

# [ ] 6) Порядок внедрения (строго)

- [x] Этап 1 (hitPadding и candidate bounds → boundsChanged)
- [x] Этап 2 (устойчивость индекса + отвязка от grid cellSize)
- [x] Этап 3 (мутабельные множества в транзакции и ChangeSet)
- [x] Этап 4 (копирование при записи: scene/layer/node)
- [x] Этап 6 (убраны O(N) сканирования на локальном коммите)


### [x] Этап 6. Убрать O(N) сканирования на коммите (обязательно)

**Цель:** коммит локального изменения не должен проходить всю сцену.

**Действия:**

- [x] 6.1. Ввести в `DocumentState` (или аналог вашего “документа”) **инкрементально поддерживаемые поля**:

* `allNodeIds: Set<NodeId>` (или лучше `HashSet<NodeId>`)
* `nodeIdSeed: int` (монотонный seed для генерации id)

- [x] 6.2. В `TxnContext`:

* перестать создавать `workingNodeIds = Set.from(store.allNodeIds)` на старте каждой транзакции;
* хранить `baseAllNodeIds` ссылкой + `addedIds`/`removedIds` как дельты;
* материализовать итоговый `allNodeIds` **только** при структурных изменениях (insert/erase), а не всегда.

- [x] 6.3. В `SceneControllerV2` на коммите:

* **удалить** вызовы `txnCollectNodeIds(...)` и `txnInitialNodeIdSeed(...)`;
* брать `allNodeIds` и `nodeIdSeed` из результата транзакции.

- [x] **Критерий готовности:** коммит “поменяли opacity у одного узла” не делает полного прохода по всем слоям/узлам (проверяется профилировкой/счётчиками).

---

### [x] Этап 7. Ввести индекс NodeId → расположение (обязательно)

**Цель:** убрать `txnFindNodeById` как линейный поиск из горячих путей.

**Действия:**

- [x] 7.1. В `DocumentState` держать `nodeLocator: Map<NodeId, NodeLocatorEntry>` где `NodeLocatorEntry = (layerIndex, nodeIndex)`.

- [x] 7.2. В `txnInsertNodeInScene` / `txnEraseNodeFromScene`:

* обновлять `nodeLocator` инкрементально,
* при вставках/удалениях в середину слоя корректировать `nodeIndex` для “хвоста” слоя (или перейти на структуру слоя “map id→node” и отдельный порядок — это вы всё равно делаете ради copy-on-write).

- [x] 7.3. Переписать в `SceneWriter` все операции, где сейчас:

* сначала ищем в `_ctx.workingScene` (линейно),
* потом снова ищем в mutable сцене,
  на одну операцию “получили locator → получили узел”.

- [x] **Критерий готовности:** `writeNodePatch`, `writeNodeErase`, `writeNodeTransformSet` не содержат линейного поиска по всем узлам.

---

### [x] Этап 8. Сделать обновление SpatialIndex инкрементальным (обязательно)

**Цель:** локальные изменения не должны приводить к rebuild индекса по всей сцене.

**Действия:**

- [x] 8.1. Расширить `ChangeSet`:

* добавить `hitGeometryChangedIds: Set<NodeId>` (или более общий `spatialGeometryChangedIds`).

- [x] 8.2. В `SceneWriter`:

* при патчах/трансформациях/видимости/селектабельности, которые меняют **candidate bounds для попадания**, добавлять id в `hitGeometryChangedIds`.
  (Это напрямую связано с вашим этапом “hitGeometryRevision/hitBoundsWorld”: тут фиксируется “что именно изменилось для spatial”.)

- [x] 8.3. Перенести обслуживающие структуры в `SceneSpatialIndex` (core), а `SpatialIndexSlice` оставить оркестратором:

* в `SceneSpatialIndex` хранить:

  * `Map<NodeId, _SpatialEntry>` с текущим `candidateBounds`,
  * `Map<_CellKey, Set<NodeId>>` покрытие ячеек,
  * `Set<NodeId>` для крупных объектов.
* в `SpatialIndexSlice` хранить `_index` и счётчики debug build/apply.

- [x] 8.4. На `update(store, changeSet)`:

* **addedIds**: добавить кандидат (в grid либо в largeObjects)
* **removedIds**: удалить кандидата из всех его ячеек/largeObjects
* **hitGeometryChangedIds**: пересчитать покрытие ячеек (и при необходимости перевести узел grid↔largeObjects)

- [x] 8.5. Полный rebuild оставить только как аварийный путь:

* при смене cellSize/политики индекса,
* или если changeSet не может быть применён инкрементально (не должно происходить в штатном потоке после этапа 7).

- [x] **Критерий готовности:** локальные изменения hit-геометрии обновляют индекс инкрементально без O(N) rebuild (покрыто тестами со счётчиками build/apply и fallback-сценариями).

---

### [ ] Этап 9. Убрать пересоздание множеств в горячих местах (обязательно)

**Цель:** минимизировать аллокации и исключить квадратичность на сериях операций.

**Действия:**

- [ ] 9.1. В `TxnContext` сделать `workingSelection` мутабельным (`HashSet`), как вы уже планировали для `workingNodeIds`.

- [ ] 9.2. В `SceneWriter` заменить:

* пересборку `_ctx.workingSelection = <NodeId>{ for (...) ... }`
* и `writeSelectionToggle` с созданием новых Set
  на обычные `.add/.remove`.

- [ ] 9.3. Переписать `ChangeSet` так, чтобы `txnTrackAdded/Removed/Updated` мутировали внутренние `HashSet`, а не создавали новые множества.

- [ ] **Критерий готовности:** массовые операции (1000 add/remove/toggle) не дают лавинообразного роста выделений памяти.

---

### [ ] Этап 10. Ускорить рендер-кеши через ревизии геометрии (обязательно)

**Цель:** убрать O(points) вычисления в отрисовке.

**Действия:**

- [ ] 10.1. Добавить в `StrokeNodeSnapshot` поле `pointsRevision` (или более общее `renderGeometryRevision`), которое берётся из `StrokeNode.pointsRevision`.

- [ ] 10.2. В `SceneStrokePathCacheV2`:

* вместо `_pointsHash(points)` использовать `(node.id, node.pointsRevision)` как ключ свежести;
* хранить в entry именно revision.

- [ ] 10.3. Аналогично (по необходимости и симметрии) добавить “ревизии” для других тяжёлых геометрий:

* `PathNodeSnapshot`: `pathRevision` (монотонно увеличивать при изменении `svgPathData`/fillRule/strokeWidth и т.д.)
* (опционально, но для “проду” лучше сделать) `TextNodeSnapshot`: `textLayoutRevision` при изменении текста/стиля/maxWidth.

- [ ] **Критерий готовности:** при отрисовке stroke не происходит полного прохода по списку точек ради “проверить кеш”.

---

### [ ] Этап 11. Ввести жёсткие пределы на “плохие” данные и худшие случаи (обязательно)

**Цель:** движок не должен зависать на одном плохом объекте/жесте.

**Действия:**

- [ ] 11.1. Ограничение на stroke points:

* в интерактивном вводе перед коммитом в `_commitStroke` применять принудительное сжатие, чтобы итоговый список был **не больше `kMaxStrokePointsPerNode = 20_000`**:

  * если больше — дополнительно разрежать равномерно до лимита (детерминированно).

- [ ] 11.2. Ограничение на сложность `_hitTestPathStrokePrecise`:

* ввести `kMaxStrokeHitSamplesPerMetric = 2048`;
* если `metric.length / step` больше лимита — увеличить `step = metric.length / kMaxStrokeHitSamplesPerMetric`.

- [ ] 11.3. Ограничение на SpatialIndex.query по размеру запроса:

* в `SceneSpatialIndex.query(worldRect)` посчитать количество ячеек, которые покрывает запрос;
* если больше `kMaxQueryCells = 50_000` — переключиться на безопасный режим:

  * вернуть кандидатов из “allCandidates” (список всех не-background узлов, поддерживаемый индексом) + largeObjects, с последующей точной проверкой пересечения.
  * (да, это O(N), но это **контролируемо** и не взрывается по координатам).

- [ ] **Критерий готовности:** ни один одиночный объект/жест не может породить неограниченные двойные циклы по координатам/метрикам/ячейкам.

---

### [ ] Этап 12. Закрыть “ручные заплатки” TextNode.size (обязательно для заявленной цели)

**Цель:** изменения текста/стиля автоматически приводят к корректным bounds/hit/отрисовке, без требований к пользователю библиотеки “обнови size сам”.

**Действия:**

- [ ] 12.1. Ввести единый механизм измерения текста (внутри движка):

* на уровне `SceneWriter.writeNodePatch` при изменениях `text/fontSize/isBold/isItalic/isUnderline/fontFamily/lineHeight/maxWidth` пересчитывать `TextNode.size` автоматически через `TextPainter` (тот же механизм, что в рендере), с одинаковыми правилами.

- [ ] 12.2. Сделать `TextNode.size` **производным полем**:

* запретить менять его напрямую через публичный patch (убрать `size` из `TextNodePatch` или игнорировать его при наличии “авто-лейаута”);
* если вам нужен ручной режим — это отдельная история, но в рамках “без заплаток” size должен быть производным всегда.

- [ ] 12.3. Увязать это с `hitGeometryRevision/renderGeometryRevision`:

* изменение текста/стиля ⇒ меняются и hitBounds, и renderBounds (через ревизии).

- [ ] **Критерий готовности:** поменяли стиль текста — попадание/выбор/отрисовка корректны без внешнего обновления размеров.

---

### [ ] Минимальный “Definition of Done” для продакшена (я бы зафиксировал это как блокер-критерии)

- [ ] **Нагрузочные профили** (автотест/бенч), которые покрывают:

* 10k / 50k / 100k узлов, локальные патчи, перемещения, выбор,
* 1k–5k strokes с длинными списками точек,
* худшие случаи (огромные bounds, огромный rect-select, path со сверхдлиной).

- [ ] **Гарантии отсутствия O(N) на локальных операциях**:

* патч одного узла,
* transform одного узла,
* toggle selection,
* перемещение selection (в вашем UX-цикле).

- [ ] **Функциональные тесты инвариантов**:

* hitPadding/изменение геометрии попадания всегда обновляет индекс,
* большие объекты не взрывают индекс,
* view-изменения не трогают document,
* локальная модификация не клонирует всё.

- [ ] **Фуззинг последовательностей патчей** (property-based): случайные патчи + проверки инвариантов + отсутствие исключений/NaN.

Если эти ворота пройдены, тогда утверждение “готово к проду” будет обоснованным.

---
