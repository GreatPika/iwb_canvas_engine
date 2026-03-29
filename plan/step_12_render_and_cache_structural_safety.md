language: russian

# Шаг 12. Закрыть structural safety рендера и кешей через подшаги 12.1-12.4

## Диагностические метрики

Этот блок остаётся диагностическим радаром шага, но для `12.x` он также
обязан быть отражён в критериях приёмки каждого подшага: новые owner-ы и
step-owned методы не должны пробивать пороги из
[analysis_options.yaml](/Users/blackpika/iwb_canvas_engine/analysis_options.yaml).

- Смотреть в первую очередь `cyclomatic-complexity`,
  `maximum-nesting-level` и `source-lines-of-code`.
- Пороговые значения для новых owner-ов и step-owned методов:
  - `cyclomatic-complexity <= 10`
  - `maximum-nesting-level <= 4`
  - `source-lines-of-code <= 40`
- Контрольные файлы:
  - `lib/src/render/scene_painter.dart`
  - `lib/src/render/canvas_scope.dart`
  - `lib/src/render/scene_grid_renderer.dart`
  - `lib/src/render/render_geometry_cache.dart`
  - `lib/src/render/cache/scene_static_layer_cache.dart`
  - `lib/src/render/cache/scene_text_layout_cache.dart`
  - `lib/src/render/cache/scene_path_metrics_cache.dart`
  - `lib/src/render/cache/scene_stroke_path_cache.dart`
  - `lib/src/render/scene_render_caches.dart`
  - `lib/src/core/scene_spatial_index.dart`
  - `lib/src/core/hit_test.dart`
  - `lib/src/core/geometry.dart`
  - `tool/invariant_registry.dart`
- Acceptance gate ставится и на новые owner-ы, и на целевые файлы этого шага.
  Если в контрольном файле уже есть hotspot, он обязан быть явно закреплён за
  одним из подшагов `12.x`, чтобы к концу шага `12` в перечисленных файлах не
  оставалось `HIGH`/`VERY HIGH` по этим трём метрикам.
- Уже подтверждённые hotspot-ы, которые нельзя оставлять «ничьими»:
  - `ScenePainter._drawSelectionForNode(...)`: `cyclomatic-complexity = 25`,
    `source-lines-of-code = 149` -> ownership `12.1`
  - `ScenePainter.shouldRepaint(...)`: `cyclomatic-complexity = 12` ->
    ownership `12.1`
  - `hitTestNode(...)`: `cyclomatic-complexity = 25`,
    `source-lines-of-code = 102` -> ownership `12.3`
  - `_hitTestPathStrokePrecise(...)`: `cyclomatic-complexity = 12` ->
    ownership `12.3`
  - `SceneSpatialIndex.query(...)`: `cyclomatic-complexity = 16`,
    `source-lines-of-code = 59` -> ownership `12.3`
  - `SceneSpatialIndex.applyIncremental(...)`:
    `cyclomatic-complexity = 14` -> ownership `12.3`
  - `segmentsIntersect(...)`: `cyclomatic-complexity = 29`,
    `source-lines-of-code = 63` -> ownership `12.3`
- Полезный сигнал после шага: painter, grid rendering, spatial index,
  hit-test и render caches больше не дублируют structural branching для одних
  и тех же shape/render cases, а cache validity держится на одном scalar /
  revision contract без скрытых mutable escape hatch-ей.

## Цель шага

После шагов `7.4`, `8.x` и `11.x` engine уже должен иметь:

- composite revision contract для invalidation;
- controller-owned commit lifecycle;
- стабильный interactive/runtime boundary.

Следующий системный drift теперь сосредоточен в render/cache контуре:

- `ScenePainter` смешивает frame orchestration, canvas nesting,
  preview-offset resolution и node-family rendering в одном giant surface;
- grid rendering продублирован между painter и static layer cache;
- hit-test, spatial index и render geometry всё ещё держат несколько похожих,
  но не одинаковых node-case веток;
- cache keys и invalidation assumptions размазаны между отдельными cache-ами,
  `SceneRenderCaches` и неявными owner contract-ами;
- часть invariants, на которых уже фактически держится render/runtime
  correctness, ещё не зарегистрирована явно.

Исходный шаг `12` перечислял правильные задачи, но без декомпозиции он
смешивал как минимум четыре разные ownership-области. Без их разведения
реализация почти неизбежно либо добавит новый sync glue между frame-local и
persistent cache state, либо оставит structural hotspot-ы «размазанными» по
`scene_painter.dart`, `hit_test.dart` и `scene_spatial_index.dart`.

## Как разбит этап

### Шаг 12.1

`plan/step_12_1_canvas_scope_and_painter_frame_contract.md`

Владелец решения по:

- `lib/src/render/canvas_scope.dart`;
- frame-local orchestration внутри `ScenePainter`;
- однократному frame-local resolution для `previewDelta` и geometry lookup;
- снятию structural hotspot-ов painter-side selection/render dispatch;
- явной границе между frame-local reuse и persistent render caches.

### Шаг 12.2

`plan/step_12_2_grid_renderer_and_static_cache_unification.md`

Владелец решения по:

- одному owner-у grid line generation;
- shared grid algorithm для painter и static layer cache;
- bounded density degradation и hysteresis без нового cross-frame mutable
  state;
- границе между grid draw plan и picture lifecycle static cache-а.

### Шаг 12.3

`plan/step_12_3_shared_node_geometry_for_render_hit_test_and_spatial_index.md`

Владелец решения по:

- одному core-owned contract-у node geometry для hit-test и spatial index;
- раз-owner-иванию shape-specific branching между `hit_test.dart`,
  `scene_spatial_index.dart`, `geometry.dart` и `render_geometry_cache.dart`;
- closure hotspot-ов `hitTestNode(...)`, `_hitTestPathStrokePrecise(...)`,
  `SceneSpatialIndex.query(...)`, `SceneSpatialIndex.applyIncremental(...)` и
  `segmentsIntersect(...)`;
- parity между coarse candidate bounds, precise hit-test и render bounds.

### Шаг 12.4

`plan/step_12_4_render_cache_keys_revision_contract_and_invariants.md`

Владелец решения по:

- точному составу render cache keys;
- явному invalidation / invalid-transform contract для render caches;
- defensive ownership mutable cache payload-ов;
- роли `SceneRenderCaches` как lifecycle owner-а, а не второго owner-а revision
  policy;
- использованию существующего `INV-ENG-EPOCH-INVALIDATION` для lifecycle
  coverage render caches без добавления новых ids в
  `tool/invariant_registry.dart`.

## Карта переноса деталей из исходного шага 12

1. Создание `lib/src/render/canvas_scope.dart`, перевод `save/restore` на
   scope helpers, устранение повторных geometry-cache запросов в пределах
   кадра и фиксация policy для `previewDelta` переносятся в `12.1`.
2. Единый генератор линий сетки, bounded density hysteresis и выравнивание
   `ScenePainter` / `SceneStaticLayerCache` на одной grid implementation
   переносятся в `12.2`.
3. Structural closure для `lib/src/core/scene_spatial_index.dart`,
   `lib/src/core/hit_test.dart` и `lib/src/core/geometry.dart`, включая
   удаление duplicate switch-like branching по node cases, переносится в
   `12.3`.
4. Пересмотр ключа `SceneTextLayoutCache`, revision policy для
   `ScenePathMetricsCache` / `SceneStrokePathCache` / `SceneRenderCaches`,
   защита от внешней мутации, явная policy для invalid transform и точное
   использование существующего invariant coverage переносятся в `12.4`.
5. `lib/src/render/render_geometry_cache.dart` целиком закрепляется за `12.3`,
   потому что текущий seam файла не позволяет независимо менять
   geometry/parity surface и cache-validity surface без одновременного
   вмешательства в тот же node-family contract.
6. `lib/src/render/cache/scene_static_layer_cache.dart` целиком закрепляется за
   `12.2`, потому что его реальный seam уже сегодня объединяет grid draw plan,
   picture reuse contract, `_StaticLayerKey` и camera shift в одном owner-е.
7. Ни один пункт исходного шага не теряется:
   - `## Диагностические метрики` остаются обязательной частью acceptance gate
     каждого подшага;
   - целевые файлы обязаны уйти ниже порога `10 / 4 / 40`;
   - lifecycle invariant coverage render caches остаётся внутри шага `12`, но
     без новых ids и без переноса tooling/coverage mechanics из шага `13`.

## Уже принятые архитектурные решения

1. `ScenePainter` получает только frame-local reuse. Новый persistent cache,
   синхронизируемый с existing caches, в шаге `12` запрещён.
2. `canvas_scope.dart` остаётся render-local utility-модулем с тремя
   helper-ами:
   - `withSave(...)`
   - `withTranslate(...)`
   - `withTransform(...)`
   Он не становится общим runtime abstraction над `Canvas`.
3. Grid rendering получает одного render-local owner-а:
   `lib/src/render/scene_grid_renderer.dart`.
   `SceneStaticLayerCache` после этого владеет только picture lifecycle и key
   по grid inputs, а не самим grid algorithm.
4. Требование hysteresis на пороге плотности решается без нового cross-frame
   mutable state. Разрешена только deterministic bucketed policy внутри shared
   grid owner-а; hidden state между кадрами и между painter/cache запрещён.
5. Для runtime `SceneNode` один owner отвечает за node-family geometry
   semantics, которые используют hit-test и spatial index. Эти модули не
   должны продолжать параллельно кодировать свои версии line/stroke/path
   branching.
6. `render_geometry_cache.dart` остаётся snapshot-side adapter-ом и не
   становится cross-layer service для core runtime nodes.
7. `SceneRenderCaches` остаётся только lifecycle aggregator-ом. Он не
   вычисляет revision validity сам и не становится вторым источником truth для
   cache key policy.
8. Invalid transform / invalid geometry policy для render caches должна быть
   явной и одинаково трактоваться всеми cache owner-ами:
   unsafe inputs не должны silently poison-ить cache state.
9. Шаг `12` не меняет `tool/invariant_registry.dart` ради `12.4`.
   Render/cache contract этого этапа использует существующий
   `INV-ENG-EPOCH-INVALIDATION`; изменения `tool/check_*` и coverage mechanics
   остаются ownership шага `13`.
10. Cross-layer invariant-ы, чьё enforcement требует ownership над
    interactive lifecycle, writer/result payload или controller semantics, не
    должны затягиваться в `12.4` только потому, что render/cache слой
    косвенно на них полагается.

## Общие правила для всех подшагов

1. Нельзя вводить второй persistent source of truth ради «ускорения» рендера.
   Разрешены только:
   - существующие render caches;
   - frame-local temporary structures, живущие не дольше одного `paint(...)`.
2. Один owner отвечает за grid algorithm. Painter и static cache не могут
   держать две реализации line generation, stride calculation или density
   degradation.
3. Один owner отвечает за runtime node-family geometry semantics. `hit_test`,
   `scene_spatial_index` и extracted helper-ы не могут оставаться competing
   источниками line/stroke/path branching.
4. Один owner отвечает за точный состав cache key. `SceneRenderCaches` не
   подменяет это lifecycle-level invalidation вызовами «на всякий случай».
5. Если в рамках подшага меняется `tool/invariant_registry.dart`, этот подшаг
   обязан прогонять `dart run tool/check_invariant_coverage.dart`.
6. Любой новый owner этого этапа обязан проходить предел `10 / 4 / 40` по
   `cyclomatic-complexity`, `maximum-nesting-level` и
   `source-lines-of-code`.

## Ownership Matrix

- `12.1` владеет только painter frame contract:
  `canvas_scope.dart`, frame-local resolved node data, previewDelta policy,
  painter-side selection/render dispatch decomposition и `shouldRepaint(...)`.
  Он не владеет parity между render bounds и core hit bounds.
- `12.2` владеет только grid draw plan:
  grid visibility predicate, line generation, density bucketing / hysteresis,
  shared adoption в painter и полный `SceneStaticLayerCache`, включая picture
  reuse contract, `_StaticLayerKey` и camera shift.
- `12.3` владеет только runtime node geometry contract:
  shape-specific geometry helpers, candidate bounds parity, precise hit-test
  decomposition, spatial-index adoption и полным
  `RenderGeometryCache`, включая `get()`, `_buildValidityKey()`,
  `invalidateAll()` и invalid-input behavior, потому что это один
  code seam.
- `12.4` владеет только cache validity contract:
  key composition для `SceneTextLayoutCache` / `ScenePathMetricsCache` /
  `SceneStrokePathCache`, invalid-transform handling для этих cache-ов,
  mutable payload ownership, `SceneRenderCaches` lifecycle boundary и
  использованием существующего lifecycle invariant coverage без registry
  additions.
- Ни один подшаг не должен одновременно владеть и painter frame orchestration,
  и persistent cache key policy для одной и той же проблемы.
- Один файл с неразделённым runtime seam не делится между двумя подшагами:
  `render_geometry_cache.dart` полностью принадлежит `12.3`,
  `scene_static_layer_cache.dart` полностью принадлежит `12.2`.

## Критерии готовности umbrella-шага

1. Для шагов `12.1`, `12.2`, `12.3`, `12.4` существуют отдельные step-файлы с
   собственной целью, границей ответственности, критериями приёмки и тестовым
   контуром.
2. В описании подшагов не осталось пересечений по владению:
   - `12.1` отвечает за painter frame contract и `canvas_scope.dart`;
   - `12.2` отвечает за grid rendering owner и полный
     `SceneStaticLayerCache`;
   - `12.3` отвечает за shared runtime node geometry для hit-test/spatial
     index и полный `RenderGeometryCache`;
   - `12.4` отвечает за остальные render caches, `SceneRenderCaches` и
     supporting invariants.
   - ни один acceptance test не принадлежит двум подшагам одновременно;
     `test/render/render_hit_bounds_parity_test.dart` остаётся только у `12.3`.
3. Ни один пункт исходного шага `12` не потерян при переносе, включая блок
   диагностических метрик и требование не пробивать пороги `10 / 4 / 40`.
4. Граница между шагами `11`, `12` и `13` зафиксирована явно:
   - `11` не владеет render/cache structural policy;
   - `12` не меняет guardrail tooling semantics;
   - `13` не забирает себе runtime render/cache ownership решения,
     сформулированные в `12.4`.
5. К концу шага `12` в контрольных файлах не остаётся `HIGH`/`VERY HIGH` по
   `cyclomatic-complexity`, `maximum-nesting-level` и
   `source-lines-of-code`, а каждый текущий hotspot имеет однозначного owner-а
   на время реализации.
