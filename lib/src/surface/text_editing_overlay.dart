import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../api/canvas_runtime.dart';
import '../contracts/public/canvas_actions.dart';
import '../contracts/public/canvas_geometry.dart';
import '../contracts/public/canvas_text_editing.dart';

const Key canvasTextEditingOverlayEditorHostKey = ValueKey<String>(
  'iwb_canvas_text_editing_overlay.editor_host',
);

const Key canvasTextEditingOverlayTransformKey = ValueKey<String>(
  'iwb_canvas_text_editing_overlay.transform',
);

const Key canvasTextEditingOverlayEditableTextKey = ValueKey<String>(
  'iwb_canvas_text_editing_overlay.editable_text',
);

const _editorInlineWidthSlack = 8.0;
const _editorScrollBehavior = _InlineTextEditorScrollBehavior();

/// Public API v1 declaration for [CanvasTextEditingOverlay].
final class CanvasTextEditingOverlay extends StatefulWidget {
  const CanvasTextEditingOverlay({
    required this.runtime,
    this.inlineEditOnDoubleTap = false,
    this.maxEditorHeight,
    this.cursorColor = const Color(0xFF1565C0),
    this.selectionColor = const Color(0x331565C0),
    this.backgroundCursorColor = const Color(0x00000000),
    this.selectionControls,
    this.autofocus = true,
    this.commitOnFocusLoss = true,
    this.dismissOnEscape = true,
    super.key,
  });

  final CanvasRuntime runtime;
  final bool inlineEditOnDoubleTap;
  final double? maxEditorHeight;
  final Color cursorColor;
  final Color selectionColor;
  final Color backgroundCursorColor;
  final TextSelectionControls? selectionControls;
  final bool autofocus;
  final bool commitOnFocusLoss;
  final bool dismissOnEscape;

  @override
  State<CanvasTextEditingOverlay> createState() {
    return _CanvasTextEditingOverlayState();
  }
}

// The state owns the Flutter editing objects and runtime subscriptions together
// so session swaps, focus cleanup, and auto-start routing stay auditable.
// Keeping this lifecycle in one state avoids a controller/focus/session
// synchronizer split that would make commit and dismiss ordering harder to
// audit at the Flutter boundary.
// ignore: coupling-between-object-classes, number-of-methods, response-for-class, weighted-methods-per-class
final class _CanvasTextEditingOverlayState
    extends State<CanvasTextEditingOverlay> {
  CanvasTextEditSession? _session;
  TextEditingController? _controller;
  FocusNode? _focusNode;
  ScrollController? _scrollController;
  StreamSubscription<CanvasContextActionRequested>? _contextSubscription;
  var _syncingController = false;
  var _focusLossCommitGeneration = 0;

  @override
  void initState() {
    super.initState();
    widget.runtime.textEditing.activeSession.addListener(
      _handleActiveSessionChanged,
    );
    widget.runtime.state.addListener(_handleRuntimeStateChanged);
    _installContextSubscription();
    _replaceSessionState(widget.runtime.textEditing.activeSession.value);
  }

  @override
  void didUpdateWidget(covariant CanvasTextEditingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.runtime, widget.runtime)) {
      oldWidget.runtime.textEditing.activeSession.removeListener(
        _handleActiveSessionChanged,
      );
      oldWidget.runtime.state.removeListener(_handleRuntimeStateChanged);
      _dismissSession();
      widget.runtime.textEditing.activeSession.addListener(
        _handleActiveSessionChanged,
      );
      widget.runtime.state.addListener(_handleRuntimeStateChanged);
      _replaceContextSubscription();
      _replaceSessionState(widget.runtime.textEditing.activeSession.value);

      return;
    }
    if (oldWidget.inlineEditOnDoubleTap != widget.inlineEditOnDoubleTap) {
      _replaceContextSubscription();
    }
    if (oldWidget.maxEditorHeight != widget.maxEditorHeight) {
      _syncScrollController();
    }
  }

  @override
  void dispose() {
    widget.runtime.textEditing.activeSession.removeListener(
      _handleActiveSessionChanged,
    );
    widget.runtime.state.removeListener(_handleRuntimeStateChanged);
    _dismissSession();
    unawaited(_contextSubscription?.cancel());
    _disposeEditorState();
    super.dispose();
  }

  @override
  // The widget tree is intentionally local to the lifecycle state so the
  // GestureDetector, Shortcuts, and EditableText callbacks share the same active
  // session guard without a second coordination object.
  // ignore: halstead-volume, maintainability-index, source-lines-of-code
  Widget build(BuildContext context) {
    final session = _session;
    final controller = _controller;
    final focusNode = _focusNode;
    if (session == null || controller == null || focusNode == null) {
      return const SizedBox.shrink();
    }

    final geometry = session.geometry;
    final editBounds = _localEditBoundsFor(geometry);
    if (editBounds == null) {
      return const SizedBox.shrink();
    }
    final cameraOffset = widget.runtime.camera.offset;
    final editorSize = _editorSizeFor(editBounds.size);
    final editorLeft = _alignedEditorLeftFor(
      align: session.style.textAlign,
      direction: session.style.textDirection,
      anchor: editBounds,
      editorWidth: editorSize.width,
    );
    final editorTop = editBounds.top;

    return SizedBox.expand(
      child: CallbackShortcuts(
        bindings: {
          if (widget.dismissOnEscape)
            const SingleActivator(LogicalKeyboardKey.escape): _dismissSession,
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _commitSession,
                child: const SizedBox.expand(),
              ),
            ),
            Positioned.fill(
              child: Transform(
                key: canvasTextEditingOverlayTransformKey,
                transform: _surfaceTransformFor(
                  geometry.transform,
                  cameraOffset,
                ),
                transformHitTests: true,
                alignment: Alignment.topLeft,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: editorLeft,
                      top: editorTop,
                      child: SizedBox(
                        key: canvasTextEditingOverlayEditorHostKey,
                        width: editorSize.width,
                        height: editorSize.height,
                        child: EditableText(
                          key: canvasTextEditingOverlayEditableTextKey,
                          controller: controller,
                          focusNode: focusNode,
                          style: _textStyleFor(session.style),
                          strutStyle: _strutStyleFor(session.style),
                          cursorColor: widget.cursorColor,
                          backgroundCursorColor: widget.backgroundCursorColor,
                          selectionColor: widget.selectionColor,
                          selectionControls: widget.selectionControls,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          textAlign: session.style.textAlign,
                          textDirection: session.style.textDirection,
                          minLines: 1,
                          maxLines: null,
                          expands: false,
                          scrollPadding: EdgeInsets.zero,
                          scrollController: _scrollController,
                          scrollBehavior: _editorScrollBehavior,
                          onEditingComplete: _commitSession,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _installContextSubscription() {
    if (!widget.inlineEditOnDoubleTap) {
      return;
    }
    _contextSubscription = widget.runtime.contextActionRequests.listen((
      request,
    ) {
      widget.runtime.textEditing.startFromContextAction(request);
    });
  }

  void _replaceContextSubscription() {
    unawaited(_contextSubscription?.cancel());
    _contextSubscription = null;
    _installContextSubscription();
  }

  void _handleActiveSessionChanged() {
    final next = widget.runtime.textEditing.activeSession.value;
    if (!identical(next, _session)) {
      _installSession(next);

      return;
    }
    _syncControllerFromSession(next);
    if (mounted) {
      setState(() {});
    }
  }

  void _handleRuntimeStateChanged() {
    if (_session == null || !mounted) {
      return;
    }
    setState(() {});
  }

  void _installSession(CanvasTextEditSession? session) {
    _replaceSessionState(session);
    if (mounted) {
      setState(() {});
    }
  }

  void _replaceSessionState(CanvasTextEditSession? session) {
    _focusLossCommitGeneration += 1;
    _disposeEditorState();
    _session = session;
    if (session != null) {
      _installEditorState(session);
    }
  }

  void _installEditorState(CanvasTextEditSession session) {
    _controller = TextEditingController(text: session.liveText)
      ..addListener(_handleControllerChanged);
    _focusNode = FocusNode()..addListener(_handleFocusChanged);
    _syncScrollController();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode?.requestFocus();
        }
      });
    }
  }

  void _disposeEditorState() {
    _focusLossCommitGeneration += 1;
    final controller = _controller;
    final focusNode = _focusNode;
    final scrollController = _scrollController;
    _controller = null;
    _focusNode = null;
    _scrollController = null;
    controller?.removeListener(_handleControllerChanged);
    controller?.dispose();
    focusNode?.removeListener(_handleFocusChanged);
    focusNode?.dispose();
    scrollController?.dispose();
  }

  void _syncScrollController() {
    if (widget.maxEditorHeight == null) {
      _scrollController?.dispose();
      _scrollController = null;

      return;
    }
    _scrollController ??= ScrollController();
  }

  void _handleControllerChanged() {
    if (_syncingController) {
      return;
    }
    final session = _session;
    final controller = _controller;
    if (session == null || controller == null || !session.isActive) {
      return;
    }
    session.updateText(controller.text);
    if (mounted) {
      setState(() {});
    }
  }

  void _syncControllerFromSession(CanvasTextEditSession? session) {
    final controller = _controller;
    if (session == null || controller == null) {
      return;
    }
    final liveText = session.liveText;
    if (controller.text == liveText) {
      return;
    }
    _syncingController = true;
    controller.value = controller.value.copyWith(
      text: liveText,
      selection: TextSelection.collapsed(offset: liveText.length),
      composing: TextRange.empty,
    );
    _syncingController = false;
  }

  void _handleFocusChanged() {
    final session = _session;
    final focusNode = _focusNode;
    if (!widget.commitOnFocusLoss ||
        session == null ||
        focusNode == null ||
        focusNode.hasFocus) {
      return;
    }
    _scheduleFocusLossCommit(session, focusNode);
  }

  void _scheduleFocusLossCommit(
    CanvasTextEditSession session,
    FocusNode focusNode,
  ) {
    final generation = _focusLossCommitGeneration;
    scheduleMicrotask(() {
      if (!mounted ||
          generation != _focusLossCommitGeneration ||
          !identical(_session, session) ||
          !identical(_focusNode, focusNode) ||
          focusNode.hasFocus ||
          !session.isActive) {
        return;
      }
      _commitSession();
    });
  }

  void _commitSession() {
    final session = _session;
    if (session == null || !session.isActive) {
      return;
    }
    session.commit();
  }

  void _dismissSession() {
    final session = _session;
    if (session == null || !session.isActive) {
      return;
    }
    session.dismiss();
  }

  Size _editorSizeFor(Size editSize) {
    final maxHeight = widget.maxEditorHeight;
    final height = maxHeight == null
        ? editSize.height
        : math.min(editSize.height, maxHeight);

    return Size(
      math.max(1, editSize.width + _editorInlineWidthSlack),
      math.max(1, height),
    );
  }
}

final class _InlineTextEditorScrollBehavior extends ScrollBehavior {
  const _InlineTextEditorScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

double _alignedEditorLeftFor({
  required TextAlign align,
  required TextDirection direction,
  required Rect anchor,
  required double editorWidth,
}) {
  return switch (_resolvedHorizontalTextAnchor(align, direction)) {
    _HorizontalTextAnchor.left => anchor.left,
    _HorizontalTextAnchor.center => anchor.center.dx - editorWidth / 2,
    _HorizontalTextAnchor.right => anchor.right - editorWidth,
  };
}

_HorizontalTextAnchor _resolvedHorizontalTextAnchor(
  TextAlign align,
  TextDirection direction,
) {
  return switch (align) {
    TextAlign.left => _HorizontalTextAnchor.left,
    TextAlign.right => _HorizontalTextAnchor.right,
    TextAlign.center => _HorizontalTextAnchor.center,
    TextAlign.justify || TextAlign.start => switch (direction) {
      TextDirection.ltr => _HorizontalTextAnchor.left,
      TextDirection.rtl => _HorizontalTextAnchor.right,
    },
    TextAlign.end => switch (direction) {
      TextDirection.ltr => _HorizontalTextAnchor.right,
      TextDirection.rtl => _HorizontalTextAnchor.left,
    },
  };
}

enum _HorizontalTextAnchor { left, center, right }

Rect? _localEditBoundsFor(CanvasTextEditGeometry geometry) {
  return geometry.editBoundsLocal;
}

Matrix4 _surfaceTransformFor(CanvasTransform transform, Offset cameraOffset) {
  final viewTransform = transform.withTranslation(
    transform.translation - cameraOffset,
  );

  return Matrix4.fromFloat64List(viewTransform.toCanvasTransform());
}

TextStyle _textStyleFor(CanvasTextEditStyle style) {
  return TextStyle(
    color: style.color,
    fontSize: style.fontSize,
    fontFamily: style.fontFamily,
    fontWeight: style.isBold ? FontWeight.bold : FontWeight.normal,
    fontStyle: style.isItalic ? FontStyle.italic : FontStyle.normal,
    decoration: style.isUnderline ? TextDecoration.underline : null,
    height: style.lineHeight,
  );
}

StrutStyle _strutStyleFor(CanvasTextEditStyle style) {
  return StrutStyle(
    fontSize: style.fontSize,
    fontFamily: style.fontFamily,
    fontWeight: style.isBold ? FontWeight.bold : FontWeight.normal,
    fontStyle: style.isItalic ? FontStyle.italic : FontStyle.normal,
    height: style.lineHeight,
    forceStrutHeight: true,
  );
}
