/// Public input types for the canvas controller.
///
/// These enums are intentionally defined outside of `scene_controller.dart` so
/// input "slices" can depend on the types without importing the controller.
enum CanvasMode { move, draw }

/// Active drawing tool when [CanvasMode.draw] is enabled.
enum DrawTool { pen, highlighter, line, eraser }
