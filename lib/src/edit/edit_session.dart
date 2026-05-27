import 'dart:ui';

// EditSession is the CanvasEdit handle and must name every DTO accepted by that
// public transaction surface; hiding those imports would make the mutation
// boundary less auditable.
// ignore_for_file: number-of-imports

import '../contracts/public/canvas_document.dart';
import '../contracts/public/canvas_element.dart';
import '../contracts/public/canvas_element_update.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_resource.dart';
import '../contracts/public/canvas_runtime.dart';
import '../store/store_revision_delta.dart';
import 'commit_plan.dart';
import 'draft_document.dart';

// CanvasEdit is intentionally represented by one session handle: the stale
// guard and draft reference must stay uniform across every public entry point.
// ignore: coupling-between-object-classes, number-of-methods
final class EditSession implements CanvasEdit {
  EditSession({required DraftDocument draft}) : _draft = draft;

  final DraftDocument _draft;
  bool _isClosed = false;

  bool get didChange => _draft.didChange;
  StoreRevisionDelta get revisionDelta => _draft.revisionDelta;
  CommitPlan get commitPlan => _draft.commitPlan;

  void close() {
    _isClosed = true;
  }

  @override
  CanvasDocument readDraftDocument() {
    _ensureActive();

    return _draft.readDocument();
  }

  @override
  CanvasDocumentSummary get draftSummary {
    _ensureActive();

    return _draft.summary;
  }

  @override
  bool ensureLayer(CanvasLayerId id, {int? index}) {
    _ensureActive();
    return _draft.ensureLayer(id, index: index);
  }

  @override
  CanvasElementId addElement(
    CanvasElement element, {
    CanvasLayerId? layerId,
    int? index,
  }) {
    _ensureActive();
    return _draft.addElement(element, layerId: layerId, index: index);
  }

  @override
  CanvasElementId addBackgroundElement(CanvasElement element, {int? index}) {
    _ensureActive();
    return _draft.addBackgroundElement(element, index: index);
  }

  @override
  bool updateElement(CanvasElementUpdate update) {
    _ensureActive();
    return _draft.updateElement(update);
  }

  @override
  bool removeElement(CanvasElementId id) {
    _ensureActive();
    return _draft.removeElement(id);
  }

  @override
  bool upsertResource(CanvasResource resource) {
    _ensureActive();
    return _draft.upsertResource(resource);
  }

  @override
  bool removeUnusedResource(CanvasResourceId id) {
    _ensureActive();
    return _draft.removeUnusedResource(id);
  }

  @override
  void setBackgroundColor(Color color) {
    _ensureActive();
    _draft.setBackgroundColor(color);
  }

  @override
  void setGrid(CanvasGrid grid) {
    _ensureActive();
    _draft.setGrid(grid);
  }

  @override
  void setPalette(CanvasPalette palette) {
    _ensureActive();
    _draft.setPalette(palette);
  }

  @override
  void setCameraOffset(Offset offset) {
    _ensureActive();
    _draft.setCameraOffset(offset);
  }

  @override
  CanvasClearResult clearContent({bool removeUnusedResources = false}) {
    _ensureActive();
    return _draft.clearContent(removeUnusedResources: removeUnusedResources);
  }

  @override
  void replaceDraftDocument(CanvasDocument document) {
    _ensureActive();
    _draft.replaceDocument(document);
  }

  void _ensureActive() {
    if (_isClosed) {
      throw StateError('CanvasEdit handle is stale.');
    }
  }
}
