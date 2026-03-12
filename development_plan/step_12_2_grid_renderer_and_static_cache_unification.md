language: russian

# Шаг 12.2. Свести grid rendering и static cache к одному owner-у

## Цель шага

После `12.1` painter уже должен иметь ясный frame-local contract, но сам
render pipeline всё ещё останется архитектурно хрупким, если grid rendering
продолжит жить одновременно в двух копиях:

- в `ScenePainter`;
- в `SceneStaticLayerCache`.

Задача подшага: ввести одного owner-а grid draw plan, перевести painter и
static cache на одну и ту же реализацию и добавить bounded density hysteresis
на пороге grid density без нового cross-frame mutable state.

## Что уже подтверждено по текущему состоянию

1. [scene_painter.dart](/Users/blackpika/iwb_canvas_engine/lib/src/render/scene_painter.dart)
   и
   [scene_static_layer_cache.dart](/Users/blackpika/iwb_canvas_engine/lib/src/render/cache/scene_static_layer_cache.dart)
   сейчас содержат две отдельные реализации:
   - `_drawGrid(...)`
   - `_isGridDrawable(...)`
   - `_gridLineCount(...)`
   - `_gridStrideForLineCount(...)`
   - `_gridStart(...)`
2. Эти две реализации сейчас должны оставаться синхронными вручную, что уже
   само по себе является dual-source drift.
3. Static cache владеет picture lifecycle и key-ами по grid inputs, но из-за
   дублирования кода фактически становится ещё и вторым owner-ом grid
   semantics.
4. Исходный шаг требовал «добавить гистерезис на пороге плотности», но в
   текущем коде есть только жёсткий threshold-based stride selection без явно
   описанной anti-flap policy.
5. Добавлять hidden cross-frame state ради hysteresis нельзя: это создаст
   новый sync problem между painter, static cache и view lifecycle.

## Рекомендуемое решение

Рекомендуемый вариант: выделить
`lib/src/render/scene_grid_renderer.dart` как render-local owner grid draw
plan и перевести painter/static cache на shared grid API.

Почему это лучший вариант:

1. Он устраняет дублирование алгоритма, а не пытается держать две версии
   синхронными.
2. Он оставляет `SceneStaticLayerCache` owner-ом picture lifecycle, а не grid
   semantics.
3. Он позволяет реализовать hysteresis как deterministic bucket policy,
   зависящую только от текущих inputs, без нового persistent mutable state.

## Зафиксированные решения (без повторного обсуждения в реализации)

1. Grid draw semantics получают одного owner-а:
   `lib/src/render/scene_grid_renderer.dart`.
2. Этот owner отвечает только за:
   - drawable predicate;
   - line plan / stride plan;
   - camera shift;
   - bounded density hysteresis policy;
   - actual grid line emission.
3. `ScenePainter` и `SceneStaticLayerCache` после подшага не содержат своих
   собственных `_drawGrid(...)` / `_isGridDrawable(...)` / `_grid*` helper-ов.
4. Hysteresis решается как deterministic bucket policy внутри shared grid
   owner-а. Новый hidden mutable state между кадрами или между cache/painter
   запрещён.
5. `SceneStaticLayerCache` остаётся owner-ом только:
   - recorded picture lifecycle;
   - `clear()` / `dispose()`.
6. `ScenePainter` после подшага лишь делегирует draw grid в shared owner и не
   становится вторым owner-ом density policy.
7. Текущий code seam `SceneStaticLayerCache` закрепляется за этим подшагом
   целиком:
   - `draw()`;
   - `_recordGridPicture()`;
   - `_StaticLayerKey`;
   - picture reuse contract;
   - camera shift.
   Причина: в текущем коде grid algorithm и picture reuse policy находятся в
   одном owner-е и не разделяются без искусственного split-а.
8. Подшаг не владеет painter frame-local reuse из `12.1` и не меняет policy
   других render caches вне `SceneStaticLayerCache`.

## Граница шага

- In:
  - `lib/src/render/scene_grid_renderer.dart`;
  - shared grid algorithm;
  - bounded density hysteresis;
  - adoption в painter;
  - полный `lib/src/render/cache/scene_static_layer_cache.dart`.
- Out:
  - painter frame-local node orchestration;
  - key policy остальных render caches;
  - hit-test / spatial-index geometry semantics.

## Точная реализация, которую должен описывать код

1. Shared grid owner предоставляет один canonical API для draw/record grid,
   пригодный и для прямого painter draw, и для picture recording static cache-а.
2. Painter и static cache используют один и тот же drawable predicate и один и
   тот же line generation contract.
3. Bounded density policy не допускает больше `kMaxGridLinesPerAxis` реальных
   линий на ось и не переключается на соседний режим из-за незначительного
   near-threshold jitter.
4. `SceneStaticLayerCache` не повторяет grid math локально, а только
   переиспользует shared owner и владеет picture lifecycle вокруг него.
5. Подшаг не вводит новый lifecycle state между кадрами и не делает hysteresis
   зависимой от «предыдущего кадра».
6. Exact key composition `SceneStaticLayerCache` фиксируется в этом же подшаге,
   потому что reuse contract picture cache-а и grid draw plan сейчас живут в
   одном модуле и меняются совместно.

## Последовательность реализации (только действия)

[x] Создать `lib/src/render/scene_grid_renderer.dart`.
[x] Перенести в него drawable predicate, line plan и camera shift policy.
[x] Добавить deterministic bounded hysteresis на пороге плотности.
[x] Перевести `ScenePainter` на shared grid owner.
[x] Перевести `SceneStaticLayerCache` на shared grid owner без дублирования
    алгоритма.
[x] Зафиксировать picture reuse contract и `_StaticLayerKey`
    `SceneStaticLayerCache` в том же owner-границе.
[x] Удалить локальные grid helper-ы из painter/static cache.
[x] Не переносить в этот подшаг painter frame orchestration и policy других
    render caches.

## Критерии приёмки

[x] `ScenePainter` и `SceneStaticLayerCache` используют одну и ту же grid
    implementation.
[x] В кодовой базе не остаётся двух competing owner-ов для grid line
    generation, stride calculation и drawable predicate.
[x] Grid draw остаётся bounded policy и не рисует больше допустимого числа
    линий на ось.
[x] Bounded density hysteresis описана явно и не требует hidden mutable state
    между кадрами.
[x] `SceneStaticLayerCache` остаётся owner-ом только picture lifecycle и не
    кодирует grid semantics повторно.
[x] Exact static-cache key inputs и `_StaticLayerKey` закреплены здесь же,
    потому что picture reuse contract не отделён реальным seam-ом от grid
    owner-а.
[x] Повторная диагностика
    `dcm calculate-metrics lib/src/render/scene_grid_renderer.dart lib/src/render/scene_painter.dart lib/src/render/cache/scene_static_layer_cache.dart --report-all`
    приложена к результату шага; новые или step-owned methods не содержат
    `HIGH`/`VERY HIGH` по `cyclomatic-complexity`,
    `maximum-nesting-level` и `source-lines-of-code`, а целевой предел остаётся
    `10 / 4 / 40`.

## Тестовый контур шага

[x] Новый targeted test:
    `test/render/scene_grid_renderer_test.dart`
[x] `test/render/scene_static_layer_cache_test.dart`
    с покрытием:
    - static cache использует тот же grid algorithm, что и painter
    - picture lifecycle и `_StaticLayerKey` соответствуют shared grid owner-у
[x] `test/render/scene_painter_test.dart`
    с покрытием:
    - painter делегирует в shared grid owner
    - bounded density hysteresis не даёт near-threshold flap на соседних
      inputs

## Диагностика шага

- `dcm calculate-metrics lib/src/render/scene_grid_renderer.dart lib/src/render/scene_painter.dart lib/src/render/cache/scene_static_layer_cache.dart --report-all`
  после шага не содержит `HIGH`/`VERY HIGH` для новых или step-owned methods.
- Отдельно проверить, что после выноса grid owner-а в `scene_painter.dart` и
  `scene_static_layer_cache.dart` не осталось grid-specific duplicate helper-ов.
- Проверять `SceneStaticLayerCache` как единый seam: grid algorithm, picture
  reuse, `_StaticLayerKey` и camera shift должны остаться под одним owner-ом.
