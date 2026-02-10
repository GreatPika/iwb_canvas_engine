/// Public input types for canvas interaction controllers.
///
/// These enums are intentionally framework-agnostic and shared between
/// legacy and v2 runtimes.
enum CanvasMode { move, draw }

/// Active drawing tool when [CanvasMode.draw] is enabled.
enum DrawTool { pen, highlighter, line, eraser }
