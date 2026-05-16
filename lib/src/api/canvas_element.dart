enum CanvasElementKind { image, path, text, stroke, line, rect }

sealed class CanvasElement {
  const CanvasElement();
}

final class CanvasImageElement extends CanvasElement {
  const CanvasImageElement();
}

final class CanvasPathElement extends CanvasElement {
  const CanvasPathElement();
}

final class CanvasTextElement extends CanvasElement {
  const CanvasTextElement();
}

final class CanvasStrokeElement extends CanvasElement {
  const CanvasStrokeElement();
}

final class CanvasLineElement extends CanvasElement {
  const CanvasLineElement();
}

final class CanvasRectElement extends CanvasElement {
  const CanvasRectElement();
}

final class CanvasElementRead {
  const CanvasElementRead();
}
