import 'dart:async';

import 'package:flutter/foundation.dart' show immutable, visibleForTesting;

import '../contracts/public/canvas_document.dart';
import '../contracts/public/canvas_element.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_metadata.dart';
import 'element_registry.dart';
import 'family_tables.dart';
import 'revision_state.dart';
import 'resource_table.dart';

enum StoreSparseCandidateEventKind {
  open,
  currentScalarRead,
  relationshipValidation,
  providedDeltaValidation,
  deferredValidation,
  acceptedFacts,
  coverageValidation,
  normalization,
  familyFreeze,
  resourceFreeze,
  structuralPublication,
  aggregatePublication,
  touchedFacts,
  touchedElementRead,
  touchedResourceRead,
  consume,
  discard,
}

enum StoreSparseCandidateReadSide { base, candidate }

@immutable
final class StoreSparseCandidateEvent {
  const StoreSparseCandidateEvent({
    required this.kind,
    this.subject,
    this.side,
  });

  final StoreSparseCandidateEventKind kind;
  final String? subject;
  final StoreSparseCandidateReadSide? side;
}

// This immutable aggregate owns committed document facts and derived variants
// together so row snapshots cannot become competing sources of truth. Its
// direct fact dependencies are the aggregate's payload, not separate concerns.
// ignore: coupling-between-object-classes, number-of-methods
final class CommittedDocument {
  static final Object _sparseCandidateEventZoneKey = Object();

  factory CommittedDocument.empty() {
    return CommittedDocument.fromStoreTables(
      camera: CanvasCamera.origin,
      background: const CanvasBackground(),
      palette: const CanvasPalette.defaults(),
      elements: ElementRegistry.empty(),
      metadata: const CanvasMetadata.empty(),
      resourceTable: const ResourceTable.empty(),
      revisions: const RevisionState(),
    );
  }

  factory CommittedDocument(CanvasDocument document) {
    return CommittedDocument.withRevisions(
      document,
      revisions: const RevisionState(),
    );
  }

  factory CommittedDocument.withRevisions(
    CanvasDocument document, {
    required RevisionState revisions,
  }) {
    final resourceTable = ResourceTable(
      document.resources,
      resourceRevision: revisions.resourceRevision,
    );

    return CommittedDocument._(
      camera: document.camera,
      background: document.background,
      palette: document.palette,
      elements: ElementRegistry(
        backgroundElements: document.backgroundElements,
        layers: document.layers,
      ),
      metadata: document.metadata,
      resourceTable: resourceTable,
      revisions: revisions,
    );
  }

  CommittedDocument._({
    required this.camera,
    required this.background,
    required this.palette,
    required this.elements,
    required this.metadata,
    required this.resourceTable,
    required this.revisions,
  }) {
    // This is the one immutable aggregate construction seam. Reporting here
    // lets candidate evidence also expose any accidental intermediate copy.
    recordSparseCandidateEvent(
      const StoreSparseCandidateEvent(
        kind: StoreSparseCandidateEventKind.aggregatePublication,
      ),
    );
  }

  factory CommittedDocument.fromStoreTables({
    required CanvasCamera camera,
    required CanvasBackground background,
    required CanvasPalette palette,
    required ElementRegistry elements,
    required CanvasMetadata metadata,
    required ResourceTable resourceTable,
    required RevisionState revisions,
  }) {
    return CommittedDocument._(
      camera: camera,
      background: background,
      palette: palette,
      elements: elements,
      metadata: metadata,
      resourceTable: resourceTable,
      revisions: revisions,
    );
  }

  // Sparse preparation reaches this factory only after the candidate has
  // normalized and frozen every changed subordinate owner.
  factory CommittedDocument.fromSparseStoreCandidate({
    required CanvasCamera camera,
    required CanvasBackground background,
    required CanvasPalette palette,
    required ElementRegistry elements,
    required CanvasMetadata metadata,
    required ResourceTable resourceTable,
    required RevisionState revisions,
  }) {
    return CommittedDocument._(
      camera: camera,
      background: background,
      palette: palette,
      elements: elements,
      metadata: metadata,
      resourceTable: resourceTable,
      revisions: revisions,
    );
  }

  @visibleForTesting
  static T observeSparseCandidateEvents<T>(
    void Function(StoreSparseCandidateEvent event) sink,
    T Function() operation,
  ) => runZoned(operation, zoneValues: {_sparseCandidateEventZoneKey: sink});

  static void recordSparseCandidateEvent(StoreSparseCandidateEvent event) {
    assert(() {
      final sink = Zone.current[_sparseCandidateEventZoneKey];
      if (sink is void Function(StoreSparseCandidateEvent)) {
        sink(event);
      }
      return true;
    }(), 'sparse candidate event observation failed');
  }

  final CanvasCamera camera;
  final CanvasBackground background;
  final CanvasPalette palette;
  final ElementRegistry elements;
  final CanvasMetadata metadata;
  final ResourceTable resourceTable;
  final RevisionState revisions;

  CanvasDocumentSummary get summary {
    return CanvasDocumentSummary(
      elementCount: elements.elementCount,
      layerCount: elements.layerTable.rows.length,
      resourceCount: resourceTable.count,
    );
  }

  StoreResourceDescriptorFacts? resourceDescriptor(CanvasResourceId id) {
    return resourceTable.descriptors[id];
  }

  CanvasElement? readSparseTouchedElement(
    CanvasElementId id, {
    required StoreSparseCandidateReadSide side,
  }) {
    recordSparseCandidateEvent(
      StoreSparseCandidateEvent(
        kind: StoreSparseCandidateEventKind.touchedElementRead,
        subject: id.value,
        side: side,
      ),
    );
    return FamilyTables.readSparseBase(() => elements.elementById(id));
  }

  StoreResourceDescriptorFacts? readSparseTouchedResource(
    CanvasResourceId id, {
    required StoreSparseCandidateReadSide side,
  }) {
    recordSparseCandidateEvent(
      StoreSparseCandidateEvent(
        kind: StoreSparseCandidateEventKind.touchedResourceRead,
        subject: id.value,
        side: side,
      ),
    );
    return resourceDescriptor(id);
  }

  CommittedDocument copyWith({
    CanvasCamera? camera,
    CanvasBackground? background,
    CanvasPalette? palette,
    ElementRegistry? elements,
    CanvasMetadata? metadata,
    ResourceTable? resourceTable,
    RevisionState? revisions,
  }) {
    return CommittedDocument._(
      camera: camera ?? this.camera,
      background: background ?? this.background,
      palette: palette ?? this.palette,
      elements: elements ?? this.elements,
      metadata: metadata ?? this.metadata,
      resourceTable: resourceTable ?? this.resourceTable,
      revisions: revisions ?? this.revisions,
    );
  }
}
