## 1. Разбить `FrameEngine` внутри реализации

**Проблема:** `FrameEngine` сейчас слишком нагруженный узел. Он одновременно:

```text
захватывает runtime facts
строит ordinary paint plan
строит selection decoration
работает с resource images
управляет frame cache
обслуживает selected move supplement
```

Это риск “комбайна”: одна часть начинает случайно инвалидировать другую.

**Исправить без изменения public API.**

Снаружи остаётся:

```text
FrameEngine
```

Внутри:

```text
FrameCaptureService
OrdinaryPaintPlanner
SelectionDecorationPlanner
PaintAssetBindingService
StaticBackgroundPlanner
```

### `FrameCaptureService`

Единственный внутренний сервис, который читает runtime/store/resource/session facts.

```text
inputs:
  FrameFactsPort
  SelectionFactsPort
  ResourceFactsPort
  SurfaceResourceSession
  viewportRect
  devicePixelRatio
  gridStyle
  selectionStyle

output:
  CapturedMainFrame
  CapturedOverlayFrame
```

Правило:

```text
после capture остальные frame-сервисы не читают runtime live state
```

### `OrdinaryPaintPlanner`

Строит обычную сцену.

```text
uses:
  structuralRevision
  boundsRevision
  elementVisualRevision
  viewportRect
  devicePixelRatio
```

Не использует:

```text
selectionRevision
selectionStyle
selectedMoveDelta
preview
resource resolver
```

### `SelectionDecorationPlanner`

Строит рамки выделения и selection UI.

```text
uses:
  selectionRevision
  structuralRevision
  boundsRevision
  selectionIds
  selectionStyle
  devicePixelRatio
```

Именно сюда уходит исправление по `boundsRevision`.

### `PaintAssetBindingService`

Связывает paint records с resolved images.

```text
  uses:
  resource descriptors
  resourceRevision
  SurfaceResourceSession
```

Правила:

```text
Painter не вызывает resolver.
OrdinaryPaintPlanner не вызывает resolver.
Только PaintAssetBindingService работает с SurfaceResourceSession.
```

### `StaticBackgroundPlanner`

Строит background/grid план.

```text
uses:
  backgroundRevision
  gridRevision
  gridStrokeWidth
  viewCamera bucket
  viewportRect
  devicePixelRatio
```

Не использует:

```text
selection
preview
resourceVisual
ordinary elementVisual
```

---

## 2. Ввести `PointerToolCleanupCoordinator`

Это не блокер API freeze, но желательно до реализации interaction.

**Проблема:** в state/sequence diagrams повторяются cleanup paths:

```text
cancel
dispose
load success
mode change
interactive=false
stale token
invalid terminal
no-op terminal
```

Эти правила будут повторяться в:

```text
pencil
marker
line
eraser
marquee
selected move
text request
```

Если писать их отдельно, легко получить расхождение.

**Исправить так:**

```text
PointerToolCleanupCoordinator
```

Он централизует:

```text
clear preview if owned by active session
preserve pending line when required
publish previewRevision only if changed
choose main vs overlay repaint
forbid resolver call on cancel/dispose/load/mode-change
forbid user-action notification on cleanup-only path
invalidate active token/session
```

Tool-specific code должен отвечать только за:


распознать жест
создать commit intent
передать cleanup в coordinator
```

---
