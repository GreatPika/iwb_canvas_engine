

1. [x] **Дефолтная вставка узла создаёт новый слой каждый раз (взрыв слоёв, “не туда добавилось”).**
   **Где:** `lib/src/model/document.dart` → `txnResolveInsertLayerIndex(...)`.
   **Как исправить:** при `layerIndex == null`:

   * если `scene.layers.isEmpty` → создать **1** `ContentLayer()` и вернуть индекс `0`;
   * иначе → вернуть индекс **последнего существующего** слоя (`scene.layers.length - 1`) без добавления нового слоя.
     **Тесты + инварианты:**
   * `scene_commands_test.dart`: `add_node_without_layerIndex_does_not_create_extra_layers`
     Проверки: после 100 `writeAddNode(..., layerIndex: null)` количество слоёв остаётся 1; все узлы лежат в одном `layerIndex`.
   * `draw_commands_test.dart`: `draw_stroke_without_layerIndex_does_not_create_extra_layers`
     Проверки аналогичные.
   * В конце тестов вызывать общий `assertSceneInvariants(...)` (см. п. 8).

2. [x] **Сигналы по выделению эмитятся даже когда состояние не изменилось (лишние события, ломают реактивную логику).**
   **Где:**

   * `lib/src/controller/commands/scene_commands.dart` → `writeSelectionReplace/Toggle/Clear`
   * `lib/src/controller/scene_write_txn.dart` и реализация writer (где реально меняется selection).
     **Как исправить:** сделать операции изменения выделения возвращающими `bool changed` на уровне транзакции/writer и в командах вызывать `writeSignalEnqueue(...)` **только если `changed == true`**.
     **Тесты + инварианты:**
   * `scene_commands_test.dart`: `selection_clear_on_empty_emits_no_signal`
     Проверки: на пустом выделении `writeSelectionClear()` не добавляет сигнал.
   * `scene_commands_test.dart`: `selection_replace_same_set_emits_no_signal`
     Проверки: повторная замена на тот же набор не эмитит сигнал.
   * После каждого действия: `assertSceneInvariants(...)`.

3. [x] **Данные `selection.*` сигналов могут не совпадать с итоговым выделением (коммит нормализует и вычищает id).**
   **Где:**

   * сигнализация: `lib/src/controller/commands/scene_commands.dart`
   * нормализация: `lib/src/controller/scene_controller_core.dart` (нормализатор selection на коммите) + writer-операции выделения.
     **Как исправить:** перенести нормализацию внутрь writer-операций выделения:
   * в `writeSelectionReplace/Toggle` **фильтровать входные id** (только существующие + видимые + контентные) перед записью;
   * в сигнал класть **уже нормализованный** список id;
   * на коммите убрать/упростить нормализацию selection (чтобы не было второго “скрытого” изменения).
     **Тесты + инварианты:**
   * `scene_commands_test.dart`: `selection_signal_ids_equal_committed_selection`
     Сценарий: передать `{существующий, отсутствующий}` → проверка, что:

     1. сигнал содержит только существующий id,
     2. `controller.selectedNodeIds` после коммита ровно равен списку из сигнала.
   * `scene_commands_test.dart`: `selection_replace_filters_invisible_or_background_nodes` (если есть такие сущности)
     Проверки: в итоговом выделении и сигнале их нет.
   * `assertSceneInvariants(...)` обязательно проверяет: `selection ⊆ видимые контентные узлы`.

4. [x] **Команды выделения принимают “мусорные” id без диагностируемого результата (тихие эффекты).**
   **Где:** `lib/src/controller/scene_write_txn.dart` / реализация writer: `writeSelectionReplace`, `writeSelectionToggle`.
   **Как исправить:** если после фильтрации (из п.3) набор кандидатов пуст:

   * операция возвращает `changed=false`;
   * сигнал не эмитится (за счёт п.2).
     **Тесты + инварианты:**
   * `scene_commands_test.dart`: `selection_replace_only_missing_ids_emits_no_signal_and_keeps_selection`
     Сценарий: `writeSelectionReplace({missing})` при пустом выделении → сигналов нет, выделение пустое.
   * `scene_commands_test.dart`: `selection_toggle_missing_id_emits_no_signal`
     Проверки аналогичные.
   * `assertSceneInvariants(...)`.

5. [ ] **Нестабильный порядок `nodeIds` в сигналах (при входе `Set` порядок может “плавать”, тесты и интерфейс становятся хрупкими).**
   **Где:**

   * `lib/src/controller/commands/scene_commands.dart` → сигналы `selection.*`
   * `lib/src/controller/commands/draw_commands.dart` → `writeEraseNodes` (формирует `removedIds`).
     **Как исправить:** перед `writeSignalEnqueue(...)` приводить список id к стабильному порядку:
   * `final ids = nodeIds.toList()..sort((a,b) => a.toString().compareTo(b.toString()));`
   * для `removedIds` — сортировать перед сигналом аналогично.
     **Тесты + инварианты:**
   * `scene_commands_test.dart`: `selection_signal_ids_are_sorted`
     Сценарий: передать `Set` из нескольких id → в сигнале порядок отсортирован.
   * `draw_commands_test.dart`: `erase_signal_removedIds_are_sorted`
     Сценарий: удалить набор в виде `Set` → сигнал содержит отсортированный список.
   * `assertSceneInvariants(...)`.

6. [ ] **`return null` в командах с “ничего не возвращают” ослабляет типовую строгость `_writeRunner` (тип выводится как `Null`).**
   **Где:** `lib/src/controller/commands/scene_commands.dart` → методы, которые сейчас делают `_writeRunner((writer) { ...; return null; });`.
   **Как исправить:** заменить на `_writeRunner<void>((writer) { ... });` и полностью убрать `return null;`.
   **Проверки (как “тест” для этого типа правки):**

   * включить/усилить статическую проверку: в `analysis_options.yaml` включить правило, запрещающее возврат `null` из `void`-контекста (например, `avoid_returning_null_for_void`), и добавить шаг `dart analyze` в запуск проверок.
   * (Опционально в тестах) простой “дымовой” тест компиляции пакета в CI, чтобы гарантировать отсутствие регрессий типов.

7. [ ] **`writeDrawStroke` допускает чрезмерное число точек (риск по памяти/времени).**
   **Где:** `lib/src/controller/commands/draw_commands.dart` → `writeDrawStroke(...)`.
   **Как исправить:** внутри `writeDrawStroke`:

   * если `points.length > kMaxStrokePointsPerNode` → **равномерно проредить** до лимита (с сохранением первой и последней точки), затем создавать `StrokeNodeSpec` по прореженному списку.
     **Тесты + инварианты:**
   * `draw_commands_test.dart`: `draw_stroke_resamples_when_exceeds_max_points`
     Проверки: длина сохранённых точек == `kMaxStrokePointsPerNode`, первая/последняя совпадают с исходными, все точки finite.
   * `assertSceneInvariants(...)` (проверка finite-геометрии).

8. [ ] **Недостаточно “контрактных” тестов и нет общего набора инвариантов сцены (регрессии будут просачиваться).**
   **Где:** `test/` (добавить утилиту) + существующие тесты команд.
   **Как исправить:**

   1. Создать `test/utils/scene_invariants.dart` с функцией `assertSceneInvariants(sceneSnapshot)` и вызывать её в конце каждого теста команд.
   2. Добавить негативные тесты на границы/ошибки в соответствующие файлы.
      **Тесты + инварианты (минимальный обязательный набор):**

   * **Инварианты (`assertSceneInvariants`)**:

     * уникальность всех `NodeId` в `scene.nodes`;
     * каждый `layer.nodeIds` ссылается на существующий `scene.nodes[id]`;
     * `selection` содержит только id существующих, видимых, контентных узлов;
     * все числовые поля геометрии finite (нет `NaN/Infinity`) для transform/offset/точек;
     * ни один `layerIndex` не выходит за диапазон `scene.layers`.
   * **Негативные тесты (закрепление контрактов ошибок):**

     * `scene_commands_test.dart`: `add_node_with_out_of_range_layerIndex_throws_RangeError`
     * `move_commands_test.dart`: `translate_selection_with_NaN_throws_ArgumentError`
     * `scene_commands_test.dart`: `grid_cell_size_non_positive_throws_ArgumentError`
     * `draw_commands_test.dart`: `draw_line_with_non_positive_thickness_throws_ArgumentError`
