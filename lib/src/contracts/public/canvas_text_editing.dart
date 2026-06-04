import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'canvas_actions.dart';
import 'canvas_geometry.dart';
import 'canvas_ids.dart';

@immutable
/// Public API v1 declaration for [CanvasTextEditGeometry].
final class CanvasTextEditGeometry {
  const CanvasTextEditGeometry({
    required this.paintBoundsWorld,
    required this.editBoundsWorld,
    required this.transform,
    required this.maxWidth,
  });

  final Rect paintBoundsWorld;
  final Rect editBoundsWorld;
  final CanvasTransform transform;
  final double? maxWidth;

  @override
  bool operator ==(Object other) {
    return other is CanvasTextEditGeometry &&
        other.paintBoundsWorld == paintBoundsWorld &&
        other.editBoundsWorld == editBoundsWorld &&
        other.transform == transform &&
        other.maxWidth == maxWidth;
  }

  @override
  int get hashCode {
    return Object.hash(paintBoundsWorld, editBoundsWorld, transform, maxWidth);
  }
}

@immutable
/// Public API v1 declaration for [CanvasTextEditStyle].
final class CanvasTextEditStyle {
  const CanvasTextEditStyle({
    required this.fontSize,
    required this.fontFamily,
    required this.isBold,
    required this.isItalic,
    required this.isUnderline,
    required this.color,
    required this.textAlign,
    required this.textDirection,
    required this.lineHeight,
  });

  final double fontSize;
  final String? fontFamily;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final Color color;
  final TextAlign textAlign;
  final TextDirection textDirection;
  final double? lineHeight;

  @override
  bool operator ==(Object other) {
    return other is CanvasTextEditStyle &&
        other.fontSize == fontSize &&
        other.fontFamily == fontFamily &&
        other.isBold == isBold &&
        other.isItalic == isItalic &&
        other.isUnderline == isUnderline &&
        other.color == color &&
        other.textAlign == textAlign &&
        other.textDirection == textDirection &&
        other.lineHeight == lineHeight;
  }

  @override
  int get hashCode {
    return Object.hash(
      fontSize,
      fontFamily,
      isBold,
      isItalic,
      isUnderline,
      color,
      textAlign,
      textDirection,
      lineHeight,
    );
  }
}

/// Public API v1 declaration for [CanvasTextEditSession].
// The session is one runtime-owned public value with guard facts, live text,
// geometry, and lifecycle operations; splitting it would make the admission
// invariant less explicit for custom overlay consumers.
// ignore: number-of-methods
final class CanvasTextEditSession {
  CanvasTextEditSession._({
    required this.elementId,
    required this.requestId,
    required this.documentRevision,
    required this.elementRevision,
    required this.generation,
    required this.initialText,
    required String Function() liveText,
    required CanvasTextEditGeometry Function() geometry,
    required CanvasTextEditStyle Function() style,
    required bool Function() isActive,
    required bool Function() isStale,
    required void Function(String text) updateText,
    required bool Function({int? timestampMs}) commit,
    required VoidCallback dismiss,
  }) : _liveText = liveText,
       _geometry = geometry,
       _style = style,
       _isActive = isActive,
       _isStale = isStale,
       _updateText = updateText,
       _commit = commit,
       _dismiss = dismiss;

  final String Function() _liveText;
  final CanvasTextEditGeometry Function() _geometry;
  final CanvasTextEditStyle Function() _style;
  final bool Function() _isActive;
  final bool Function() _isStale;
  final void Function(String text) _updateText;
  final bool Function({int? timestampMs}) _commit;
  final VoidCallback _dismiss;

  final CanvasElementId elementId;
  final CanvasInteractionRequestId requestId;
  final int documentRevision;
  final int elementRevision;
  final int generation;
  final String initialText;
  String get liveText => _liveText();
  CanvasTextEditGeometry get geometry => _geometry();
  CanvasTextEditStyle get style => _style();
  bool get isActive => _isActive();
  bool get isStale => _isStale();

  void updateText(String text) => _updateText(text);
  bool commit({int? timestampMs}) => _commit(timestampMs: timestampMs);
  void dismiss() => _dismiss();
}

/// Public API v1 declaration for [CanvasTextEditingPort].
abstract interface class CanvasTextEditingPort {
  ValueListenable<CanvasTextEditSession?> get activeSession;
  bool get readOnly;

  CanvasTextEditSession? sessionCandidateFor(
    CanvasContextActionRequested request,
  );
  CanvasTextEditSession? start(CanvasTextEditSession session);
  CanvasTextEditSession? startFromContextAction(
    CanvasContextActionRequested request,
  );
  // Positional bool is the locked public API shape for ergonomic
  // runtime.textEditing.setReadOnly(true) calls.
  // ignore: avoid_positional_boolean_parameters
  void setReadOnly(bool value);
  void dismissActive();
}

// Runtime session construction keeps guard facts and lifecycle callbacks in one
// handoff so Unit 3 cannot wire a session from mismatched state fragments.
// ignore: number-of-parameters
CanvasTextEditSession canvasTextEditSessionForRuntime({
  required CanvasElementId elementId,
  required CanvasInteractionRequestId requestId,
  required int documentRevision,
  required int elementRevision,
  required int generation,
  required String initialText,
  required String Function() liveText,
  required CanvasTextEditGeometry Function() geometry,
  required CanvasTextEditStyle Function() style,
  required bool Function() isActive,
  required bool Function() isStale,
  required void Function(String text) updateText,
  required bool Function({int? timestampMs}) commit,
  required VoidCallback dismiss,
}) {
  return CanvasTextEditSession._(
    elementId: elementId,
    requestId: requestId,
    documentRevision: documentRevision,
    elementRevision: elementRevision,
    generation: generation,
    initialText: initialText,
    liveText: liveText,
    geometry: geometry,
    style: style,
    isActive: isActive,
    isStale: isStale,
    updateText: updateText,
    commit: commit,
    dismiss: dismiss,
  );
}
