// Runtime-facing public ports stay together so the package exposes one coherent
// runtime contract instead of metric-shaped fragments.
// ignore_for_file: type=metrics

import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'canvas_actions.dart';
import 'canvas_diagnostics.dart';
import 'canvas_document.dart';
import 'canvas_element.dart';
import 'canvas_element_update.dart';
import 'canvas_ids.dart';
import 'canvas_pointer.dart';
import 'canvas_preview.dart';
import 'canvas_resource.dart';
import 'canvas_tools.dart';

final class CanvasRuntime {
  CanvasRuntime({
    CanvasDocument? initialDocument,
    CanvasRuntimeConfig config = const CanvasRuntimeConfig(),
  });

  CanvasDocument readDocument() => throw UnimplementedError();
  ValueListenable<CanvasRuntimeState> get state => throw UnimplementedError();
  CanvasEditPort get edits => throw UnimplementedError();
  CanvasSelectionPort get selection => throw UnimplementedError();
  CanvasToolPort get tools => throw UnimplementedError();
  CanvasCommandPort get commands => throw UnimplementedError();
  CanvasCameraPort get camera => throw UnimplementedError();
  CanvasResourcePort get resources => throw UnimplementedError();
  CanvasPreviewState get preview => throw UnimplementedError();
  Stream<CanvasActionCommitted> get actions => throw UnimplementedError();
  Stream<CanvasContextActionRequested> get contextActionRequests =>
      throw UnimplementedError();
  CanvasElementId generateElementId() => throw UnimplementedError();
  CanvasLayerId generateLayerId() => throw UnimplementedError();
  CanvasResourceId generateResourceId() => throw UnimplementedError();
  void dispose() => throw UnimplementedError();
}

final class CanvasRuntimeConfig {
  const CanvasRuntimeConfig({
    this.pointerPolicy = CanvasPointerPolicy.defaultPolicy,
    this.initialMode = CanvasInteractionMode.move,
    this.initialDrawStyle = CanvasDrawStyle.defaultStyle,
    this.clearSelectionOnDrawModeEnter = false,
    this.moveCommitResolver,
    this.diagnosticPolicy = const CanvasDiagnosticPolicy.disabled(),
  });

  final CanvasPointerPolicy pointerPolicy;
  final CanvasInteractionMode initialMode;
  final CanvasDrawStyle initialDrawStyle;
  final bool clearSelectionOnDrawModeEnter;
  final CanvasMoveCommitResolver? moveCommitResolver;
  final CanvasDiagnosticPolicy diagnosticPolicy;
}

@immutable
final class CanvasRuntimeState {
  const CanvasRuntimeState({required this.revisions, required this.summary});
  final CanvasRuntimeRevisions revisions;
  final CanvasRuntimeSummary summary;

  @override
  bool operator ==(Object other) {
    return other is CanvasRuntimeState &&
        other.revisions == revisions &&
        other.summary == summary;
  }

  @override
  int get hashCode => Object.hash(revisions, summary);
}

@immutable
final class CanvasRuntimeRevisions {
  const CanvasRuntimeRevisions({
    required this.document,
    required this.selection,
    required this.preview,
    required this.viewCamera,
    required this.resourceVisual,
    required this.interaction,
    required this.epoch,
  });

  final int document;
  final int selection;
  final int preview;
  final int viewCamera;
  final int resourceVisual;
  final int interaction;
  final int epoch;

  @override
  bool operator ==(Object other) {
    return other is CanvasRuntimeRevisions &&
        other.document == document &&
        other.selection == selection &&
        other.preview == preview &&
        other.viewCamera == viewCamera &&
        other.resourceVisual == resourceVisual &&
        other.interaction == interaction &&
        other.epoch == epoch;
  }

  @override
  int get hashCode {
    return Object.hash(
      document,
      selection,
      preview,
      viewCamera,
      resourceVisual,
      interaction,
      epoch,
    );
  }
}

@immutable
final class CanvasRuntimeSummary {
  const CanvasRuntimeSummary({
    required this.elementCount,
    required this.layerCount,
    required this.resourceCount,
    required this.selectedCount,
  });

  final int elementCount;
  final int layerCount;
  final int resourceCount;
  final int selectedCount;

  @override
  bool operator ==(Object other) {
    return other is CanvasRuntimeSummary &&
        other.elementCount == elementCount &&
        other.layerCount == layerCount &&
        other.resourceCount == resourceCount &&
        other.selectedCount == selectedCount;
  }

  @override
  int get hashCode {
    return Object.hash(elementCount, layerCount, resourceCount, selectedCount);
  }
}

abstract interface class CanvasEditPort {
  T edit<T>(T Function(CanvasEdit edit) fn);
  void loadDocument(CanvasDocument document);
}

abstract interface class CanvasEdit {
  CanvasDocument readDraftDocument();
  CanvasDocumentSummary get draftSummary;
  bool ensureLayer(CanvasLayerId id, {int? index});
  CanvasElementId addElement(
    CanvasElement element, {
    CanvasLayerId? layerId,
    int? index,
  });
  CanvasElementId addBackgroundElement(CanvasElement element, {int? index});
  bool updateElement(CanvasElementUpdate update);
  bool removeElement(CanvasElementId id);
  bool upsertResource(CanvasResource resource);
  bool removeUnusedResource(CanvasResourceId id);
  void setBackgroundColor(Color color);
  void setGrid(CanvasGrid grid);
  void setPalette(CanvasPalette palette);
  void setCameraOffset(Offset offset);
  CanvasClearResult clearContent({bool removeUnusedResources = false});
  void replaceDraftDocument(CanvasDocument document);
}

final class CanvasClearResult {
  CanvasClearResult({
    required Iterable<CanvasElementId> removedElementIds,
    required Iterable<CanvasResourceId> removedResourceIds,
    required this.didClearContent,
  }) : _removedElementIds = List.unmodifiable(removedElementIds),
       _removedResourceIds = List.unmodifiable(removedResourceIds);

  final List<CanvasElementId> _removedElementIds;
  final List<CanvasResourceId> _removedResourceIds;
  final bool didClearContent;
  List<CanvasElementId> get removedElementIds => _removedElementIds;
  List<CanvasResourceId> get removedResourceIds => _removedResourceIds;
}

abstract interface class CanvasCommandPort {
  bool removeElement(CanvasElementId id, {int? timestampMs});
  bool commitTextEdit(
    CanvasInteractionRequestId requestId,
    String newText, {
    int? timestampMs,
  });
  CanvasClearResult clearContent({
    bool removeUnusedResources = false,
    int? timestampMs,
  });
}

abstract interface class CanvasSelectionPort {
  Set<CanvasElementId> get selectedElementIds;
  void setSelection(Iterable<CanvasElementId> ids);
  void toggleSelection(CanvasElementId id);
  void clearSelection();
  void selectAll({bool onlySelectable = true});
  void moveSelection(Offset delta, {int? timestampMs});
  void rotateSelectionClockwise({int? timestampMs});
  void rotateSelectionCounterClockwise({int? timestampMs});
  void flipSelectionVertical({int? timestampMs});
  void flipSelectionHorizontal({int? timestampMs});
  void deleteSelection({int? timestampMs});
}

abstract interface class CanvasCameraPort {
  CanvasCamera get camera;
  Offset get offset;
  void setOffset(Offset offset);
  void panBy(Offset delta);
}
