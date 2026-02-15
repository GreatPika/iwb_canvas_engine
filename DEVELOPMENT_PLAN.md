## Цель

Перевести библиотеку на новую структуру и нейминг так, чтобы:

* `V2` полностью исчез **из имён**: папок/файлов/классов/типов/функций/методов/инвариантов/тестов/доков.
* `lib/src/input/slices/**` исчез как концепция: эти файлы становятся **частями контроллера** и переезжают в `lib/src/controller/{commands,internal}/**`.
* `scene_controller_interactive.dart` **не разрезаем на `part`** (только переименования/импорты/типы).
* Все проверки проекта (анализатор, тесты, “тулы”) проходят, включая ваши guardrails/инварианты/границы импортов.

---

## Обязательные проверки (Definition of Done)

Прогоняются **в конце каждого этапа**, а на финале — все вместе.

### A. Статические проверки

* [ ] `dart format --output=none --set-exit-if-changed lib test tool example/lib`
* [ ] `flutter analyze`

### B. Проектные инструменты (обязательны)

* [ ] `dart run tool/check_import_boundaries.dart`
* [ ] `dart run tool/check_invariant_coverage.dart`
* [ ] `dart run tool/check_guardrails.dart`

### C. Тесты и покрытие

* [ ] `flutter test --coverage`
* [ ] `dart run tool/check_coverage.dart` (100% для `lib/src/**`, как сейчас требуется)

### D. Публикация и документация

* [ ] `dart doc`
* [ ] `dart pub publish --dry-run`

### E. Бенчмарки (если ты считаешь их частью “обязательных”)

* [ ] `dart run tool/bench/run_load_profiles.dart --profile=smoke --output=build/bench/load_profiles_smoke.json`

### F. Проверка “V2 нет в именах” (без ложных совпадений)

> Важно: **не используем** простой `grep V2`, потому что в `test/fixtures/scene.json` есть `V20` (SVG-команда), это не про нейминг.

* [ ] Нет файлов/папок с `V2` в имени:

  * `find lib test tool -name '*V2*' -o -name '*_v2*'`
* [ ] Нет `V2`-идентификаторов в Dart:

  * `grep -RIn --include='*.dart' -E '(\bV2\b|V2[A-Za-z_]|[A-Za-z_]+V2\b)' lib test tool` → **пусто**
* [ ] Нет `V2` в доках/публичных описаниях (по желанию, но рекомендуется):

  * `grep -RIn --include='*.md' -E '(\bV2\b|InteractiveV2|ViewInteractiveV2|ScenePainterV2)' .` → **пусто**

---

# План миграции (чекбоксы)

## Этап 0 — Контрольная точка

* [ ] Создать ветку.
* [ ] Прогнать все проверки из DoD на текущей версии и убедиться, что база “зелёная”.
* [ ] Зафиксировать текущий публичный API (опционально: снимок `dart doc`/список экспортов).

---

## Этап 1 — Рендер: убрать `V2` из кэшей и painter’а (самое локальное и безопасное)

### 1.1 Переименование файлов (через `git mv`)

* [x] `lib/src/render/cache/scene_path_metrics_cache_v2.dart` → `scene_path_metrics_cache.dart`
* [x] `lib/src/render/cache/scene_static_layer_cache_v2.dart` → `scene_static_layer_cache.dart`
* [x] `lib/src/render/cache/scene_stroke_path_cache_v2.dart` → `scene_stroke_path_cache.dart`
* [x] `lib/src/render/cache/scene_text_layout_cache_v2.dart` → `scene_text_layout_cache.dart`

### 1.2 Переименование типов внутри кэшей (убрать V2 из “ключей” и “entry”)

* [x] `_NodeInstanceKeyV2` → `_NodeInstanceKey`
* [x] `_TextLayoutKeyV2` → `_TextLayoutKey`
* [x] `_StaticLayerKeyV2` → `_StaticLayerKey`
* [x] `_StrokePathEntryV2` → `_StrokePathEntry`
* [x] `_PathMetricsEntryV2` → `_PathMetricsEntry`
* [x] `PathSelectionContoursV2` → `PathSelectionContours`
* [x] `ScenePathMetricsCacheV2` → `ScenePathMetricsCache`
* [x] `SceneStaticLayerCacheV2` → `SceneStaticLayerCache`
* [x] `SceneStrokePathCacheV2` → `SceneStrokePathCache`
* [x] `SceneTextLayoutCacheV2` → `SceneTextLayoutCache`

### 1.3 Painter и кэши рендера

* [x] `ScenePainterV2` → `ScenePainter`
* [x] `SceneRenderCachesV2` → `SceneRenderCaches`
* [x] `ImageResolverV2` → `ImageResolver`
* [x] `NodePreviewOffsetResolverV2` → `NodePreviewOffsetResolver`

### Проверки этапа

* [x] A + B (format/analyze/tools)
* [x] `flutter test test/render --coverage`

---

## Этап 2 — View: убрать `V2` из виджетов (пока контроллер ещё может быть V2)

### 2.1 Переименование виджетов и внутренних классов

* [x] `SceneViewV2` → `SceneViewCore`
* [x] `_SceneViewV2State` → `_SceneViewCoreState`
* [x] `SceneViewInteractiveV2` → `SceneViewInteractive`
* [x] `_SceneViewInteractiveV2State` → `_SceneViewInteractiveState`
* [x] `_SceneInteractiveOverlayPainterV2` → `_SceneInteractiveOverlayPainter`

### 2.2 Публичный алиас (удобство)

* [x] `typedef SceneView = SceneViewInteractive;`

### Проверки этапа

* [x] A + B
* [x] `flutter test test/view --coverage`

---

## Этап 3 — Публичные типы: убрать `V2PathFillRule` и конвертации “From/ToV2”

### 3.1 Удалить публичный `V2PathFillRule`

* [x] Удалить `enum V2PathFillRule` из `lib/src/public/snapshot.dart`
* [x] В `public/snapshot.dart`, `public/node_spec.dart`, `public/node_patch.dart`: заменить `V2PathFillRule` → `PathFillRule`
* [x] Включить `PathFillRule` как публично используемый тип (точечный импорт `show PathFillRule` из core)

### 3.2 Удалить/переименовать “V2”-функции конвертации

* [x] Удалить `_txnPathFillRuleFromV2/_txnPathFillRuleToV2`
* [x] Удалить `_pathFillRuleFromV2/_pathFillRuleToV2`
* [x] `_parsePathFillRule` должен возвращать `PathFillRule` (не `V2PathFillRule`)

### Проверки этапа

* [x] A + B
* [x] `flutter test test/public test/serialization --coverage`

---

## Этап 4 — Новая структура: перенос `input/slices/**` в `controller/{commands,internal}` + переименование без `slice` и без `V2`

### 4.1 Перенос файлов (через `git mv`)

**Команды (API-подобные группы)**

* [x] `lib/src/input/slices/commands/scene_commands.dart` → `lib/src/controller/commands/scene_commands.dart`
* [x] `lib/src/input/slices/draw/draw_slice.dart` → `lib/src/controller/commands/draw_commands.dart`
* [x] `lib/src/input/slices/move/move_slice.dart` → `lib/src/controller/commands/move_commands.dart`

**Внутреннее (буферы/кэши/нормализация/флаги)**

* [x] `lib/src/input/slices/grid/grid_slice.dart` → `lib/src/controller/internal/grid_normalizer.dart`
* [x] `lib/src/input/slices/selection/selection_slice.dart` → `lib/src/controller/internal/selection_normalizer.dart`
* [x] `lib/src/input/slices/repaint/repaint_slice.dart` → `lib/src/controller/internal/repaint_flag.dart`
* [x] `lib/src/input/slices/signals/signal_event.dart` → `lib/src/controller/internal/signal_event.dart`
* [x] `lib/src/input/slices/signals/signals_slice.dart` → `lib/src/controller/internal/signals_buffer.dart`
* [x] `lib/src/input/slices/spatial_index/spatial_index_slice.dart` → `lib/src/controller/internal/spatial_index_cache.dart`

### 4.2 Переименовать классы/типы (убрать `Slice` и `V2`)

**Команды**

* [x] `V2SceneCommandsSlice` → `SceneCommands`
* [x] `V2DrawSlice` → `DrawCommands`
* [x] `V2MoveSlice` → `MoveCommands`

**Внутреннее**

* [x] `V2GridSlice` → `GridNormalizer`
* [x] `V2SelectionSlice` → `SelectionNormalizer`
* [x] `V2SelectionNormalizationResult` → `SelectionNormalizationResult`
* [x] `V2SignalsSlice` → `SignalsBuffer`
* [x] `V2BufferedSignal` → `BufferedSignal`
* [x] `V2CommittedSignal` → `CommittedSignal`
* [x] `V2SpatialIndexSlice` → `SpatialIndexCache`
* [x] `V2RepaintSlice` → `RepaintFlag`

### 4.3 Обновить импорты и поля в контроллере

* [x] В `lib/src/controller/scene_controller.dart`: заменить импорты со старых путей на `controller/commands/**` и `controller/internal/**`
* [x] Переименовать поля/геттеры с `...Slice` на смысловые (`signalsBuffer`, `repaintFlag`, `spatialIndexCache`, …)
* [x] Обновить типы потоков сигналов (CommittedSignal без V2)

### 4.4 Удалить слой `input`

* [x] Удалить `lib/src/input/` (после того как не осталось ссылок)

### Проверки этапа

* [x] A + B
* [x] `flutter test test/controller --coverage` (можно временно падать из-за тестов, если они ещё не перенесены; но к концу этапа 7 всё должно стать зелёным)

---

## Этап 5 — Контроллер: убрать `V2` из ключевых классов (core/store/writer)

### 5.1 Переименовать классы (файлы можно оставить, чтобы не трогать лишнее)

* [ ] `SceneControllerV2` → `SceneControllerCore` (в `lib/src/controller/scene_controller.dart`)
* [ ] `V2Store` → `SceneStore` (в `lib/src/controller/store.dart`)
* [ ] В `scene_writer.dart`: `V2*Signal` → `*Signal` (если ещё остались)

### 5.2 Обновить все использования

* [ ] render/view/interactive
* [ ] tests
* [ ] tool/bench

### Проверки этапа

* [ ] A + B
* [ ] `flutter test test/controller --coverage`

---

## Этап 6 — Interactive: убрать `V2`, файл не режем

* [ ] `SceneControllerInteractiveV2` → `SceneControllerInteractive`
* [ ] Заменить ссылки `SceneControllerV2` → `SceneControllerCore`
* [ ] Добавить/обновить `typedef SceneController = SceneControllerInteractive;` (без V2)

### Проверки этапа

* [ ] A + B
* [ ] `flutter test test/interactive --coverage`

---

## Этап 7 — Тесты: перенести и переименовать под новую структуру + убрать `V2` из названий

* [ ] Перенести тесты из `test/input/slices/**` в:

  * [ ] `test/controller/commands/**`
  * [ ] `test/controller/internal/**`
* [ ] Обновить все импорты на новые пути и новые имена типов
* [ ] Удалить `V2` из строк-описаний тестов (например “ScenePainterV2 …”)

### Проверки этапа

* [ ] `flutter test --coverage`
* [ ] `dart run tool/check_coverage.dart`

---

## Этап 8 — Тулы и инварианты: убрать `V2` и подстроить проверки под новую структуру

### 8.1 Переименовать инварианты (убрать `INV-V2-*` и “slice” из ID)

* [ ] В `tool/invariant_registry.dart`: заменить `INV-V2-*` на нейтральные, например `INV-ENG-*`
* [ ] Везде, где есть `// INV:INV-V2-...` — обновить на новые ID
* [ ] То же для `INV-SLICE-*` / `INV-INTERNAL-*`: переименовать под `controller/commands` и `controller/internal`

### 8.2 Обновить `tool/check_import_boundaries.dart`

* [ ] Удалить/заменить правила, привязанные к `lib/src/input/slices/**`
* [ ] Добавить правила для:

  * [ ] `lib/src/controller/commands/**`
  * [ ] `lib/src/controller/internal/**`
* [ ] Сохранить смысл: запрет циклов и “модули не импортируют друг друга” (если это нужно)

### 8.3 Обновить `tool/check_guardrails.dart` и тесты тулов

* [ ] Заменить упоминания старых инвариантов на новые
* [ ] Обновить `test/tool/guardrails_tools_test.dart` (там есть синтетические “cross-slice import” кейсы)

### Проверки этапа

* [ ] `dart run tool/check_import_boundaries.dart`
* [ ] `dart run tool/check_invariant_coverage.dart`
* [ ] `dart run tool/check_guardrails.dart`

---

## Этап 9 — Bench и example

* [ ] В `tool/bench/load_profiles_cases_test.dart` заменить `SceneControllerV2` → `SceneControllerCore`
* [ ] Прогнать smoke-профиль бенчмарка

### Проверки этапа

* [ ] `dart run tool/bench/run_load_profiles.dart --profile=smoke --output=build/bench/load_profiles_smoke.json`

---

## Этап 10 — Документация и финальная “чистка”

* [ ] Обновить `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, `DEVELOPMENT_PLAN.md`:

  * пути `input/slices` → `controller/commands` и `controller/internal`
  * убрать “v2 entrypoint”
  * новые имена типов/классов
* [ ] Обновить комментарий в `lib/iwb_canvas_engine.dart` (если там упоминается v2)

### Финальные проверки

* [ ] Прогнать весь DoD (A–F)
* [ ] Проверка “V2 нет в именах”:

  * [ ] `find lib test tool -name '*V2*' -o -name '*_v2*'` → пусто
  * [ ] `grep -RIn --include='*.dart' -E '(\bV2\b|V2[A-Za-z_]|[A-Za-z_]+V2\b)' lib test tool` → пусто

---
