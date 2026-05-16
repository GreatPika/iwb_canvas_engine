import 'canvas_ids.dart';

sealed class CanvasResource {
  const CanvasResource();
}

final class CanvasImageResource extends CanvasResource {
  const CanvasImageResource();
}

final class CanvasResourceSource {
  const CanvasResourceSource();
}

abstract interface class CanvasResourceResolver {
  CanvasResource? resolve(CanvasResourceId id);
}

abstract interface class CanvasResourcePort {}
