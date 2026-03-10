language: russian

# Шаг 12. Перевести рендер и кеши на структурно безопасную форму

## Диагностические метрики

Этот блок нужен как диагностический радар после изменений шага, а не как отдельный критерий готовности. В этом шаге важно не просто "разбить painter", а убедиться, что structural complexity уходит из render/cache/hit-test контура целиком.

- Смотреть в первую очередь `cyclomatic-complexity`, `source-lines-of-code` и `maximum-nesting-level`.
- Контрольные файлы:
  - `lib/src/render/scene_painter.dart`
  - `lib/src/render/render_geometry_cache.dart`
  - `lib/src/render/cache/scene_static_layer_cache.dart`
  - `lib/src/core/scene_spatial_index.dart`
  - `lib/src/core/hit_test.dart`
  - `lib/src/core/geometry.dart`
- Полезный сигнал после шага: painter, spatial index и hit-test больше не дублируют structural branching и не требуют длинных switch-like маршрутов для тех же render cases.

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
