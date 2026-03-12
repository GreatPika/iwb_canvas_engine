language: russian

# Шаг 12.3. Свести runtime node geometry к одному owner-у для render parity, hit-test и spatial index

## Цель шага

После `12.1` и `12.2` painter/grid side уже должны иметь ясные owner-ы, но
сам render/runtime контур всё ещё останется структурно опасным, если
shape-specific geometry продолжит жить одновременно в нескольких местах:

- `hit_test.dart`;
- `scene_spatial_index.dart`;
- `geometry.dart`;
- `render_geometry_cache.dart`.

Задача подшага: ввести один core-owned contract для runtime node geometry,
перевести hit-test и spatial index на него, а snapshot-side render geometry
оставить отдельным adapter-ом, который переиспользует те же leaf primitives,
но не становится cross-layer owner-ом для runtime nodes.

## Что уже подтверждено по текущему состоянию

1. [hit_test.dart](/Users/blackpika/iwb_canvas_engine/lib/src/core/hit_test.dart)
   сейчас сам кодирует большую часть node-family branching; `hitTestNode(...)`
   уже имеет `cyclomatic-complexity = 25`, `source-lines-of-code = 102`.
2. `_hitTestPathStrokePrecise(...)` там же уже имеет
   `cyclomatic-complexity = 12`.
3. [scene_spatial_index.dart](/Users/blackpika/iwb_canvas_engine/lib/src/core/scene_spatial_index.dart)
   сам принимает часть geometry-routing решений; `query(...)` уже имеет
   `cyclomatic-complexity = 16`, `source-lines-of-code = 59`, а
   `applyIncremental(...)` имеет `cyclomatic-complexity = 14`.
4. [geometry.dart](/Users/blackpika/iwb_canvas_engine/lib/src/core/geometry.dart)
   уже содержит giant numeric helper `segmentsIntersect(...)`:
   `cyclomatic-complexity = 29`, `source-lines-of-code = 63`.
5. [render_geometry_cache.dart](/Users/blackpika/iwb_canvas_engine/lib/src/render/render_geometry_cache.dart)
   остаётся snapshot-side owner-ом geometry entry для painter, но его node-case
   switch не должен становиться третьим owner-ом runtime geometry semantics.
6. Полный merge render snapshots и runtime nodes в один cross-layer owner
   запрещён layer DAG-ом и приведёт к лишней связности между `core` и `render`.

## Рекомендуемое решение

Рекомендуемый вариант: выделить
`lib/src/core/node_geometry.dart` как runtime owner node-family geometry
contract-а и перевести `hit_test.dart` / `scene_spatial_index.dart` на него,
оставив `render_geometry_cache.dart` snapshot-side adapter-ом.

Почему это лучший вариант:

1. Он убирает duplicate branching между core runtime modules, не ломая layer
   DAG.
2. Он оставляет render snapshot geometry в render layer, а runtime node
   semantics в core layer.
3. Он делает parity между candidate bounds, precise hit-test и render bounds
   проверяемой через один explicit contract.

## Зафиксированные решения (без повторного обсуждения в реализации)

1. Runtime node-family geometry ownership фиксируется за
   `lib/src/core/node_geometry.dart`.
2. Этот owner отвечает только за runtime `SceneNode` semantics:
   - coarse candidate bounds;
   - shape-specific geometry facts для hit-test;
   - shared line/stroke/path decomposition, нужную spatial index и hit-test.
3. `hit_test.dart` после подшага не должен оставаться giant node-case router-ом
   и не должен локально переопределять те же geometry rules.
4. `scene_spatial_index.dart` после подшага не должен принимать shape-specific
   geometry decisions сверх index lifecycle:
   - rebuild;
   - incremental update;
   - query routing;
   - invalidation fallback.
5. `render_geometry_cache.dart` остаётся snapshot-side adapter-ом и может
   переиспользовать extracted geometry primitives, но не становится owner-ом
   runtime `SceneNode` semantics. При этом текущий code seam файла
   закрепляется за этим подшагом целиком:
   - `get()`;
   - `_buildValidityKey()`;
   - `_buildEntry(...)` и family-specific builders;
   - `_buildLocalPath()`;
   - invalid input behavior;
   - local/world bounds semantics.
   Причина: в текущем коде validity key и geometry builders опираются на один
   и тот же node-family contract, поэтому делить файл между `12.3` и `12.4`
   без overlap-а нельзя.
6. `geometry.dart` после подшага владеет только leaf math primitives и больше
   не держит giant helper-ы без явного ownership decomposition.
7. Parity между render bounds, candidate bounds и precise hit-test должна быть
   доказана тестами, а не предполагаться по сходству кода.

## Граница шага

- In:
  - `lib/src/core/node_geometry.dart`;
  - adoption в `hit_test.dart` и `scene_spatial_index.dart`;
  - decomposition `geometry.dart` и `render_geometry_cache.dart` в части shared
    leaf geometry primitives и validity surface;
  - closure hotspot-ов `hitTestNode(...)`, `_hitTestPathStrokePrecise(...)`,
  `SceneSpatialIndex.query(...)`, `SceneSpatialIndex.applyIncremental(...)`
  и `segmentsIntersect(...)`.
- Out:
  - painter frame orchestration;
  - grid algorithm;
  - cache policy остальных render caches и invariant registry additions.

## Точная реализация, которую должен описывать код

1. Один core owner задаёт runtime geometry contract для line/stroke/path/rect
   node families.
2. `hit_test.dart` использует этот owner вместо giant inline branching.
3. `scene_spatial_index.dart` использует этот owner для candidate bounds /
   geometry facts и остаётся owner-ом только index lifecycle.
4. `render_geometry_cache.dart` при необходимости переиспользует extracted
   leaf helpers, но не импортирует runtime owner так, чтобы смешивать snapshot
   и runtime contracts. При этом этот подшаг меняет `RenderGeometryCache`
   целиком как один snapshot-side seam, включая key/invalid-input behavior,
   потому что они завязаны на тот же node-family contract.
5. `segmentsIntersect(...)` и другие math helper-ы разрезаются так, чтобы
   numeric robustness не потерялась, но giant control surface исчез.
6. После подшага candidate bounds, precise hit-test и render bounds остаются
   согласованными для line/stroke/path cases.

## Последовательность реализации (только действия)

[ ] Создать `lib/src/core/node_geometry.dart` как runtime owner-а
    node-family geometry contract-а.
[ ] Перевести `hit_test.dart` на shared runtime geometry owner.
[ ] Перевести `scene_spatial_index.dart` на shared runtime geometry owner.
[ ] Разрезать `segmentsIntersect(...)` и связанные giant geometry helper-ы в
    `geometry.dart`.
[ ] Уточнить границу `render_geometry_cache.dart` как snapshot-side adapter-а и
    закрепить файл целиком за этим подшагом.
[ ] Закрыть parity тестами между render bounds, candidate bounds и precise
    hit-test.
[ ] Не переносить в этот подшаг grid semantics, policy остальных render
    caches и invariant registry additions.

## Критерии приёмки

[ ] `lib/src/core/node_geometry.dart` является одним owner-ом runtime
    node-family geometry contract-а.
[ ] `hit_test.dart` больше не является giant source of truth для тех же
    geometry rules.
[ ] `scene_spatial_index.dart` больше не кодирует shape-specific geometry
    semantics отдельно от shared runtime owner-а.
[ ] `render_geometry_cache.dart` остаётся snapshot-side adapter-ом и не
    нарушает layer DAG cross-layer ownership-ом.
[ ] `render_geometry_cache.dart` закреплён за этим подшагом как один code seam:
    geometry extraction, world/local bounds semantics, key composition и
    invalid-input behavior меняются совместно и не делятся с `12.4`.
[ ] `hitTestNode(...)` больше не является `HIGH`/`VERY HIGH` по
    `cyclomatic-complexity`, `maximum-nesting-level` и
    `source-lines-of-code`.
[ ] `_hitTestPathStrokePrecise(...)` больше не является `HIGH`/`VERY HIGH` по
    `cyclomatic-complexity`, `maximum-nesting-level` и
    `source-lines-of-code`.
[ ] `SceneSpatialIndex.query(...)` больше не является `HIGH`/`VERY HIGH` по
    `cyclomatic-complexity`, `maximum-nesting-level` и
    `source-lines-of-code`.
[ ] `SceneSpatialIndex.applyIncremental(...)` больше не является
    `HIGH`/`VERY HIGH` по `cyclomatic-complexity`,
    `maximum-nesting-level` и `source-lines-of-code`.
[ ] `segmentsIntersect(...)` больше не является `HIGH`/`VERY HIGH` по
    `cyclomatic-complexity`, `maximum-nesting-level` и
    `source-lines-of-code`.
[ ] Повторная диагностика
    `dcm calculate-metrics lib/src/core/node_geometry.dart lib/src/core/hit_test.dart lib/src/core/scene_spatial_index.dart lib/src/core/geometry.dart lib/src/render/render_geometry_cache.dart --report-all`
    приложена к результату шага; новые или step-owned methods не содержат
    `HIGH`/`VERY HIGH` по `cyclomatic-complexity`,
    `maximum-nesting-level` и `source-lines-of-code`, а целевой предел остаётся
    `10 / 4 / 40`.

## Тестовый контур шага

[ ] Новый targeted test:
    `test/core/node_geometry_test.dart`
[ ] `test/core/scene_spatial_index_test.dart`
    с покрытием:
    - candidate bounds используют shared runtime geometry contract
    - incremental update не ломает parity с rebuild path
[ ] `test/render/render_hit_bounds_parity_test.dart`
    с расширением на line/stroke/path parity после выделения owner-а
[ ] `test/render/render_geometry_cache_test.dart`
    с покрытием:
    - key composition и invalid-input behavior не расходятся с geometry/parity
      contract внутри одного owner-а
[ ] `test/core/hit_test_test.dart`
    с покрытием:
    - precise path/stroke hit-test использует shared runtime geometry contract
    - decomposition giant helpers не меняет hit semantics

`test/render/render_hit_bounds_parity_test.dart` является эксклюзивной
acceptance surface этого подшага и не дублируется в `12.1`.

## Диагностика шага

- `dcm calculate-metrics lib/src/core/node_geometry.dart lib/src/core/hit_test.dart lib/src/core/scene_spatial_index.dart lib/src/core/geometry.dart lib/src/render/render_geometry_cache.dart --report-all`
  после шага не содержит `HIGH`/`VERY HIGH` для новых или step-owned methods.
- Особое внимание приложить к:
  - `hitTestNode(...)`
  - `_hitTestPathStrokePrecise(...)`
  - `SceneSpatialIndex.query(...)`
  - `SceneSpatialIndex.applyIncremental(...)`
  - `segmentsIntersect(...)`
- В `render_geometry_cache.dart` смотреть только на geometry extraction/parity
  и на validity helpers вместе: файл принимается как один code seam, без
  деления ownership с `12.4`
