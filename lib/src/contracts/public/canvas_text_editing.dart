import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'canvas_actions.dart';
import 'canvas_geometry.dart';
import 'canvas_ids.dart';

/// The terminal choice for an active text-editing session.
enum CanvasTextEditFinishIntent {
  /// Confirms the current runtime-owned draft.
  commit,

  /// Discards the current runtime-owned draft.
  cancel,
}

/// The terminal behavior for an existing text draft whose text is empty.
enum CanvasTextEditEmptyTextBehavior {
  /// Retains the element and commits an empty text update when it changed.
  keepElement,

  /// Removes the element through the existing deletion confirmation route.
  deleteElement,
}

/// The reason a requested existing-text editing session was not admitted.
enum CanvasTextEditStartRefusalReason {
  /// Editing is disabled for the runtime.
  readOnly,

  /// A different text editing session already occupies the runtime slot.
  anotherSessionActive,

  /// The requested target or retained same-target session is no longer current.
  stale,

  /// No element with the requested identifier exists.
  notFound,

  /// The requested element exists but is not a text element.
  unsupportedType,

  /// The requested text element cannot be edited from its current location.
  unavailable,
}

/// The typed outcome of admitting an existing text element for editing.
sealed class CanvasTextEditStartResult {
  const CanvasTextEditStartResult();
}

/// A successful existing-text admission.
final class CanvasTextEditStartSuccess extends CanvasTextEditStartResult {
  const CanvasTextEditStartSuccess(this.session);

  /// The active runtime-owned session for the admitted element.
  final CanvasTextEditSession session;
}

/// An existing-text admission refusal.
final class CanvasTextEditStartRefusal extends CanvasTextEditStartResult {
  const CanvasTextEditStartRefusal(this.reason);

  /// The current reason the session was not admitted.
  final CanvasTextEditStartRefusalReason reason;
}

/// The observable outcome of completing an active text-editing session.
enum CanvasTextEditFinishResult {
  /// A changed draft was installed.
  committed,

  /// A net-equal draft closed without document work.
  unchanged,

  /// The active draft was discarded.
  cancelled,

  /// The resolver refused the prepared draft, which remains retryable.
  rejected,

  /// The draft's captured existing-target guard no longer matches.
  stale,

  /// No active draft was available to complete.
  noActiveSession,
}

@immutable
/// Public API v1 declaration for [CanvasTextEditGeometry].
final class CanvasTextEditGeometry {
  const CanvasTextEditGeometry({
    required this.paintBoundsWorld,
    required this.editBoundsWorld,
    required this.transform,
    required this.maxWidth,
    this.editBoundsLocal,
  });

  final Rect paintBoundsWorld;
  final Rect editBoundsWorld;
  final CanvasTransform transform;
  final double? maxWidth;
  final Rect? editBoundsLocal;

  @override
  bool operator ==(Object other) {
    return other is CanvasTextEditGeometry &&
        other.paintBoundsWorld == paintBoundsWorld &&
        other.editBoundsWorld == editBoundsWorld &&
        other.transform == transform &&
        other.maxWidth == maxWidth &&
        other.editBoundsLocal == editBoundsLocal;
  }

  @override
  int get hashCode {
    return Object.hash(
      paintBoundsWorld,
      editBoundsWorld,
      transform,
      maxWidth,
      editBoundsLocal,
    );
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
  const CanvasTextEditSession._({
    required this.elementId,
    required this.requestId,
    required this.documentRevision,
    required this.elementRevision,
    required this.generation,
    required this.initialText,
    required this.emptyTextBehavior,
    required String Function() liveText,
    required CanvasTextEditGeometry Function() geometry,
    required CanvasTextEditStyle Function() style,
    required bool Function() isActive,
    required bool Function() isStale,
    required void Function(String text) updateText,
    required void Function({bool? isBold, bool? isItalic, bool? isUnderline})
    updateFormatting,
    required bool Function({int? timestampMs}) commit,
    required VoidCallback dismiss,
  }) : _liveText = liveText,
       _geometry = geometry,
       _style = style,
       _isActive = isActive,
       _isStale = isStale,
       _updateText = updateText,
       _updateFormatting = updateFormatting,
       _commit = commit,
       _dismiss = dismiss;

  final String Function() _liveText;
  final CanvasTextEditGeometry Function() _geometry;
  final CanvasTextEditStyle Function() _style;
  final bool Function() _isActive;
  final bool Function() _isStale;
  final void Function(String text) _updateText;
  final void Function({bool? isBold, bool? isItalic, bool? isUnderline})
  _updateFormatting;
  final bool Function({int? timestampMs}) _commit;
  final VoidCallback _dismiss;

  final CanvasElementId elementId;
  final CanvasInteractionRequestId requestId;
  final int documentRevision;
  final int elementRevision;
  final int generation;
  final String initialText;
  final CanvasTextEditEmptyTextBehavior emptyTextBehavior;
  String get liveText => _liveText();
  CanvasTextEditGeometry get geometry => _geometry();
  CanvasTextEditStyle get style => _style();
  bool get isActive => _isActive();
  bool get isStale => _isStale();

  void updateText(String text) => _updateText(text);
  void updateFormatting({bool? isBold, bool? isItalic, bool? isUnderline}) =>
      _updateFormatting(
        isBold: isBold,
        isItalic: isItalic,
        isUnderline: isUnderline,
      );
  bool commit({int? timestampMs}) => _commit(timestampMs: timestampMs);
  void dismiss() => _dismiss();
}

/// Public API v1 declaration for [CanvasTextEditingPort].
abstract interface class CanvasTextEditingPort {
  ValueListenable<CanvasTextEditSession?> get activeSession;
  bool get readOnly;

  /// Admits a visible existing text element without a context-action event.
  CanvasTextEditStartResult startForElement(
    CanvasElementId elementId, {
    CanvasTextEditEmptyTextBehavior emptyTextBehavior =
        CanvasTextEditEmptyTextBehavior.keepElement,
  });

  CanvasTextEditSession? sessionCandidateFor(
    CanvasContextActionRequested request, {
    CanvasTextEditEmptyTextBehavior emptyTextBehavior =
        CanvasTextEditEmptyTextBehavior.keepElement,
  });
  CanvasTextEditSession? start(CanvasTextEditSession session);
  CanvasTextEditSession? startFromContextAction(
    CanvasContextActionRequested request, {
    CanvasTextEditEmptyTextBehavior emptyTextBehavior =
        CanvasTextEditEmptyTextBehavior.keepElement,
  });
  // Positional bool is the locked public API shape for ergonomic
  // runtime.textEditing.setReadOnly(true) calls.
  // ignore: avoid_positional_boolean_parameters
  void setReadOnly(bool value);
  CanvasTextEditFinishResult finishActive(
    CanvasTextEditFinishIntent intent, {
    int? timestampMs,
  });
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
  required CanvasTextEditEmptyTextBehavior emptyTextBehavior,
  required String Function() liveText,
  required CanvasTextEditGeometry Function() geometry,
  required CanvasTextEditStyle Function() style,
  required bool Function() isActive,
  required bool Function() isStale,
  required void Function(String text) updateText,
  required void Function({bool? isBold, bool? isItalic, bool? isUnderline})
  updateFormatting,
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
    emptyTextBehavior: emptyTextBehavior,
    liveText: liveText,
    geometry: geometry,
    style: style,
    isActive: isActive,
    isStale: isStale,
    updateText: updateText,
    updateFormatting: updateFormatting,
    commit: commit,
    dismiss: dismiss,
  );
}
