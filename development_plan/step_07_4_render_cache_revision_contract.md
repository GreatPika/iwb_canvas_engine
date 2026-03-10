language: russian

# Шаг 7.4. Зафиксировать render-cache invalidation на composite revision contract

## Цель шага

После `7.3` revision policy уже должна быть формализована, но её всё ещё
можно сломать, если render/cache слой останется на неявном контракте
"где-то есть `instanceRevision`, где-то есть `epoch`, а stale-hit не
случается просто потому что повезло".

Задача подшага: пройти по render/cache owner-ам, определить для каждого явный
invalidation contract и зафиксировать, где достаточно owner-side `clearAll()`
на epoch boundary, а где ключ обязан включать composite revision identity.

## Что уже подтверждено по текущему состоянию

1. [render_geometry_cache.dart](/Users/blackpika/iwb_canvas_engine/lib/src/render/render_geometry_cache.dart),
   [scene_stroke_path_cache.dart](/Users/blackpika/iwb_canvas_engine/lib/src/render/cache/scene_stroke_path_cache.dart)
   и
   [scene_path_metrics_cache.dart](/Users/blackpika/iwb_canvas_engine/lib/src/render/cache/scene_path_metrics_cache.dart)
   уже используют `nodeId + instanceRevision` как основу cache key.
2. [scene_view.dart](/Users/blackpika/iwb_canvas_engine/lib/src/view/scene_view.dart)
   и
   [scene_view_interactive.dart](/Users/blackpika/iwb_canvas_engine/lib/src/view/scene_view_interactive.dart)
   уже очищают render caches при `epoch` change.
3. [scene_render_caches.dart](/Users/blackpika/iwb_canvas_engine/lib/src/render/scene_render_caches.dart)
   уже задаёт owner lifecycle через `clearAll()`.
4. Текущий шаг 07 в исходной форме говорил "при необходимости добавить epoch в
   ключи", но не определял, где это действительно нужно, а где приведёт к
   двойной invalidation-механике.

## Зафиксированные решения (без повторного обсуждения в реализации)

1. Для каждого cache-owner выбирается один объяснимый invalidation contract:
   либо owner-side clear on epoch boundary, либо composite revision в key.
2. Нельзя оставлять расплывчатое правило "и clear, и epoch везде в key" без
   локальной причины.
3. Подшаг не создаёт новый sync glue между render caches и controller store;
   он только формализует существующий owner lifecycle поверх новой revision
   policy.
4. Для шага `7.4` принято точное решение: `epoch` не добавляется ни в один
   render cache key. `epoch` остаётся только owner-level boundary для
   `SceneRenderCaches.clearAll()`.

## Граница шага

- In:
  - audit render/cache key design;
  - явная фиксация epoch-clear contract;
  - добавление epoch в key только там, где одного owner-clear недостаточно.
- Out:
  - изменение public id/revision surface;
  - общий refactor view lifecycle вне cache invalidation semantics.

## Точная реализация, которую должен описывать код

1. `SceneViewCore` и `SceneViewInteractive` обязаны вызывать
   `SceneRenderCaches.clearAll()`:
   - при любом изменении `controllerEpoch`;
   - при замене controller instance;
   - при dispose owned caches.
2. `SceneStaticLayerCache`:
   - не содержит `epoch` в key;
   - key зависит только от `size`, `gridEnabled`, `gridCellSize`, `gridColor`,
     `gridStrokeWidth`;
   - correctness across document boundary обеспечивается только через
     owner-side `clearAll()`.
3. `SceneTextLayoutCache`:
   - не содержит `epoch`, `nodeId` или `instanceRevision` в key;
   - key зависит только от layout inputs;
   - non-layout visual fields не должны входить в key;
   - correctness across document boundary обеспечивается через `clearAll()`.
4. `RenderGeometryCache`:
   - не содержит `epoch` в key;
   - entry owner key это `(nodeId, instanceRevision)`;
   - дополнительный validity discriminator зависит только от geometry-owning
     scalar inputs.
5. `SceneStrokePathCache`:
   - не содержит `epoch` в key;
   - entry owner key это `(nodeId, instanceRevision)`;
   - `pointsRevision` остаётся secondary discriminator внутри entry semantics.
6. `ScenePathMetricsCache`:
   - не содержит `epoch` в key;
   - entry owner key это `(nodeId, instanceRevision)`;
   - `svgPathData` и `fillRule` остаются secondary discriminator внутри entry.
7. Revision rollover из `7.3` не требует новых cache-key полей. Он работает
   через уже существующий `controllerEpoch` bump, который принудительно
   очищает все view-owned render caches.

Почему именно так:

1. Добавлять `epoch` в каждый key здесь избыточно: view уже владеет cache
   lifecycle и умеет принудительно очищать все кэши на boundary change.
2. Если одновременно держать `clearAll()` и `epoch` в каждом key, система
   получает двойную invalidation-механику без выигрыша в correctness, но с
   большей сложностью reasoning и тестов.
3. Для `RenderGeometryCache`, `SceneStrokePathCache` и
   `ScenePathMetricsCache` `instanceRevision` уже описывает внутридокументную
   mutation identity. Этого достаточно между epoch-boundary.
4. `SceneStaticLayerCache` и `SceneTextLayoutCache` не должны знать о
   document lifecycle через key, потому что их owner и так один:
   `SceneRenderCaches`.
5. Ревизионный rollover из `7.3` становится бесплатным для cache-дизайна:
   он piggybacks на уже существующий epoch-clear contract и не заставляет
   менять формулу ключей по всему render слою.

## Последовательность реализации (только действия)

[ ] Зафиксировать для каждого render/cache owner-а его invalidation contract.
[ ] Перепроверить `RenderGeometryCache`, `SceneStrokePathCache` и
    `ScenePathMetricsCache` на stale-hit сценарии после adopt/replaceScene и
    revision overflow semantics.
[ ] Оставить owner-side `clearAll()` единственным epoch invalidation
    механизмом там, где это уже достаточно и проверяемо тестами.
[ ] Не добавлять `epoch` ни в один render cache key; вместо этого закрепить
    per-cache owner contract и tests на `clearAll()` boundary.
[ ] Обновить render/view tests так, чтобы они проверяли финальный contract, а
    не случайную комбинацию текущих key fields.

## Критерии приёмки

[ ] Для каждого render cache есть явный и единый invalidation contract.
[ ] Не остаётся двусмысленного пункта "при необходимости добавить epoch в
    ключи": решение зафиксировано как "не добавлять никуда".
[ ] Ни один render cache key не содержит `epoch`; epoch используется только
    как owner-level `clearAll()` boundary.
[ ] replaceScene / epoch bump / revision overflow не приводят к stale-hit в
    render caches.
[ ] Render tests проверяют именно composite revision contract и owner lifecycle.

## Тестовый контур шага

[ ] `test/view/scene_view_test.dart`
[ ] `test/view/scene_view_interactive_test.dart`
[ ] `test/render/render_geometry_cache_test.dart`
[ ] Новые targeted tests для `scene_stroke_path_cache.dart`
[ ] Новые targeted tests для `scene_path_metrics_cache.dart`
