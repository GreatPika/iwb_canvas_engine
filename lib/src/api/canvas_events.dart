enum CanvasActionType { transform, selection, delete, clear, draw, erase, text }

enum CanvasTransformOperation { move, resize, rotate }

final class CanvasActionCommitted {
  const CanvasActionCommitted();
}

sealed class CanvasActionPayload {
  const CanvasActionPayload();
}

final class CanvasTransformActionPayload extends CanvasActionPayload {
  const CanvasTransformActionPayload();
}

final class CanvasSelectionActionPayload extends CanvasActionPayload {
  const CanvasSelectionActionPayload();
}

final class CanvasDeleteActionPayload extends CanvasActionPayload {
  const CanvasDeleteActionPayload();
}

final class CanvasClearActionPayload extends CanvasActionPayload {
  const CanvasClearActionPayload();
}

final class CanvasDrawStrokeActionPayload extends CanvasActionPayload {
  const CanvasDrawStrokeActionPayload();
}

final class CanvasDrawLineActionPayload extends CanvasActionPayload {
  const CanvasDrawLineActionPayload();
}

final class CanvasEraseActionPayload extends CanvasActionPayload {
  const CanvasEraseActionPayload();
}

final class CanvasTextEditRequested {
  const CanvasTextEditRequested();
}

abstract interface class CanvasMoveCommitResolver {
  CanvasMoveResolution resolve(CanvasMoveCommitRequest request);
}

final class CanvasMoveCommitRequest {
  const CanvasMoveCommitRequest();
}

sealed class CanvasMoveResolution {
  const CanvasMoveResolution();
}

final class CanvasMoveCommit extends CanvasMoveResolution {
  const CanvasMoveCommit();
}

final class CanvasMoveCancel extends CanvasMoveResolution {
  const CanvasMoveCancel();
}
