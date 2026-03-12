language: russian

# Шаг 12.1. Ввести `canvas_scope.dart` и frame-local contract для `ScenePainter`

## Цель шага

Сначала нужно замкнуть painter-side frame contract. Пока `ScenePainter`
одновременно сам:

- держит `save/restore` nesting;
- повторно запрашивает geometry в пределах одного кадра;
- по-разному резолвит `previewDelta` для culling, paint и selection;
- несёт giant branching в `_drawSelectionForNode(...)`;

любой следующий подшаг будет строиться на плавающем основании. Задача
подшага: зафиксировать `ScenePainter` как owner-а только frame-local
orchestration одного `paint(...)`, убрать внутрикадровое дублирование resolved
node data и вынести canvas nesting в маленький render-local utility без
создания нового persistent cache.

## Что уже подтверждено по текущему состоянию

1. [scene_painter.dart](/Users/blackpika/iwb_canvas_engine/lib/src/render/scene_painter.dart)
   сейчас содержит ручные `canvas.save()` / `canvas.restore()` в нескольких
   независимых ветках, включая preview translate, transform apply и halo draw.
2. `_drawSelectionForNode(...)` там же уже является явным hotspot-ом:
   `cyclomatic-complexity = 25`, `source-lines-of-code = 149`.
3. `shouldRepaint(...)` там же уже имеет `cyclomatic-complexity = 12`.
4. `_nodePreviewOffset(...)` и `_geometryCache.get(node)` вызываются в одном
   кадре больше одного раза для одного и того же node-а: отдельно на culling,
   отдельно на draw и отдельно на selection path.
5. В текущем коде `previewDelta` участвует и в culling, и в actual draw, но
   сам contract этого участия не сформулирован как один owner-level decision.
6. Persistent render caches уже существуют:
   `RenderGeometryCache`, `SceneTextLayoutCache`, `SceneStrokePathCache`,
   `ScenePathMetricsCache`. Подшаг не может добавлять ещё один cache с тем же
   содержимым и потом синхронизировать его с ними.

## Рекомендуемое решение

Рекомендуемый вариант: ввести
`lib/src/render/canvas_scope.dart` как минимальный utility для scoped canvas
operations и перевести `ScenePainter` на один private frame-local resolved node
context, который живёт только в пределах одного `paint(...)`.

Почему это лучший вариант:

1. Он убирает structural branching из painter без нового runtime state между
   кадрами.
2. Он не добавляет второй persistent источник truth поверх existing caches.
3. Он делает `previewDelta` и geometry reuse явными frame-local decisions, а
   не случайным следствием порядка вызовов.

## Зафиксированные решения (без повторного обсуждения в реализации)

1. `lib/src/render/canvas_scope.dart` вводится в render layer и экспортирует
   ровно три helper-а:
   - `withSave(...)`
   - `withTranslate(...)`
   - `withTransform(...)`
2. Эти helper-ы остаются purely lexical wrappers вокруг canvas scope и не
   становятся stateful abstraction-ом, который хранит `Canvas`, собирает
   команды или кэширует transform state.
3. `ScenePainter` получает один frame-local resolved node context на каждый
   node, который может содержать только:
   - normalized `previewDelta`;
   - уже полученный geometry entry / world bounds;
   - derived flags, нужные для текущего кадра.
4. Этот frame-local context живёт только внутри одного вызова `paint(...)` и
   не переживает кадр.
5. `previewDelta` нормализуется один раз на node за кадр и затем одинаково
   используется для culling, actual draw и selection draw этого же node-а.
6. Подшаг убирает только повторные frame-local запросы к already-existing
   painter dependencies внутри одного кадра, где drift реально живёт в
   `ScenePainter`:
   - `previewDelta`;
   - `RenderGeometryCache.get(...)` / derived `worldBounds`.
   Persistent cache key policy, mutable payload ownership и cache invalidation
   ownership остаются ownership `12.4`.
7. `_drawSelectionForNode(...)` и `shouldRepaint(...)` входят в прямой scope
   подшага и обязаны перестать быть metric hotspot-ами.
8. Подшаг не владеет grid algorithm. Даже если `ScenePainter` будет тронут в
   grid call sites, semantics line generation, density bucketing и hysteresis
   остаются ownership `12.2`.

## Граница шага

- In:
  - `lib/src/render/canvas_scope.dart`;
  - painter-side frame-local resolved node data;
  - единый contract `previewDelta` внутри `ScenePainter`;
  - устранение повторных frame-local geometry lookup в одном `paint(...)`;
  - closure hotspot-ов `_drawSelectionForNode(...)` и `shouldRepaint(...)`.
- Out:
  - grid algorithm;
  - render cache key policy;
  - invalid-transform semantics persistent caches;
  - core hit-test / spatial-index geometry contract;
  - render/core parity acceptance surfaces, завязанные на
    `RenderGeometryCache` vs core geometry contract.

## Точная реализация, которую должен описывать код

1. `ScenePainter.paint(...)` строит frame-local данные ровно для текущего
   прохода и не складывает их в persistent field/cache.
2. Любой scoped translate/transform/save внутри painter идёт через
   `canvas_scope.dart`, а не через новые ad hoc пары `save/restore`.
3. Один и тот же node в пределах одного кадра не инициирует конкурирующие
   запросы `previewDelta` и geometry entry для culling/draw/selection.
4. `_drawSelectionForNode(...)` разрезается по node-family responsibility так,
   чтобы painter-side selection contract оставался явным и читаемым.
5. `shouldRepaint(...)` после подшага выражает только факторы repaint
   invalidation и не продолжает быть giant boolean surface.
6. Подшаг не вводит новый render cache owner и не меняет revision contract
   existing caches.

## Последовательность реализации (только действия)

[x] Создать `lib/src/render/canvas_scope.dart` с тремя scoped helper-ами.
[x] Перевести painter-side `save/restore` на `canvas_scope.dart`.
[x] Ввести один frame-local resolved node context на время `paint(...)`.
[x] Зафиксировать один owner-level contract для `previewDelta` в culling,
    draw и selection.
[x] Убрать повторные geometry lookup в пределах одного кадра.
[x] Разрезать `_drawSelectionForNode(...)` и упростить `shouldRepaint(...)` до
    прохождения metric gate.
[x] Не переносить в этот подшаг grid semantics и cache key policy.

## Критерии приёмки

[x] `canvas_scope.dart` создан и остаётся render-local utility без hidden
    state.
[x] Painter-side scoped `save/restore` больше не размазаны ad hoc по нескольким
    веткам.
[x] `previewDelta` для одного node-а резолвится один раз на кадр и одинаково
    используется в culling/draw/selection.
[x] В пределах одного `paint(...)` один node не инициирует конкурирующие
    запросы `RenderGeometryCache.get(...)` ради тех же derived данных.
[x] `ScenePainter._drawSelectionForNode(...)` больше не является
    `HIGH`/`VERY HIGH` по `cyclomatic-complexity`,
    `maximum-nesting-level` и `source-lines-of-code`.
[x] `ScenePainter.shouldRepaint(...)` больше не является `HIGH`/`VERY HIGH` по
    `cyclomatic-complexity`, `maximum-nesting-level` и
    `source-lines-of-code`.
[x] Подшаг не вводит новый persistent render cache и не дублирует ownership
    существующих caches.
[x] Повторная диагностика
    `dcm calculate-metrics lib/src/render/scene_painter.dart lib/src/render/canvas_scope.dart --report-all`
    приложена к результату шага; новые или step-owned methods не содержат
    `HIGH`/`VERY HIGH` по `cyclomatic-complexity`,
    `maximum-nesting-level` и `source-lines-of-code`, а целевой предел остаётся
    `10 / 4 / 40`.

## Тестовый контур шага

[x] Новый targeted test:
    `test/render/scene_painter_frame_contract_test.dart`
[x] `test/render/scene_painter_test.dart`
    с покрытием:
    - save/restore integrity после перевода на `canvas_scope.dart`
    - одинаковый `previewDelta` contract для culling/draw/selection
    - отсутствие повторных `RenderGeometryCache.get(...)` / derived-bounds
      drift внутри одного кадра на одном node-е

`test/render/render_hit_bounds_parity_test.dart` не входит в ownership
подшага. Это acceptance surface шага `12.3`, потому что проверяет parity
между `RenderGeometryCache` и core geometry contract, а не painter frame
contract.

## Диагностика шага

- `dcm calculate-metrics lib/src/render/scene_painter.dart lib/src/render/canvas_scope.dart --report-all`
  после шага не содержит `HIGH`/`VERY HIGH` для новых или step-owned methods.
- Особое внимание приложить к:
  - `ScenePainter._drawSelectionForNode(...)`
  - `ScenePainter.shouldRepaint(...)`
  - новым helper-ам, появившимся вместо giant branching painter-а
- parity между render bounds и core hit bounds этим подшагом не принимается и
  не диагностируется; это ownership `12.3`
