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
import '../store/document_store_kernel.dart';
import '../store/sparse_store_commit.dart';
import '../store/store_commit_finalization.dart';
import '../store/store_revision_delta.dart';
import 'commit_plan.dart';

typedef DocumentInstall =
    void Function(CommittedDocument document, StoreRevisionDelta delta);
typedef DocumentReplace =
    void Function(CommittedDocument document, StoreRevisionDelta delta);
typedef SparseDocumentInstall = void Function(PreparedSparseStoreCommit commit);
typedef DeletionSparseDocumentPrepare =
    PreparedDeletionSparseStoreInstall Function(
      PreparedSparseStoreCommit commit,
    );
typedef PreparedMaterializedDocumentInstall =
    void Function(PreparedMaterializedStoreCommit commit);
typedef SelectionEffectPrepare =
    PreparedSelectionEffect Function(
      CommitSelectionEffect effect,
      PreparedCommitDocument document,
    );
typedef SelectionEffectInstall = bool Function(PreparedSelectionEffect effect);
typedef OwnedSelectionEffectInstall =
    bool Function(LinkedHashSet<CanvasElementId> elementIds);

/// Distinct pre-resolver phases owned by the prepared commit boundary.
@visibleForTesting
enum DeletionCommitPreparationPhase {
  documentPreparation,
  revisionPreparation,
  actionInputSealing,
}

final class CommitDocumentInstallers {
  const CommitDocumentInstallers({
    required this.installDocument,
    required this.replaceDocument,
    required this.installSparseCommit,
    required this.installPreparedMaterializedCommit,
    this.prepareDeletionSparseInstall,
  });

  final DocumentInstall installDocument;
  final DocumentReplace replaceDocument;
  final SparseDocumentInstall installSparseCommit;
  final PreparedMaterializedDocumentInstall installPreparedMaterializedCommit;
  final DeletionSparseDocumentPrepare? prepareDeletionSparseInstall;
}

final class CommitSelectionInstallers {
  const CommitSelectionInstallers({
    required this.prepareSelectionEffect,
    required this.installSelectionEffect,
    this.installOwnedSelectionEffect,
  });

  final SelectionEffectPrepare prepareSelectionEffect;
  final SelectionEffectInstall installSelectionEffect;
  final OwnedSelectionEffectInstall? installOwnedSelectionEffect;
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

/// Work owned by the private deletion-only prepared package.
///
/// The events exist solely behind assertions and a Zone observer. They expose
/// lifecycle work to route tests without retaining a production counter or
/// widening the package into a transaction abstraction.
@visibleForTesting
enum PreparedDeletionApplyWorkEvent {
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
  static T observePreparedDeletionWork<T>(
    void Function(PreparedDeletionApplyWorkEvent event) sink,
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

  static bool _recordPreparedDeletionWork(
    PreparedDeletionApplyWorkEvent event,
  ) {
    final sink = Zone.current[_preparedDeletionWorkZoneKey];
    if (sink is void Function(PreparedDeletionApplyWorkEvent)) {
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
          replacedDocument: result.replacedDocument,
          effects: scope.observeEffects(result.effects),
          actionIntents: scope.observeActions(result.actionIntents),
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
    if (!plan.hasChanges) {
      return CommitDeliveryResult(shouldPublishState: false);
    }

    final state = _PreparedApplyState.prepare(
      document: document,
      plan: plan,
      prepareSelectionEffect: selectionInstallers.prepareSelectionEffect,
    );
    if (state.installsDocument) {
      _installPreparedDocument(
        state.document,
        documentReplaced: state.documentReplaced,
        documentInstallers: documentInstallers,
      );
    }
    final didChangeSelection = _installSelectionEffect(
      state.selectionEffect,
      selectionInstallers.installSelectionEffect,
    );
    return state.resultFor(didChangeSelection: didChangeSelection);
  }

  /// Prepares the deletion-only deferred install boundary.
  ///
  /// All validation and selection backing construction happen before a
  /// resolver is invoked. The returned package is package-private by export
  /// policy and can be consumed once only by the two deletion routes.
  PreparedDeletionApply prepareDeletion({
    required AcceptedCommitDocument document,
    required CommitPlan plan,
    required CommitDocumentInstallers documentInstallers,
    required CommitSelectionInstallers selectionInstallers,
  }) {
    if (!plan.hasChanges) {
      throw StateError('A deferred deletion requires a changed commit plan.');
    }
    final state = _PreparedApplyState.prepare(
      document: document,
      plan: plan,
      prepareSelectionEffect: selectionInstallers.prepareSelectionEffect,
    );
    final sparseInstall = switch (state.document) {
      PreparedSparseStoreDocument(:final commit) =>
        (documentInstallers.prepareDeletionSparseInstall ??
                _missingDeletionSparseInstall)
            .call(commit),
      _ => throw StateError(
        'A deferred deletion requires a sparse Store commit.',
      ),
    };
    final installOwnedSelectionEffect =
        selectionInstallers.installOwnedSelectionEffect ??
        _missingOwnedSelectionInstall;
    final prepared = PreparedDeletionApply._(
      state: state,
      sparseInstall: sparseInstall,
      installOwnedSelectionEffect: installOwnedSelectionEffect,
    );
    assert(
      _recordPreparedDeletionWork(PreparedDeletionApplyWorkEvent.prepared),
      'prepared deletion work observation failed',
    );
    return prepared;
  }
}

PreparedDeletionSparseStoreInstall _missingDeletionSparseInstall(
  PreparedSparseStoreCommit _,
) => throw StateError('Deletion Store preparation is unavailable.');

bool _missingOwnedSelectionInstall(LinkedHashSet<CanvasElementId> _) =>
    throw StateError('Deletion selection installation is unavailable.');

/// A single-use deletion-only install package.
///
/// It is not exported from the package and deliberately has no rollback or
/// generic transaction operations.
final class PreparedDeletionApply {
  PreparedDeletionApply._({
    required _PreparedApplyState state,
    required PreparedDeletionSparseStoreInstall sparseInstall,
    required OwnedSelectionEffectInstall installOwnedSelectionEffect,
  }) : _owned = _PreparedDeletionOwned(
         state: state,
         sparseInstall: sparseInstall,
         installOwnedSelectionEffect: installOwnedSelectionEffect,
       );

  _PreparedDeletionOwned? _owned;
  bool _terminal = false;

  CommitDeliveryResult consume() {
    final owned = _takeOwned();
    assert(
      CommitApplier._recordPreparedDeletionWork(
        PreparedDeletionApplyWorkEvent.consumed,
      ),
      'prepared deletion work observation failed',
    );
    final ownedSelectionIds = owned.state.selectionEffect
        ?.takeOwnedElementIds();
    if (ownedSelectionIds != null) {
      assert(
        CommitApplier._recordPreparedDeletionWork(
          PreparedDeletionApplyWorkEvent.selectionBackingTransferred,
        ),
        'prepared deletion work observation failed',
      );
    }
    owned.sparseInstall.consume();
    final didChangeSelection = ownedSelectionIds == null
        ? false
        : owned.installOwnedSelectionEffect(ownedSelectionIds);
    return owned.state.resultFor(didChangeSelection: didChangeSelection);
  }

  /// Releases a rejected resolver's private prepared state without rollback.
  void discard() {
    _takeOwned();
    assert(
      CommitApplier._recordPreparedDeletionWork(
        PreparedDeletionApplyWorkEvent.discarded,
      ),
      'prepared deletion work observation failed',
    );
  }

  _PreparedDeletionOwned _takeOwned() {
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
      CommitApplier._recordPreparedDeletionWork(
        PreparedDeletionApplyWorkEvent.ownershipReleased,
      ),
      'prepared deletion ownership release observation failed',
    );
    return owned;
  }
}

final class _PreparedDeletionOwned {
  const _PreparedDeletionOwned({
    required this.state,
    required this.sparseInstall,
    required this.installOwnedSelectionEffect,
  });

  final _PreparedApplyState state;
  final PreparedDeletionSparseStoreInstall sparseInstall;
  final OwnedSelectionEffectInstall installOwnedSelectionEffect;
}

void _installPreparedDocument(
  PreparedCommitDocument document, {
  required bool documentReplaced,
  required CommitDocumentInstallers documentInstallers,
}) {
  switch (document) {
    case PreparedMaterializedDocument(:final document, :final revisionDelta):
      if (documentReplaced) {
        documentInstallers.replaceDocument(document, revisionDelta);
      } else {
        documentInstallers.installDocument(document, revisionDelta);
      }
    case PreparedSparseStoreDocument():
      documentInstallers.installSparseCommit(document.commit);
    case PreparedMaterializedStoreDocument(:final commit):
      documentInstallers.installPreparedMaterializedCommit(commit);
    case PreparedUnchangedStoreDocument():
      break;
  }
}

final class _PreparedApplyState {
  _PreparedApplyState({
    required this.document,
    required this.installsDocument,
    required this.documentRevisionChanged,
    required this.documentReplaced,
    required this.deliveryEffects,
    required this.actionIntents,
    required this.selectionEffect,
  });

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

    return _PreparedApplyState(
      document: preparedDocument,
      installsDocument: installsDocument,
      documentRevisionChanged: documentRevisionChanged,
      documentReplaced: documentReplaced,
      deliveryEffects: deliveryEffects,
      actionIntents: actionIntents,
      selectionEffect: selectionEffect,
    );
  }

  final PreparedCommitDocument document;
  final bool installsDocument;
  final bool documentRevisionChanged;
  final bool documentReplaced;
  final List<CommitDeliveryEffect> deliveryEffects;
  final List<CommitActionIntent> actionIntents;
  final PreparedSelectionEffect? selectionEffect;

  CommitDeliveryResult resultFor({required bool didChangeSelection}) {
    final didAcceptChange = installsDocument || didChangeSelection;
    final shouldPublishState = documentRevisionChanged || didChangeSelection;
    if (!didAcceptChange) {
      return CommitDeliveryResult(shouldPublishState: false);
    }

    return CommitDeliveryResult.sealed(
      shouldPublishState: shouldPublishState,
      replacedDocument: documentReplaced,
      effects: deliveryEffects,
      actionIntents: shouldPublishState ? actionIntents : const [],
    );
  }
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

bool _installSelectionEffect(
  PreparedSelectionEffect? effect,
  SelectionEffectInstall install,
) {
  if (effect == null) {
    return false;
  }

  return install(effect);
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
