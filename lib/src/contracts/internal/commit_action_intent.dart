import 'dart:ui';

import '../public/canvas_actions.dart';
import '../public/canvas_geometry.dart';
import '../public/canvas_ids.dart';
import '../public/canvas_tools.dart';
import '../public/canvas_value_validators.dart';

enum CommitActionIntentKind {
  moveSelection,
  selectMarquee,
  transformSelection,
  deleteSelection,
  removeElement,
  clearContent,
  drawStroke,
  drawLine,
  erase,
  editText,
}

sealed class CommitActionIntent {
  CommitActionIntent({int? timestampHintMs})
    : timestampHintMs = _validateTimestampHint(timestampHintMs);

  CommitActionIntentKind get kind;
  List<CanvasElementId> get elementIds;
  final int? timestampHintMs;
}

final class MoveSelectionActionIntent extends CommitActionIntent {
  MoveSelectionActionIntent({
    required Iterable<CanvasElementId> elementIds,
    required this.transform,
    super.timestampHintMs,
  }) : elementIds = List.unmodifiable(elementIds);

  @override
  CommitActionIntentKind get kind => CommitActionIntentKind.moveSelection;

  @override
  final List<CanvasElementId> elementIds;
  final CanvasTransform transform;
  CanvasTransformOperation get operation => CanvasTransformOperation.move;
  Offset? get pivotWorld => null;
}

final class SelectMarqueeActionIntent extends CommitActionIntent {
  SelectMarqueeActionIntent({
    required Iterable<CanvasElementId> previousSelection,
    required Iterable<CanvasElementId> nextSelection,
    required this.marqueeRectWorld,
    super.timestampHintMs,
  }) : previousSelection = List.unmodifiable(previousSelection),
       nextSelection = List.unmodifiable(nextSelection);

  @override
  CommitActionIntentKind get kind => CommitActionIntentKind.selectMarquee;

  @override
  List<CanvasElementId> get elementIds => nextSelection;

  final List<CanvasElementId> previousSelection;
  final List<CanvasElementId> nextSelection;
  final Rect marqueeRectWorld;
}

final class TransformSelectionActionIntent extends CommitActionIntent {
  TransformSelectionActionIntent({
    required Iterable<CanvasElementId> elementIds,
    required this.transform,
    required this.operation,
    required this.pivotWorld,
    super.timestampHintMs,
  }) : elementIds = List.unmodifiable(elementIds);

  @override
  CommitActionIntentKind get kind => CommitActionIntentKind.transformSelection;

  @override
  final List<CanvasElementId> elementIds;
  final CanvasTransform transform;
  final CanvasTransformOperation operation;
  final Offset pivotWorld;
}

final class DeleteSelectionActionIntent extends CommitActionIntent {
  DeleteSelectionActionIntent({
    required Iterable<CanvasElementId> removedElementIds,
    super.timestampHintMs,
  }) : removedElementIds = List.unmodifiable(removedElementIds);

  @override
  CommitActionIntentKind get kind => CommitActionIntentKind.deleteSelection;

  @override
  List<CanvasElementId> get elementIds => removedElementIds;

  final List<CanvasElementId> removedElementIds;
}

final class RemoveElementActionIntent extends CommitActionIntent {
  RemoveElementActionIntent({
    required CanvasElementId elementId,
    super.timestampHintMs,
  }) : removedElementIds = List.unmodifiable([elementId]);

  @override
  CommitActionIntentKind get kind => CommitActionIntentKind.removeElement;

  @override
  List<CanvasElementId> get elementIds => removedElementIds;

  final List<CanvasElementId> removedElementIds;
}

final class ClearContentActionIntent extends CommitActionIntent {
  ClearContentActionIntent({
    required Iterable<CanvasElementId> removedElementIds,
    required Iterable<CanvasResourceId> removedResourceIds,
    super.timestampHintMs,
  }) : removedElementIds = List.unmodifiable(removedElementIds),
       removedResourceIds = List.unmodifiable(removedResourceIds);

  @override
  CommitActionIntentKind get kind => CommitActionIntentKind.clearContent;

  @override
  List<CanvasElementId> get elementIds => removedElementIds;

  final List<CanvasElementId> removedElementIds;
  final List<CanvasResourceId> removedResourceIds;
}

final class DrawStrokeActionIntent extends CommitActionIntent {
  DrawStrokeActionIntent({
    required CanvasElementId elementId,
    required CanvasDrawTool tool,
    required this.color,
    required this.thickness,
    required this.opacity,
    required this.pointCount,
    super.timestampHintMs,
  }) : tool = _validateStrokeTool(tool),
       elementIds = List.unmodifiable([elementId]);

  @override
  CommitActionIntentKind get kind => CommitActionIntentKind.drawStroke;

  @override
  final List<CanvasElementId> elementIds;
  final CanvasDrawTool tool;
  final Color color;
  final double thickness;
  final double opacity;
  final int pointCount;
}

final class DrawLineActionIntent extends CommitActionIntent {
  DrawLineActionIntent({
    required CanvasElementId elementId,
    required this.color,
    required this.thickness,
    required this.opacity,
    required this.startWorld,
    required this.endWorld,
    super.timestampHintMs,
  }) : elementIds = List.unmodifiable([elementId]);

  @override
  CommitActionIntentKind get kind => CommitActionIntentKind.drawLine;

  @override
  final List<CanvasElementId> elementIds;
  final Color color;
  final double thickness;
  final double opacity;
  final Offset startWorld;
  final Offset endWorld;
}

final class EraseActionIntent extends CommitActionIntent {
  EraseActionIntent({
    required Iterable<CanvasElementId> erasedElementIds,
    required double eraserThickness,
    required int corridorPointCount,
    super.timestampHintMs,
  }) : erasedElementIds = List.unmodifiable(erasedElementIds),
       eraserThickness = _validateEraserThickness(eraserThickness),
       corridorPointCount = _validateCorridorPointCount(corridorPointCount);

  @override
  CommitActionIntentKind get kind => CommitActionIntentKind.erase;

  @override
  List<CanvasElementId> get elementIds => erasedElementIds;

  final List<CanvasElementId> erasedElementIds;
  final double eraserThickness;
  final int corridorPointCount;
}

final class EditTextActionIntent extends CommitActionIntent {
  EditTextActionIntent({
    required this.requestId,
    required CanvasElementId elementId,
    required int previousTextLength,
    required int nextTextLength,
    super.timestampHintMs,
  }) : previousTextLength = _validateTextLength(
         previousTextLength,
         'previousTextLength',
       ),
       nextTextLength = _validateTextLength(nextTextLength, 'nextTextLength'),
       elementIds = List.unmodifiable([elementId]);

  @override
  CommitActionIntentKind get kind => CommitActionIntentKind.editText;

  @override
  final List<CanvasElementId> elementIds;
  final CanvasInteractionRequestId requestId;
  final int previousTextLength;
  final int nextTextLength;
}

int? _validateTimestampHint(int? timestampHintMs) {
  if (timestampHintMs != null) {
    validateNonNegativeInt(timestampHintMs, path: 'action.timestampMs');
  }

  return timestampHintMs;
}

CanvasDrawTool _validateStrokeTool(CanvasDrawTool tool) {
  return switch (tool) {
    CanvasDrawTool.pencil || CanvasDrawTool.marker => tool,
    CanvasDrawTool.line || CanvasDrawTool.eraser => throw ArgumentError.value(
      tool,
      'tool',
      'must be pencil or marker',
    ),
  };
}

double _validateEraserThickness(double value) {
  validatePositiveDouble(value, path: 'action.eraserThickness');

  return value;
}

int _validateCorridorPointCount(int value) {
  validateNonNegativeInt(value, path: 'action.corridorPointCount');

  return value;
}

int _validateTextLength(int value, String field) {
  validateNonNegativeInt(value, path: 'action.$field');

  return value;
}
