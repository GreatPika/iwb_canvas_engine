import 'package:flutter/material.dart';

import 'canvas_example_view_model.dart';

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
// positioned panel together so app-owned editor lifecycle is disposed in one
// place instead of split across indirect owner widgets.
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
    final bounds = widget.session.boundsWorld;
    final left = bounds.left - widget.cameraOffset.dx;
    final top = bounds.top - widget.cameraOffset.dy;

    return Positioned(
      left: left,
      top: top,
      child: _TextEditPanel(
        width: bounds.width.clamp(160, double.infinity).toDouble(),
        minHeight: bounds.height,
        controller: _controller,
        focusNode: _focusNode,
        onCommit: widget.onCommit,
        onDismiss: widget.onDismiss,
      ),
    );
  }

  void _installEditorState() {
    _controller = TextEditingController(text: widget.session.initialText);
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
    _controller.dispose();
    _focusNode.dispose();
  }
}

// This panel intentionally owns the inline editor controls in one small row so
// tab order and commit/dismiss affordances are visible at the app UI boundary.
// ignore: coupling-between-object-classes
final class _TextEditPanel extends StatelessWidget {
  const _TextEditPanel({
    required this.width,
    required this.minHeight,
    required this.controller,
    required this.focusNode,
    required this.onCommit,
    required this.onDismiss,
  });

  final double width;
  final double minHeight;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onCommit;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: _editorDecoration,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: width,
          maxWidth: width,
          minHeight: minHeight,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _textField()),
            _commitButton(),
            _dismissButton(),
          ],
        ),
      ),
    );
  }

  Widget _textField() {
    return TextField(
      key: const ValueKey('text.edit.field'),
      controller: controller,
      focusNode: focusNode,
      minLines: 1,
      maxLines: 4,
      textInputAction: TextInputAction.done,
      onSubmitted: onCommit,
      decoration: const InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: EdgeInsets.all(10),
      ),
    );
  }

  Widget _commitButton() {
    return IconButton(
      key: const ValueKey('text.edit.commit'),
      icon: const Icon(Icons.check),
      tooltip: 'Commit text',
      onPressed: () => onCommit(controller.text),
    );
  }

  Widget _dismissButton() {
    return IconButton(
      key: const ValueKey('text.edit.dismiss'),
      icon: const Icon(Icons.close),
      tooltip: 'Dismiss text edit',
      onPressed: onDismiss,
    );
  }
}

final _editorDecoration = BoxDecoration(
  color: Colors.white,
  border: Border.all(color: Colors.black54),
  borderRadius: BorderRadius.circular(4),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.18),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ],
);
