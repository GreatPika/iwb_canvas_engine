import 'dart:ui';

import 'package:iwb_canvas_engine/src/core/transform2d.dart';

enum HarnessNodeKind { rect, text, stroke, line }

class HarnessScript {
  const HarnessScript({required this.name, required this.steps});

  final String name;
  final List<HarnessStep> steps;
}

class HarnessStep {
  const HarnessStep({required this.tag, required this.operation});

  final String tag;
  final HarnessOperation operation;
}

sealed class HarnessOperation {
  const HarnessOperation();
}

class AddRectOp extends HarnessOperation {
  const AddRectOp({
    required this.id,
    required this.position,
    required this.size,
    this.fillColor = const Color(0xFF42A5F5),
    this.strokeColor,
    this.strokeWidth = 1,
  });

  final String id;
  final Offset position;
  final Size size;
  final Color? fillColor;
  final Color? strokeColor;
  final double strokeWidth;
}

class AddTextOp extends HarnessOperation {
  const AddTextOp({
    required this.id,
    required this.position,
    required this.size,
    required this.text,
    this.fontSize = 20,
    this.color = const Color(0xFF212121),
  });

  final String id;
  final Offset position;
  final Size size;
  final String text;
  final double fontSize;
  final Color color;
}

class PatchNodeCommonOp extends HarnessOperation {
  const PatchNodeCommonOp({
    required this.id,
    required this.kind,
    this.transform,
    this.opacity,
  });

  final String id;
  final HarnessNodeKind kind;
  final Transform2D? transform;
  final double? opacity;
}

class PatchRectStyleOp extends HarnessOperation {
  const PatchRectStyleOp({
    required this.id,
    this.fillColor,
    this.strokeColor,
    this.strokeWidth,
  });

  final String id;
  final Color? fillColor;
  final Color? strokeColor;
  final double? strokeWidth;
}

class DeleteNodeOp extends HarnessOperation {
  const DeleteNodeOp({required this.id});

  final String id;
}

class ReplaceSelectionOp extends HarnessOperation {
  const ReplaceSelectionOp({required this.ids});

  final List<String> ids;
}

class ToggleSelectionOp extends HarnessOperation {
  const ToggleSelectionOp({required this.id});

  final String id;
}

class TranslateSelectionOp extends HarnessOperation {
  const TranslateSelectionOp({required this.delta});

  final Offset delta;
}

class DrawStrokeOp extends HarnessOperation {
  const DrawStrokeOp({
    required this.id,
    required this.points,
    required this.thickness,
    required this.color,
    this.opacity = 1,
  });

  final String id;
  final List<Offset> points;
  final double thickness;
  final Color color;
  final double opacity;
}

class DrawLineOp extends HarnessOperation {
  const DrawLineOp({
    required this.id,
    required this.start,
    required this.end,
    required this.thickness,
    required this.color,
    this.opacity = 1,
  });

  final String id;
  final Offset start;
  final Offset end;
  final double thickness;
  final Color color;
  final double opacity;
}

class EraseNodesOp extends HarnessOperation {
  const EraseNodesOp({required this.ids});

  final List<String> ids;
}

class SetGridEnabledOp extends HarnessOperation {
  const SetGridEnabledOp({required this.value});

  final bool value;
}

class SetGridCellSizeOp extends HarnessOperation {
  const SetGridCellSizeOp({required this.value});

  final double value;
}

class ReplaceSceneOp extends HarnessOperation {
  const ReplaceSceneOp({required this.sceneJson});

  final Map<String, dynamic> sceneJson;
}
