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
import '../store/committed_document.dart';
import '../store/sparse_store_commit.dart';
import '../store/store_commit_finalization.dart';
import '../store/store_revision_delta.dart';
import 'commit_plan.dart';

typedef DocumentInstall =
    void Function(CommittedDocument document, StoreRevisionDelta delta);
typedef DocumentReplace =
    void Function(CommittedDocument document, StoreRevisionDelta delta);
typedef SparseDocumentInstall = void Function(PreparedSparseStoreCommit commit);
typedef PreparedMaterializedDocumentInstall =
    void Function(PreparedMaterializedStoreCommit commit);
typedef SelectionEffectPrepare =
    PreparedSelectionEffect Function(
      CommitSelectionEffect effect,
      PreparedCommitDocument document,
    );
typedef SelectionEffectInstall = bool Function(PreparedSelectionEffect effect);

final class CommitDocumentInstallers {
  const CommitDocumentInstallers({
    required this.installDocument,
    required this.replaceDocument,
    required this.installSparseCommit,
    required this.installPreparedMaterializedCommit,
  });

  final DocumentInstall installDocument;
  final DocumentReplace replaceDocument;
  final SparseDocumentInstall installSparseCommit;
  final PreparedMaterializedDocumentInstall installPreparedMaterializedCommit;
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

final class CommitApplier {
  const CommitApplier();

  static final Object _sealedDeliveryWorkZoneKey = Object();

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
    final preparedDocument = _prepareDocument(document);
    final deliveryEffects = _deliveryEffectsFor(plan.effects);
    final actionIntents = plan.actionIntents;
    final selectionEffect = switch (plan.selectionEffect) {
      null => null,
      final effect => prepareSelectionEffect(effect, preparedDocument),
    };

    return _PreparedApplyState(
      document: preparedDocument,
      installsDocument: plan.revisionDelta.hasChanges,
      documentRevisionChanged: plan.revisionDelta.document,
      documentReplaced: plan.documentReplaced,
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
