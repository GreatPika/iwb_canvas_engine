## 6. Resource resolver cache переносим в surface resource session

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

## 7. `CanvasPreviewState` делаем sealed-union

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

## 8. Text edit request снабжаем stale guard

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

## 9. Action events объявляем notification stream, не undo/redo

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

## 10. Operation matrix переводим на field-effect taxonomy

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

## 11. Non-invertible transform fallback убираем

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
