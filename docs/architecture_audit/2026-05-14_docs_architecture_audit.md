# Docs Architecture Audit Fix List

Дата: 2026-05-14  
Область: `/Users/blackpika/iwb_canvas_engine/docs`

## Нужно исправить

### A05. Уточнить phase-order edges для ранних фаз

Приоритет: до P6/P7.

Проблема: несколько ранних фаз читают поздние контракты как prerequisites:

- `loadDocument` P6 -> `InteractionEngine` P10;
- `cache_policy` P7 -> `SpatialKernel` P8;
- `functional_ledger` P1 -> public API P1.5/P2.

Исправление:

- для P6 выделить минимальный ранний interrupt/preview-cleanup boundary вместо зависимости от всего interaction contract;
- для P7 отделить `ImageResolveCache` core policy от spatial/frame cache policy или явно allowlist'ить edge как navigation-only;
- для P1 разделить legacy capability inventory и API mapping after scope gate, если phase closure остается неясным.

### A06. Зафиксировать lifecycle listenables после dispose

Приоритет: до runtime/surface lifecycle implementation.

Проблема: streams после dispose описаны, а `documentRevisionListenable` и `previewRevisionListenable` нет.

Исправление:

- указать, читаются ли `value` после dispose;
- указать, возможны ли notifications после dispose;
- указать, кто снимает listeners;
- покрыть dispose lifecycle test.

### A07. Уточнить repaint wording для `setPalette` и `markResourceDirty`

Приоритет: до соответствующих edit/resource phases.

Проблема:

- `setPalette`: `none unless UI observes doc` смешивает engine repaint и external UI observation;
- `markResourceDirty`: wording assumes attached `CanvasSurface`, хотя runtime может быть headless.

Исправление:

- `setPalette`: написать `no canvas repaint; documentRevisionListenable notification after atomic install; external UI repaint is app responsibility`;
- `markResourceDirty`: написать `publishes main repaint intent; attached surface observes it if present`.

### A08. Исправить README/index drift

Приоритет: P3 docs cleanup.

Проблема:

- `docs/README.md` обещает phase index, но `docs/indexes/by_phase.md` отсутствует;
- `docs/README.md` перечисляет `plan/` как часть docs layout, хотя `plan/` лежит в root.

Исправление:

- добавить `docs/indexes/by_phase.md` или убрать обещание phase index;
- заменить `plan/` wording на `root plan/`.
