Ниже — **полный, пошаговый, логичный план** перехода на **вертикальные срезы** с **общим ядром**, с **жёсткими границами (без `part`)**, с **нарезкой тестов**, и с **тремя типами инвариантов** (глобальные / срезовые / инварианты границ).
---

## Рабочий процесс (обязательно)

Чтобы не ломать `main` и получать CI на каждый шаг:

* Вся работа по “вертикальным срезам” ведётся **только** в ветке `codex/vertical-slices`.
* Есть **один** Draft PR `codex/vertical-slices → main`. Любые новые коммиты просто пушатся в эту ветку — PR обновляется, CI на PR запускается автоматически.
* Каждый этап/подэтап плана — отдельный commit (Conventional Commits).
* В `main` не коммитим напрямую. Если что-то случайно попало в `main`, исправляем через `git revert` (без переписывания истории).

## 0) Ограничения, которые план обязан сохранить

### Публичный API не ломаем

* Импорты пользователей и тестов остаются рабочими:

  * `package:iwb_canvas_engine/basic.dart`
  * `package:iwb_canvas_engine/advanced.dart`
* Типы `CanvasMode` и `DrawTool` должны остаться доступными тем же импортом (сейчас они внутри `scene_controller.dart`).

### Семантика уведомлений сохраняется “бит-в-бит”

У вас два разных класса обновлений:

1. **Немедленное уведомление** (`_notifyNow()`):
   `setMode`, `setDrawTool`, `setDrawColor`, `setBackgroundColor`, `setGridEnabled`, `setGridCellSize`, `notifySceneChanged()`, большинство команд (rotate/flip/delete/clear/moveNode/removeNode/addNode).
2. **Коалесинг “раз в кадр”** (`requestRepaintOncePerFrame()`):
   изменения толщин (`penThickness`, `highlighterThickness`, `lineThickness`, `eraserThickness`, `highlighterOpacity`), `_setCameraOffset(...)`, `_setSelection(...)`/`_setSelectionRect(...)`, и “горячие” пути во время жестов.

Это нельзя “упростить” при нарезке — иначе сломаются тесты и ощущения от взаимодействия.

### Жёсткие границы: без `part`

* Срезы не должны импортировать `scene_controller.dart`.
* Срезы не должны импортировать друг друга (кроме файлов **внутри своего среза**).
* Любой переиспользуемый код между срезами выносим в `lib/src/input/internal/*` (или в `lib/src/core/*`, если это “чистая” математика/геометрия), чтобы не плодить исключения в правилах.
* `lib/src/input/internal/*` — “общая инфраструктура ввода”: её можно импортировать из срезов и `scene_controller.dart`, но она **не должна** импортировать `slices/**` или `scene_controller.dart` (иначе появятся циклы и неявные зависимости).
* Доступ к состоянию контроллера — только через узкие интерфейсы (“контракты границы”).

### Стратегия выполнения (оптимально по снижению рисков)

* Делаем **строго этапами** (как ниже), без “перепрыгиваний”.
* После каждого этапа — **отдельный commit** (Conventional Commits).
* После каждого крупного этапа — прогоняем “ворота качества” (см. раздел 5), чтобы ловить регрессии максимально рано.

---

## 1) Целевая структура проекта

### Общее ядро (остается общим)

`lib/src/core/*` остаётся “единственным источником истины” для модели и математики.
Правило: **ядро не импортирует** `input/`, `render/`, `view/`, `serialization/`.

### Ввод как набор вертикальных срезов

Рекомендуемая структура:

```
lib/src/input/
  scene_controller.dart          // публичный фасад: режимы, маршрутизация, API
  types.dart                     // CanvasMode, DrawTool (публичные типы)
  internal/
    contracts.dart               // узкие интерфейсы доступа (границы)
    shared/                      // (по необходимости) маленькие shared-хелперы (не “второе ядро”)
    boundary_rules.md            // (опционально) краткие правила/обоснование
  slices/
    repaint/repaint_scheduler.dart
    signals/action_dispatcher.dart
    selection/selection_model.dart
    commands/scene_commands.dart
    move/move_mode_engine.dart
    draw/draw_mode_engine.dart
    draw/tools/stroke_tool.dart
    draw/tools/line_tool.dart
    draw/tools/eraser_tool.dart
```

---

## 2) Инварианты (3 типа) — как их закрепить, чтобы они реально работали

### 2.1. Глобальные инварианты (всё приложение)

Фиксируются в `ARCHITECTURE.md` и подтверждаются тестами/`assert`.

Минимальный список, который соответствует вашему текущему поведению:

* Уникальность `NodeId` в сцене.
* Выделение не содержит `NodeId`, которых нет в сцене (восстанавливается через `notifySceneChanged()`).
* Преобразования и геометрия не порождают `NaN/Infinity`.
* Границы действий: `ActionCommitted` эмитится в правильный момент (обычно на commit жеста/команды).
* “Одна перерисовка на кадр” для частых изменений: не должно быть лишних `notifyListeners()`.

### 2.2. Инварианты срезов (для каждого среза свои)

Фиксируются в `ARCHITECTURE.md` и подтверждаются тестами с разбивкой по папкам.

Примерный набор (будет в плане ниже как чек-лист для каждого среза):

* Move: один активный указатель; drag и рамка взаимоисключающие; commit ровно один; при cancel состояние очищено.
* Draw/Line: pending-старт живёт ≤10 секунд; протягивание сбрасывает pending; commit ровно один.
* Draw/Eraser: действие только если реально удалили; учитывается `Transform2D`; траектория очищается.
* Selection: ревизии обновляются; прямоугольник нормализован/сбрасывается по правилам.
* Commands: команды сохраняют целостность сцены и выделения.

### 2.3. Инварианты границ (контракты и запреты зависимостей)

Фиксируются в `ARCHITECTURE.md` и **исполняются автоматически** скриптом в `tool/`.

Правила:

* В `lib/src/input/slices/**` запрещено: `part`, `part of`, импорт `scene_controller.dart`, импорт других срезов.
* Разрешены импорты: `core/*`, `input/action_events.dart`, `input/pointer_input.dart`, `input/types.dart`, `input/internal/*` (+ стандартные библиотеки Dart/Flutter).
* В `lib/src/input/internal/**` запрещено: импорт `scene_controller.dart`, импорт `slices/**` (чтобы “инфраструктура” не зависела от деталей срезов).

---

## 3) Полный пошаговый план с чекбоксами

### Этап 0 — Эталон и контрольная точка

* [ ] Прогнать локально полный набор как в CI:

  * [x] форматирование
  * [x] анализатор
  * [x] `flutter test --coverage`
  * [x] `dart run tool/check_coverage.dart`
  * [x] `dart doc`
  * [x] `dart pub publish --dry-run`
* [ ] Зафиксировать контрольную точку (ветка/тег) для сравнения поведения.

---

### Этап 1 — Вынести публичные типы режимов (обязательно, иначе границы не собрать)

Причина: сейчас `CanvasMode` и `DrawTool` объявлены внутри `scene_controller.dart`. Если срезам запрещён импорт контроллера, типы должны жить отдельно.

* [x] Создать `lib/src/input/types.dart`:

  * [x] `enum CanvasMode { move, draw }`
  * [x] `enum DrawTool { pen, highlighter, line, eraser }`
* [x] В `scene_controller.dart`:

  * [x] удалить определения `CanvasMode` и `DrawTool`
  * [x] импортировать `types.dart`
* [x] В экспортной поверхности:

  * [x] Добавить `export 'types.dart';` внутри `scene_controller.dart` (минимальный риск: не трогаем публичные entrypoints)
* [x] Прогнать тесты (минимум smoke + один input-тест).
* [x] Commit: `refactor(input): move CanvasMode/DrawTool to types.dart`

---

### Этап 2 — Зафиксировать 3 типа инвариантов в документации

* [x] В `ARCHITECTURE.md` добавить раздел `Инварианты`, с подразделами:

  * [x] `Глобальные`
  * [x] `Инварианты границ`
  * [x] `Инварианты срезов` (Move / Draw(Stroke,Line,Eraser) / Selection / Commands / Signals / Repaint)
* [x] В каждый подраздел добавить пункты **в стиле проверяемых утверждений**, не “общих слов”.
* [x] Commit: `docs(architecture): document invariants`

---

### Этап 3 — Исполняемая проверка границ (чтобы границы были реальными)

* [x] Добавить `tool/check_import_boundaries.dart`:

  * [x] сканирует `lib/src/input/**/*.dart` (или хотя бы `lib/src/input/slices/**`)
  * [x] валидирует:

    * [x] нет `part` / `part of`
    * [x] файлы `slices/**` не импортируют `scene_controller.dart`
    * [x] файлы `slices/**` не импортируют другие `slices/**` (кроме своей подпапки)
    * [x] файлы `internal/**` не импортируют `scene_controller.dart` и `slices/**`
    * [ ] (опционально, позже) соблюдён белый список разрешённых импортов — если захочется усилить правила
* [x] В `.github/workflows/ci.yaml` добавить шаг:

  * [x] `dart run tool/check_import_boundaries.dart`
* [x] Commit: `chore(tool): enforce input slice boundaries`

---

### Этап 4 — Контракты границы (узкие интерфейсы доступа)

Цель: срезы не знают “внутренности” контроллера.

* [x] Создать `lib/src/input/internal/contracts.dart` и описать минимальные интерфейсы:

**(1) Доступ к сцене и координатам**

* [x] `Scene get scene`
* [x] `Offset toScenePoint(Offset viewPoint)` (обёртка над `toScene(viewPoint, scene.camera.offset)`)
* [x] `double get dragStartSlop`

**(2) Выделение**

* [x] `Set<NodeId> get selectedNodeIds`
* [x] `bool setSelection(Iterable<NodeId> ids, {bool notify})` (как `_setSelection`)
* [x] `Rect? get selectionRect`
* [x] `void setSelectionRect(Rect? rect, {bool notify})`

**(3) Ревизии/маркировка изменений**

* [x] `int get sceneRevision`
* [x] `int get selectionRevision`
* [x] `void markSceneGeometryChanged()`
* [x] `void markSceneStructuralChanged()`
* [x] `void markSelectionChanged()`

**(4) Перерисовка/уведомления**

* [x] `void requestRepaintOncePerFrame()`
* [x] `void notifyNow()` (немедленно)
* [x] `bool get needsNotify` и/или `void notifyNowIfNeeded()` (чтобы срезы могли повторить вашу текущую логику: “на up/cancel — уведомить немедленно только если были изменения”)

**(5) Сигналы**

* [x] `void emitAction(ActionCommitted action)` или метод-обёртка `emitAction(type, ids, ts, payload)`
* [x] `void emitEditTextRequested(EditTextRequested req)`

**(6) Генерация идентификаторов**

* [x] `NodeId newNodeId()`

**(7) Настройки рисования (read-only)**

* [x] `DrawTool get drawTool`
* [x] `Color get drawColor`
* [x] `double get penThickness`
* [x] `double get highlighterThickness`
* [x] `double get lineThickness`
* [x] `double get eraserThickness`
* [x] `double get highlighterOpacity`

* [x] В `SceneController` реализовать эти интерфейсы (или создать адаптер-объект, который делегирует в `SceneController`).

* [x] Прогнать тесты.
* [x] Commit: `refactor(input): introduce slice boundary contracts`

---

### Этап 5 — Вынести “перерисовку раз в кадр” в отдельный срез Repaint

Причина: это общий механизм и очень “тонкий”.

* [x] Создать `lib/src/input/slices/repaint/repaint_scheduler.dart`
* [x] Перенести из `SceneController`:

  * [x] `_repaintScheduled`, `_repaintToken`, `_isDisposed`, `_needsNotify`
  * [x] `_cancelScheduledRepaint()`, `requestRepaintOncePerFrame()`, `_notifyNow()` (или публичный `notifyNow()`)
* [x] **Инварианты этого среза (обязательные чекбоксы):**

  * [x] повторный вызов `requestRepaintOncePerFrame()` не планирует второй кадр
  * [x] токен `_repaintToken` отменяет ранее запланированный кадр
  * [x] `try/catch FlutterError` сохранён (в тестах без биндинга должен быть fallback)
  * [x] при `notifyNow()` сбрасывается `_needsNotify` и отменяется запланированная перерисовка
* [x] В `SceneController.dispose()`:

  * [x] установить disposed и отменить планирование, как сейчас
* [x] Прогнать `test/input_scene_controller_notify_test.dart`.
* [x] Commit: `refactor(input): extract repaint scheduler`

---

### Этап 6 — Вынести сигналы (actions + editTextRequests) в отдельный срез Signals

* [ ] Создать `lib/src/input/slices/signals/action_dispatcher.dart`
* [ ] Перенести:

  * [ ] `StreamController<ActionCommitted>.broadcast(sync: true)`
  * [ ] `StreamController<EditTextRequested>.broadcast(sync: true)`
  * [ ] `_actionCounter`, `_emitAction(...)`
* [ ] **Инварианты:**

  * [ ] `broadcast(sync: true)` сохранён (это влияет на порядок/момент доставки)
  * [ ] формат `actionId: 'a${counter++}'` сохранён
* [ ] В `dispose()`:

  * [ ] закрывать оба контроллера (как сейчас)
* [ ] Прогнать:

  * [ ] `test/input_action_events_payload_test.dart`
  * [ ] `test/input_edit_text_requested_test.dart`
* [ ] Commit: `refactor(input): extract action dispatcher`

---

### Этап 7 — Вынести Selection (модель выделения) в отдельный срез

* [ ] Создать `lib/src/input/slices/selection/selection_model.dart`
* [ ] Перенести:

  * [ ] `_selectedNodeIds` (`LinkedHashSet`)
  * [ ] `_selectedNodeIdsView` (`UnmodifiableSetView`)
  * [ ] `_selectionRect`
  * [ ] `_selectionRevision` (или хранить в контроллере, но логичнее рядом)
  * [ ] `_setSelection(...)`, `_setSelectionRect(...)` (или адаптировать к контрактам)
* [ ] Сохранить публичные тестовые крючки и геттеры в `SceneController`:

  * [ ] `selectedNodeIds`, `selectionRect`, `debugSelectionRevision`, `debugSetSelection`, `debugSetSelectionRect`
* [ ] **Инварианты:**

  * [ ] `_setSelection(...)` по умолчанию делает `requestRepaintOncePerFrame()` (как сейчас), а не `notifyNow()`
  * [ ] `clearSelection()` остаётся немедленным (`_notifyNow()`), как сейчас
* [ ] Прогнать:

  * [ ] `test/input_commands_test.dart`
  * [ ] `test/input_scene_controller_mutations_test.dart`
  * [ ] `test/input_move_mode_test.dart`
* [ ] Commit: `refactor(input): extract selection model`

---

### Этап 8 — Вынести MoveModeEngine (перемещение + рамка выделения)

* [ ] Создать `lib/src/input/slices/move/move_mode_engine.dart`
* [ ] Перенести из `SceneController`:

  * [ ] поля move-состояния: `_activePointerId`, `_pointerDownScene`, `_lastDragScene`, `_dragTarget`, `_dragMoved`, `_pendingClearSelection`
  * [ ] буфер: `_moveGestureNodes`, `_dragSceneRevision`, `_dragSelectionRevision`, `_debugMoveGestureBuildCount`, `_debugDragSceneStructureFingerprint`
  * [ ] `_DragTarget` (как приватный enum внутри этого файла)
  * [ ] обработчики: `_handleMoveModePointer`, `_handleDown/_handleMove/_handleUp/_handleCancel`, commit/применение дельты
  * [ ] `_normalizeRect` (сейчас это приватная верхнеуровневая функция) — перенести сюда или в `move/_utils.dart` внутри среза
  * [ ] вычисление “отпечатка структуры” (`_debugComputeSceneStructureFingerprint`) — либо оставить в контроллере и дать через контракт, либо перенести в move-engine (он использует только `scene`)
* [ ] В `SceneController.handlePointer(...)` оставить маршрутизацию:

  * [ ] если `mode == move` → `moveEngine.handle(sample)`
  * [ ] иначе → draw-engine
* [ ] Сохранить в `SceneController` `@visibleForTesting` геттеры:

  * [ ] `debugMoveGestureBuildCount`
  * [ ] `debugMoveGestureNodes`
* [ ] **Инварианты Move:**

  * [ ] один активный указатель в move-режиме
  * [ ] drag и рамка выделения взаимоисключающие
  * [ ] commit действия и эмиссия `ActionCommitted` происходят ровно один раз (на `up`)
  * [ ] `cancel` полностью очищает состояние
  * [ ] `notifyNow` на `up/cancel` вызывается только если были изменения (`needsNotify == true`) — как сейчас
* [ ] Прогнать:

  * [ ] `test/input_move_mode_test.dart`
  * [ ] `test/input_scene_controller_drag_buffer_test.dart`
  * [ ] `test/input_scene_controller_edge_cases_test.dart`
* [ ] Commit: `refactor(input): extract move mode engine`

---

### Этап 9 — Вынести DrawModeEngine и инструменты (Stroke/Line/Eraser)

#### 9.1 DrawModeEngine (общий движок режима рисования)

* [ ] Создать `lib/src/input/slices/draw/draw_mode_engine.dart`
* [ ] Перенести:

  * [ ] `_handleDrawModePointer`, `_handleDrawDown/_handleDrawMove/_handleDrawUp/_handleDrawCancel`
  * [ ] состояние pointer-рисования: `_drawPointerId`, `_drawDownScene`, `_lastDrawScene`, `_drawMoved`
  * [ ] `_resetDrawPointer()`
  * [ ] `_ensureAnnotationLayer()` (**сохранить нюанс**: сейчас добавление слоя не помечает структуру)
  * [ ] `_strokeThicknessForTool()`
  * [ ] `_resetDraw()` (**сохранить нюанс**: удаление черновых узлов из слоя + `_markSceneStructuralChanged()` как сейчас)
* [ ] В `SceneController.setMode(...)` и `setDrawTool(...)` делегировать сброс состояния в draw-engine, сохранив немедленное уведомление.

#### 9.2 Tool: Stroke (pen/highlighter)

* [ ] Создать `lib/src/input/slices/draw/tools/stroke_tool.dart`
* [ ] Перенести логику:

  * [ ] создание `StrokeNode`, добавление точек, commit
  * [ ] учёт `drawColor`, толщины и прозрачности для highlighter
* [ ] Инварианты:

  * [ ] “черновой” штрих существует только между `down` и `up/cancel`
  * [ ] действие эмитится только если реально создан узел

#### 9.3 Tool: Line (drag + two-tap + тайм-аут 10s)

* [ ] Создать `lib/src/input/slices/draw/tools/line_tool.dart`
* [ ] Перенести:

  * [ ] `_pendingLineStart`, `_pendingLineTimestampMs`
  * [ ] `_setPendingLineStart(...)`, `_clearPendingLine()`, `_expirePendingLine(...)`
  * [ ] логику протягивания линии и логику “двумя нажатиями”
* [ ] Сохранить публичные геттеры в `SceneController`:

  * [ ] `pendingLineStart`, `pendingLineTimestampMs`, `hasPendingLineStart`
* [ ] Инварианты:

  * [ ] pending живёт ≤ 10 секунд и очищается
  * [ ] протягивание/смена режима/смена инструмента корректно сбрасывают pending

#### 9.4 Tool: Eraser

* [ ] Создать `lib/src/input/slices/draw/tools/eraser_tool.dart`

* [ ] Перенести:

  * [ ] хранение траектории (`_eraserPoints`) и очистку
  * [ ] пересечения/удаление с учётом `Transform2D`
  * [ ] `_maxSingularValue2x2(...)` (сейчас это вспомогательная функция) — внутрь eraser-tool (или в `eraser/_math.dart`)

* [ ] Инварианты:

  * [ ] действие “delete/erase” эмитится только если реально удалили
  * [ ] учёт обратного преобразования сохраняется (иначе ломается ваш отдельный тест)

* [ ] Прогнать:

  * [ ] `test/input_draw_mode_test.dart`
  * [ ] `test/input_scene_controller_eraser_transform2d_test.dart`
  * [ ] `test/input_scene_controller_edge_cases_test.dart`
* [ ] Commit: `refactor(input): extract draw mode engine and tools`

---

### Этап 10 — Вынести Commands (команды сцены/выделения/мутаций)

* [ ] Создать `lib/src/input/slices/commands/scene_commands.dart`
* [ ] Перенести:

  * [ ] `mutate(fn, structural)`
  * [ ] `notifySceneChanged()` (восстановление инвариантов выделения)
  * [ ] `addNode`, `removeNode`, `moveNode`, `clearScene`
  * [ ] `rotateSelection`, `flipSelectionVertical`, `flipSelectionHorizontal`, `deleteSelection`
  * [ ] `setSelection`, `toggleSelection`, `selectAll`, `clearSelection`
* [ ] Важные нюансы, которые обязаны сохраниться:

  * [ ] `mutate(structural: true)` вызывает `notifySceneChanged()` и **возвращается** (как сейчас)
  * [ ] `notifySceneChanged()` делает `_markSceneStructuralChanged()` и немедленный `_notifyNow()`
  * [ ] `clearSelection()` — немедленный `_notifyNow()`
  * [ ] `setSelection()` — по умолчанию через `_setSelection(...)` → `requestRepaintOncePerFrame()` (не `notifyNow`)
* [ ] Отдельно оставить в `SceneController` (или в commands) настройки фона/сетки и камеры, но **с прежней семантикой**:

  * [ ] `setBackgroundColor` / `setGridEnabled` / `setGridCellSize` → немедленно `_notifyNow()`
  * [ ] `setCameraOffset` → `_setCameraOffset(..., notify: true)` → `requestRepaintOncePerFrame()`
* [ ] Прогнать:

  * [ ] `test/input_commands_test.dart`
  * [ ] `test/input_scene_controller_mutations_test.dart`
  * [ ] `test/input_scene_controller_notify_test.dart`
* [ ] Commit: `refactor(input): extract scene commands`

---

### Этап 11 — Нарезка тестов по вертикальным срезам (папки)

Делается механически, логика тестов не меняется.

* [ ] Создать структуру:

```
test/
  core/
  input/
    move/
    draw/
      tools/
    commands/
    notify/
    signals/
    pointer/
  render/
  serialization/
  view/
  entrypoints/
  fixtures/
```

* [ ] Перенести файлы (1:1 соответствие):

  * [ ] `test/core_geometry_test.dart` → `test/core/geometry_test.dart`

  * [ ] `test/core_nodes_test.dart` → `test/core/nodes_test.dart`

  * [ ] `test/core_transform2d_test.dart` → `test/core/transform2d_test.dart`

  * [ ] `test/core_transform2d_json_test.dart` → `test/core/transform2d_json_test.dart`

  * [ ] `test/input_move_mode_test.dart` → `test/input/move/move_mode_test.dart`

  * [ ] `test/input_scene_controller_drag_buffer_test.dart` → `test/input/move/drag_buffer_test.dart`

  * [ ] `test/input_draw_mode_test.dart` → `test/input/draw/draw_mode_test.dart`

  * [ ] `test/input_scene_controller_eraser_transform2d_test.dart` → `test/input/draw/tools/eraser_transform2d_test.dart`

  * [ ] `test/input_commands_test.dart` → `test/input/commands/commands_test.dart`

  * [ ] `test/input_scene_controller_mutations_test.dart` → `test/input/commands/mutations_test.dart`

  * [ ] `test/input_scene_controller_notify_test.dart` → `test/input/notify/notify_test.dart`

  * [ ] `test/input_action_events_payload_test.dart` → `test/input/signals/action_events_payload_test.dart`

  * [ ] `test/input_edit_text_requested_test.dart` → `test/input/signals/edit_text_requested_test.dart`

  * [ ] `test/input_pointer_input_test.dart` → `test/input/pointer/pointer_input_test.dart`

  * [ ] `test/input_scene_controller_edge_cases_test.dart` → `test/input/edge_cases_test.dart`

  * [ ] `test/render_scene_painter_test.dart` → `test/render/scene_painter_test.dart`

  * [ ] `test/render_scene_static_layer_cache_test.dart` → `test/render/scene_static_layer_cache_test.dart`

  * [ ] `test/serialization_scene_test.dart` → `test/serialization/scene_test.dart`

  * [ ] `test/serialization_scene_codec_validation_test.dart` → `test/serialization/scene_codec_validation_test.dart`

  * [ ] `test/serialization_scene_v2_fixture_test.dart` → `test/serialization/scene_v2_fixture_test.dart`

  * [ ] `test/view_scene_view_test.dart` → `test/view/scene_view_test.dart`

  * [ ] `test/entrypoints_basic_smoke_test.dart` → `test/entrypoints/basic_smoke_test.dart`

* [ ] `test/fixtures/scene_v2.json` оставить как есть (пути у вас уже “от корня test/fixtures”, перенос тестов это не ломает).

* [ ] Прогнать:

  * [ ] `flutter test --coverage`
  * [ ] `dart run tool/check_coverage.dart`
* [ ] Commit: `test: reorganize tests by slice`

---

### Этап 12 — Финальная шлифовка и контроль “ничего не упустили”

* [ ] Убедиться, что `basic.dart` и `advanced.dart` экспортируют всё, что пользователи ожидают:

  * [ ] `SceneController`
  * [ ] `CanvasMode`, `DrawTool` (через `types.dart`)
* [ ] Убедиться, что `SceneController` по-прежнему содержит публичные свойства/методы (поведенчески эквивалентны):

  * [ ] режим/инструмент/цвет/фон/сетка/камера
  * [ ] толщины и прозрачность (через коалесинг “раз в кадр”)
  * [ ] `selectedNodeIds`, `selectionRect`, `selectionBoundsWorld`, `selectionCenterWorld`
  * [ ] `pendingLine*` геттеры
  * [ ] `getNode`, `findNode`
  * [ ] команды и `mutate/notifySceneChanged`
  * [ ] `handlePointer`, `handlePointerSignal`
  * [ ] `actions`, `editTextRequests`
  * [ ] `dispose` закрывает всё как раньше
* [ ] Прогнать полный CI-набор команд (как на Этапе 0).
* [ ] (Опционально, но полезно) привести документацию в соответствие: в `ARCHITECTURE.md` убрать/исправить упоминания несуществующего `iwb_canvas_engine.dart` (у вас публичные входы — `basic.dart` и `advanced.dart`).
* [ ] Commit: `chore: final polish`

---

## 4) “Карта переноса” — чтобы реально ничего не забыть

### Остаётся во фасаде `SceneController` (публичное API и маршрутизация)

* Публичные геттеры/сеттеры:

  * `mode`, `setMode`
  * `drawTool`, `setDrawTool`
  * `drawColor`, `setDrawColor`
  * `setBackgroundColor`, `setGridEnabled`, `setGridCellSize`, `setCameraOffset`
  * `penThickness`, `highlighterThickness`, `lineThickness`, `eraserThickness`, `highlighterOpacity`
* Публичные запросы:

  * `handlePointer` (маршрутизация на move/draw)
  * `handlePointerSignal` (можно делегировать move-срезу, но публичная точка остаётся здесь)
* Публичные выборки:

  * `selectedNodeIds`, `selectionRect`, `selectionBoundsWorld`, `selectionCenterWorld`
  * `pendingLineStart`, `pendingLineTimestampMs`, `hasPendingLineStart`
  * `getNode`, `findNode`
* `dispose()` (делегирует закрытие/отмены внутрь срезов)

### В `types.dart`

* `CanvasMode`, `DrawTool`

### В `slices/repaint/*`

* `_repaintScheduled`, `_repaintToken`, `_needsNotify`, `_cancelScheduledRepaint`, `requestRepaintOncePerFrame`, `_notifyNow`

### В `slices/signals/*`

* `_actions`, `_editTextRequests`, `_actionCounter`, `_emitAction`

### В `slices/selection/*`

* `_selectedNodeIds`, `_selectedNodeIdsView`, `_selectionRect`, `_selectionRevision`, `_setSelection`, `_setSelectionRect`

### В `slices/move/*`

* `_activePointerId`, `_pointerDownScene`, `_lastDragScene`, `_dragTarget`, `_dragMoved`, `_pendingClearSelection`
* `_moveGestureNodes` + ревизии/отпечаток структуры + `debugMoveGesture*`
* `_normalizeRect`, `_DragTarget`, вся логика move-жеста и marquee

### В `slices/draw/*` и `slices/draw/tools/*`

* `_drawPointerId`, `_drawDownScene`, `_lastDrawScene`, `_drawMoved`, `_resetDrawPointer`
* `_resetDraw`, `_ensureAnnotationLayer`, `_strokeThicknessForTool`
* StrokeTool: активный штрих
* LineTool: активная линия + pending-логика + тайм-аут 10с
* EraserTool: траектория + пересечения + `_maxSingularValue2x2`

### В `slices/commands/*`

* `mutate`, `notifySceneChanged`
* все команды (add/remove/move/clear/rotate/flip/delete/selection ops)

---

## 5) Контроль качества после КАЖДОГО крупного этапа (обязательные “ворота”)

После этапов 1, 3, 5, 6, 7, 8, 9, 10, 11:

* [ ] форматирование
* [ ] анализатор
* [ ] `flutter test --coverage`
* [ ] `dart run tool/check_coverage.dart`
* [ ] `dart doc`
* [ ] `dart pub publish --dry-run`

Это гарантирует, что вы не накопите “долг” и не сломаете CI в конце, когда уже тяжело локализовать причину.

---
