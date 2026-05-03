/// Public input types for canvas interaction controllers.
///
/// These enums are intentionally framework-agnostic and shared between
/// runtime implementations.
enum CanvasMode {
  /// Selection, marquee, drag-move, and transform interactions.
  move,

  /// Freehand drawing, line drawing, and erasing interactions.
  draw,
}

/// Active drawing tool when [CanvasMode.draw] is enabled.
enum DrawTool {
  /// Opaque freehand stroke tool.
  pen,

  /// Semi-transparent freehand stroke tool.
  highlighter,

  /// Straight-line drawing tool.
  line,

  /// Stroke and line eraser tool.
  eraser,
}
