import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'canvas_contract_limits.dart';
import 'canvas_value_validators.dart';

/// Public API v1 declaration for [CanvasPointerLifecyclePhase].
enum CanvasPointerLifecyclePhase { down, move, up, cancel }

@immutable
/// Public API v1 declaration for [CanvasPointerPolicy].
final class CanvasPointerPolicy {
  factory CanvasPointerPolicy({
    double tapSlop = 8.0,
    double doubleTapSlop = 24.0,
    int doubleTapMaxDelayMs = 300,
    bool deferSingleTap = true,
    double? dragStartSlop,
  }) {
    validateNonNegativeDouble(
      tapSlop,
      path: 'pointerPolicy.tapSlop',
      max: canvasMaxPositiveSize,
    );
    validateNonNegativeDouble(
      doubleTapSlop,
      path: 'pointerPolicy.doubleTapSlop',
      max: canvasMaxPositiveSize,
    );
    validateNonNegativeInt(
      doubleTapMaxDelayMs,
      path: 'pointerPolicy.doubleTapMaxDelayMs',
    );
    if (dragStartSlop != null) {
      validateNonNegativeDouble(
        dragStartSlop,
        path: 'pointerPolicy.dragStartSlop',
        max: canvasMaxPositiveSize,
      );
    }

    return CanvasPointerPolicy._(
      tapSlop: tapSlop,
      doubleTapSlop: doubleTapSlop,
      doubleTapMaxDelayMs: doubleTapMaxDelayMs,
      deferSingleTap: deferSingleTap,
      dragStartSlop: dragStartSlop,
    );
  }

  const CanvasPointerPolicy._({
    this.tapSlop = 8.0,
    this.doubleTapSlop = 24.0,
    this.doubleTapMaxDelayMs = 300,
    this.deferSingleTap = true,
    this.dragStartSlop,
  });

  static const defaultPolicy = CanvasPointerPolicy._(dragStartSlop: 1.0);
  final double tapSlop;
  final double doubleTapSlop;
  final int doubleTapMaxDelayMs;
  final bool deferSingleTap;
  final double? dragStartSlop;

  @override
  bool operator ==(Object other) {
    return other is CanvasPointerPolicy &&
        other.tapSlop == tapSlop &&
        other.doubleTapSlop == doubleTapSlop &&
        other.doubleTapMaxDelayMs == doubleTapMaxDelayMs &&
        other.deferSingleTap == deferSingleTap &&
        other.dragStartSlop == dragStartSlop;
  }

  @override
  int get hashCode {
    return Object.hash(
      tapSlop,
      doubleTapSlop,
      doubleTapMaxDelayMs,
      deferSingleTap,
      dragStartSlop,
    );
  }
}

@immutable
/// Public API v1 declaration for [CanvasPointerSample].
final class CanvasPointerSample {
  factory CanvasPointerSample({
    required int pointerId,
    required Offset position,
    required CanvasPointerLifecyclePhase phase,
    required PointerDeviceKind kind,
    int? timestampMs,
  }) {
    validateNonNegativeInt(pointerId, path: 'pointer.pointerId');
    validateOffset(position, path: 'pointer.position');
    if (timestampMs != null) {
      validateNonNegativeInt(timestampMs, path: 'pointer.timestampMs');
    }

    return CanvasPointerSample._(
      pointerId: pointerId,
      position: position,
      phase: phase,
      kind: kind,
      timestampMs: timestampMs,
    );
  }

  const CanvasPointerSample._({
    required this.pointerId,
    required this.position,
    required this.phase,
    required this.kind,
    this.timestampMs,
  });

  final int pointerId;
  final Offset position;
  final int? timestampMs;
  final CanvasPointerLifecyclePhase phase;
  final PointerDeviceKind kind;

  @override
  bool operator ==(Object other) {
    return other is CanvasPointerSample &&
        other.pointerId == pointerId &&
        other.position == position &&
        other.timestampMs == timestampMs &&
        other.phase == phase &&
        other.kind == kind;
  }

  @override
  int get hashCode =>
      Object.hash(pointerId, position, timestampMs, phase, kind);
}
