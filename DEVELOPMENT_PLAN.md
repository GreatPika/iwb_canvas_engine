Цель: **уменьшить “огромные” файлы и упростить ревью**, не меняя поведение.

---

## План работ (чекбоксы)


---

## 2) Разнести `scene_controller_interactive.dart` на `part`-файлы (без изменения публичного API)

**Факт по коду:** `lib/src/interactive/scene_controller_interactive.dart` ~1319 строк.
**Статус:** отложено; в Dart нет partial class, поэтому перенос методов класса в `part`-файлы не компилируется без смены подхода (например, extensions + тонкие прокси-методы).

### 2.1 Создать `part`-файлы

* [ ] В `lib/src/interactive/` создать файлы:

  * [ ] `scene_controller_interactive_input.part.dart`
  * [ ] `scene_controller_interactive_move.part.dart`
  * [ ] `scene_controller_interactive_draw.part.dart`
  * [ ] `scene_controller_interactive_hit_test.part.dart`
  * [ ] `scene_controller_interactive_events.part.dart`
* [ ] В каждом из них первой строкой сделать:

  * [ ] `part of 'scene_controller_interactive.dart';`

### 2.2 Добавить `part`-директивы в основной файл

* [ ] В `lib/src/interactive/scene_controller_interactive.dart` после импортов добавить:

  * [ ] `part 'scene_controller_interactive_input.part.dart';`
  * [ ] `part 'scene_controller_interactive_move.part.dart';`
  * [ ] `part 'scene_controller_interactive_draw.part.dart';`
  * [ ] `part 'scene_controller_interactive_hit_test.part.dart';`
  * [ ] `part 'scene_controller_interactive_events.part.dart';`

### 2.3 Разложить код по частям (перенос 1:1)

* [ ] В `*_input.part.dart` перенести:

  * [ ] `handlePointer(CanvasPointerInput ...)`
  * [ ] `handleDoubleTap(...)`
  * [ ] `_resolveTimestampMs(...)`
  * [ ] преобразование `CanvasPointerInput -> PointerSample`
  * [ ] маршрутизацию в `_handleMovePointer(...)` / `_handleDrawPointer(...)`
* [ ] В `*_move.part.dart` перенести:

  * [ ] `_handleMovePointer(...)` и всю связанную логику перемещения/выделения/preview
* [ ] В `*_draw.part.dart` перенести:

  * [ ] `_handleDrawPointer(...)` и всю связанную логику рисования/ластика/линии/pending line
* [ ] В `*_hit_test.part.dart` перенести:

  * [ ] `_toScenePoint(...)`, `_nodesIntersecting(...)`, `_hitTestTopNode(...)`, `_hitTestNodeWithMovePreview(...)`
  * [ ] `_selectedTransformableNodesInSnapshotOrder(...)` и прочие геометрические/поисковые помощники
* [ ] В `*_events.part.dart` перенести:

  * [ ] `class _InteractiveEventDispatcher` и код эмиссии `ActionCommitted`/`EditTextRequested`

### 2.4 Проверки

* [ ] `dart format --output=none --set-exit-if-changed lib test example/lib tool`
* [ ] `flutter analyze`
* [ ] `flutter test`

---

## 3) Разнести `scene_painter.dart` на “рисование” + отдельные файлы кешей

**Факт по коду:** `lib/src/render/scene_painter.dart` ~1411 строк и содержит 4 крупных кеша + `ScenePainterV2`. Также есть агрегатор `lib/src/render/scene_render_caches.dart`, который импортирует `scene_painter.dart`.

### 3.1 Создать директорию и файлы кешей

* [x] Создать папку: `lib/src/render/cache/`
* [x] Создать файлы:

  * [x] `lib/src/render/cache/scene_stroke_path_cache_v2.dart`
  * [x] `lib/src/render/cache/scene_text_layout_cache_v2.dart`
  * [x] `lib/src/render/cache/scene_path_metrics_cache_v2.dart`
  * [x] `lib/src/render/cache/scene_static_layer_cache_v2.dart`

### 3.2 Перенести классы кешей из `scene_painter.dart` (перенос 1:1)

* [x] В `scene_stroke_path_cache_v2.dart` перенести:

  * [x] `SceneStrokePathCacheV2` и связанные внутренние структуры (например `_StrokePathEntryV2`)
* [x] В `scene_text_layout_cache_v2.dart` перенести:

  * [x] `SceneTextLayoutCacheV2` и ключи (например `_TextLayoutKeyV2`)
* [x] В `scene_path_metrics_cache_v2.dart` перенести:

  * [x] `ScenePathMetricsCacheV2`, `PathSelectionContoursV2` и связанные ключи/entries (например `_NodeInstanceKeyV2`, `_PathMetricsEntryV2`)
* [x] В `scene_static_layer_cache_v2.dart` перенести:

  * [x] `SceneStaticLayerCacheV2` и ключи (например `_StaticLayerKeyV2`)
* [x] В `lib/src/render/scene_painter.dart` оставить:

  * [x] `ScenePainterV2`
  * [x] `ImageResolverV2`, `NodePreviewOffsetResolverV2` (и всё, что относится именно к рисованию кадра)

### 3.3 Обновить импорты агрегатора кешей

* [x] В `lib/src/render/scene_render_caches.dart` убрать зависимость от кешей через `scene_painter.dart`:

  * [x] заменить `import 'scene_painter.dart';` на импорты новых файлов из `render/cache/*`
  * [x] оставить импорт `scene_painter.dart` только если он реально нужен для `ScenePainterV2` (обычно агрегатору он не нужен)

### 3.4 Проверки

* [x] `dart format ...`
* [x] `flutter analyze`
* [x] `flutter test`

---

## 4) Разнести `scene_builder.dart` на `part`-файлы по этапам (без изменения поведения)

**Факт по коду:** `lib/src/model/scene_builder.dart` ~1350 строк; много приватных (`_...`) функций → удобнее делить через `part`, чтобы не менять видимость.

### 4.1 Создать `part`-файлы

* [x] В `lib/src/model/` создать:

  * [x] `scene_builder_json_require.part.dart` (все `_require*`, `_cast*`, парсеры примитивов)
  * [x] `scene_builder_decode_json.part.dart` (`_decodeSnapshotFromJson` и весь `_decode*` блок)
  * [x] `scene_builder_scene_from_snapshot.part.dart` (`_sceneFromSnapshot`, `_sceneNodeFromSnapshot`, и т.п.)
  * [x] `scene_builder_snapshot_from_scene.part.dart` (`_snapshotFromScene` и обратные преобразования)
  * [x] `scene_builder_canonicalize_validate.part.dart` (канонизация/валидация, если сейчас размазано по файлу)
* [x] В каждом `part`-файле первой строкой:

  * [x] `part of 'scene_builder.dart';`

### 4.2 Подключить `part`-директивы

* [x] В `lib/src/model/scene_builder.dart` после импортов добавить `part '...';` для всех файлов из шага 4.1

### 4.3 Разложить код (перенос 1:1)

* [x] Перенести соответствующие блоки функций в свои `part`-файлы, не меняя сигнатуры и порядок вызовов.

### 4.4 Проверки

* [x] `dart format ...`
* [x] `flutter analyze`
* [x] `flutter test`

---

## 5) Разнести `scene_value_validation.dart` на `part`-файлы по группам проверок

**Факт по коду:** `lib/src/model/scene_value_validation.dart` ~1112 строк; много функций одного уровня.

### 5.1 Создать `part`-файлы

* [ ] В `lib/src/model/` создать:

  * [ ] `scene_value_validation_primitives.part.dart` (числа/Offset/Size/Transform2D и т.п.)
  * [ ] `scene_value_validation_palette_grid.part.dart` (палитра/сетка)
  * [ ] `scene_value_validation_node.part.dart` (проверки узлов/spec/patch + общие внутренние helpers)
  * [ ] `scene_value_validation_top_level.part.dart` (`sceneValidateSnapshotValues`, `sceneValidateSceneValues` и верхний уровень)
* [ ] В каждом `part`-файле первой строкой:

  * [ ] `part of 'scene_value_validation.dart';`

### 5.2 Подключить `part`-директивы

* [ ] В `lib/src/model/scene_value_validation.dart` после импортов добавить `part '...';` для всех файлов из шага 5.1

### 5.3 Разложить код (перенос 1:1)

* [ ] Перенести функции по группам без изменения сигнатур.

### 5.4 Проверки

* [ ] `dart format ...`
* [ ] `flutter analyze`
* [ ] `flutter test`

---

## Финальный контроль качества

* [x] Убедиться, что публичный entrypoint `lib/iwb_canvas_engine.dart` **не менялся** (кроме уже сделанного ранее сужения API; в этом плане entrypoint не трогаем).
* [x] Убедиться, что все команды проходят:

  * [x] `dart format --output=none --set-exit-if-changed lib test example/lib tool`
  * [x] `flutter analyze`
  * [x] `flutter test`

---

## Результат, который должен получиться

* `scene_controller_interactive.dart` остаётся тем же классом, но код разнесён по 5 файлам.
* `scene_painter.dart` перестаёт быть “комбайном”: кеши живут отдельно.
* `scene_builder.dart` и `scene_value_validation.dart` становятся читабельными за счёт `part`-файлов без изменения видимости `_...` функций.
* `SceneViewInteractiveV2` больше не светит наружу `RenderGeometryCache`.

Если хочешь, я добавлю к этому плану **готовые команды `git mv`/создания файлов** и точные “якоря” (по каким строкам резать/куда переносить), но текущий список уже полностью исполним Codex без дополнительных уточнений.
