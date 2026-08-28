import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../contracts/internal/deletion_entry_projection_port.dart';
import '../contracts/public/canvas_contract_limits.dart';
import '../contracts/public/canvas_preview.dart';
import '../contracts/public/canvas_tools.dart';
import 'interaction_read_port.dart';
import 'interaction_runtime_intents.dart';
import 'pointer_session_identity.dart';

final class EraserMachine {
  const EraserMachine();

  EraserStartDecision start({
    required CanvasDrawTool tool,
    required Offset startWorld,
    required CanvasDrawStyle style,
  }) {
    if (tool != CanvasDrawTool.eraser) {
      return const EraserStartDecision.rejected();
    }

    return EraserStartDecision.admitted(
      eraser: PointerEraserCapture(
        points: [startWorld],
        thickness: style.eraserThickness,
      ),
    );
  }

  EraserPreviewDecision preview({
    required PointerEraserCapture eraser,
    required List<Offset> corridorPoints,
  }) {
    return EraserPreviewDecision.changed(
      eraser: eraser,
      preview: CanvasEraserPreview(
        corridor: corridorPoints,
        thickness: eraser.thickness,
      ),
    );
  }

  EraserPreviewDecision initialPreview({
    required PointerEraserCapture eraser,
    required EraserReadFacts facts,
  }) {
    return EraserPreviewDecision.changed(
      eraser: eraser,
      preview: CanvasEraserPreview(
        corridor: facts.corridorPoints,
        thickness: eraser.thickness,
      ),
    );
  }

  EraserTerminalDecision terminal({required EraserTerminalInput input}) {
    if (input.facts.exactBudgetExceeded || input.facts.erasedEntries.isEmpty) {
      return const EraserTerminalDecision.cleanupOnly();
    }

    return EraserTerminalDecision.commit(
      sessionId: input.sessionId,
      pointerToken: input.pointerToken,
      eraser: input.eraser,
      corridorPointCount: input.facts.corridorPoints.length,
      erasedEntries: input.facts.erasedEntries,
    );
  }
}

final class EraserTerminalInput {
  const EraserTerminalInput({
    required this.sessionId,
    required this.pointerToken,
    required this.eraser,
    required this.facts,
  });

  final PointerSessionId sessionId;
  final PointerSessionToken pointerToken;
  final PointerEraserCapture eraser;
  final EraserReadFacts facts;
}

@visibleForTesting
enum PointerEraserCaptureWorkKind {
  sampleAdmitted,
  duplicateSuppressed,
  ordinaryAppend,
  resampled,
  snapshotCreated,
}

@visibleForTesting
final class PointerEraserCaptureWorkEvent {
  const PointerEraserCaptureWorkEvent({
    required this.kind,
    required this.retainedPointCount,
    this.retainedPrefixPointsTraversed = 0,
    this.retainedPrefixPointsCopied = 0,
  });

  final PointerEraserCaptureWorkKind kind;
  final int retainedPointCount;
  final int retainedPrefixPointsTraversed;
  final int retainedPrefixPointsCopied;
}

final Object _eraserCaptureWorkZoneKey = Object();

/// The active eraser corridor is the sole mutable trajectory. Callers obtain
/// immutable snapshots only when crossing preview or read boundaries.
final class PointerEraserCapture {
  PointerEraserCapture({
    required Iterable<Offset> points,
    required this.thickness,
  }) : _storage = List<Offset?>.filled(
         canvasEraserCorridorSoftLimit + 1,
         null,
         growable: false,
       ) {
    for (final point in points) {
      if (_length >= _storage.length) {
        throw ArgumentError.value(
          points,
          'points',
          'initial eraser corridor exceeds bounded capture capacity',
        );
      }
      _storage[_length] = point;
      _length += 1;
    }
  }

  final List<Offset?> _storage;
  int _length = 0;
  final double thickness;

  @visibleForTesting
  static T observeWork<T>(
    void Function(PointerEraserCaptureWorkEvent event) sink,
    T Function() operation,
  ) => runZoned(operation, zoneValues: {_eraserCaptureWorkZoneKey: sink});

  List<Offset> get points => snapshot();

  // Admission and overflow resampling must remain one atomic owner operation:
  // extracting metric-shaped helpers would obscure append-before-resample order.
  // ignore: halstead-volume, source-lines-of-code
  PointerEraserSampleAdmission admitPoint(Offset point) {
    if (_length > 0 && _storage[_length - 1] == point) {
      assert(
        _recordWork(
          PointerEraserCaptureWorkEvent(
            kind: PointerEraserCaptureWorkKind.duplicateSuppressed,
            retainedPointCount: _length,
          ),
        ),
        'eraser capture work observation failed',
      );
      return const PointerEraserSampleAdmission.duplicate();
    }

    _storage[_length] = point;
    _length += 1;
    assert(
      _recordWork(
        PointerEraserCaptureWorkEvent(
          kind: PointerEraserCaptureWorkKind.sampleAdmitted,
          retainedPointCount: _length,
        ),
      ),
      'eraser capture work observation failed',
    );
    if (_length > canvasEraserCorridorSoftLimit) {
      final inputLength = _length;
      for (
        var index = 0;
        index < canvasEraserCorridorResampleTarget;
        index += 1
      ) {
        final sourceIndex =
            (index * (inputLength - 1)) ~/
            (canvasEraserCorridorResampleTarget - 1);
        _storage[index] = _storage[sourceIndex];
      }
      for (
        var index = canvasEraserCorridorResampleTarget;
        index < inputLength;
        index += 1
      ) {
        _storage[index] = null;
      }
      _length = canvasEraserCorridorResampleTarget;
      assert(
        _recordWork(
          PointerEraserCaptureWorkEvent(
            kind: PointerEraserCaptureWorkKind.resampled,
            retainedPointCount: _length,
            retainedPrefixPointsTraversed: inputLength,
            retainedPrefixPointsCopied: _length,
          ),
        ),
        'eraser capture work observation failed',
      );
    } else {
      assert(
        _recordWork(
          PointerEraserCaptureWorkEvent(
            kind: PointerEraserCaptureWorkKind.ordinaryAppend,
            retainedPointCount: _length,
          ),
        ),
        'eraser capture work observation failed',
      );
    }
    return const PointerEraserSampleAdmission.admitted();
  }

  List<Offset> snapshot() {
    final snapshot = List<Offset>.unmodifiable(
      List<Offset>.generate(_length, (index) {
        final point = _storage[index];
        if (point == null) {
          throw StateError('eraser capture storage has a gap at $index');
        }
        return point;
      }),
    );
    assert(
      _recordWork(
        PointerEraserCaptureWorkEvent(
          kind: PointerEraserCaptureWorkKind.snapshotCreated,
          retainedPointCount: snapshot.length,
          retainedPrefixPointsTraversed: _length,
          retainedPrefixPointsCopied: _length,
        ),
      ),
      'eraser capture work observation failed',
    );
    return snapshot;
  }

  static bool _recordWork(PointerEraserCaptureWorkEvent event) {
    final sink = Zone.current[_eraserCaptureWorkZoneKey];
    if (sink is void Function(PointerEraserCaptureWorkEvent)) {
      sink(event);
    }
    return true;
  }
}

final class PointerEraserSampleAdmission {
  const PointerEraserSampleAdmission.admitted() : admitted = true;
  const PointerEraserSampleAdmission.duplicate() : admitted = false;

  final bool admitted;
}

final class EraserStartDecision {
  const EraserStartDecision.rejected() : admitted = false, eraser = null;

  const EraserStartDecision.admitted({required this.eraser}) : admitted = true;

  final bool admitted;
  final PointerEraserCapture? eraser;
}

final class EraserPreviewDecision {
  const EraserPreviewDecision.noChange()
    : changed = false,
      eraser = null,
      preview = null;

  const EraserPreviewDecision.changed({
    required this.eraser,
    required this.preview,
  }) : changed = true;

  final bool changed;
  final PointerEraserCapture? eraser;
  final CanvasEraserPreview? preview;
}

final class EraserTerminalDecision {
  const EraserTerminalDecision.cleanupOnly() : intent = null;

  EraserTerminalDecision.commit({
    required PointerSessionId sessionId,
    required PointerSessionToken pointerToken,
    required PointerEraserCapture eraser,
    required int corridorPointCount,
    required List<DeletionEntryFacts> erasedEntries,
  }) : intent = EraserCommitIntent(
         sessionId: sessionId,
         pointerToken: pointerToken,
         eraserThickness: eraser.thickness,
         corridorPointCount: corridorPointCount,
         erasedEntries: erasedEntries,
       );

  final EraserCommitIntent? intent;
}
