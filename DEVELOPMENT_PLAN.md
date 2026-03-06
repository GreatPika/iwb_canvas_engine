

---

# Шаг 1. Зафиксировать среду, конвейер и правила анализа

## `pubspec.yaml`

Сделать:

1. Зафиксировать или сузить `dev_dependencies`, прежде всего `analyzer`.
2. Проверить совместимость версий с AST-парсингом для новых guardrails.
3. Убедиться, что `example/` не живёт на отдельном дрейфующем наборе зависимостей.
4. Если для новых проверок нужны дополнительные пакеты для анализа исходников, добавить их сразу и зафиксировать.

## `analysis_options.yaml`

Сделать:

1. Усилить правила анализатора.
2. Включить более строгую проверку публичного API.
3. Включить анализ `example/**`.
4. Подготовить правила, которые помогают ловить:

   * опасные приведения типов,
   * использование внутренних импортов,
   * недокументированные публичные исключения.
5. Добавить правила, которые затрудняют утечки изменяемой модели через публичные сигнатуры.

## `.github/workflows/ci.yaml`

Сделать:

1. Убрать неблокирующие проверки производительности.
2. Сделать обязательным падение CI при:

   * деградации производительности,
   * пропаже ожидаемого perf-кейса,
   * неполном perf-отчёте.
3. Включить `example/` в проверку.
4. Включить `tool`-проверки и guardrails как обязательный этап.
5. Включить форматирование и тесты для `example/test/**`.
6. Добавить отдельный этап проверки публичного API и запрета использования `src/**`.

## `.github/workflows/perf_nightly.yaml`

Сделать:

1. Убрать неблокирующие обходы.
2. Сделать perf-сравнение блокирующим.
3. Проверять полноту набора кейсов.
4. Валить джобу при пропаже обязательной операции или сценария.

## `tool/bench/**`

Сделать:

1. Зафиксировать ожидаемый набор операций и кейсов.
2. Считать ошибкой отсутствие любого обязательного кейса.
3. Ввести реальные пороги деградации по времени и памяти.
4. Считать неполный отчёт невалидным.
5. Явно описать ожидаемый состав perf-набора, чтобы его можно было проверить автоматически.

## `example/**`

Сделать:

1. Подключить к анализу, форматированию, тестам и сборке.
2. Проверить, что пример использует только публичный API, а не `src/**`.
3. Ввести smoke-тест или минимальную сборку примера в CI.

---

# Шаг 2. Ввести валидированные типы и фабрики на публичной границе

## Создать каталог `lib/src/contract/validated/**`

Создать файлы:

1. `node_id_value.dart`
2. `layer_id_value.dart`
3. `instance_revision_value.dart`
4. `finite_offset_value.dart`
5. `positive_finite_double_value.dart`
6. `non_negative_finite_double_value.dart`
7. `opacity_value.dart`
8. `svg_path_data_value.dart`
9. `text_content_value.dart`
10. `font_family_value.dart`

В этих файлах реализовать:

* фабрики `parse(...)`, `of(...)`, `fromJson(...)`, `validated(...)`;
* проверки:

  * пустоты,
  * длины,
  * конечности,
  * знака,
  * safe-int,
  * диапазона `[0..1]`,
  * длины `svgPathData`,
  * длины текста,
  * длины `fontFamily`.

## `lib/src/contract/ids.dart`

Сделать:

1. Убрать модель, где `NodeId` и `LayerId` фактически являются “голой строкой” как единственным уровнем защиты.
2. Оставить совместимость наружу там, где это нужно, но создание новых id перевести на фабрики.
3. Подготовить переходный слой, чтобы существующий код мигрировал поэтапно.
4. Явно отделить:

   * разбор входного id,
   * генерацию нового id,
   * проверку legacy-формата.

## `lib/src/contract/scene_data_exception.dart`

Сделать:

1. Ввести усечение `source`.
2. Не хранить огромный JSON или огромную `svgPathData` целиком.
3. Нормализовать:

   * `code`,
   * `path`,
   * безопасное содержимое `source`.
4. Подготовить поле `path` к обязательному использованию в ошибках кодирования и декодирования, включая ошибки `TextAlign`.

---

# Шаг 3. Закрыть сырые публичные конструкторы

## `lib/src/contract/snapshot.dart`

Сделать:

1. Убрать возможность свободно собрать критичные snapshot-структуры из сырых примитивов.
2. Для полей:

   * id,
   * revision,
   * opacity,
   * size,
   * strokeWidth,
   * text,
   * fontFamily,
   * path data
     перевести создание через валидированные значения или валидирующие конструкторы.
3. Формально закрепить политику для `TextNodeSnapshot.size`.
4. Формально закрепить политику `backgroundLayer`.
5. Явно определить, допустим ли `backgroundLayer == null` в публичном snapshot и как это канонизируется.

## `lib/src/contract/node_spec.dart`

Сделать:

1. Конструкторы либо валидируют сразу, либо реальное создание уходит в `validated(...)`.
2. Закрыть обходы для:

   * длины текста,
   * длины `fontFamily`,
   * длины id,
   * path data,
   * диапазонов,
   * safe-int.
3. Для геометрии и transform использовать валидированный слой, а не голые примитивы.

## `lib/src/contract/node_patch.dart`

Сделать:

1. Ту же схему, что и для `NodeSpec`.
2. Патч не должен пронести невалидное значение мимо общей политики.
3. Для списков точек и ревизий предусмотреть политику no-op без лишнего копирования.

## `lib/src/contract/scene_write_txn.dart`

Сделать:

1. Формально закрепить семантику `writeSelectionReplace([])`:

   * либо clear,
   * либо no-op.
2. Сохранить неизменяемость `ClearSceneResult.removedNodeIds`.
3. Описать исключения у публичных методов.
4. Убедиться, что наружу не утекают изменяемые внутренние структуры.

---

# Шаг 4. Сразу выровнять точный публичный API-контракт

## `lib/iwb_canvas_engine.dart`

Сделать:

1. Проверить, что экспортируются только публичные типы.
2. Не экспортировать внутренние модельные типы.
3. При необходимости экспортировать validated-типы или фабрики, если они являются частью контракта.

## `lib/src/serialization/scene_codec.dart`

Сделать:

1. Зафиксировать точные `throws`-контракты.
2. Привести описание API к реальному поведению.
3. Для ошибок неподдерживаемого `TextAlign` обеспечить не только корректный код ошибки, но и **заполненный `path`**.
4. Если `_textAlignToString(...)` остаётся отдельной функцией, она должна получать контекст пути или работать только после каноникализации, где путь уже известен.

## `lib/src/model/scene_builder_api.dart`

Сделать:

1. Зафиксировать точные `throws`-контракты.
2. Описать семантику `buildFromJson/buildFromSnapshot`.

## `lib/src/contract/**` и `lib/src/serialization/**`

Сделать:

1. По `TextAlign` выбрать одну финальную стратегию:

   * либо сузить публичный контракт до реально поддерживаемых значений,
   * либо полноценно поддержать весь набор значений в сериализации и модели.
2. Эта политика должна совпадать в:

   * snapshot,
   * spec,
   * patch,
   * encode/decode,
   * builder/runtime.
3. Ошибка на unsupported align должна иметь:

   * детерминированный `code`,
   * заполненный `path`,
   * единое поведение для всех публичных входов.

## `lib/src/controller/commands/draw_commands.dart`

Сделать:

1. Возвращать `NodeId`, а не `String`.

## `lib/src/controller/scene_writer.dart`

Сделать:

1. Формально закрепить порядок композиции transform в `writeSelectionTransform`.
2. Этот порядок должен быть документирован и протестирован.

## `tool/check_guardrails.dart`

Сделать:

1. Защитить правило “один публичный импортный вход”, чтобы использование `src/**` не превращалось в нормальный контракт интеграции.

---

# Шаг 5. Ввести единый `ScenePolicy`

## Создать `lib/src/model/scene_policy.dart`

В нём реализовать:

1. `validateImportSnapshot(...)`
2. `validateRuntimeSnapshot(...)`
3. `validateEncodeSnapshot(...)`
4. `validateNodeSpec(...)`
5. `validateNodePatch(...)`
6. `validateSceneCore(...)`
7. `validateSceneCounts(...)`
8. `validateSceneRanges(...)`
9. `validateSceneIds(...)`
10. `validateTextPolicy(...)`
11. `validateSvgPathPolicy(...)`
12. `validateBackgroundLayerPolicy(...)`

## `lib/src/core/scene_limits.dart`

Сделать:

1. Оставить только константы.
2. Выровнять использование лимитов через `ScenePolicy`.
3. Добавить недостающий лимит размера JSON-входа.

## `lib/src/model/scene_builder.dart`

Сделать:

1. Убрать размазанную валидацию.
2. Перевести:

   * структурную проверку,
   * диапазоны,
   * лимиты,
   * policy background layer
     в `ScenePolicy`.
3. Убрать дублирование владения правилами.

## `lib/src/model/scene_builder_json_require.part.dart`

Сделать:

1. Safe-int проверять:

   * и для `int`,
   * и для `num`.
2. Делегировать в validated-слой и `ScenePolicy`.
3. Закрыть:

   * пустые id,
   * длинные id,
   * длинные строки,
   * длинные path data.

## `lib/src/model/scene_value_validation.dart`

## `lib/src/model/scene_value_validation_primitives.part.dart`

## `lib/src/model/scene_value_validation_node.part.dart`

## `lib/src/model/scene_value_validation_top_level.part.dart`

Сделать:

1. Превратить эти модули во внутренние примитивы `ScenePolicy`, а не во второй независимый источник правил.
2. Добавить:

   * лимиты `kMax*`,
   * политику пустых/длинных id,
   * политику `svgPathData`,
   * политику `TextNodeSnapshot.size`,
   * политику `backgroundLayer`.
3. Убрать **двойной проход** проверки уникальности `NodeId/LayerId`:

   * оставить один владелец проверки уникальности,
   * второй слой либо удалить,
   * либо свести к вызову первого.
4. Добиться одинакового кода и типа ошибки для дублей `NodeId/LayerId` через все публичные входы.

## `lib/src/core/scene.dart`

Сделать:

1. Выбрать одну внутреннюю форму `backgroundLayer`.
2. Убрать плавающую семантику “то null, то обязателен”.
3. Под это привести:

   * builder,
   * serialization,
   * runtime model.
4. Довести до конца политику `ensureBackgroundLayer`.
5. Выбрать судьбу `SceneDataErrorCode.multipleBackgroundLayers`:

   * либо реально реализовать путь, где он выбрасывается, и покрыть тестом,
   * либо удалить как мёртвый код.
6. Зафиксировать одно детерминированное поведение:

   * отсутствие фона,
   * множественность фона,
   * нормализация фона на входе.

---

# Шаг 6. Нормализовать всю внешнюю границу данных и ошибок

## `lib/src/model/scene_builder_api.dart`

Сделать:

1. Обернуть `buildFromJson(...)` в единый `_guardBuild(...)`.
2. Убрать сырой `Map<String, Object?>.from(rawJson)` из незащищённого пути.

## `lib/src/serialization/scene_codec.dart`

Сделать:

1. `decodeSceneFromJson(String)`:

   * лимит размера входа до `jsonDecode`,
   * общий `catch`,
   * нормализация в `SceneDataException`.
2. `decodeScene(Map<String, dynamic>)`:

   * убрать сырой `Map.from(...)` вне guard-слоя.
3. `encodeScene(...)` и `encodeSceneDocument(...)`:

   * прогонять через `encodePolicy`,
   * гарантировать симметрию `encode -> decode`.
4. Ошибки сериализации должны не терять `path`, включая ошибки `TextAlign`.

## Создать `lib/src/serialization/codec_guards.dart`

Реализовать:

1. `_guardDecode`
2. `_guardBuild`
3. `_guardEncode`
4. усечение `source`
5. нормализацию `path`
6. перевод системных исключений в доменные

---

# Шаг 7. Перевести id и ревизии на безопасную политику

## Создать `lib/src/core/id_generator.dart`

Сделать:

1. Генератор `NodeId`
2. Генератор `LayerId`
3. Без зависимости от простого роста `int` как единственной стратегии

## Создать `lib/src/core/revision_policy.dart`

Сделать:

1. Безопасный диапазон ревизий
2. Политику `(epoch, revision)`
3. Политику переполнения

## `lib/src/controller/txn_context.dart`

Сделать:

1. Переписать:

   * `txnNextNodeId()`
   * `txnNextLayerId()`
   * `txnNextInstanceRevision()`
2. Перевести их на новую политику генерации.

## `lib/src/model/document_clone.dart`

Сделать:

1. Перестать использовать числовой разбор legacy-id как основной механизм.
2. Legacy-формат оставить только как совместимость на чтение.

## `lib/src/render/cache/**`

Сделать:

1. Ключи кешей перевести на новую ревизионную политику.
2. При необходимости добавить `epoch` в ключи.

---

# Шаг 8. Ввести ядро операций записи

## Создать `lib/src/controller/mutation_op.dart`

Добавить типы операций:

1. `InsertNodeOp`
2. `PatchNodeOp`
3. `DeleteNodeOp`
4. `DeleteNodesBulkOp`
5. `ReplaceSceneOp`
6. `SetBackgroundColorOp`
7. `SetGridEnabledOp`
8. `SetGridCellSizeOp`
9. `SetCameraOffsetOp`
10. `TransformSelectionOp`
11. `TranslateSelectionOp`

## Создать `lib/src/controller/mutation_executor.dart`

Сделать единый маршрут:

1. preconditions
2. apply
3. postcheck
4. changeSet
5. commit preparation

## `lib/src/controller/scene_writer.dart`

Сделать:

1. Перевести write-методы на общий исполнитель операций.
2. Не держать локальные частные правила там, где ими должен владеть `ScenePolicy`.
3. Убрать лишние копии selection и signals.
4. `selectedNodeIds` отдавать как безопасное представление, без лишнего пересоздания.

## `lib/src/controller/scene_controller.dart`

Сделать:

1. `write(...)` перевести на общий исполнитель.
2. Коммит выполнять только после postcheck.
3. `dispose()`:

   * либо запрещён во время write,
   * либо откладывается.
4. Из hot path убрать:

   * debug copies,
   * commit phase copying,
   * лишние списки и клонирования.

---

# Шаг 9. Довести командный слой до правильной сложности и семантики

## `lib/src/controller/commands/draw_commands.dart`

Сделать:

1. `writeDrawStroke(...)`:

   * использовать одну каноническую политику точек,
   * не возвращать список, который потом может быть неожиданно разделён с внешним кодом.
2. `writeEraseNodes(...)`:

   * перейти на bulk delete.
3. Возвращать `NodeId`, а не `String`.

## `lib/src/controller/commands/scene_commands.dart`

Сделать:

1. `writeBackgroundColorSet(...)`
2. `writeGridEnabledSet(...)`
3. `writeGridCellSizeSet(...)`
4. `writeCameraOffsetSet(...)`

Они должны:

* не строить full snapshot до/после;
* использовать `changed`;
* сравнивать уже нормализованное значение;
* не слать ложные сигналы.

## `lib/src/model/document.dart`

Сделать:

1. Все пути удаления перевести на bulk-вариант.
2. Убрать квадратичные маршруты удаления.
3. Для `writeDeleteSelection` не делать полный скан документа, когда выбор маленький и есть локатор.
4. Для патча точек штриха:

   * сначала сравнивать длину и элементы,
   * копировать список только при реальном изменении,
   * **не менять `pointsRevision` на no-op**,
   * **не создавать новый список на no-op**.

## `lib/src/controller/scene_writer.dart`

Сделать:

1. Оптимизировать:

   * `writeDeleteSelection()`
   * `writeSelectionSelectAll()`
   * `writeSelectionTransform()`
   * `writeSignalEnqueue(...)`
2. Убрать лишние проходы.
3. Убрать лишние копии.
4. Закрепить transform order.
5. Закрепить семантику пустой selection replacement.

---

# Шаг 10. Вынести pointer-router в правильную форму

## `lib/src/view/scene_view_interactive.dart`

Сделать:

1. В самом начале `_handlePointerEvent(...)`:

   * отсекать `NaN/Infinity`
   * до:

     * `_captureActivePointer`
     * `handlePointer`
     * `_pointerTracker.handle`
     * `_syncPendingFlushTimer`

2. Исправить `Duration(milliseconds: ...)` через явный `toInt()`.

3. Развести пространства:

   * raw pointer ids
   * internal slot ids

4. Исправить `_resolvePointerId(...)`:

   * удерживаемый raw-pointer сохраняет свой internal id до конца жизни.

5. Изменить reset-политику:

   * нельзя сбрасывать tracking, пока есть хоть один живой raw-pointer.

6. Изменить порядок:

   * сначала release slot,
   * потом reset и очистка таблиц.

7. Убрать линейный поиск минимума в `_acquirePointerSlot()`.

8. Заменить ручное сравнение `PointerInputSettings` по полям на более надёжную схему.

9. `flushPending`:

   * не создавать коллекции, если результат дальше не используется.

10. Проверить `mounted` во всех отложенных путях и слушателях.

11. Пересмотреть смену pointer settings при активном жесте.

---

# Шаг 11. Вынести gesture-machine и единый предикат допустимости

## `lib/src/interactive/scene_controller_interactive.dart`

Сделать:

1. В конструкторе та же валидация `dragStartSlop`, что и в сеттере.
2. Отдельно выбрать и закрепить **одно правило** для:

   * `setDragStartSlop(...)`
   * `pointerSettings.tapSlop`
     если сейчас одно допускает `0`, а другое требует `> 0`.
3. В `handlePointer(...)`:

   * `cancel` не отбрасывается из-за невалидной позиции,
   * `up` с невалидной позицией трактуется как `cancel`.
4. На `down`:

   * фиксировать baseline `dragStartSlop` для текущего жеста.
5. `replaceScene(...)`:

   * отменяет активный жест полностью.
6. `setCameraOffset(...)`:

   * отменяет активный жест полностью.
7. Сохранить монотонность `timestampMs`.
8. Привести preview/commit к одному предикату допустимости.

## `lib/src/interactive/internal/interactive_move_session.dart`

Сделать:

1. Preview использует тот же предикат, что commit:

   * `isLocked`
   * `isTransformable`
   * `isSelectable`
2. На `cancel`:

   * откатить baseline выбора.
3. Убрать дублирующие `onStateChanged`.
4. Логику допустимости держать не в нескольких местах, а в одном.

## `lib/src/interactive/internal/interactive_draw_coordinator.dart`

Сделать:

1. Допустимость удаления и рисования привести к общей политике.
2. Проверить восстановление после безопасного `cancel`.

## `lib/src/interactive/internal/interactive_draw_line_engine.dart`

Сделать:

1. Пересмотреть таймеры и pending-state при cancel и при смене сцены.
2. Не допускать утечки активной pending-линии после общего сброса интерактива.

## Создать `lib/src/interactive/interaction_eligibility_policy.dart`

Добавить:

1. `canSelect(...)`
2. `canPreviewMove(...)`
3. `canCommitMove(...)`
4. `canDelete(...)`
5. `canTransform(...)`

Этим модулем должны пользоваться:

* interactive move
* selection
* delete
* writer/runtime, где релевантно

---

# Шаг 12. Перевести рендер и кеши на структурно безопасную форму

## Создать `lib/src/render/canvas_scope.dart`

Добавить:

1. `withSave(...)`
2. `withTranslate(...)`
3. `withTransform(...)`

## `lib/src/render/scene_painter.dart`

Сделать:

1. Перевести все `save/restore` на `canvas_scope.dart`.
2. Убрать повторные запросы в геометрический кеш в пределах одного кадра.
3. Использовать единый генератор линий сетки.
4. Добавить гистерезис на пороге плотности.
5. Проверить политику `previewDelta`.

## `lib/src/render/cache/scene_static_layer_cache.dart`

Сделать:

1. Сетка должна использовать ту же реализацию, что и painter.
2. Убрать дублирование алгоритма.

## `lib/src/render/cache/scene_text_layout_cache.dart`

Сделать:

1. Убрать цвет из ключа, если цвет не влияет на layout.
2. Перепроверить состав ключа layout.

## `lib/src/render/cache/scene_path_metrics_cache.dart`

## `lib/src/render/cache/scene_stroke_path_cache.dart`

## `lib/src/render/cache/scene_render_caches.dart`

Сделать:

1. Перевести ключи на новую ревизионную политику.
2. Защитить внутреннее содержимое от внешней мутации.
3. Прописать явную политику для невалидных transform.

## `tool/invariant_registry.dart`

Добавить:

1. Инвариант инвалидирования `PathNode` cache.
2. Инвариант контракта ревизий.
3. Инвариант монотонности timestamp.
4. Инвариант неизменяемости `ClearSceneResult`.

---

# Шаг 13. Ужесточить guardrails и реестр инвариантов

## `tool/check_import_boundaries.dart`

Сделать:

1. `Link` внутри `lib/src/**` — ошибка.
2. Анализировать `part`.
3. Анализировать `part of`.
4. Запретить новые `lib/src/*.dart`, кроме white list.
5. Добавить политику внешних пакетов по слоям.
6. Перекрыть обходы через `lib/*.dart`.

## `tool/src/layer_guardrails.dart`

Сделать:

1. Зафиксировать white list top-level слоёв.
2. Формально зафиксировать запрещённые и удалённые слои.
3. Согласовать с `check_import_boundaries`.

## `tool/check_guardrails.dart`

Сделать:

1. Убрать `skip` для `interactive/view`.
2. Проверять утечку изменяемых типов в сигнатуры.
3. Проверять write-only mutation по AST и опасным операциям, а не по имени.
4. Проверять epoch invalidation по смыслу, а не по наличию слова.
5. Защитить правило “один публичный вход”.

## `tool/check_invariant_coverage.dart`

Сделать:

1. Перестать считать комментарий `INV:...` покрытием.
2. Считать покрытием только:

   * реальную тестовую точку,
   * инструментальную проверку,
   * явный механизм доказательства.

## `tool/check_coverage.dart`

Сделать:

1. Убрать исключение для файла с реальной логикой.
2. Ужесточить требования для критичных файлов.

## `tool/invariant_registry.dart`

Сделать:

1. Добавить:

   * `INV-SER-SCHEMA-VERSION-CONTRACT`
   * инвариант монотонности `timestampMs`
   * инвариант инвалидирования `PathNode` cache
   * инвариант неизменяемости `ClearSceneResult.removedNodeIds`
   * инвариант корректного `code` для unsupported schema version
2. Переименовать существующие `INV-*`, которые содержат подчёркивания, в единый формат без `_`, например `UPPER-KEBAB-CASE`.
3. Добавить проверку, что новые ID не содержат `_`.

## `test/tool/**`

Добавить:

1. Отрицательный сценарий на каждый guardrail:

   * Link
   * part
   * part of
   * утечка `Scene`
   * fake `controllerEpoch`
   * мутирующий метод с нейтральным именем
   * формальное `INV:` без реальной проверки

---

# Шаг 14. Закрыть тестами и невозвратом все этапы

## `test/serialization/**`

Добавить и обновить:

1. bad map → всегда `SceneDataException`
2. huge JSON → доменная ошибка до `jsonDecode`
3. safe-int для `int`
4. unsupported schema version → правильный `code`
5. `TextAlign` по финальной политике
6. unsupported align → заполненный `path`
7. пустые и длинные id
8. симметрия `encode -> decode`

## `test/model/**`

Добавить и обновить:

1. policy `backgroundLayer`
2. `TextNodeSnapshot.size`
3. лимиты `kMax*` не только на JSON-пути
4. legacy id format reading
5. revision policy
6. отсутствие двойной проверки уникальности с расхождением по ошибкам
7. выбранная судьба `multipleBackgroundLayers`
8. выбранная судьба `ensureBackgroundLayer`

## `test/controller/**`

Добавить и обновить:

1. `writeSelectionReplace([])` по финальной семантике
2. bulk delete для всех путей
3. transform composition order
4. `dispose()` во время write
5. неизменяемость `ClearSceneResult`
6. no-op patch точек:

   * не копирует список,
   * не меняет `pointsRevision`

## `test/interactive/**`

Добавить и обновить:

1. `dragStartSlop` constructor validation
2. `dragStartSlop` frozen on down
3. invalid `up/cancel`
4. cancel rollback of selection baseline
5. replaceScene cancels active gesture
6. setCameraOffset cancels active gesture
7. monotonic timestamp
8. preview/commit parity for locked/untransformable nodes
9. единое правило для `dragStartSlop` и `tapSlop = 0`

## `test/view/**`

Добавить и обновить:

1. invalid pointer filtered before side effects
2. slot release order
3. raw-id/slot-id separation
4. no reset while raw pointers alive
5. mounted guard
6. no useless collections on flush path

## `test/render/**`

Добавить и обновить:

1. save/restore integrity
2. grid line generation bounded by actual step
3. same grid algorithm in painter and static cache
4. no color in text layout cache key if layout unchanged
5. path cache invalidation invariant
6. revision contract for caches

## `test/core/**`

Добавить и обновить:

1. validated value types
2. id factories
3. revision policy
4. one-owner defaults

---

# Финальный критерий готовности

Работа закончена только когда для **каждой** проблемы из этапов 0–10 выполнены одновременно три вещи:

1. изменён конкретный файл,
2. применён конкретный механизм закрытия,
3. есть конкретный тест, guardrail или CI-проверка, которая не даст проблеме вернуться.

Если хочешь, следующим сообщением я превращу **этот уже исправленный план** в самый жёсткий формат:
**по каждому файлу — список точных правок внутри файла**, без фаз и без абстракций.
