language: russian

# Шаг 12.4. Зафиксировать render cache key / revision contract и supporting invariants

## Цель шага

После `12.1-12.3` структурная форма painter/grid/core geometry уже должна
стать управляемой, но шаг `12` всё ещё не будет закрыт архитектурно, если
render caches продолжат опираться на неявные assumptions:

- какие поля входят в key;
- что считается invalid input для cache build;
- кто владеет lifecycle invalidation;
- какие borrowed render payload-ы могут переиспользоваться без per-hit cloning;
- какие render/cache invariants из этого уже должны быть формально
  зарегистрированы.

Задача подшага: зафиксировать один render cache validity contract,
зафиксировать точный key / reuse policy без лишних полей,
определить borrowed render payload contract, убрать неявные second-source
inputs и явно зарегистрировать только те invariants, от которых действительно
зависят cache invalidation и render-side correctness.

## Что уже подтверждено по текущему состоянию

1. [scene_text_layout_cache.dart](/Users/blackpika/iwb_canvas_engine/lib/src/render/cache/scene_text_layout_cache.dart)
   сейчас кэширует render-ready `TextPainter`, поэтому `color` и другие
   paint-affecting inputs должны оставаться в key, пока payload остаётся
   `TextPainter`. Дополнительно текущий API принимает одновременно
   `TextNodeSnapshot`, `TextStyle` и `maxWidth`, то есть уже сегодня допускает
   два источника истины для одного cached object.
2. `ScenePathMetricsCache` и `SceneStrokePathCache` уже держат mutable payload-ы
   (`Path`, `List<Path>`, `List<Offset>`) и поэтому требуют явного borrowed
   render contract-а: steady-state hits не должны копировать payload-ы, а
   callers не должны мутировать возвращённые render objects.
3. `ScenePathMetricsCache` получает `localPath` снаружи, а не строит его сам,
   поэтому шаг должен явно описывать precondition этого seam-а и не выдавать
   внешний helper input за неформальный второй источник истины.
4. [scene_render_caches.dart](/Users/blackpika/iwb_canvas_engine/lib/src/render/scene_render_caches.dart)
   уже является lifecycle aggregator-ом, но точная граница между
   lifecycle invalidation и per-cache validity policy пока не описана жёстко.
5. В текущем репозитории lifecycle coverage для render caches уже живёт в
   [test/view/scene_view_test.dart](/Users/blackpika/iwb_canvas_engine/test/view/scene_view_test.dart)
   и
   [test/view/scene_view_interactive_test.dart](/Users/blackpika/iwb_canvas_engine/test/view/scene_view_interactive_test.dart),
   а отдельного `test/render/scene_render_caches_test.dart` ещё нет.
6. В текущем реестре invariant-ов уже есть `INV-ENG-EPOCH-INVALIDATION`, а
   отдельные новые ids для `12.4` пока не зафиксированы. Подшаг не должен
   заявлять additions, которых нет в `tool/invariant_registry.dart`.
7. Исходный шаг требовал:
   - новую revision policy для render caches;
   - explicit invalid-transform policy;
   - invariants для cache invalidation и revision contract.
8. Invariant-ы, чьё enforcement требует ownership над interactive lifecycle,
   writer result payload или controller semantics, не должны искусственно
   затягиваться в этот подшаг. `12.4` использует только тот invariant
   coverage, который уже существует и действительно принадлежит render/cache
   lifecycle seam-у.

## Принятое решение

`12.4` является единственным owner-ом render cache validity contract-а и
ограничен пятью обязанностями:

- observable-input source of truth;
- key composition;
- invalid input / seam precondition policy;
- borrowed render payload contract;
- truthful test/invariant coverage.

Почему это решение зафиксировано:

1. Он не превращает `SceneRenderCaches` во второй owner revision policy.
2. Он закрывает исходные требования шага `12`, не перенося tooling semantics в
   шаг `13`.
3. Он позволяет держать cache invalidation чистым: lifecycle boundary отдельно,
   per-cache validity отдельно.
4. Он убирает главную причину повторных review-loop: step перестаёт обещать
   phantom tests, phantom invariants и неформальные mixed-input contracts.

## Зафиксированные решения (без повторного обсуждения в реализации)

1. `SceneTextLayoutCache` остаётся render-ready cache-ом для `TextPainter`.
   Paint-affecting поля остаются в key, пока cache хранит именно
   render-ready объект. Этот подшаг не переводит его в layout-only cache.
2. `SceneTextLayoutCache` должен закончить шаг с одним source of truth для
   observable inputs cached object-а. Принятое решение для этого подшага:
   `getOrBuild(...)` принимает `TextNodeSnapshot` и `TextDirection`,
   а `TextStyle` и normalized `maxWidth` строятся внутри cache из полей node.
   Внешний `TextStyle` в API после подшага отсутствует.
3. `ScenePathMetricsCache`, `SceneStrokePathCache` и другие render caches
   используют stable scalar / revision inputs только там, где они полностью
   определяют reused result; borrowed render payload-ы не копируются на каждом
   steady-state hit.
4. `ScenePathMetricsCache` продолжает получать `localPath` снаружи. Принятое
   решение для этого подшага: cache не строит path самостоятельно и не
   дублирует geometry ownership из `12.3`; caller обязан передавать
   geometry-owner `localPath` для того же `PathNodeSnapshot`.
5. `RenderGeometryCache` не входит в этот scope: файл целиком закреплён за
   `12.3`, потому что его validity key и geometry extraction используют один
   и тот же node-family seam.
6. `SceneStaticLayerCache` тоже не входит в этот scope: exact composition
   `_StaticLayerKey`, picture reuse contract и camera shift закреплены за
   `12.2`, потому что этот модуль уже сегодня является одним grid/static-cache
   seam.
7. Invalid transform / invalid geometry policy для render caches фиксируется
   явно и только на тех seams, которыми реально владеет `12.4`:
   - `SceneTextLayoutCache` normalizes `fontSize`, `lineHeight` и `maxWidth`
     через existing text-layout helpers до построения key и `TextPainter`;
     normalized equivalent inputs должны давать один и тот же cache key;
   - `SceneStrokePathCache` не кэширует degenerate stroke cases:
     `points.isEmpty` и `points.length == 1` возвращаются как uncached safe
     result; только stroke с `points.length >= 2` попадает в cache entry;
   - `ScenePathMetricsCache` не принимает `localPath == null`; отсутствие
     geometry-owner path остаётся outside-cache seam и обрабатывается в owner
     `12.3` / caller contract;
   - `ScenePathMetricsCache` при валидном `localPath` кэширует и non-empty, и
     empty contour result; empty metrics represented as explicit cached empty
     `PathSelectionContours`, а не как special uncached branch;
   - `12.4` не забирает у `12.3` ownership над генерацией `localPath`,
     `localPath == null` и другой geometry-extraction семантикой.
8. `SceneRenderCaches` остаётся lifecycle owner-ом:
   - `clearAll()`
   - `disposeOwned()`
   Он не вычисляет revision validity вместо конкретных caches и не скрывает
   проблемы «принудительным clear ради совместимости».
9. Mutable cache payload-ы после подшага трактуются как borrowed render data:
   caches не копируют `Path` / contour payload-ы на steady-state hit, а
   callers не мутируют возвращённые render objects. Этот contract должен быть
   явным в API/comments/tests, а не только подразумеваться.
10. Этот подшаг не добавляет и не меняет invariant ids в
    `tool/invariant_registry.dart`. Для lifecycle boundary используется уже
    существующий `INV-ENG-EPOCH-INVALIDATION`; cache-specific source-of-truth
    и borrowed-payload contract закрываются кодом, комментариями и тестами
    этого шага, а не новым registry id.
11. Invariant-ы про interactive timestamp ordering, writer result payload
    immutability и другие cross-layer behavioral contracts остаются вне scope
    этого подшага.
12. Этот подшаг не меняет `tool/check_guardrails.dart`,
    `tool/check_invariant_coverage.dart` или другие tooling mechanics. Это
    ownership шага `13`.
13. Marker-ы для существующего `INV-ENG-EPOCH-INVALIDATION` остаются только
    там, где enforcement реально принадлежит lifecycle boundary render caches;
    этот подшаг не раздувает coverage registry-маркерами для contracts, которые
    уже достаточно выражены unit/render tests.

## Граница шага

- In:
  - observable-input source of truth render caches;
  - key composition render caches;
  - invalid-transform / invalid-geometry cache policy на owner seams этого
    подшага;
  - borrowed render payload contract;
  - lifecycle boundary `SceneRenderCaches`;
  - `SceneTextLayoutCache`;
  - `ScenePathMetricsCache`;
  - `SceneStrokePathCache`;
  - truthful usage existing `INV-ENG-EPOCH-INVALIDATION` coverage markers;
  - truthful test contour для lifecycle boundary и per-cache validity contract.
- Out:
  - painter frame orchestration;
  - grid algorithm;
  - `SceneStaticLayerCache`;
  - `RenderGeometryCache`;
  - runtime node geometry decomposition;
  - interactive timestamp ordering invariants;
  - writer/result payload immutability invariants;
  - redesign guardrail tooling шага `13`.

## Точная реализация, которую должен описывать код

1. Каждый render cache имеет один явный key contract с перечисленными
   layout/geometry/revision inputs и один явный source of truth для observable
   inputs reused object-а.
2. `SceneTextLayoutCache` остаётся cache-ом render-ready `TextPainter`;
   paint-affecting inputs остаются в key, потому что payload этого шага не
   меняется на layout-only data.
3. `ScenePathMetricsCache` и `SceneStrokePathCache` не полагаются на неполный
   scalar/hash contract там, где reused result зависит от полного local input;
   borrowed render payload-ы не копируются на every-hit hot path.
4. `ScenePathMetricsCache` принимает `localPath` снаружи; precondition этого
   seam-а описан явно: caller передаёт geometry-owner path для того же
   `PathNodeSnapshot`.
5. Invalid-input behavior описан у реального owner seam-а с точной политикой
   для text/stroke/path caches. `12.4` не
   присваивает себе geometry-owner semantics из `12.3`.
6. `SceneRenderCaches` остаётся lifecycle wrapper-ом вокруг caches и не
   прячет неявную revision policy.
7. Existing invariant coverage и test contour соответствуют реальному состоянию
   репозитория; step не ссылается на несуществующие ids, marker-ы и test
   files.
8. Подшаг не вводит новый interactive timestamp contract, не меняет
   controller/writer semantics и не забирает чужие behavioral invariants ради
   «полноты» шага.

## Последовательность реализации (только действия)

[x] Зафиксировать точный observable key contract `SceneTextLayoutCache`,
    включая paint-affecting inputs cached `TextPainter`.
[x] Убрать из `SceneTextLayoutCache` неявный dual-input contract: сделать
    `TextNodeSnapshot` + `TextDirection` единственным source of truth и
    перенести построение `TextStyle` / normalized `maxWidth` внутрь cache.
[x] Зафиксировать key / entry-reuse contract для
    `ScenePathMetricsCache`, `SceneStrokePathCache` и связанных render caches.
[x] Явно описать и реализовать invalid-transform / invalid-geometry policy
    только на owner seams этого подшага и не забирать `RenderGeometryCache`
    / geometry extraction из `12.3`.
[x] Зафиксировать precondition для externally supplied `localPath` в
    `ScenePathMetricsCache`: caller передаёт geometry-owner path для того же
    `PathNodeSnapshot`; cache не rebuild-ит path и не валидирует geometry заново.
[x] Зафиксировать borrowed render payload contract без копирования mutable
    paths/contours на каждом cache hit.
[x] Зафиксировать `SceneRenderCaches` как lifecycle owner-а, а не owner-а
    revision policy.
[x] Добавить direct unit coverage для lifecycle owner-а в
    `test/render/scene_render_caches_test.dart`.
[x] Использовать только существующий `INV-ENG-EPOCH-INVALIDATION` для lifecycle
    coverage и не менять `tool/invariant_registry.dart`.

## Критерии приёмки

[x] `SceneTextLayoutCache` key покрывает все inputs, которые влияют на
    observable behavior cached `TextPainter`, а не только layout metrics.
[x] Paint-affecting inputs `SceneTextLayoutCache` остаются в key, пока cache
    хранит render-ready `TextPainter`.
[x] `SceneTextLayoutCache` имеет один явный source of truth для observable
    inputs cached object-а: `TextNodeSnapshot` + `TextDirection`; внешний
    `TextStyle` не участвует в cache API.
[x] `ScenePathMetricsCache` использует stable scalar inputs только там, где они
    полностью определяют cached result; `SceneStrokePathCache` не подменяет
    exact stroke equality hash-ом или неполным scalar contract-ом.
[x] `ScenePathMetricsCache` держит не более одной cache entry на
    `(nodeId, instanceRevision)` и заменяет stale path contract вместо роста
    LRU на один logical path instance.
[x] `ScenePathMetricsCache` принимает `localPath` снаружи, и precondition
    этого seam-а описан явно: caller передаёт geometry-owner path для того же
    `PathNodeSnapshot`; cache не становится вторым owner-ом geometry semantics.
[x] Invalid transform / invalid geometry policy для render caches описана явно
    на owner seams этого подшага:
    `SceneTextLayoutCache` normalizes layout scalars,
    `SceneStrokePathCache` не кэширует degenerate 0/1-point cases,
    `ScenePathMetricsCache` кэширует explicit empty contours для valid
    `localPath` и не принимает `localPath == null`;
    `12.4` не приписывает себе geometry behavior из `12.3`.
[x] Render caches не дублируют `Path` / contour payload-ы на steady-state hit;
    callers трактуют их как borrowed render data и не мутируют.
[x] `SceneRenderCaches` остаётся только lifecycle aggregator-ом и не
    превращается во второй owner revision policy.
[x] Step-doc не ссылается на несуществующие invariant ids, markers и test
    files; все claims про coverage соответствуют фактическому состоянию repo.
[x] `12.4` не затягивает в свой scope invariants, требующие ownership над
    interactive timestamp ordering или writer/result payload immutability.
[x] `tool/invariant_registry.dart` в этом подшаге не меняется; lifecycle
    invariant coverage опирается только на существующий
    `INV-ENG-EPOCH-INVALIDATION`.
[x] Direct lifecycle coverage для `SceneRenderCaches` закреплено за
    `test/render/scene_render_caches_test.dart`.
[x] Повторная диагностика
    `dcm calculate-metrics lib/src/render/cache/scene_text_layout_cache.dart lib/src/render/cache/scene_path_metrics_cache.dart lib/src/render/cache/scene_stroke_path_cache.dart lib/src/render/scene_render_caches.dart tool/invariant_registry.dart --report-all`
    приложена к результату шага; новые или step-owned methods не содержат
    `HIGH`/`VERY HIGH` по `cyclomatic-complexity`,
    `maximum-nesting-level` и `source-lines-of-code`, а целевой предел остаётся
    `10 / 4 / 40`.

## Тестовый контур шага

[x] `test/render/scene_text_layout_cache_test.dart`
    с покрытием:
    - paint-affecting inputs не дают ложный cache hit
    - key меняется только по observable inputs cached `TextPainter`
    - тесты не маскируют mixed input contract `node + external TextStyle`
[x] `test/render/scene_render_caches_test.dart`
    с покрытием:
    - lifecycle `clearAll()` / `disposeOwned()` не подменяет key policy
    - owned/external caches dispose-ятся по точному contract-у
    - lifecycle boundary не маскирует проблемы per-cache validity contract
[x] `test/render/scene_path_metrics_cache_test.dart`
    и `test/render/scene_stroke_path_cache_test.dart`
    с покрытием:
    - exact invalidation / reuse contract для path и stroke caches
    - replacement semantics без stale duplicate entries на один instance
    - borrowed payload reuse без per-hit cloning
    - `SceneStrokePathCache` не кэширует degenerate 0/1-point cases
    - `ScenePathMetricsCache` принимает explicit empty contour result для valid
      `localPath`
    - explicit seam contract для externally supplied `localPath`
[x] Existing render/tool tests получают marker-ы только там, где enforcement
    реально принадлежит render/cache contract-у

## Диагностика шага

- `dcm calculate-metrics lib/src/render/cache/scene_text_layout_cache.dart lib/src/render/cache/scene_path_metrics_cache.dart lib/src/render/cache/scene_stroke_path_cache.dart lib/src/render/scene_render_caches.dart --report-all`
  после шага не содержит `HIGH`/`VERY HIGH` для новых или step-owned methods.
- Отдельно проверить, что existing lifecycle invariant coverage не
  пересекается по ownership со tooling redesign шага `13`.
- Отдельно проверить, что existing lifecycle invariant coverage не требует
  правок в `interactive/**`, `controller/**` или других чужих owner-зонах
  ради формального закрытия `12.4`.
- Не добавлять и не менять в этом подшаге invariant ids; использовать
  существующий `INV-ENG-EPOCH-INVALIDATION` и реальные test files этого шага.
- Не забирать в этот шаг `render_geometry_cache.dart` и
  `scene_static_layer_cache.dart`: оба файла уже закреплены за реальными
  seams `12.3` и `12.2`.
