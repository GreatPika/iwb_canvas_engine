import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

const Key canvasExampleTextEditDismissOverlayKey = Key(
  'canvas-example-text-edit-dismiss-overlay',
);

class CanvasTextEditOverlay extends StatelessWidget {
  const CanvasTextEditOverlay({
    super.key,
    required this.node,
    required this.cameraOffset,
    required this.textController,
    required this.focusNode,
    required this.onDismiss,
  });

  final TextNodeSnapshot node;
  final Offset cameraOffset;
  final TextEditingController textController;
  final FocusNode focusNode;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final viewPosition = _toViewPoint(node.transform.translation, cameraOffset);
    final rotationDeg = _rotationDegreesFromTransform(node.transform);
    final scaleX = _scaleXFromTransform(node.transform);
    final scaleY = _scaleYFromTransform(node.transform);
    final alignment = _mapTextAlignToAlignment(node.align);
    final lineHeight = node.lineHeight;
    final textSize = _measureTextNode(node);

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            key: canvasExampleTextEditDismissOverlayKey,
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          left: viewPosition.dx,
          top: viewPosition.dy,
          child: Transform(
            transform: Matrix4.rotationZ(
              rotationDeg * math.pi / 180,
            ).scaledByVector3(Vector3(scaleX, scaleY, 1)),
            child: FractionalTranslation(
              translation: const Offset(-0.5, -0.5),
              child: SizedBox(
                width: textSize.width,
                height: textSize.height,
                child: OverflowBox(
                  maxWidth: 3000,
                  maxHeight: 2000,
                  alignment: alignment,
                  child: TextField(
                    controller: textController,
                    focusNode: focusNode,
                    maxLines: null,
                    textAlign: node.align,
                    scrollPadding: EdgeInsets.zero,
                    strutStyle: StrutStyle(
                      fontSize: node.fontSize,
                      height: lineHeight == null
                          ? null
                          : lineHeight / node.fontSize,
                      forceStrutHeight: true,
                    ),
                    style: TextStyle(
                      fontSize: node.fontSize,
                      color: node.color,
                      fontWeight: node.isBold
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontStyle: node.isItalic
                          ? FontStyle.italic
                          : FontStyle.normal,
                      decoration: node.isUnderline
                          ? TextDecoration.underline
                          : null,
                      fontFamily: node.fontFamily,
                      height: lineHeight == null
                          ? null
                          : lineHeight / node.fontSize,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Size _measureTextNode(TextNodeSnapshot node) {
  final safeFontSize = node.fontSize > 0 && node.fontSize.isFinite
      ? node.fontSize
      : 24.0;
  final lineHeight = node.lineHeight;
  final maxWidth = node.maxWidth;
  final painter = TextPainter(
    text: TextSpan(
      text: node.text,
      style: TextStyle(
        color: node.color,
        fontSize: safeFontSize,
        fontFamily: node.fontFamily,
        fontWeight: node.isBold ? FontWeight.bold : FontWeight.normal,
        fontStyle: node.isItalic ? FontStyle.italic : FontStyle.normal,
        decoration: node.isUnderline
            ? TextDecoration.underline
            : TextDecoration.none,
        height: lineHeight == null || !lineHeight.isFinite || lineHeight <= 0
            ? null
            : lineHeight / safeFontSize,
      ),
    ),
    textAlign: node.align,
    textDirection: node.textDirection,
    maxLines: null,
  );
  if (maxWidth == null || !maxWidth.isFinite || maxWidth <= 0) {
    painter.layout();
  } else {
    painter.layout(maxWidth: maxWidth);
  }
  return Size(painter.width, painter.height);
}

Alignment _mapTextAlignToAlignment(TextAlign align) {
  switch (align) {
    case TextAlign.center:
      return Alignment.center;
    case TextAlign.right:
      return Alignment.centerRight;
    default:
      return Alignment.centerLeft;
  }
}

double _rotationDegreesFromTransform(Transform2D transform) {
  return math.atan2(transform.b, transform.a) * 180 / math.pi;
}

double _scaleXFromTransform(Transform2D transform) {
  return math.sqrt(transform.a * transform.a + transform.b * transform.b);
}

double _scaleYFromTransform(Transform2D transform) {
  final magnitude = math.sqrt(
    transform.c * transform.c + transform.d * transform.d,
  );
  final determinant = transform.a * transform.d - transform.b * transform.c;
  return determinant < 0 ? -magnitude : magnitude;
}

Offset _toViewPoint(Offset scenePoint, Offset cameraOffset) {
  return Offset(
    scenePoint.dx - cameraOffset.dx,
    scenePoint.dy - cameraOffset.dy,
  );
}
