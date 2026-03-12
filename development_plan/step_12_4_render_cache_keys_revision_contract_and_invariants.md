language: russian

# Шаг 12.4. Зафиксировать render cache key / revision contract и supporting invariants

## Цель шага

После `12.1-12.3` структурная форма painter/grid/core geometry уже должна
стать управляемой, но шаг `12` всё ещё не будет закрыт архитектурно, если
render caches продолжат опираться на неявные assumptions:

- какие поля входят в key;
- что считается invalid input для cache build;
- кто владеет lifecycle invalidation;
- какие mutable payload-ы можно или нельзя отдавать наружу;
- какие render/cache invariants из этого уже должны быть формально
  зарегистрированы.

Задача подшага: зафиксировать один render cache validity contract,
перевести caches на scalar / revision key policy без лишних полей,
защитить mutable payload-ы и явно зарегистрировать invariants, от которых
зависят cache invalidation и render-side correctness.

## Что уже подтверждено по текущему состоянию

1. [scene_text_layout_cache.dart](/Users/blackpika/iwb_canvas_engine/lib/src/render/cache/scene_text_layout_cache.dart)
   сейчас включает `color` в key, хотя сам layout от цвета не зависит.
2. `ScenePathMetricsCache` и `SceneStrokePathCache` уже держат mutable payload-ы
   (`Path`, `List<Path>`, `List<Offset>`) и поэтому требуют явного owner
   contract-а на случай внешней мутации.
3. [scene_render_caches.dart](/Users/blackpika/iwb_canvas_engine/lib/src/render/scene_render_caches.dart)
   уже является lifecycle aggregator-ом, но точная граница между
   lifecycle invalidation и per-cache validity policy пока не описана жёстко.
4. Исходный шаг требовал:
   - новую revision policy для render caches;
   - explicit invalid-transform policy;
   - invariants для cache invalidation и revision contract.
5. Invariant-ы, чьё enforcement требует ownership над interactive lifecycle,
   writer result payload или controller semantics, не должны искусственно
   затягиваться в этот подшаг. `12.4` регистрирует только те invariants,
   которые действительно принадлежат render/cache seam-у.

## Рекомендуемое решение

Рекомендуемый вариант: сделать `12.4` единственным owner-ом render cache
validity contract-а и ограничить его четырьмя обязанностями:

- key composition;
- invalid input policy;
- mutable payload ownership;
- invariant registry additions.

Почему это лучший вариант:

1. Он не превращает `SceneRenderCaches` во второй owner revision policy.
2. Он закрывает исходные требования шага `12`, не перенося tooling semantics в
   шаг `13`.
3. Он позволяет держать cache invalidation чистым: lifecycle boundary отдельно,
   per-cache validity отдельно.

## Зафиксированные решения (без повторного обсуждения в реализации)

1. `SceneTextLayoutCache` key включает только layout-affecting inputs.
   `color` удаляется из key, если не доказано обратное layout behavior-ом.
2. `ScenePathMetricsCache`, `SceneStrokePathCache` и другие render caches
   используют только stable scalar / revision inputs и не опираются на
   collection identity.
3. `RenderGeometryCache` не входит в этот scope: файл целиком закреплён за
   `12.3`, потому что его validity key и geometry extraction используют один
   и тот же node-family seam.
4. `SceneStaticLayerCache` тоже не входит в этот scope: exact composition
   `_StaticLayerKey`, picture reuse contract и camera shift закреплены за
   `12.2`, потому что этот модуль уже сегодня является одним grid/static-cache
   seam.
5. Invalid transform / invalid geometry policy для render caches фиксируется
   явно:
   - cache не должен silently сохранять poisoned entry;
   - invalid input либо не кэшируется, либо кэшируется как explicit safe empty
     result по одному contract-у;
   - разные caches не могут трактовать invalid transform по-разному.
6. `SceneRenderCaches` остаётся lifecycle owner-ом:
   - `clearAll()`
   - `disposeOwned()`
   Он не вычисляет revision validity вместо конкретных caches и не скрывает
   проблемы «принудительным clear ради совместимости».
7. Mutable cache payload-ы после подшага не должны давать внешний escape hatch,
   который ломает correctness внутреннего cache state.
8. `tool/invariant_registry.dart` в этом подшаге получает ровно те additions,
   которые нужны render/cache correctness:
   - invariant invalidation `PathNode` cache
   - invariant render/cache revision contract
   Invariant-ы про interactive timestamp ordering, writer result payload
   immutability и другие cross-layer behavioral contracts остаются вне scope
   этого подшага.
9. Этот подшаг не меняет `tool/check_guardrails.dart`,
   `tool/check_invariant_coverage.dart` или другие tooling mechanics. Это
   ownership шага `13`.
10. Если для invariant additions требуются существующие enforcement markers в
   `test/**` или `tool/**`, они добавляются здесь ровно в объёме, нужном для
   `dart run tool/check_invariant_coverage.dart`, но без расширения scope до
   guardrail redesign.

## Граница шага

- In:
  - key composition render caches;
  - invalid-transform / invalid-geometry cache policy;
  - defensive ownership mutable cache payload-ов;
  - lifecycle boundary `SceneRenderCaches`;
  - `SceneTextLayoutCache`;
  - `ScenePathMetricsCache`;
  - `SceneStrokePathCache`;
  - additions в `tool/invariant_registry.dart` и нужные render/cache markers
    покрытия.
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
   layout/geometry/revision inputs.
2. `SceneTextLayoutCache` не инвалидируется по цвету, если layout unchanged.
3. `ScenePathMetricsCache` и `SceneStrokePathCache` не полагаются на mutable
   collection identity и не дают внешней мутации сломать внутренний cache
   contract.
4. `SceneRenderCaches` остаётся lifecycle wrapper-ом вокруг caches и не
   прячет неявную revision policy.
5. Invariant additions в `tool/invariant_registry.dart` соответствуют
   реальным render/cache assumptions шага `12`, а не абстрактным будущим
   намерениям.
6. Подшаг не вводит новый interactive timestamp contract, не меняет
   controller/writer semantics и не забирает чужие behavioral invariants ради
   «полноты» шага.

## Последовательность реализации (только действия)

[ ] Зафиксировать точный key contract `SceneTextLayoutCache` и убрать из него
    `color`, если layout unchanged.
[ ] Зафиксировать scalar / revision key contract для
    `ScenePathMetricsCache`, `SceneStrokePathCache` и связанных render caches.
[ ] Явно описать и реализовать общую invalid-transform / invalid-geometry
    policy для `SceneTextLayoutCache`, `ScenePathMetricsCache` и
    `SceneStrokePathCache`, не забирая `RenderGeometryCache` и
    `SceneStaticLayerCache` из их owner-ов.
[ ] Закрыть mutable payload ownership без внешних escape hatch-ей.
[ ] Зафиксировать `SceneRenderCaches` как lifecycle owner-а, а не owner-а
    revision policy.
[ ] Добавить invariants и enforcement markers в `tool/invariant_registry.dart`
    / `test/**` / `tool/**` ровно в объёме render/cache contract-а.
[ ] Прогнать `dart run tool/check_invariant_coverage.dart`.

## Критерии приёмки

[ ] `SceneTextLayoutCache` key содержит только layout-affecting inputs.
[ ] Из `SceneTextLayoutCache` key убран `color`, если он не влияет на layout.
[ ] `ScenePathMetricsCache` и `SceneStrokePathCache` используют stable scalar /
    revision contract и не опираются на collection identity.
[ ] Invalid transform / invalid geometry policy для render caches описана явно
    и не расходится между `SceneTextLayoutCache`,
    `ScenePathMetricsCache` и `SceneStrokePathCache`.
[ ] Mutable cache payload-ы не дают внешней мутации сломать внутренний cache
    contract.
[ ] `SceneRenderCaches` остаётся только lifecycle aggregator-ом и не
    превращается во второй owner revision policy.
[ ] В `tool/invariant_registry.dart` добавлены invariant invalidation
    `PathNode` cache и invariant render/cache revision contract.
[ ] `12.4` не затягивает в свой scope invariants, требующие ownership над
    interactive timestamp ordering или writer/result payload immutability.
[ ] `dart run tool/check_invariant_coverage.dart` проходит после additions в
    invariant registry.
[ ] Повторная диагностика
    `dcm calculate-metrics lib/src/render/cache/scene_text_layout_cache.dart lib/src/render/cache/scene_path_metrics_cache.dart lib/src/render/cache/scene_stroke_path_cache.dart lib/src/render/scene_render_caches.dart tool/invariant_registry.dart --report-all`
    приложена к результату шага; новые или step-owned methods не содержат
    `HIGH`/`VERY HIGH` по `cyclomatic-complexity`,
    `maximum-nesting-level` и `source-lines-of-code`, а целевой предел остаётся
    `10 / 4 / 40`.

## Тестовый контур шага

[ ] `test/render/scene_text_layout_cache_test.dart`
    с покрытием:
    - color не влияет на cache hit при unchanged layout
    - key меняется только по layout-affecting inputs
[ ] `test/render/scene_render_caches_test.dart`
    с покрытием:
    - lifecycle `clearAll()` / `disposeOwned()` не подменяет key policy
    - lifecycle boundary не маскирует проблемы per-cache validity contract
[ ] `test/render/scene_path_metrics_cache_test.dart`
    и `test/render/scene_stroke_path_cache_test.dart`
    с покрытием:
    - scalar / revision invalidation contract
    - отсутствие внешнего mutable escape hatch-а
[ ] Existing render/tool tests получают marker-ы только там, где enforcement
    реально принадлежит render/cache contract-у

## Диагностика шага

- `dcm calculate-metrics lib/src/render/cache/scene_text_layout_cache.dart lib/src/render/cache/scene_path_metrics_cache.dart lib/src/render/cache/scene_stroke_path_cache.dart lib/src/render/scene_render_caches.dart tool/invariant_registry.dart --report-all`
  после шага не содержит `HIGH`/`VERY HIGH` для новых или step-owned methods.
- Отдельно проверить, что invariant additions не пересекаются по ownership со
  tooling redesign шага `13`.
- Отдельно проверить, что invariant additions не требуют правок в
  `interactive/**`, `controller/**` или других чужих owner-зонах ради
  формального закрытия `12.4`.
- Не забирать в этот шаг `render_geometry_cache.dart` и
  `scene_static_layer_cache.dart`: оба файла уже закреплены за реальными
  seams `12.3` и `12.2`
