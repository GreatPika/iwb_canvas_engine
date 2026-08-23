# Substituting Dependencies in Flutter Tests

Use real domain code by default. Substitute a dependency only at a confirmed
boundary where the test would otherwise depend on application-provided assets,
Flutter rendering, persistent storage, time, randomness, or another external
service.

## Canvas Resource Resolution Boundary

- `CanvasResourceResolver` is the public boundary through which the host app
  supplies image and prepared-vector assets for canvas resources.
- Use a resolver fake when a test needs to return no asset, a known asset, or
  an error without depending on host-app asset loading.
- The canvas package owns resource-session behavior. Do not replace it with a
  call counter when the real `SurfaceResourceSession` path is practical to
  exercise.

Deterministic, quick tests are valuable for interactive canvas rendering. Do
not replace real domain behavior or a native resource lifetime with a call
counter when the real path is practical to exercise.

## Inject External Effects Normally

For new code that owns an external effect, pass a narrow, operation-specific
boundary through normal application composition. `CanvasSurface` already
accepts `CanvasResourceResolver` from the host app; use that boundary rather
than adding a broad wrapper or a test-only constructor parameter.

## Fakes at Narrow Ports

Do not substitute an internal collaborator merely to assert its implementation
calls. A fake resolver can control the app-owned asset result while the test
still observes the real resource-session outcome.

```dart
import 'dart:ui' as ui;

import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

final class FakeCanvasResourceResolver implements CanvasResourceResolver {
  FakeCanvasResourceResolver({this.image, this.imageFailure});

  final ui.Image? image;
  final Object? imageFailure;
  final List<CanvasImageResource> resolvedImages = [];

  @override
  ui.Image? resolveImage(CanvasImageResource resource) {
    resolvedImages.add(resource);
    final failure = imageFailure;
    if (failure != null) throw failure;

    return image;
  }

  @override
  CanvasPreparedVector? resolveVector(CanvasVectorResource resource) => null;
}
```

Use a hand-written `Fake` or `Stub` by default. Keep it local to one proof
unless several tests share the same stable semantic seam. Give it the exact
responses and observable state that the test needs; it must not reproduce the
production algorithm. A call count or captured argument may support an
assertion, but never be the only observed outcome.

## Mocking Libraries

Do not add `mocktail` or `mockito` merely to avoid a small fake. Consider a
mocking library only when a third-party boundary needs many independently
configured responses or interaction assertions and a hand-written fake would
obscure the test. If one is adopted, use it only at that boundary, not for the
package's internal domain collaborators.

## Operation-Specific Ports

When a new external integration is needed, expose typed operations for the
required actions rather than a generic fetcher with conditional test setup.
Each fake should return one known shape, so the exercised external operation
and its failure behavior remain visible in the test.
