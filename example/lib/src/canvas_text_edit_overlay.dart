import 'package:flutter/material.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

import 'canvas_example_view_model.dart';

const Key canvasExampleTextEditDismissOverlayKey = Key(
  'canvas-example-text-edit-dismiss-overlay',
);

final class CanvasTextEditOverlay extends StatefulWidget {
  const CanvasTextEditOverlay({
    required this.session,
    required this.cameraOffset,
    required this.onCommit,
    required this.onDismiss,
    super.key,
  });

  final CanvasExampleTextEditSession session;
  final Offset cameraOffset;
  final ValueChanged<String> onCommit;
  final VoidCallback onDismiss;

  @override
  State<CanvasTextEditOverlay> createState() => _CanvasTextEditOverlayState();
}

// The state keeps the controller, focus node, request-session swap, and
// positioned editor together so lifecycle and commit ordering remain explicit.
// ignore: coupling-between-object-classes
final class _CanvasTextEditOverlayState extends State<CanvasTextEditOverlay> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _installEditorState();
    _requestFocusAfterBuild();
  }

  @override
  void didUpdateWidget(covariant CanvasTextEditOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.requestId == widget.session.requestId) {
      return;
    }
    _disposeEditorState();
    _installEditorState();
    _requestFocusAfterBuild();
  }

  @override
  void dispose() {
    _disposeEditorState();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final element = widget.session.elementSnapshot;
    final bounds = widget.session.boundsWorld;
    final viewPosition = bounds.topLeft - widget.cameraOffset;
    final textHeight = _measureTextHeight(
      element: element,
      text: _controller.text,
      maxWidth: bounds.width,
    ).clamp(bounds.height, double.infinity);

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            key: canvasExampleTextEditDismissOverlayKey,
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.onCommit(_controller.text),
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          left: viewPosition.dx,
          top: viewPosition.dy,
          child: SizedBox(
            key: const ValueKey('text.edit.bounds'),
            width: bounds.width,
            height: textHeight,
            child: TextField(
              key: const ValueKey('text.edit.field'),
              controller: _controller,
              focusNode: _focusNode,
              minLines: 1,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textAlign: element.align,
              scrollPadding: EdgeInsets.zero,
              textInputAction: TextInputAction.done,
              strutStyle: StrutStyle(
                fontSize: element.fontSize,
                height: _lineHeightMultiplier(element),
                forceStrutHeight: true,
              ),
              style: TextStyle(
                fontSize: element.fontSize,
                color: element.color,
                fontWeight: element.isBold
                    ? FontWeight.bold
                    : FontWeight.normal,
                fontStyle: element.isItalic
                    ? FontStyle.italic
                    : FontStyle.normal,
                decoration: element.isUnderline
                    ? TextDecoration.underline
                    : null,
                fontFamily: element.fontFamily,
                height: _lineHeightMultiplier(element),
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _installEditorState() {
    _controller = TextEditingController(text: widget.session.initialText);
    _controller.addListener(_handleTextChanged);
    _focusNode = FocusNode();
  }

  void _requestFocusAfterBuild() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  void _disposeEditorState() {
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    _focusNode.dispose();
  }

  void _handleTextChanged() {
    setState(() {});
  }
}

double _measureTextHeight({
  required CanvasTextElement element,
  required String text,
  required double maxWidth,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text.isEmpty ? ' ' : text,
      style: TextStyle(
        color: element.color,
        fontSize: element.fontSize,
        fontFamily: element.fontFamily,
        fontWeight: element.isBold ? FontWeight.bold : FontWeight.normal,
        fontStyle: element.isItalic ? FontStyle.italic : FontStyle.normal,
        decoration: element.isUnderline
            ? TextDecoration.underline
            : TextDecoration.none,
        height: _lineHeightMultiplier(element),
      ),
    ),
    textAlign: element.align,
    textDirection: element.textDirection,
    maxLines: null,
  );
  painter.layout(maxWidth: maxWidth);

  return painter.height;
}

double? _lineHeightMultiplier(CanvasTextElement element) {
  return element.lineHeight;
}
