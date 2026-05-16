## 1. `CanvasOptional` заменяем на `CanvasFieldUpdate`

**Проблема:** `CanvasOptional.value(null)` создаёт двусмысленность. Для patch/update-семантики это плохое место.

**Решение:** заменить тип на явный update-контейнер.

```dart
sealed class CanvasFieldUpdate<T> {
  const CanvasFieldUpdate();
}

final class CanvasFieldAbsent<T> extends CanvasFieldUpdate<T> {
  const CanvasFieldAbsent();
}

final class CanvasFieldSet<T> extends CanvasFieldUpdate<T> {
  CanvasFieldSet(this.value) {
    if (value == null) {
      throw ArgumentError('Use CanvasFieldClear for nullable fields.');
    }
  }

  final T value;
}

final class CanvasFieldClear<T> extends CanvasFieldUpdate<T> {
  const CanvasFieldClear();
}
```

Правила:

```text
CanvasFieldAbsent -> поле не меняется.
CanvasFieldSet(value) -> поле получает новое non-null значение.
CanvasFieldClear -> nullable-поле получает null.
CanvasFieldSet(null) -> всегда ошибка.
CanvasFieldClear для non-nullable поля -> ошибка в update compiler.
```

Пример:

```dart
final class CanvasImageElementUpdate {
  const CanvasImageElementUpdate({
    this.resourceId = const CanvasFieldAbsent(),
    this.naturalSize = const CanvasFieldAbsent(),
  });

  final CanvasFieldUpdate<CanvasResourceId> resourceId;
  final CanvasFieldUpdate<Size?> naturalSize;
}
```

**Итог:** tri-state patch сохраняется, но двусмысленность исчезает.

---

## 2. DTO с коллекциями и metadata делаем non-const

**Проблема:** `const`-конструктор не может надёжно сделать defensive copy для `Iterable`, `List`, `Map`, `Set`. Значит, `const` конфликтует с требованием immutable DTO.

**Решение:** все DTO с коллекциями, metadata, списками точек, maps делаем non-const. `const` оставляем только для DTO со scalar-полями без runtime validation.

```dart
final class CanvasPalette {
  CanvasPalette({
    required Iterable<Color> penColors,
    required Iterable<Color> backgroundColors,
    required Iterable<double> gridSizes,
  })  : penColors = List.unmodifiable(penColors),
        backgroundColors = List.unmodifiable(backgroundColors),
        gridSizes = List.unmodifiable(gridSizes) {
    CanvasValidation.validatePalette(this);
  }

  final List<Color> penColors;
  final List<Color> backgroundColors;
  final List<double> gridSizes;
}
```

Для metadata вводим единый тип:

```dart
final class CanvasMetadata {
  CanvasMetadata(Map<String, Object?> input)
      : value = CanvasJson.freezeObject(input) {
    CanvasValidation.validateMetadata(value);
  }

  final Map<String, Object?> value;
}
```

Все DTO принимают не `Map<String, Object?>`, а `CanvasMetadata`.

**Итог:** immutable DTO становится реальным свойством, а не декларацией.

---

## 3. Selection выносим из `DocumentStoreKernel`

**Проблема:** selection — это не содержимое документа. Это view/runtime state. Если держать selection в store, она смешивается с committed document state.

**Решение:** вводим отдельный владелец.

```text
SelectionKernel
  - selectedIds
  - selectionRevision
  - normalizeSelection
  - clearSelection
  - selectAllContent
  - toggleSelection
  - selectedOrder
```

`DocumentStoreKernel` хранит только committed document:

```text
DocumentStoreKernel
  - elements
  - layers
  - resources
  - background
  - document metadata
  - document revisions
```

`SelectionKernel` читает факты через query-port:

```text
DocumentFactsPort
  - exists(id)
  - isContentElement(id)
  - isVisible(id)
  - isSelectable(id)
  - isLocked(id)
  - documentOrder(ids)
```

При `loadDocument` порядок такой:

```text
RuntimeRoot.prepareReplacement
InteractionEngine.interruptAfterSuccessfulPrepare
SelectionKernel.clearForReplacement
DocumentStoreKernel.installReplacement
FrameEngine.invalidateForReplacement
```

**Итог:** document state и view state разделены.

---

## 4. Selection scope фиксируем как content-only

**Проблема:** background elements не pointer-selectable, но публичный `setSelection` может случайно выбрать background element программно.

**Решение:** в v1 selection работает только с content elements.

Правило:

```text
SelectionKernel никогда не хранит background element ids.
```

Нормализация selection:

```text
remove non-existing ids
remove background ids
remove non-selectable ids
deduplicate
sort by document order
```

`selectAll` выбирает только:

```text
content elements
visible
selectable
not locked
```

`deleteSelection` удаляет только content selection.

Background elements удаляются только низкоуровневым edit API:

```dart
edit.removeElement(backgroundElementId);
```

**Итог:** pointer selection и programmatic selection больше не расходятся.

---

## 5. Public revision/listener model заменяем на единый snapshot

**Проблема:** public API показывает не все изменения runtime. Например, selection может измениться без `documentRevision`, но приложению всё равно нужен сигнал.

**Решение:** вводим единый публичный snapshot ревизий.

```dart
final class CanvasRuntimeRevisions {
  const CanvasRuntimeRevisions({
    required this.document,
    required this.selection,
    required this.preview,
    required this.camera,
    required this.resourceVisual,
    required this.tools,
    required this.epoch,
  });

  final int document;
  final int selection;
  final int preview;
  final int camera;
  final int resourceVisual;
  final int tools;
  final int epoch;
}
```

В public runtime:

```dart
abstract interface class CanvasRuntime {
  ValueListenable<CanvasRuntimeRevisions> get revisions;
  CanvasRuntimeSummary get summary;
}
```

Summary:

```dart
final class CanvasRuntimeSummary {
  const CanvasRuntimeSummary({
    required this.elementCount,
    required this.layerCount,
    required this.resourceCount,
    required this.selectedCount,
    required this.documentRevision,
    required this.selectionRevision,
    required this.epoch,
  });

  final int elementCount;
  final int layerCount;
  final int resourceCount;
  final int selectedCount;
  final int documentRevision;
  final int selectionRevision;
  final int epoch;
}
```

Старые отдельные listenables убираем из public API.

**Итог:** приложение получает один согласованный сигнал обо всех runtime-изменениях.

---

## 6. Camera разделяем на view camera и persisted document camera

**Проблема:** pan камеры не должен быть document mutation. Камера текущего вида — это view state. Камера в документе — это persisted default.

**Решение:** фиксируем две разные сущности.

```text
Runtime view camera:
  - текущая камера surface/runtime
  - меняется через CanvasCameraPort
  - меняет cameraRevision
  - не меняет documentRevision
  - не инвалидирует document projection

Persisted document camera:
  - default camera в CanvasDocument
  - сохраняется в schema
  - меняется только через CanvasEdit
  - меняет documentRevision
```

Public API:

```dart
abstract interface class CanvasCameraPort {
  Offset get offset;

  void setOffset(Offset offset);
  void panBy(Offset delta);

  void persistCurrentOffset();
}
```

Поведение:

```text
setOffset/panBy -> меняет только runtime view camera.
persistCurrentOffset -> пишет текущую runtime camera в document default camera через edit transaction.
loadDocument -> runtime view camera инициализируется из document default camera.
readDocument -> возвращает persisted document camera.
```

**Итог:** обычный pan больше не выглядит как изменение документа.

---

## 7. `PaintPlanCache` отвязываем от `selectionRevision`

**Проблема:** selection не меняет ordinary committed elements. Значит, изменение selection не должно сбрасывать ordinary paint plan.

**Решение:** разделяем ordinary paint и selection rendering.

```text
OrdinaryPaintPlanCache key:
  structuralRevision
  boundsRevision
  elementVisualRevision
  viewportBucket
  devicePixelRatio
```

Selection-декорации отдельно:

```text
SelectionDecorationPlan key:
  selectionRevision
  structuralRevision
  selectionStyleRevision
  devicePixelRatio
```

Selected move supplement:

```text
SelectedMoveSupplement:
  computed per frame
  uses selected ids + selectedMoveDelta
  never stored in OrdinaryPaintPlanCache
  painted in main-scene phase
```

`RenderElementRecord` для ordinary cache не содержит selection flags.

**Итог:** выделение не ломает кэш обычной сцены.

---

## 8. `frameMetaRevision` сразу разделяем

**Проблема:** общий `frameMetaRevision` смешивает camera, background, grid и surface styles. Это даёт лишние invalidation.

**Решение:** вводим отдельные ревизии.

```text
cameraRevision
backgroundRevision
gridRevision
surfaceStyleRevision
```

Static background cache key:

```text
StaticBackgroundCacheKey:
  backgroundRevision
  gridRevision
  cameraBucket
  devicePixelRatio
  gridStrokeWidth
```

Captured main frame:

```dart
final class CapturedMainFrame {
  const CapturedMainFrame({
    required this.cameraOffset,
    required this.viewportRect,
    required this.devicePixelRatio,
    required this.gridStyle,
    required this.selectionStyle,
    required this.cameraRevision,
    required this.backgroundRevision,
    required this.gridRevision,
    required this.surfaceStyleRevision,
  });

  final Offset cameraOffset;
  final Rect viewportRect;
  final double devicePixelRatio;
  final CanvasGridStyle gridStyle;
  final CanvasSelectionStyle selectionStyle;
  final int cameraRevision;
  final int backgroundRevision;
  final int gridRevision;
  final int surfaceStyleRevision;
}
```

**Итог:** camera pan не сбрасывает background/grid кэши шире нужного.

---

## 9. Resource resolver cache переносим в surface resource session

**Проблема:** resolver живёт на `CanvasSurface`, а image cache сейчас относится к runtime. Это разные lifecycle.

**Решение:** resolved image cache принадлежит surface session, не runtime.

```text
Runtime ResourceStore:
  - resource descriptors
  - resourceRevision
  - resourceVisualRevision
  - dirty resource ids

SurfaceResourceSession:
  - resourceResolver
  - resolverGeneration
  - ImageResolveCache
  - per-frame resolver budget
  - missing-result suppression for current frame
```

На attach:

```text
CanvasSurface creates SurfaceResourceSession.
resolverGeneration increments.
ImageResolveCache starts empty.
```

На detach/dispose:

```text
SurfaceResourceSession is disposed.
ImageResolveCache is dropped.
ui.Image ownership remains application-owned.
```

Cache key:

```text
ImageResolveCacheKey:
  resolverGeneration
  resourceId
  resourceRevision
  resourceVisualRevision
```

Frame rule:

```text
Painter never calls resolver.
FrameEngine asks SurfaceResourceSession for resolved image.
SurfaceResourceSession enforces resolver budget.
```

**Итог:** stale image от старого resolver не переживает surface swap.

---

## 10. `CanvasPreviewState` делаем sealed-union

**Проблема:** один класс со всеми nullable-полями допускает невозможные состояния.

**Решение:** заменить на sealed variants.

```dart
sealed class CanvasPreviewState {
  const CanvasPreviewState();

  CanvasPreviewKind get kind;
}

final class CanvasNoPreview extends CanvasPreviewState {
  const CanvasNoPreview();

  @override
  CanvasPreviewKind get kind => CanvasPreviewKind.none;
}

final class CanvasMarqueePreview extends CanvasPreviewState {
  const CanvasMarqueePreview({
    required this.rect,
  });

  final Rect rect;

  @override
  CanvasPreviewKind get kind => CanvasPreviewKind.marquee;
}

final class CanvasSelectedMovePreview extends CanvasPreviewState {
  const CanvasSelectedMovePreview({
    required this.activePointerId,
    required this.sessionId,
    required this.delta,
    required this.selectedIds,
  });

  final int activePointerId;
  final int sessionId;
  final Offset delta;
  final List<CanvasElementId> selectedIds;

  @override
  CanvasPreviewKind get kind => CanvasPreviewKind.selectedMove;
}

final class CanvasStrokePreview extends CanvasPreviewState {
  CanvasStrokePreview({
    required this.tool,
    required Iterable<Offset> points,
    required this.color,
    required this.thickness,
    required this.opacity,
  }) : points = List.unmodifiable(points);

  final CanvasDrawTool tool;
  final List<Offset> points;
  final Color color;
  final double thickness;
  final double opacity;

  @override
  CanvasPreviewKind get kind => CanvasPreviewKind.stroke;
}

final class CanvasPendingLinePreview extends CanvasPreviewState {
  const CanvasPendingLinePreview({
    required this.start,
    required this.timestampMs,
    required this.color,
    required this.thickness,
  });

  final Offset start;
  final int timestampMs;
  final Color color;
  final double thickness;

  @override
  CanvasPreviewKind get kind => CanvasPreviewKind.pendingLine;
}

final class CanvasLinePreview extends CanvasPreviewState {
  const CanvasLinePreview({
    required this.start,
    required this.end,
    required this.color,
    required this.thickness,
  });

  final Offset start;
  final Offset end;
  final Color color;
  final double thickness;

  @override
  CanvasPreviewKind get kind => CanvasPreviewKind.line;
}

final class CanvasEraserPreview extends CanvasPreviewState {
  CanvasEraserPreview({
    required Iterable<Offset> corridor,
    required this.thickness,
  }) : corridor = List.unmodifiable(corridor);

  final List<Offset> corridor;
  final double thickness;

  @override
  CanvasPreviewKind get kind => CanvasPreviewKind.eraser;
}
```

**Итог:** invalid preview state становится невозможным на уровне типа.

---

## 11. Text edit request снабжаем stale guard

**Проблема:** app-owned text editing может завершиться после delete/load/update элемента. Старый request не должен молча применить изменение к новому состоянию.

**Решение:** text edit request получает идентификатор и ревизионные факты.

```dart
extension type CanvasTextEditRequestId(String value) {}

final class CanvasTextEditRequested {
  const CanvasTextEditRequested({
    required this.requestId,
    required this.elementId,
    required this.controllerEpoch,
    required this.documentRevision,
    required this.elementRevision,
    required this.timestampMs,
    required this.viewPosition,
    required this.worldPosition,
    required this.boundsWorld,
    required this.textSnapshot,
  });

  final CanvasTextEditRequestId requestId;
  final CanvasElementId elementId;
  final int controllerEpoch;
  final int documentRevision;
  final int elementRevision;
  final int timestampMs;
  final Offset viewPosition;
  final Offset worldPosition;
  final Rect boundsWorld;
  final CanvasTextElement textSnapshot;
}
```

Добавляем public helper:

```dart
abstract interface class CanvasCommandPort {
  bool commitTextEdit(
    CanvasTextEditRequestId requestId,
    String newText,
  );
}
```

Semantics:

```text
commitTextEdit возвращает false, если:
- requestId неизвестен;
- controllerEpoch изменился;
- element удалён;
- elementRevision изменился;
- element больше не text element.
```

При успехе:

```text
commitTextEdit выполняет updateElement внутри normal edit transaction.
```

**Итог:** text editing остаётся app-owned, но stale commit контролируется движком.

---

## 12. Action events объявляем notification stream, не undo/redo

**Проблема:** payloads action events не содержат enough data для полноценного undo/redo.

**Решение:** меняем контракт и названия.

```text
CanvasActionCommitted is a user-action notification stream.
It is not an undo/redo journal.
Undo/redo is application-owned.
```

Публичные события оставляем для:

```text
analytics
application notifications
toolbar state
domain reactions
external logging
```

Переименовать документационную формулировку:

```text
app's undo/redo action stream
```

в:

```text
app's user-action notification stream
```

Payloads не расширяем до inverse patches в v1.

**Итог:** API не обещает историю изменений там, где её нет.

---

# Две обязательные правки без отдельного редизайна

## 13. Operation matrix переводим на field-effect taxonomy

**Проблема:** строки вида `update visual only` и `update geometry/transform` слишком грубые. Реальная логика зависит от конкретного поля.

**Решение:** вводим центральную таблицу эффектов полей и один compiler.

```text
UpdateEffectCompiler
  input: element update DTO
  output: typed effects
```

Пример field taxonomy:

```text
opacity:
  elementVisualRevision
  repaint main
  no spatial

transform:
  boundsRevision
  elementVisualRevision
  spatial touched
  repaint main

hitPadding:
  boundsRevision
  spatial touched
  repaint none

isVisible:
  elementVisualRevision
  spatial touched
  repaint main
  selection normalization

isSelectable:
  selection normalization
  no document visual repaint

text:
  boundsRevision
  elementVisualRevision
  spatial touched
  repaint main

fontSize:
  boundsRevision
  elementVisualRevision
  spatial touched
  repaint main

resourceId:
  elementVisualRevision
  resource reference validation
  repaint main

metadata:
  projectionRevision
  no repaint by default
```

**Итог:** effects вычисляются единым способом, а не размазываются по handlers.

---

## 14. Non-invertible transform fallback убираем

**Проблема:** если transform должен быть invertible, coarse fallback для non-invertible transform скрывает corrupted state.

**Решение:** non-invertible transform запрещён на всех входах.

```text
public DTO construction rejects non-invertible transform
decode rejects non-invertible transform
edit update rejects non-invertible transform
loadDocument rejects non-invertible transform
```

Runtime corrupted row policy:

```text
non-invertible row is excluded from exact hit-test
diagnostic record emitted
no coarse candidate fallback
```

**Итог:** corrupted geometry не превращается в странные попадания.

---

