// The atomic applier keeps its contract, store, and test-observation types
// together; splitting those owner boundaries would obscure the install order.
// ignore_for_file: number-of-imports

import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart' show visibleForTesting;

import '../contracts/internal/commit_delivery.dart';
import '../contracts/internal/commit_action_intent.dart';
import '../contracts/internal/prepared_selection_effect.dart';
import '../contracts/public/canvas_document.dart';
import '../contracts/public/canvas_ids.dart';
import '../store/committed_document.dart';
import '../store/sparse_store_commit.dart';
import '../store/store_commit_finalization.dart';
import '../store/store_revision_delta.dart';
import 'commit_plan.dart';

typedef PreparedDocumentInstall = void Function();
typedef DocumentInstallPrepare =
    PreparedDocumentInstall Function(
      PreparedCommitDocument document, {
      required bool documentReplaced,
    });
typedef SelectionEffectPrepare =
    PreparedSelectionEffect Function(
      CommitSelectionEffect effect,
      PreparedCommitDocument document,
    );
typedef SelectionEffectInstall = bool Function(PreparedSelectionInstall effect);

/// Distinct pre-resolver phases owned by the prepared commit boundary.
@visibleForTesting
enum DeletionCommitPreparationPhase {
  documentPreparation,
  revisionPreparation,
  actionInputSealing,
}

final class CommitDocumentInstallers {
  const CommitDocumentInstallers({required this.prepareDocumentInstall});

  final DocumentInstallPrepare prepareDocumentInstall;
}

final class CommitSelectionInstallers {
  const CommitSelectionInstallers({
    required this.prepareSelectionEffect,
    required this.installSelectionEffect,
  });

  final SelectionEffectPrepare prepareSelectionEffect;
  final SelectionEffectInstall installSelectionEffect;
}

sealed class AcceptedCommitDocument {
  const AcceptedCommitDocument({required this.revisionDelta});

  final StoreRevisionDelta revisionDelta;
}

final class AcceptedMaterializedDocument extends AcceptedCommitDocument {
  const AcceptedMaterializedDocument({
    required this.document,
    required super.revisionDelta,
  });

  final CanvasDocument document;
}

final class AcceptedSparseStoreDocument extends AcceptedCommitDocument {
  AcceptedSparseStoreDocument({required this.commit})
    : super(revisionDelta: commit.revisionDelta);

  final PreparedSparseStoreCommit commit;
}

final class AcceptedMaterializedStoreDocument extends AcceptedCommitDocument {
  AcceptedMaterializedStoreDocument({required this.commit})
    : super(revisionDelta: commit.revisionDelta);

  final PreparedMaterializedStoreCommit commit;
}

final class AcceptedUnchangedStoreDocument extends AcceptedCommitDocument {
  const AcceptedUnchangedStoreDocument()
    : super(revisionDelta: const StoreRevisionDelta());
}

sealed class PreparedCommitDocument {
  const PreparedCommitDocument({required this.revisionDelta});

  final StoreRevisionDelta revisionDelta;
}

final class PreparedMaterializedDocument extends PreparedCommitDocument {
  const PreparedMaterializedDocument({
    required this.document,
    required super.revisionDelta,
  });

  final CommittedDocument document;
}

final class PreparedSparseStoreDocument extends PreparedCommitDocument {
  PreparedSparseStoreDocument({required this.commit})
    : super(revisionDelta: commit.revisionDelta);

  final PreparedSparseStoreCommit commit;
}

final class PreparedMaterializedStoreDocument extends PreparedCommitDocument {
  PreparedMaterializedStoreDocument({required this.commit})
    : super(revisionDelta: commit.revisionDelta);

  final PreparedMaterializedStoreCommit commit;
}

final class PreparedUnchangedStoreDocument extends PreparedCommitDocument {
  const PreparedUnchangedStoreDocument()
    : super(revisionDelta: const StoreRevisionDelta());
}

/// Work owned by the private prepared interaction package.
///
/// The events exist solely behind assertions and a Zone observer. They expose
/// lifecycle work to route tests without retaining a production counter or
/// widening the package into a transaction abstraction.
@visibleForTesting
enum PreparedInteractionApplyWorkEvent {
  prepared,
  consumed,
  selectionBackingTransferred,
  ownershipReleased,
  discarded,
}

// Accepted document forms and the deletion-only bounded Store install meet at
// this one ordering owner; splitting them would hide the atomic install seam.
// ignore: coupling-between-object-classes
final class CommitApplier {
  const CommitApplier();

  static final Object _sealedDeliveryWorkZoneKey = Object();
  static final Object _preparedDeletionWorkZoneKey = Object();
  static final Object _deletionPreparationFailureZoneKey = Object();

  /// Observes the private deletion package's terminal lifecycle in tests.
  @visibleForTesting
  static T observePreparedInteractionWork<T>(
    void Function(PreparedInteractionApplyWorkEvent event) sink,
    T Function() operation,
  ) => runZoned(operation, zoneValues: {_preparedDeletionWorkZoneKey: sink});

  /// Causes one CommitApplier preparation phase to fail under asserts only.
  @visibleForTesting
  static T injectDeletionPreparationFailure<T>(
    DeletionCommitPreparationPhase phase,
    Error error,
    T Function() operation,
  ) => runZoned(
    operation,
    zoneValues: {
      _deletionPreparationFailureZoneKey: (phase: phase, error: error),
    },
  );

  static bool _throwInjectedDeletionPreparationFailure(
    DeletionCommitPreparationPhase expected,
  ) {
    final value = Zone.current[_deletionPreparationFailureZoneKey];
    if (value is ({DeletionCommitPreparationPhase phase, Error error}) &&
        value.phase == expected) {
      throw value.error;
    }
    return true;
  }

  static bool _recordPreparedInteractionWork(
    PreparedInteractionApplyWorkEvent event,
  ) {
    final sink = Zone.current[_preparedDeletionWorkZoneKey];
    if (sink is void Function(PreparedInteractionApplyWorkEvent)) {
      sink(event);
    }
    return true;
  }

  // This assert-only observer reports preparation and real sealed-collection
  // reads, so tests count owner work rather than self-reported loops.
  @visibleForTesting
  static T observeSealedDeliveryWork<T>(
    void Function(CommitSealedDeliveryWork work) sink,
    T Function() operation,
  ) {
    final scope = _SealedDeliveryWorkScope(sink);

    return runZoned(operation, zoneValues: {_sealedDeliveryWorkZoneKey: scope});
  }

  /// Wraps the immutable collections that RuntimeRoot is about to consume.
  ///
  /// This remains a no-op outside asserts; the wrapper lets the one work seam
  /// observe real RuntimeRoot reads even when a route augments a prepared
  /// result with its cleanup effects.
  @visibleForTesting
  static CommitDeliveryResult observeSealedDeliveryCollections(
    CommitDeliveryResult result,
  ) {
    var observed = result;
    assert(() {
      final scope = Zone.current[_sealedDeliveryWorkZoneKey];
      if (scope is _SealedDeliveryWorkScope) {
        observed = CommitDeliveryResult.sealed(
          shouldPublishState: result.shouldPublishState,
          didChangeSelection: result.didChangeSelection,
          replacedDocument: result.replacedDocument,
          effects: scope.observeEffects(result.effects),
          actionIntents: scope.observeActions(result.actionIntents),
          acceptedTouchedElementIds: result.acceptedTouchedElementIds,
        );
      }
      return true;
    }(), 'sealed delivery work observation failed');
    return observed;
  }

  @visibleForTesting
  static bool recordSealedDeliveryPhase(CommitSealedDeliveryPhase phase) {
    final scope = Zone.current[_sealedDeliveryWorkZoneKey];
    if (scope is _SealedDeliveryWorkScope) {
      scope.currentPhase = phase;
    }
    return true;
  }

  CommitDeliveryResult apply({
    required AcceptedCommitDocument document,
    required CommitPlan plan,
    required CommitDocumentInstallers documentInstallers,
    required CommitSelectionInstallers selectionInstallers,
  }) {
    return prepareInteraction(
      document: document,
      plan: plan,
      documentInstallers: documentInstallers,
      selectionInstallers: selectionInstallers,
    ).consume();
  }

  /// Prepares every current interaction route for one terminal consume.
  PreparedInteractionApply prepareInteraction({
    required AcceptedCommitDocument document,
    required CommitPlan plan,
    required CommitDocumentInstallers documentInstallers,
    required CommitSelectionInstallers selectionInstallers,
  }) {
    if (!plan.hasChanges) {
      return PreparedInteractionApply.noOp();
    }
    final state = _PreparedApplyState.prepare(
      document: document,
      plan: plan,
      prepareSelectionEffect: selectionInstallers.prepareSelectionEffect,
    );
    final installDocument = state.installsDocument
        ? documentInstallers.prepareDocumentInstall(
            state.document,
            documentReplaced: state.documentReplaced,
          )
        : () => 0;
    final installSelection = switch (state.selectionInstall) {
      final effect? when effect.didChange =>
        () => selectionInstallers.installSelectionEffect(effect),
      _ => () => false,
    };
    final prepared = PreparedInteractionApply._(
      state: state,
      installDocument: installDocument,
      installSelection: installSelection,
    );
    assert(
      _recordPreparedInteractionWork(
        PreparedInteractionApplyWorkEvent.prepared,
      ),
      'prepared interaction work observation failed',
    );
    return prepared;
  }
}

/// A single-use prepared interaction install package.
///
/// It is not exported from the package and deliberately has no rollback or
/// generic transaction operations.
final class PreparedInteractionApply {
  PreparedInteractionApply._({
    required _PreparedApplyState state,
    required void Function() installDocument,
    required bool Function() installSelection,
  }) : _owned = _PreparedInteractionOwned(
         state: state,
         installDocument: installDocument,
         installSelection: installSelection,
       );

  PreparedInteractionApply.noOp()
    : _owned = _PreparedInteractionOwned(
        state: _PreparedApplyState.noOp(),
        installDocument: () => 0,
        installSelection: () => false,
      );

  _PreparedInteractionOwned? _owned;
  bool _terminal = false;

  CommitDeliveryResult consume() {
    final owned = _takeOwned();
    assert(
      CommitApplier._recordPreparedInteractionWork(
        PreparedInteractionApplyWorkEvent.consumed,
      ),
      'prepared deletion work observation failed',
    );
    owned.installDocument();
    owned.installSelection();
    return owned.state.result;
  }

  /// Releases a rejected resolver's private prepared state without rollback.
  void discard() {
    _takeOwned();
    assert(
      CommitApplier._recordPreparedInteractionWork(
        PreparedInteractionApplyWorkEvent.discarded,
      ),
      'prepared deletion work observation failed',
    );
  }

  _PreparedInteractionOwned _takeOwned() {
    if (_terminal) {
      throw StateError('A prepared deletion can only be consumed once.');
    }
    _terminal = true;
    final owned = _owned;
    if (owned == null) {
      throw StateError('A prepared deletion has no owned install state.');
    }
    _owned = null;
    assert(
      CommitApplier._recordPreparedInteractionWork(
        PreparedInteractionApplyWorkEvent.ownershipReleased,
      ),
      'prepared deletion ownership release observation failed',
    );
    return owned;
  }
}

final class _PreparedInteractionOwned {
  const _PreparedInteractionOwned({
    required this.state,
    required this.installDocument,
    required this.installSelection,
  });

  final _PreparedApplyState state;
  final void Function() installDocument;
  final bool Function() installSelection;
}

// This state deliberately keeps document, selection transfer, and sealed
// result facts together so no fallible preparation crosses the owner tail.
// ignore: coupling-between-object-classes, reason: Atomic preparation needs the complete owner facts.
final class _PreparedApplyState {
  _PreparedApplyState({
    required this.document,
    required this.installsDocument,
    required this.documentRevisionChanged,
    required this.documentReplaced,
    required this.deliveryEffects,
    required this.actionIntents,
    required this.selectionInstall,
    required this.result,
  });

  factory _PreparedApplyState.noOp() => _PreparedApplyState(
    document: const PreparedUnchangedStoreDocument(),
    installsDocument: false,
    documentRevisionChanged: false,
    documentReplaced: false,
    deliveryEffects: const [],
    actionIntents: const [],
    selectionInstall: null,
    result: CommitDeliveryResult(shouldPublishState: false),
  );

  // ignore: halstead-volume, source-lines-of-code, reason: Preparation order is the atomicity boundary.
  factory _PreparedApplyState.prepare({
    required AcceptedCommitDocument document,
    required CommitPlan plan,
    required SelectionEffectPrepare prepareSelectionEffect,
  }) {
    assert(
      CommitApplier._throwInjectedDeletionPreparationFailure(
        DeletionCommitPreparationPhase.documentPreparation,
      ),
      'deletion document preparation injection did not complete',
    );
    final preparedDocument = _prepareDocument(document);
    final deliveryEffects = _deliveryEffectsFor(plan.effects);
    assert(
      CommitApplier._throwInjectedDeletionPreparationFailure(
        DeletionCommitPreparationPhase.revisionPreparation,
      ),
      'deletion revision preparation injection did not complete',
    );
    final installsDocument = plan.revisionDelta.hasChanges;
    final documentRevisionChanged = plan.revisionDelta.document;
    final documentReplaced = plan.documentReplaced;
    assert(
      CommitApplier._throwInjectedDeletionPreparationFailure(
        DeletionCommitPreparationPhase.actionInputSealing,
      ),
      'deletion action input sealing injection did not complete',
    );
    final actionIntents = plan.actionIntents;
    final selectionEffect = switch (plan.selectionEffect) {
      null => null,
      final effect => prepareSelectionEffect(effect, preparedDocument),
    };
    final selectionInstall = selectionEffect?.transferOwnership();
    if (selectionInstall != null) {
      assert(
        CommitApplier._recordPreparedInteractionWork(
          PreparedInteractionApplyWorkEvent.selectionBackingTransferred,
        ),
        'prepared selection transfer observation failed',
      );
    }
    final didChangeSelection = selectionInstall?.didChange ?? false;
    final result = _resultFor(
      installsDocument: installsDocument,
      documentRevisionChanged: documentRevisionChanged,
      documentReplaced: documentReplaced,
      didChangeSelection: didChangeSelection,
      acceptedTouchedElementIds: plan.touchedSet.elementIds,
      deliveryEffects: deliveryEffects,
      actionIntents: actionIntents,
    );

    return _PreparedApplyState(
      document: preparedDocument,
      installsDocument: installsDocument,
      documentRevisionChanged: documentRevisionChanged,
      documentReplaced: documentReplaced,
      deliveryEffects: deliveryEffects,
      actionIntents: actionIntents,
      selectionInstall: selectionInstall,
      result: result,
    );
  }

  final PreparedCommitDocument document;
  final bool installsDocument;
  final bool documentRevisionChanged;
  final bool documentReplaced;
  final List<CommitDeliveryEffect> deliveryEffects;
  final List<CommitActionIntent> actionIntents;
  final PreparedSelectionInstall? selectionInstall;
  final CommitDeliveryResult result;
}

// ignore: number-of-parameters, reason: The sealed result is derived from these one-time prepared facts.
CommitDeliveryResult _resultFor({
  required bool installsDocument,
  required bool documentRevisionChanged,
  required bool documentReplaced,
  required bool didChangeSelection,
  required Iterable<CanvasElementId> acceptedTouchedElementIds,
  required List<CommitDeliveryEffect> deliveryEffects,
  required List<CommitActionIntent> actionIntents,
}) {
  final didAcceptChange = installsDocument || didChangeSelection;
  final shouldPublishState = documentRevisionChanged || didChangeSelection;
  if (!didAcceptChange) {
    return CommitDeliveryResult(shouldPublishState: false);
  }

  return CommitDeliveryResult.sealed(
    shouldPublishState: shouldPublishState,
    didChangeSelection: didChangeSelection,
    replacedDocument: documentReplaced,
    effects: deliveryEffects,
    actionIntents: shouldPublishState ? actionIntents : const [],
    acceptedTouchedElementIds: Set.unmodifiable(acceptedTouchedElementIds),
  );
}

enum CommitSealedDeliveryPhase { spatial, resource, repaint, action, observer }

@visibleForTesting
final class CommitSealedDeliveryPhaseWork {
  const CommitSealedDeliveryPhaseWork({
    required this.effectLengthReads,
    required this.effectIterations,
    required this.effectElements,
    required this.actionLengthReads,
    required this.actionIterations,
    required this.actionElements,
  });

  final int effectLengthReads;
  final int effectIterations;
  final int effectElements;
  final int actionLengthReads;
  final int actionIterations;
  final int actionElements;
}

@visibleForTesting
final class CommitSealedDeliveryWork {
  const CommitSealedDeliveryWork({
    required this.preparations,
    required this.effectLengthReads,
    required this.effectIterations,
    required this.effectElements,
    required this.actionLengthReads,
    required this.actionIterations,
    required this.actionElements,
    required this.phaseWork,
  });

  final int preparations;
  final int effectLengthReads;
  final int effectIterations;
  final int effectElements;
  final int actionLengthReads;
  final int actionIterations;
  final int actionElements;
  final Map<CommitSealedDeliveryPhase, CommitSealedDeliveryPhaseWork> phaseWork;
}

final class _SealedDeliveryWorkScope {
  _SealedDeliveryWorkScope(this._sink);

  final void Function(CommitSealedDeliveryWork work) _sink;
  int preparations = 0;
  int effectLengthReads = 0;
  int effectIterations = 0;
  int effectElements = 0;
  int actionLengthReads = 0;
  int actionIterations = 0;
  int actionElements = 0;
  CommitSealedDeliveryPhase? currentPhase;
  final Map<CommitSealedDeliveryPhase, _SealedDeliveryReadCounts> _phaseWork =
      {};

  void recordPreparation() {
    preparations += 1;
    _report();
  }

  List<CommitDeliveryEffect> observeEffects(
    List<CommitDeliveryEffect> effects,
  ) => _ObservedSealedList(
    effects,
    onLengthRead: () {
      effectLengthReads += 1;
      _currentPhaseWork.effectLengthReads += 1;
      _report();
    },
    onIteration: () {
      effectIterations += 1;
      _currentPhaseWork.effectIterations += 1;
      _report();
    },
    onElement: () {
      effectElements += 1;
      _currentPhaseWork.effectElements += 1;
      _report();
    },
  );

  List<CommitActionIntent> observeActions(List<CommitActionIntent> actions) =>
      _ObservedSealedList(
        actions,
        onLengthRead: () {
          actionLengthReads += 1;
          _currentPhaseWork.actionLengthReads += 1;
          _report();
        },
        onIteration: () {
          actionIterations += 1;
          _currentPhaseWork.actionIterations += 1;
          _report();
        },
        onElement: () {
          actionElements += 1;
          _currentPhaseWork.actionElements += 1;
          _report();
        },
      );

  void _report() => _sink(snapshot());

  _SealedDeliveryReadCounts get _currentPhaseWork {
    final phase = currentPhase;
    if (phase == null) {
      throw StateError('Sealed delivery read occurred without an owner phase.');
    }
    return _phaseWork.putIfAbsent(phase, _SealedDeliveryReadCounts.new);
  }

  CommitSealedDeliveryWork snapshot() => CommitSealedDeliveryWork(
    preparations: preparations,
    effectLengthReads: effectLengthReads,
    effectIterations: effectIterations,
    effectElements: effectElements,
    actionIterations: actionIterations,
    actionElements: actionElements,
    actionLengthReads: actionLengthReads,
    phaseWork: Map.unmodifiable({
      for (final entry in _phaseWork.entries)
        entry.key: CommitSealedDeliveryPhaseWork(
          effectLengthReads: entry.value.effectLengthReads,
          effectIterations: entry.value.effectIterations,
          effectElements: entry.value.effectElements,
          actionLengthReads: entry.value.actionLengthReads,
          actionIterations: entry.value.actionIterations,
          actionElements: entry.value.actionElements,
        ),
    }),
  );
}

final class _SealedDeliveryReadCounts {
  int effectLengthReads = 0;
  int effectIterations = 0;
  int effectElements = 0;
  int actionLengthReads = 0;
  int actionIterations = 0;
  int actionElements = 0;
}

final class _ObservedSealedList<T> extends ListBase<T> {
  _ObservedSealedList(
    this._values, {
    required this.onLengthRead,
    required this.onIteration,
    required this.onElement,
  });

  final List<T> _values;
  final void Function() onLengthRead;
  final void Function() onIteration;
  final void Function() onElement;

  @override
  int get length {
    onLengthRead();
    return _values.length;
  }

  @override
  T operator [](int index) {
    onElement();
    return _values[index];
  }

  @override
  set length(int value) => throw UnsupportedError('sealed list is immutable');

  @override
  void operator []=(int index, T value) =>
      throw UnsupportedError('sealed list is immutable');

  @override
  Iterator<T> get iterator {
    onIteration();
    return _ObservedSealedIterator(_values.iterator, onElement);
  }
}

final class _ObservedSealedIterator<T> implements Iterator<T> {
  _ObservedSealedIterator(this._delegate, this._onElement);

  final Iterator<T> _delegate;
  final void Function() _onElement;

  @override
  T get current => _delegate.current;

  @override
  bool moveNext() {
    final hasElement = _delegate.moveNext();
    if (hasElement) {
      _onElement();
    }
    return hasElement;
  }
}

PreparedCommitDocument _prepareDocument(AcceptedCommitDocument document) {
  return switch (document) {
    AcceptedMaterializedDocument(:final document, :final revisionDelta) =>
      PreparedMaterializedDocument(
        document: CommittedDocument(document),
        revisionDelta: revisionDelta,
      ),
    AcceptedSparseStoreDocument(:final commit) => PreparedSparseStoreDocument(
      commit: commit,
    ),
    AcceptedMaterializedStoreDocument(:final commit) =>
      PreparedMaterializedStoreDocument(commit: commit),
    AcceptedUnchangedStoreDocument() => const PreparedUnchangedStoreDocument(),
  };
}

List<CommitDeliveryEffect> _deliveryEffectsFor(List<CommitEffect> effects) {
  final sealed = List<CommitDeliveryEffect>.unmodifiable(
    effects.map(_deliveryEffectFor),
  );
  assert(() {
    final scope = Zone.current[CommitApplier._sealedDeliveryWorkZoneKey];
    if (scope is _SealedDeliveryWorkScope) {
      scope.recordPreparation();
    }
    return true;
  }(), 'sealed delivery work observation failed');

  return sealed;
}

CommitDeliveryEffect _deliveryEffectFor(CommitEffect effect) {
  return switch (effect) {
    ProjectionEffect() => const ProjectionDeliveryEffect(),
    SpatialEffect(:final touchedSet) => SpatialDeliveryEffect(
      touchedSet: touchedSet,
    ),
    ResourceEffect(:final touchedSet) => ResourceDeliveryEffect(
      touchedSet: touchedSet,
    ),
    RepaintEffect(:final mainCanvas, :final overlayCanvas) =>
      RepaintDeliveryEffect(
        mainCanvas: mainCanvas,
        overlayCanvas: overlayCanvas,
      ),
    SelectionEffect() => const SelectionDeliveryEffect(),
    PublicStateEffect() => const PublicStateDeliveryEffect(),
  };
}
