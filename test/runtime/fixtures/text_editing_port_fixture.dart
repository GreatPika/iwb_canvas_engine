import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_contract_limits.dart';
import 'package:iwb_canvas_engine/src/frame/frame_text_layout_measurer.dart';
import 'package:iwb_canvas_engine/src/frame/render_element_record.dart';
import 'package:iwb_canvas_engine/src/edit/commit_applier.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';
// This one cohesive runtime fixture observes both the Store pair seam and its
// existing committed-document preparation trace; a second fixture would hide
// their required causal order.
// ignore_for_file: number-of-imports
import 'package:iwb_canvas_engine/src/store/committed_document.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';
import 'package:iwb_canvas_engine/src/store/sparse_store_commit.dart';
import '../../support/accept_commit.dart';
import '../../support/runtime_root_with_committed_document_seed.dart';

// The fixture's one registration point lists every public text-session witness
// so its coverage boundary remains explicit rather than hidden in test glue.
// ignore: halstead-volume, source-lines-of-code
void main() {
  _testCandidateLookup();
  _testEmptyPolicyDeletion();
  _testRejectedEmptyPolicyDeletionRetainsDraft();
  _testEmptyPolicyDeletionResolverFailuresRetainDraft();
  _testEmptyPolicyDeletionPreparationFailureRetainsDraft();
  _testEmptyPolicyDeletionDelivery();
  _testEmptyPolicyDeletionCloseFailureRemainsCommitted();
  _testNonTextCandidateLookup();
  _testReadOnlyAdmission();
  _testNewTextAdmission();
  _testNewTextDelivery();
  _testSingleActiveAdmission();
  _testIdAdmission();
  _testLiveUpdateRemeasuresGeometry();
  _testFormattingDraftCommitsOneCompleteUpdate();
  _testFormattingNoOpAndCancelAreSilent();
  _testFormattedDraftGeometryMatchesAcceptedFrame();
  _testRuntimeDefaultFontFamilyIsEffectiveButNotStored();
  _testLiveGeometryPreservesTextAlignmentAnchor();
  _testRuntimeUsesMeasuredLayoutBoundary();
  _testActiveSessionPublishesLiveUpdates();
  _testChangedTextListenerRunsAfterOuterDelivery();
  _testLateCloseListenerCanDisposeRuntime();
  _testChangedTextListenerFailureReportsAndContinuesDelivery();
  _testTypedFinishReportsNoActiveSession();
  _testDirectTerminalInputAndSharedValidation();
  _testSessionCommitDelegatesToCommandPath();
  _testCommitPreservesTextAlignmentAnchor();
  _testDirectCommandCommitClearsActiveSession();
  _testDirectCommandCommitWithoutActiveSessionKeepsCloseStatePrivate();
  _testSessionNoOpCommitUsesCommandPath();
  _testSessionCancelPreservesDraftForRetry();
  _testCandidateStateReusedAndPrunedAfterCommit();
  _testStaleCandidateStatePruned();
  _testStaleCommitRetainsDraft();
  _testDirectStaleCommandRetainsActiveSession();
  _testRemovalAndSameIdReplacementRetainStaleDrafts();
  _testUnrelatedDocumentRevisionIsObservationOnly();
  _testUnrelatedDocumentRevisionPreservesSuppressionIdentity();
  _testPreparedTextFactsAreExactBeforeInstall();
  _testUnifiedSessionCommitRequestAndLeaseOrder();
  _testFailedPreparePreservesActiveSessionForRetry();
  _testValidationFailurePreservesActiveSession();
  _testSuccessfulLoadClearsActiveSession();
  _testFailedLoadPreservesActiveSession();
  _testDisposedRuntimeRejectsTextEditingPortOperations();
  _testDisposedRuntimeRejectsTextEditingSessionCallbacks();
}

// The creation lifecycle needs one registration group because the public
// session, guard, placement, request, action and retry facts share its setup.
// Splitting it only for metrics would hide those causal witnesses.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _testNewTextAdmission() {
  test(
    'new text admission stays transient until one accepted insertion',
    () async {
      final scenario = _Scenario();
      final seed = CanvasTextElement(
        id: CanvasElementId('new-text'),
        revision: 7,
        text: 'seed',
        fontSize: 18,
        color: const Color(0xFF224466),
        textDirection: TextDirection.ltr,
        transform: CanvasTransform.translation(const Offset(12, 16)),
      );
      try {
        final admission = scenario.root.textEditing.startNew(seed);
        final session = _expectStartSuccess(admission);

        expect(session.origin, CanvasTextEditOrigin.newElement);
        expect(session.elementRevision, seed.revision);
        expect(session.generation, 0);
        expect(session.initialText, 'seed');
        expect(_containsElement(scenario.root, seed.id), isFalse);
        expect(scenario.root.readDocument().layers, hasLength(1));

        expect(session.commit(), isTrue);
        final inserted = scenario.root
            .readDocument()
            .layers
            .single
            .elements
            .whereType<CanvasTextElement>()
            .singleWhere((element) => element.id == seed.id);
        _expectCompleteTextElement(inserted, seed);
        expect(scenario.actions.single.type, CanvasActionType.createText);
        final payload =
            scenario.actions.single.payload as CanvasTextCreateActionPayload;
        expect(payload.requestId, session.requestId);
        expect(payload.createdTextLength, seed.text.length);
      } finally {
        await scenario.dispose();
      }
    },
  );

  test(
    'each released new session has an issued request matching its proposal',
    () async {
      final requests = <CanvasTextCreateCommitRequest>[];
      final scenario = _Scenario(
        config: CanvasRuntimeConfig(
          commitResolver: (request) {
            if (request is CanvasTextCreateCommitRequest) requests.add(request);
            return acceptCommit(request);
          },
        ),
      );
      try {
        final first = _expectStartSuccess(
          scenario.root.textEditing.startNew(
            _newTextSeed(id: CanvasElementId('issued-new-first')),
          ),
        );
        expect(first.commit(), isTrue);
        final second = _expectStartSuccess(
          scenario.root.textEditing.startNew(
            _newTextSeed(id: CanvasElementId('issued-new-second')),
          ),
        );
        expect(second.commit(), isTrue);

        expect(first.requestId, isNot(second.requestId));
        expect(requests.map((request) => request.requestId), [
          first.requestId,
          second.requestId,
        ]);
        expect(
          scenario.actions.map(
            (action) =>
                (action.payload as CanvasTextCreateActionPayload).requestId,
          ),
          [first.requestId, second.requestId],
        );
      } finally {
        await scenario.dispose();
      }
    },
  );

  test(
    'new text uses shared slot refusal and duplicate-id admission',
    () async {
      final scenario = _Scenario();
      final seed = _newTextSeed(id: CanvasElementId('new-admission'));
      try {
        scenario.root.textEditing.setReadOnly(true);
        await _observeAdmissionRefusal(
          scenario,
          () => scenario.root.textEditing.startNew(seed),
          reason: CanvasTextEditStartRefusalReason.readOnly,
        );
        scenario.root.textEditing.setReadOnly(false);

        final active = _expectStartSuccess(
          scenario.root.textEditing.startNew(seed),
        );
        active.updateText('retained draft');
        active.updateFormatting(isBold: true);
        await _observeAdmissionRefusal(
          scenario,
          () => scenario.root.textEditing.startNew(
            _newTextSeed(id: CanvasElementId('competing-new')),
          ),
          reason: CanvasTextEditStartRefusalReason.anotherSessionActive,
          expectedActive: active,
        );
        active.dismiss();

        final existing = _expectStartSuccess(
          scenario.root.textEditing.startForElement(_textId),
        );
        expect(existing.origin, CanvasTextEditOrigin.existing);
        existing.updateText('retained existing draft');
        await _observeAdmissionRefusal(
          scenario,
          () => scenario.root.textEditing.startNew(
            _newTextSeed(id: CanvasElementId('competing-existing')),
          ),
          reason: CanvasTextEditStartRefusalReason.anotherSessionActive,
          expectedActive: existing,
        );
        _makeTextRequestStale(scenario);
        await _observeAdmissionRefusal(
          scenario,
          () => scenario.root.textEditing.startNew(
            _newTextSeed(id: CanvasElementId('competing-stale-existing')),
          ),
          reason: CanvasTextEditStartRefusalReason.anotherSessionActive,
          expectedActive: existing,
        );
        expect(existing.liveText, 'retained existing draft');
        existing.dismiss();

        _expectStartRefusal(
          scenario.root.textEditing.startNew(_textElement(scenario.root)),
          CanvasTextEditStartRefusalReason.alreadyExists,
        );
        final staleNew = _expectStartSuccess(
          scenario.root.textEditing.startNew(
            seed,
            layerId: CanvasLayerId('new-stale-layer'),
          ),
        );
        scenario.root.edits.edit((edit) {
          edit.addElement(
            CanvasRectElement(
              id: CanvasElementId('stale-new-layer-change'),
              size: const Size(2, 2),
            ),
            layerId: CanvasLayerId('new-stale-layer'),
          );
        });
        await _observeAdmissionRefusal(
          scenario,
          () => scenario.root.textEditing.startNew(seed),
          reason: CanvasTextEditStartRefusalReason.stale,
          expectedActive: staleNew,
        );
        staleNew.dismiss();
        expect(
          scenario.root.textEditing.startNew(seed),
          isA<CanvasTextEditStartSuccess>(),
        );
      } finally {
        await scenario.dispose();
      }
    },
  );

  test(
    'new trim-empty and cancellation leave a prospective layer transient',
    () async {
      var resolverCalls = 0;
      final scenario = _Scenario(
        document: CanvasDocument(),
        config: CanvasRuntimeConfig(
          commitResolver: (_) {
            resolverCalls += 1;
            return const CanvasCommitCancel();
          },
        ),
      );
      final seed = _newTextSeed(id: CanvasElementId('prospective-text'));
      try {
        final revisions = scenario.root.state.value.revisions;
        final documentBefore = scenario.root.readDocument();
        final cancelledWork = <PreparedInteractionApplyWorkEvent>[];
        late CanvasTextEditSession session;
        CommitApplier.observePreparedInteractionWork(cancelledWork.add, () {
          session = _expectStartSuccess(
            scenario.root.textEditing.startNew(
              seed,
              layerId: CanvasLayerId('prospective-layer'),
              index: 9,
            ),
          );
          session.updateText('draft');
          session.updateFormatting(isBold: true, isItalic: true);
          session.dismiss();
        });
        expect(scenario.root.readDocument().layers, isEmpty);
        expect(scenario.root.selectedElementIds, isEmpty);
        expect(scenario.actions, isEmpty);
        expect(scenario.root.readDocument(), same(documentBefore));
        expect(
          scenario.root.state.value.revisions.document,
          revisions.document,
        );
        expect(cancelledWork, isEmpty);
        expect(resolverCalls, 0);

        final emptyWork = <PreparedInteractionApplyWorkEvent>[];
        late CanvasTextEditSession empty;
        CommitApplier.observePreparedInteractionWork(emptyWork.add, () {
          empty = _expectStartSuccess(
            scenario.root.textEditing.startNew(
              seed,
              layerId: CanvasLayerId('prospective-layer'),
            ),
          );
          empty.updateText(' \n ');
          expect(empty.commit(), isTrue);
        });
        expect(scenario.root.readDocument().layers, isEmpty);
        expect(scenario.root.textEditing.activeSession.value, isNull);
        expect(scenario.actions, isEmpty);
        expect(scenario.root.readDocument(), same(documentBefore));
        expect(
          scenario.root.state.value.revisions.document,
          revisions.document,
        );
        expect(emptyWork, isEmpty);
        expect(resolverCalls, 0);
      } finally {
        await scenario.dispose();
      }
    },
  );

  test('new text retains destination and latches creation conflicts', () async {
    var resolverCalls = 0;
    final scenario = _Scenario(
      document: CanvasDocument(),
      config: CanvasRuntimeConfig(
        commitResolver: (request) {
          resolverCalls += 1;
          return acceptCommit(request);
        },
      ),
    );
    final seed = _newTextSeed(id: CanvasElementId('guarded-new'));
    try {
      final session = _expectStartSuccess(
        scenario.root.textEditing.startNew(
          seed,
          layerId: CanvasLayerId('prospective-layer'),
        ),
      );
      session.updateText('draft before prospective conflict');
      session.updateFormatting(isBold: true, isItalic: true, isUnderline: true);
      final prospectiveStyle = session.style;
      final prospectiveGeometry = session.geometry;
      scenario.root.edits.edit((edit) {
        edit.addElement(
          CanvasRectElement(
            id: CanvasElementId('external-layer-occupant'),
            size: const Size(2, 2),
          ),
          layerId: CanvasLayerId('prospective-layer'),
        );
      });
      final prospectiveConflictDocument = scenario.root.readDocument();
      expect(session.isStale, isTrue);
      session.updateText('must not mutate retained draft');
      session.updateFormatting(isBold: false, isItalic: false, isUnderline: false);
      expect(session.liveText, 'draft before prospective conflict');
      expect(session.style, prospectiveStyle);
      expect(session.geometry, prospectiveGeometry);
      expect(session.commit(), isFalse);
      expect(session.commit(), isFalse);
      expect(session.liveText, 'draft before prospective conflict');
      expect(session.style, prospectiveStyle);
      expect(session.geometry, prospectiveGeometry);
      expect(scenario.root.textEditing.activeSession.value, same(session));
      expect(_containsElement(scenario.root, seed.id), isFalse);
      expect(scenario.actions, isEmpty);
      expect(scenario.root.readDocument(), same(prospectiveConflictDocument));
      expect(resolverCalls, 0);
      session.dismiss();

      final idSession = _expectStartSuccess(
        scenario.root.textEditing.startNew(
          _newTextSeed(id: CanvasElementId('external-element-occupant')),
          layerId: CanvasLayerId('prospective-layer'),
        ),
      );
      idSession.updateText('draft before occupied-id conflict');
      idSession.updateFormatting(isBold: true, isItalic: true, isUnderline: true);
      final idStyle = idSession.style;
      final idGeometry = idSession.geometry;
      scenario.root.edits.edit((edit) {
        edit.addElement(
          CanvasRectElement(
            id: CanvasElementId('external-element-occupant'),
            size: const Size(2, 2),
          ),
          layerId: CanvasLayerId('prospective-layer'),
        );
      });
      final idConflictDocument = scenario.root.readDocument();
      expect(idSession.isStale, isTrue);
      idSession.updateText('must not mutate the occupied-id draft');
      idSession.updateFormatting(isBold: false, isItalic: false, isUnderline: false);
      expect(idSession.liveText, 'draft before occupied-id conflict');
      expect(idSession.style, idStyle);
      expect(idSession.geometry, idGeometry);
      expect(idSession.commit(), isFalse);
      expect(idSession.commit(), isFalse);
      expect(idSession.liveText, 'draft before occupied-id conflict');
      expect(idSession.style, idStyle);
      expect(idSession.geometry, idGeometry);
      expect(scenario.actions, isEmpty);
      expect(scenario.root.textEditing.activeSession.value, same(idSession));
      expect(scenario.root.readDocument(), same(idConflictDocument));
      expect(resolverCalls, 0);
      idSession.dismiss();

      final retainedDestination = _expectStartSuccess(
        scenario.root.textEditing.startNew(
          _newTextSeed(id: CanvasElementId('retained-default-destination')),
        ),
      );
      scenario.root.edits.edit(
        (edit) => edit.ensureLayer(CanvasLayerId('later-last-layer')),
      );
      retainedDestination.updateText('must stay in the admitted layer');
      expect(retainedDestination.isStale, isFalse);
      expect(retainedDestination.commit(), isTrue);
      expect(resolverCalls, 1);
      final admittedLayer = scenario.root.readDocument().layers.singleWhere(
        (layer) => layer.id == CanvasLayerId('prospective-layer'),
      );
      expect(
        admittedLayer.elements.map((element) => element.id),
        contains(retainedDestination.elementId),
      );
      expect(
        scenario.root
            .readDocument()
            .layers
            .singleWhere(
              (layer) => layer.id == CanvasLayerId('later-last-layer'),
            )
            .elements,
        isEmpty,
      );

      final removedDestination = CanvasLayerId('removed-destination');
      scenario.root.edits.edit(
        (edit) => expect(edit.ensureLayer(removedDestination), isTrue),
      );
      final lostDestination = _expectStartSuccess(
        scenario.root.textEditing.startNew(
          _newTextSeed(id: CanvasElementId('lost-destination-text')),
          layerId: removedDestination,
        ),
      );
      scenario.root.edits.edit(
        (edit) => expect(edit.removeEmptyLayer(removedDestination), isTrue),
      );
      final removedDestinationDocument = scenario.root.readDocument();
      expect(lostDestination.isStale, isTrue);
      lostDestination.updateText('must retain only a stale draft');
      expect(lostDestination.liveText, 'seed');
      expect(lostDestination.commit(), isFalse);
      expect(lostDestination.commit(), isFalse);
      expect(
        _containsElement(scenario.root, lostDestination.elementId),
        isFalse,
      );
      expect(
        scenario.root.textEditing.activeSession.value,
        same(lostDestination),
      );
      expect(scenario.root.readDocument(), same(removedDestinationDocument));
      expect(resolverCalls, 1);
    } finally {
      await scenario.dispose();
    }
  });

  test('new text proposal is exact and rejection retains its draft', () async {
    final requests = <CanvasTextCreateCommitRequest>[];
    var accept = false;
    final scenario = _Scenario(
      config: CanvasRuntimeConfig(
        commitResolver: (request) {
          if (request is CanvasTextCreateCommitRequest) {
            requests.add(request);
          }
          return accept ? acceptCommit(request) : const CanvasCommitCancel();
        },
      ),
    );
    final seed = _newTextSeed(id: CanvasElementId('proposal-text'));
    try {
      final session = _expectStartSuccess(
        scenario.root.textEditing.startNew(seed, index: 0),
      );
      session.updateText(' untrimmed proposal ');
      session.updateFormatting(isBold: true, isUnderline: true);
      final refusedWork = <PreparedInteractionApplyWorkEvent>[];
      expect(
        CommitApplier.observePreparedInteractionWork(
          refusedWork.add,
          session.commit,
        ),
        isFalse,
      );
      expect(session.liveText, ' untrimmed proposal ');
      expect(_containsElement(scenario.root, seed.id), isFalse);
      expect(requests, hasLength(1));
      final refused = requests.single;
      expect(refused.requestId, session.requestId);
      expect(refused.entry.element, isA<CanvasTextElement>());
      final proposed = refused.entry.element as CanvasTextElement;
      expect(proposed.text, ' untrimmed proposal ');
      expect(proposed.isBold, isTrue);
      expect(proposed.isUnderline, isTrue);
      expect(refused.entry.elementIndex, 0);
      expect(refused.layerIndex, 0);
      expect(refused.createsLayer, isFalse);
      expect(refusedWork, [
        PreparedInteractionApplyWorkEvent.prepared,
        PreparedInteractionApplyWorkEvent.ownershipReleased,
        PreparedInteractionApplyWorkEvent.discarded,
      ]);

      accept = true;
      expect(session.commit(), isTrue);
      expect(requests, hasLength(2));
      final accepted = requests.last;
      expect(accepted.entry.elementIndex, 0);
      expect(accepted.requestId, session.requestId);
      final installed = scenario.root
          .readDocument()
          .layers
          .single
          .elements
          .first;
      _expectCompleteTextElement(installed as CanvasTextElement, proposed);
    } finally {
      await scenario.dispose();
    }
  });

  test(
    'new text creates an absent destination only after acceptance',
    () async {
      CanvasTextCreateCommitRequest? request;
      late final RuntimeRoot root;
      root = runtimeRootWithCommittedDocumentSeed(
        CanvasDocument(),
        config: CanvasRuntimeConfig(
          commitResolver: (candidate) {
            request = candidate as CanvasTextCreateCommitRequest;
            expect(root.readDocument().layers, isEmpty);
            return acceptCommit(candidate);
          },
        ),
      );
      try {
        final session = _expectStartSuccess(
          root.textEditing.startNew(
            _newTextSeed(id: CanvasElementId('accepted-prospective-text')),
            layerId: CanvasLayerId('accepted-prospective-layer'),
          ),
        );
        session.updateText('accepted prospective');
        expect(session.commit(), isTrue);
        final proposal = request;
        if (proposal == null) fail('Expected a creation proposal.');
        expect(proposal.createsLayer, isTrue);
        expect(proposal.layerIndex, 0);
        expect(
          proposal.entry.layerId,
          CanvasLayerId('accepted-prospective-layer'),
        );
        expect(proposal.entry.elementIndex, 0);
        expect(root.readDocument().layers.single.id, proposal.entry.layerId);
        expect(_containsElement(root, session.elementId), isTrue);
      } finally {
        root.dispose();
      }
    },
  );

  test(
    'new text normalizes retained append and numeric placement at preparation',
    () async {
      final requests = <CanvasTextCreateCommitRequest>[];
      final scenario = _Scenario(
        config: CanvasRuntimeConfig(
          commitResolver: (request) {
            if (request is CanvasTextCreateCommitRequest) {
              requests.add(request);
            }
            return acceptCommit(request);
          },
        ),
      );
      try {
        final append = _expectStartSuccess(
          scenario.root.textEditing.startNew(
            _newTextSeed(id: CanvasElementId('retained-append')),
          ),
        );
        scenario.root.edits.edit((edit) {
          edit.addElement(
            CanvasRectElement(
              id: CanvasElementId('append-after-admission'),
              size: const Size(2, 2),
            ),
          );
        });
        final appendOracle = _ordinaryTextInsertionLocation(
          scenario.root.readDocument(),
          _newTextSeed(id: CanvasElementId('retained-append')),
        );
        expect(append.commit(), isTrue);
        expect(requests.single.layerIndex, appendOracle.layerIndex);
        expect(requests.single.entry.elementIndex, appendOracle.elementIndex);
        final appendDocument = scenario.root.readDocument();
        final appendInstalled =
            appendDocument.layers[appendOracle.layerIndex]
                .elements[appendOracle.elementIndex];
        expect(appendInstalled.id, append.elementId);

        final numeric = _expectStartSuccess(
          scenario.root.textEditing.startNew(
            _newTextSeed(id: CanvasElementId('retained-numeric')),
            index: 5,
          ),
        );
        scenario.root.edits.edit((edit) {
          edit.addElement(
            CanvasRectElement(
              id: CanvasElementId('numeric-after-admission'),
              size: const Size(2, 2),
            ),
          );
        });
        final numericOracle = _ordinaryTextInsertionLocation(
          scenario.root.readDocument(),
          _newTextSeed(id: CanvasElementId('retained-numeric')),
          index: 5,
        );
        expect(numeric.commit(), isTrue);
        expect(requests.last.layerIndex, numericOracle.layerIndex);
        expect(requests.last.entry.elementIndex, numericOracle.elementIndex);
        final numericDocument = scenario.root.readDocument();
        final numericInstalled =
            numericDocument.layers[numericOracle.layerIndex]
                .elements[numericOracle.elementIndex];
        expect(numericInstalled.id, numeric.elementId);
        expect(
          scenario.root
              .readDocument()
              .layers
              .single
              .elements
              .where(
                (element) => element.id == CanvasElementId('retained-numeric'),
              )
              .single,
          isA<CanvasTextElement>(),
        );
      } finally {
        await scenario.dispose();
      }
    },
  );
}

// New-origin confirmation crosses the same resolver, sealed preparation, lease,
// delivery, and close boundary as editing an existing element. These are kept
// together so successful delivery cannot mask a pre-install failure.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _testNewTextDelivery() {
  test(
    'new text rejects pre-install failures and retains its retryable draft',
    () async {
      final resolverFailure = _Scenario(
        config: CanvasRuntimeConfig(
          commitResolver: (_) => throw StateError('creation resolver failed'),
        ),
      );
      try {
        final session = _expectStartSuccess(
          resolverFailure.root.textEditing.startNew(
            _newTextSeed(id: CanvasElementId('resolver-failure-new')),
          ),
        );
        session.updateText('retryable creation');

        expect(session.commit(), isFalse);
        expect(session.isActive, isTrue);
        expect(session.liveText, 'retryable creation');
        expect(
          _containsElement(resolverFailure.root, session.elementId),
          isFalse,
        );
        expect(resolverFailure.actions, isEmpty);
      } finally {
        await resolverFailure.dispose();
      }

      final lease = _TextCommitLease();
      final incompatible = _Scenario(
        config: CanvasRuntimeConfig(
          commitResolver: (_) =>
              CanvasMoveCommitAccept(delta: const Offset(1, 0), lease: lease),
        ),
      );
      try {
        final session = _expectStartSuccess(
          incompatible.root.textEditing.startNew(
            _newTextSeed(id: CanvasElementId('incompatible-new')),
          ),
        );

        expect(session.commit(), isFalse);
        expect(session.isActive, isTrue);
        expect(_containsElement(incompatible.root, session.elementId), isFalse);
        expect(lease.committedCalls, 0);
        expect(lease.abortedCalls, 1);
        expect(incompatible.actions, isEmpty);
      } finally {
        await incompatible.dispose();
      }

      var retry = false;
      final failedLease = _TextCommitLease();
      final retryLease = _TextCommitLease();
      final consumeFailure = _Scenario(
        config: CanvasRuntimeConfig(
          commitResolver: (_) =>
              CanvasCommitAccept(lease: retry ? retryLease : failedLease),
        ),
      );
      try {
        final session = _expectStartSuccess(
          consumeFailure.root.textEditing.startNew(
            _newTextSeed(id: CanvasElementId('consume-failure-new')),
          ),
        );
        session.updateText('retry after consume failure');
        final failure = StateError('creation consume failed');
        final work = <PreparedInteractionApplyWorkEvent>[];

        expect(
          () => CommitApplier.observePreparedInteractionWork((event) {
            work.add(event);
            if (event == PreparedInteractionApplyWorkEvent.consumed) {
              throw failure;
            }
          }, session.commit),
          throwsA(same(failure)),
        );
        expect(work, [
          PreparedInteractionApplyWorkEvent.prepared,
          PreparedInteractionApplyWorkEvent.ownershipReleased,
          PreparedInteractionApplyWorkEvent.consumed,
        ]);
        expect(session.isActive, isTrue);
        expect(session.liveText, 'retry after consume failure');
        expect(
          consumeFailure.root.textEditing.activeSession.value,
          same(session),
        );
        expect(
          _containsElement(consumeFailure.root, session.elementId),
          isFalse,
        );
        expect(failedLease.committedCalls, 0);
        expect(failedLease.abortedCalls, 1);
        expect(consumeFailure.actions, isEmpty);

        retry = true;
        expect(session.commit(), isTrue);
        expect(
          _containsElement(consumeFailure.root, session.elementId),
          isTrue,
        );
        expect(retryLease.committedCalls, 1);
        expect(retryLease.abortedCalls, 0);
      } finally {
        await consumeFailure.dispose();
      }
    },
  );

  test(
    'new text installs once and delivers state lease action observer then close',
    () async {
      final trace = <String>[];
      final lease = _TextCommitLease();
      late final RuntimeRoot root;
      late CanvasTextEditSession session;
      var committing = false;
      root = runtimeRootWithCommittedDocumentSeed(
        _document(),
        config: CanvasRuntimeConfig(
          commitResolver: (request) {
            expect(request, isA<CanvasTextCreateCommitRequest>());
            expect(
              _containsElement(root, CanvasElementId('delivery-new')),
              isFalse,
            );
            expect(
              () => root.commands.removeElement(_rectId),
              throwsA(isA<StateError>()),
            );
            expect(root.generateElementId, throwsA(isA<StateError>()));
            expect(() => session.commit(), throwsA(isA<StateError>()));
            expect(root.dispose, throwsA(isA<StateError>()));
            return CanvasCommitAccept(lease: lease);
          },
        ),
        commitEffectObserver: (_) {
          if (committing) trace.add('observer');
        },
      );
      final actions = <CanvasActionCommitted>[];
      final actionSubscription = root.actions.listen((action) {
        if (committing) {
          actions.add(action);
          trace.add('action');
        }
      });
      void onState() {
        if (committing) trace.add('state');
      }

      root.state.addListener(onState);
      try {
        session = _expectStartSuccess(
          root.textEditing.startNew(
            _newTextSeed(id: CanvasElementId('delivery-new')),
          ),
        );
        CanvasTextEditSession? replacement;
        void onClose() {
          if (root.textEditing.activeSession.value != null) return;
          trace.add('close');
          replacement = _expectStartSuccess(
            root.textEditing.startNew(
              _newTextSeed(id: CanvasElementId('delivery-replacement')),
            ),
          );
        }

        root.textEditing.activeSession.addListener(onClose);
        try {
          lease.onCommitted = () {
            trace.add('lease');
            expect(
              () => root.commands.removeElement(_rectId),
              throwsA(isA<StateError>()),
            );
            expect(root.generateElementId, throwsA(isA<StateError>()));
            expect(() => session.commit(), throwsA(isA<StateError>()));
            expect(root.dispose, throwsA(isA<StateError>()));
          };
          committing = true;
          expect(session.commit(timestampMs: 73), isTrue);
          committing = false;
        } finally {
          root.textEditing.activeSession.removeListener(onClose);
        }

        expect(trace, [
          'state',
          'lease',
          'action',
          'observer',
          'close',
          'state',
        ]);
        expect(_containsElement(root, session.elementId), isTrue);
        expect(session.isActive, isFalse);
        expect(root.textEditing.activeSession.value, same(replacement));
        expect(lease.committedCalls, 1);
        expect(lease.abortedCalls, 0);
        expect(actions, hasLength(1));
        expect(actions.single.type, CanvasActionType.createText);
        final payload = actions.single.payload as CanvasTextCreateActionPayload;
        expect(payload.requestId, session.requestId);
        expect(payload.createdTextLength, session.liveText.length);
      } finally {
        root.state.removeListener(onState);
        await actionSubscription.cancel();
        root.dispose();
      }
    },
  );

  test(
    'new text remains committed when its post-install close notification fails',
    () async {
      final reports = <FlutterErrorDetails>[];
      final previousReporter = FlutterError.onError;
      FlutterError.onError = reports.add;
      final lease = _TextCommitLease();
      final scenario = _Scenario(
        config: CanvasRuntimeConfig(
          commitResolver: (_) => CanvasCommitAccept(lease: lease),
        ),
      );
      try {
        final session = _expectStartSuccess(
          scenario.root.textEditing.startNew(
            _newTextSeed(id: CanvasElementId('close-failure-new')),
          ),
        );
        void throwingCloseListener() {
          if (scenario.root.textEditing.activeSession.value == null) {
            throw StateError('creation close listener failed');
          }
        }

        CanvasTextEditSession? replacement;
        void replacementCloseListener() {
          if (scenario.root.textEditing.activeSession.value == null) {
            replacement = _expectStartSuccess(
              scenario.root.textEditing.startNew(
                _newTextSeed(id: CanvasElementId('close-failure-replacement')),
              ),
            );
          }
        }

        scenario.root.textEditing.activeSession.addListener(
          throwingCloseListener,
        );
        scenario.root.textEditing.activeSession.addListener(
          replacementCloseListener,
        );
        try {
          expect(session.commit(), isTrue);
        } finally {
          scenario.root.textEditing.activeSession.removeListener(
            throwingCloseListener,
          );
          scenario.root.textEditing.activeSession.removeListener(
            replacementCloseListener,
          );
        }
        expect(_containsElement(scenario.root, session.elementId), isTrue);
        expect(session.isActive, isFalse);
        expect(
          scenario.root.textEditing.activeSession.value,
          same(replacement),
        );
        expect(lease.committedCalls, 1);
        expect(lease.abortedCalls, 0);
        expect(scenario.actions.single.type, CanvasActionType.createText);
        expect(reports, hasLength(1));
      } finally {
        FlutterError.onError = previousReporter;
        await scenario.dispose();
      }
    },
  );
}

// Default resolution is observed at the real frame/session handoffs and then
// across confirmation so a display-only fallback cannot become stored data.
// Keeping this end-to-end assertion together makes the stored-versus-effective
// distinction and cross-runtime isolation easier to audit than test splitting.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _testRuntimeDefaultFontFamilyIsEffectiveButNotStored() {
  test(
    'runtime font defaults stay isolated and preserve stored families',
    () async {
      await _loadRobotoForRuntimeStyleGeometry();
      final inherited = _Scenario(
        config: const CanvasRuntimeConfig(
          commitResolver: acceptCommit,
          defaultFontFamily: _unit3RuntimeRobotoFamily,
        ),
      );
      final fallback = _Scenario(
        config: const CanvasRuntimeConfig(commitResolver: acceptCommit),
      );
      final explicit = _Scenario(
        document: _document(fontFamily: 'Inter'),
        config: const CanvasRuntimeConfig(
          commitResolver: acceptCommit,
          defaultFontFamily: _unit3RuntimeRobotoFamily,
        ),
      );
      try {
        final inheritedRow = _textRenderRowFor(inherited.root);
        final fallbackRow = _textRenderRowFor(fallback.root);
        final explicitRow = _textRenderRowFor(explicit.root);
        expect(inheritedRow.layoutInput.fontFamily, _unit3RuntimeRobotoFamily);
        expect(
          inheritedRow.layoutCacheKey.fontFamily,
          _unit3RuntimeRobotoFamily,
        );
        expect(fallbackRow.layoutInput.fontFamily, isNull);
        expect(fallbackRow.layoutCacheKey.fontFamily, isNull);
        expect(explicitRow.layoutInput.fontFamily, 'Inter');
        expect(explicitRow.layoutCacheKey.fontFamily, 'Inter');

        final inheritedSession = _expectSession(
          inherited.root.textEditing.startFromContextAction(
            await inherited.issueTextRequest(),
          ),
        );
        final fallbackSession = _expectSession(
          fallback.root.textEditing.startFromContextAction(
            await fallback.issueTextRequest(),
          ),
        );
        final explicitSession = _expectSession(
          explicit.root.textEditing.startFromContextAction(
            await explicit.issueTextRequest(),
          ),
        );
        expect(inheritedSession.style.fontFamily, _unit3RuntimeRobotoFamily);
        expect(fallbackSession.style.fontFamily, isNull);
        expect(explicitSession.style.fontFamily, 'Inter');
        expect(inheritedSession.commit(), isTrue);
        expect(explicitSession.commit(), isTrue);
        final createdSeed = CanvasTextElement(
          id: CanvasElementId('inherited-created-text'),
          text: 'created',
          color: const Color(0xFF224466),
          textDirection: TextDirection.ltr,
        );
        final creation = _expectStartSuccess(
          inherited.root.textEditing.startNew(createdSeed),
        );
        expect(creation.style.fontFamily, _unit3RuntimeRobotoFamily);
        creation.updateFormatting(isBold: true);
        expect(creation.commit(), isTrue);
        expect(inherited.root.projectionBuildCount, 0);
        expect(explicit.root.projectionBuildCount, 0);
        expect(_textElement(inherited.root).fontFamily, isNull);
        expect(_textElement(explicit.root).fontFamily, 'Inter');
        final created = inherited.root
            .readDocument()
            .layers
            .single
            .elements
            .whereType<CanvasTextElement>()
            .singleWhere((element) => element.id == createdSeed.id);
        expect(created.fontFamily, isNull);
        final encoded = encodeCanvasDocumentToJson(
          inherited.root.readDocument(),
        );
        expect(
          encoded,
          contains(RegExp('"id":"inherited-created-text".*?"fontFamily":null')),
        );
        fallbackSession.dismiss();
      } finally {
        await inherited.dispose();
        await fallback.dispose();
        await explicit.dispose();
      }
    },
  );

  test(
    'new default and explicit families keep their draft geometry through acceptance',
    () async {
      await _loadRobotoForRuntimeStyleGeometry();
      for (final family in <String?>[null, 'Inter']) {
        final scenario = _Scenario(
          document: CanvasDocument(),
          config: const CanvasRuntimeConfig(
            commitResolver: acceptCommit,
            defaultFontFamily: _unit3RuntimeRobotoFamily,
          ),
        );
        final id = CanvasElementId('new-family-${family ?? 'default'}');
        final seed = CanvasTextElement(
          id: id,
          text: 'WMWMWM',
          fontSize: 18,
          color: const Color(0xFF224466),
          textDirection: TextDirection.ltr,
          align: TextAlign.right,
          transform: CanvasTransform.translation(const Offset(30, 15)),
          fontFamily: family,
        );
        try {
          final session = _expectStartSuccess(
            scenario.root.textEditing.startNew(seed),
          );
          final baseAnchor = _anchorValueFor(
            session.geometry.editBoundsWorld,
            TextAlign.right,
          );
          session.updateText('WMWMWM\nformatted creation');
          session.updateFormatting(isBold: true);
          final draftGeometry = session.geometry;
          expect(
            _anchorValueFor(draftGeometry.editBoundsWorld, TextAlign.right),
            moreOrLessEquals(baseAnchor, epsilon: 0.001),
          );
          expect(session.commit(), isTrue);
          _expectAcceptedTextFrameMatchesDraftGeometry(
            scenario.root,
            draftGeometry: draftGeometry,
            baseAnchor: baseAnchor,
            expectedRow: (
              elementId: id,
              text: 'WMWMWM\nformatted creation',
              isBold: true,
              isItalic: false,
              isUnderline: false,
            ),
          );
          final installed = scenario.root
              .readDocument()
              .layers
              .single
              .elements
              .whereType<CanvasTextElement>()
              .single;
          expect(installed.fontFamily, family);
        } finally {
          await scenario.dispose();
        }
      }
    },
  );

  test(
    'runtime config admits null and valid defaults and rejects element-invalid defaults',
    () {
      final valid = runtimeRootWithCommittedDocumentSeed(
        _document(),
        config: const CanvasRuntimeConfig(
          commitResolver: acceptCommit,
          defaultFontFamily: 'Roboto',
        ),
      );
      valid.dispose();
      final fallback = runtimeRootWithCommittedDocumentSeed(
        _document(),
        config: const CanvasRuntimeConfig(commitResolver: acceptCommit),
      );
      fallback.dispose();

      for (final invalid in ['', 'f' * (canvasMaxFontFamilyLength + 1)]) {
        expect(
          () => runtimeRootWithCommittedDocumentSeed(
            _document(),
            config: CanvasRuntimeConfig(
              commitResolver: acceptCommit,
              defaultFontFamily: invalid,
            ),
          ),
          throwsA(
            isA<CanvasDataException>()
                .having(
                  (error) => error.code,
                  'code',
                  CanvasDataErrorCode.fieldMaxLength,
                )
                .having(
                  (error) => error.message,
                  'message',
                  'font family length is invalid.',
                )
                .having((error) => error.path, 'path', 'text.fontFamily'),
          ),
        );
      }
    },
  );
}

TextRenderRow _textRenderRowFor(RuntimeRoot root) {
  final output = root.buildResourceFreeMainFrame(
    viewportWorldBounds: const Rect.fromLTWH(-20, -20, 220, 120),
    devicePixelRatio: 1,
    selectionStyle: CanvasSelectionStyle.defaultStyle,
    gridStyle: CanvasGridStyle.defaultStyle,
  );
  final row = output.ordinaryPlan.ordinaryRecords
      .singleWhere((record) => record.id == _textId)
      .row;
  if (row is! TextRenderRow) {
    throw StateError('Expected a text render row.');
  }

  return row;
}

// The accepted deletion, fallible close notifier, and committed lease are one
// failure boundary, so keeping their assertions together is clearer.
// ignore: halstead-volume
void _testEmptyPolicyDeletionCloseFailureRemainsCommitted() {
  test('deletion close notification failure cannot abort accepted deletion', () async {
    final errors = <FlutterErrorDetails>[];
    final previousErrorHandler = FlutterError.onError;
    final lease = _TextCommitLease();
    final scenario = _Scenario(
      config: CanvasRuntimeConfig(
        commitResolver: (_) => CanvasCommitAccept(lease: lease),
      ),
    );
    void onClose() {
      if (scenario.root.textEditing.activeSession.value == null) {
        throw StateError('deletion close listener failed');
      }
    }

    scenario.root.textEditing.activeSession.addListener(onClose);
    FlutterError.onError = errors.add;
    try {
      final request = await scenario.issueTextRequest();
      final session = _expectSession(
        scenario.root.textEditing.startFromContextAction(
          request,
          emptyTextBehavior: CanvasTextEditEmptyTextBehavior.deleteElement,
        ),
      );
      session.updateText(' ');

      expect(session.commit(), isTrue);
      expect(_containsElement(scenario.root, _textId), isFalse);
      expect(session.isActive, isFalse);
      expect(lease.committedCalls, 1);
      expect(lease.abortedCalls, 0);
      expect(scenario.actions.single.type, CanvasActionType.deleteElements);
      expect(errors.single.exception, isA<StateError>());
    } finally {
      FlutterError.onError = previousErrorHandler;
      scenario.root.textEditing.activeSession.removeListener(onClose);
      await scenario.dispose();
    }
  });
}

// This pre-install failure keeps all retained-draft assertions at the one
// request-construction seam instead of scattering partial snapshots.
// ignore: halstead-volume
void _testEmptyPolicyDeletionPreparationFailureRetainsDraft() {
  test('deletion request preparation failure keeps original draft and state', () async {
    final scenario = _Scenario();
    try {
      final request = await scenario.issueTextRequest();
      final session = _expectSession(
        scenario.root.textEditing.startFromContextAction(
          request,
          emptyTextBehavior: CanvasTextEditEmptyTextBehavior.deleteElement,
        ),
      );
      final failure = StateError('deletion request construction failed');
      final beforeRevisions = scenario.root.state.value.revisions;
      session.updateText('\n');

      RuntimeRoot.injectDeletionRequestPreparationFailure(
        RuntimeDeletionRequestPreparationPhase.requestConstruction,
        failure,
        () => expect(session.commit, throwsA(same(failure))),
      );

      expect(_containsElement(scenario.root, _textId), isTrue);
      expect(scenario.root.state.value.revisions, beforeRevisions);
      expect(session.liveText, '\n');
      expect(scenario.root.textEditing.activeSession.value, same(session));
      _expectRequestFactsLive(scenario.root, request);
      expect(scenario.actions, isEmpty);
    } finally {
      await scenario.dispose();
    }
  });
}

// Resolver guard, accepted delivery, and close replacement are one causal
// runtime behavior, so this deletion witness retains their observable order.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _testEmptyPolicyDeletionDelivery() {
  test(
    'empty deletion guards callbacks then delivers state lease action observer and close',
    () async {
      final trace = <String>[];
      final lease = _TextCommitLease();
      late final RuntimeRoot root;
      var committing = false;
      root = runtimeRootWithCommittedDocumentSeed(
        _document(),
        config: CanvasRuntimeConfig(
          commitResolver: (request) {
            expect(request, isA<CanvasDeleteCommitRequest>());
            expect(_textValue(root), 'hello');
            expect(
              () => root.commands.removeElement(_rectId),
              throwsA(isA<StateError>()),
            );
            return CanvasCommitAccept(lease: lease);
          },
        ),
        commitEffectObserver: (_) {
          if (committing) trace.add('observer');
        },
      );
      final requests = <CanvasContextActionRequested>[];
      final requestSubscription = root.contextActionRequests.listen(requests.add);
      final actionSubscription = root.actions.listen((_) {
        if (committing) trace.add('action');
      });
      void onState() {
        if (committing) trace.add('state');
      }

      root.state.addListener(onState);
      try {
        root.edits.edit((edit) {
          edit.addElement(
            CanvasTextElement(
              id: _replacementTextId,
              text: 'replacement',
              fontSize: 16,
              color: const Color(0xFF111111),
              textDirection: TextDirection.ltr,
              transform: CanvasTransform.translation(const Offset(200, 0)),
            ),
          );
        });
        root.handleDoubleTap(position: Offset.zero, timestampMs: 1);
        await Future<void>.delayed(Duration.zero);
        final outerRequest = requests.single;
        requests.clear();
        root.handleDoubleTap(position: const Offset(200, 0), timestampMs: 2);
        await Future<void>.delayed(Duration.zero);
        final replacementRequest = requests.single;
        final outer = _expectSession(
          root.textEditing.startFromContextAction(
            outerRequest,
            emptyTextBehavior: CanvasTextEditEmptyTextBehavior.deleteElement,
          ),
        );
        CanvasTextEditSession? replacement;
        void onClose() {
          if (root.textEditing.activeSession.value != null) return;
          trace.add('close');
          replacement = _expectSession(
            root.textEditing.startFromContextAction(replacementRequest),
          );
        }

        root.textEditing.activeSession.addListener(onClose);
        try {
          outer.updateText(' ');
          lease.onCommitted = () {
            trace.add('lease');
            expect(
              () => root.commands.removeElement(_rectId),
              throwsA(isA<StateError>()),
            );
          };
          committing = true;
          expect(outer.commit(timestampMs: 104), isTrue);
          committing = false;
        } finally {
          root.textEditing.activeSession.removeListener(onClose);
        }

        expect(trace, [
          'state',
          'lease',
          'action',
          'observer',
          'close',
          'state',
        ]);
        expect(_containsElement(root, _textId), isFalse);
        expect(outer.isActive, isFalse);
        expect(root.textEditing.activeSession.value, same(replacement));
        expect(lease.committedCalls, 1);
        expect(lease.abortedCalls, 0);
      } finally {
        root.state.removeListener(onState);
        await actionSubscription.cancel();
        await requestSubscription.cancel();
        root.dispose();
      }
    },
  );
}

// The rejection and retry stay on the public session seam so a deletion route
// cannot discard the draft merely because its prepared package was rejected.
// Rejection, discard, and retry are one public terminal behavior and remain
// together so a lost draft cannot hide behind the retry result.
// ignore: halstead-volume, source-lines-of-code
void _testRejectedEmptyPolicyDeletionRetainsDraft() {
  test('rejected empty deletion retains its draft and request for retry', () async {
    var accept = false;
    final scenario = _Scenario(
      config: CanvasRuntimeConfig(
        commitResolver: (request) => accept
            ? acceptCommit(request)
            : const CanvasCommitCancel(),
      ),
    );
    try {
      final request = await scenario.issueTextRequest();
      final session = _expectSession(
        scenario.root.textEditing.startFromContextAction(
          request,
          emptyTextBehavior: CanvasTextEditEmptyTextBehavior.deleteElement,
        ),
      );
      final work = <PreparedInteractionApplyWorkEvent>[];
      session.updateText('  ');

      expect(
        CommitApplier.observePreparedInteractionWork(
          work.add,
          () => scenario.root.textEditing.finishActive(
            CanvasTextEditFinishIntent.commit,
          ),
        ),
        CanvasTextEditFinishResult.rejected,
      );
      expect(_containsElement(scenario.root, _textId), isTrue);
      expect(session.liveText, '  ');
      expect(scenario.root.textEditing.activeSession.value, same(session));
      _expectRequestFactsLive(scenario.root, request);
      expect(scenario.actions, isEmpty);
      expect(work, [
        PreparedInteractionApplyWorkEvent.prepared,
        PreparedInteractionApplyWorkEvent.ownershipReleased,
        PreparedInteractionApplyWorkEvent.discarded,
      ]);

      accept = true;
      expect(session.commit(), isTrue);
      expect(_containsElement(scenario.root, _textId), isFalse);
      expect(scenario.actions, hasLength(1));
    } finally {
      await scenario.dispose();
    }
  });
}

// Resolver exception and incompatible acceptance share one pre-install
// terminal invariant: neither may install or lose the retryable draft.
// ignore: halstead-volume, source-lines-of-code
void _testEmptyPolicyDeletionResolverFailuresRetainDraft() {
  test('deletion resolver exception and incompatible acceptance discard before install', () async {
    final exceptionScenario = _Scenario(
      config: CanvasRuntimeConfig(
        commitResolver: (_) => throw StateError('deletion resolver failed'),
      ),
    );
    try {
      final request = await exceptionScenario.issueTextRequest();
      final session = _expectSession(
        exceptionScenario.root.textEditing.startFromContextAction(
          request,
          emptyTextBehavior: CanvasTextEditEmptyTextBehavior.deleteElement,
        ),
      );
      session.updateText(' ');

      expect(
        exceptionScenario.root.textEditing.finishActive(
          CanvasTextEditFinishIntent.commit,
        ),
        CanvasTextEditFinishResult.rejected,
      );
      expect(_containsElement(exceptionScenario.root, _textId), isTrue);
      expect(session.isActive, isTrue);
      expect(session.isStale, isFalse);
      expect(session.liveText, ' ');
      expect(exceptionScenario.root.textEditing.activeSession.value, same(session));
      _expectRequestFactsLive(exceptionScenario.root, request);
      expect(exceptionScenario.actions, isEmpty);
    } finally {
      await exceptionScenario.dispose();
    }

    final lease = _TextCommitLease();
    final incompatibleScenario = _Scenario(
      config: CanvasRuntimeConfig(
        commitResolver: (_) => CanvasMoveCommitAccept(
          delta: const Offset(1, 0),
          lease: lease,
        ),
      ),
    );
    try {
      final request = await incompatibleScenario.issueTextRequest();
      final session = _expectSession(
        incompatibleScenario.root.textEditing.startFromContextAction(
          request,
          emptyTextBehavior: CanvasTextEditEmptyTextBehavior.deleteElement,
        ),
      );
      session.updateText(' ');

      expect(
        incompatibleScenario.root.textEditing.finishActive(
          CanvasTextEditFinishIntent.commit,
        ),
        CanvasTextEditFinishResult.rejected,
      );
      expect(_containsElement(incompatibleScenario.root, _textId), isTrue);
      expect(incompatibleScenario.root.textEditing.activeSession.value, same(session));
      _expectRequestFactsLive(incompatibleScenario.root, request);
      expect(lease.committedCalls, 0);
      expect(lease.abortedCalls, 1);
      expect(incompatibleScenario.actions, isEmpty);
    } finally {
      await incompatibleScenario.dispose();
    }
  });
}

// These public text-session witnesses keep independent deletion outcomes
// isolated while preserving the full policy, direct-removal, and terminal-work
// oracle where an empty update before deletion could otherwise pass by final
// document state alone.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _testEmptyPolicyDeletion() {
  test(
    'delete policy removes whitespace through one direct deletion',
    () async {
      CanvasDeleteCommitRequest? whitespaceProposal;
      final whitespaceLease = _TextCommitLease();
      final whitespaceScenario = _Scenario(
        config: CanvasRuntimeConfig(
          commitResolver: (request) {
            whitespaceProposal = request as CanvasDeleteCommitRequest;
            return CanvasCommitAccept(lease: whitespaceLease);
          },
        ),
      );
      try {
        final request = await whitespaceScenario.issueTextRequest();
        final session = _expectSession(
          whitespaceScenario.root.textEditing.sessionCandidateFor(
            request,
            emptyTextBehavior: CanvasTextEditEmptyTextBehavior.deleteElement,
          ),
        );
        expect(session.emptyTextBehavior, CanvasTextEditEmptyTextBehavior.deleteElement);
        expect(
          whitespaceScenario.root.textEditing.sessionCandidateFor(
            request,
            emptyTextBehavior: CanvasTextEditEmptyTextBehavior.keepElement,
          ),
          same(session),
        );
        expect(whitespaceScenario.root.textEditing.start(session), same(session));
        expect(
          whitespaceScenario.root.textEditing.startFromContextAction(
            request,
            emptyTextBehavior: CanvasTextEditEmptyTextBehavior.keepElement,
          ),
          same(session),
        );
        final original = _textElement(whitespaceScenario.root);
        final work = <PreparedInteractionApplyWorkEvent>[];
        var projectionCount = 0;
        final construction = <RuntimeDeletionRouteConstructionKind>[];
        final requestWork = <RuntimeDeletionRequestWorkEvent>[];

        session.updateFormatting(isBold: true);
        session.updateText(' \n\t');

        expect(
          DocumentStoreKernel.observeDeletionEntryProjection(
            (_) => projectionCount += 1,
            () => RuntimeRoot.observeDeletionRouteConstruction(
              construction.add,
              () => RuntimeRoot.observeDeletionRequestWork(
                requestWork.add,
                () => CommitApplier.observePreparedInteractionWork(
                  work.add,
                  () => session.commit(timestampMs: 103),
                ),
              ),
            ),
          ),
          isTrue,
        );

        final proposal = whitespaceProposal;
        if (proposal == null) fail('Expected a deletion proposal.');
        expect(proposal.entries, hasLength(1));
        final entry = proposal.entries.single;
        _expectCompleteTextElement(_asTextElement(entry.element), original);
        expect(entry.layerId, CanvasLayerId('layer-a'));
        expect(entry.elementIndex, 0);
        expect(_containsElement(whitespaceScenario.root, _textId), isFalse);
        expect(work, [
          PreparedInteractionApplyWorkEvent.prepared,
          PreparedInteractionApplyWorkEvent.ownershipReleased,
          PreparedInteractionApplyWorkEvent.consumed,
        ]);
        expect(whitespaceLease.committedCalls, 1);
        expect(whitespaceLease.abortedCalls, 0);
        expect(projectionCount, 1);
        expect(construction, [RuntimeDeletionRouteConstructionKind.request]);
        expect(requestWork, [RuntimeDeletionRequestWorkEvent.entryCopied]);
        expect(whitespaceScenario.actions, hasLength(1));
        expect(
          whitespaceScenario.actions.single.type,
          CanvasActionType.deleteElements,
        );
      } finally {
        await whitespaceScenario.dispose();
      }
    },
  );

  test('delete policy removes originally empty nondeletable text directly', () async {
    CanvasDeleteCommitRequest? emptyProposal;
    final emptyScenario = _Scenario(
      document: _document(text: '', isDeletable: false),
      config: CanvasRuntimeConfig(
        commitResolver: (request) {
          emptyProposal = request as CanvasDeleteCommitRequest;
          return acceptCommit(request);
        },
      ),
    );
    try {
      final request = await emptyScenario.issueTextRequest();
      final session = _expectSession(
        emptyScenario.root.textEditing.startFromContextAction(
          request,
          emptyTextBehavior: CanvasTextEditEmptyTextBehavior.deleteElement,
        ),
      );
      final original = _textElement(emptyScenario.root);

      expect(session.commit(), isTrue);

      final proposal = emptyProposal;
      if (proposal == null) fail('Expected an empty-text deletion proposal.');
      _expectCompleteTextElement(
        _asTextElement(proposal.entries.single.element),
        original,
      );
      expect(proposal.entries.single.element.isDeletable, isFalse);
      expect(_containsElement(emptyScenario.root, _textId), isFalse);
    } finally {
      await emptyScenario.dispose();
    }
  });

  test('empty text keeps its element by default', () async {
    CanvasCommitRequest? keepProposal;
    final keepScenario = _Scenario(
      config: CanvasRuntimeConfig(
        commitResolver: (request) {
          keepProposal = request;
          return acceptCommit(request);
        },
      ),
    );
    try {
      final session = await _startTextSession(keepScenario);
      session.updateText(' \n\t');

      expect(session.commit(), isTrue);
      expect(keepProposal, isA<CanvasTextEditCommitRequest>());
      expect(_textValue(keepScenario.root), ' \n\t');
    } finally {
      await keepScenario.dispose();
    }
  });
}

// Direct command input must reach the terminal unchanged, while all committing
// adapters validate before no-op closure or resolver work.
// ignore: halstead-volume, maintainability-index, source-lines-of-code
void _testDirectTerminalInputAndSharedValidation() {
  test(
    'direct command input does not publish a draft before terminal delivery',
    () async {
      CanvasTextEditCommitRequest? proposed;
      final scenario = _Scenario(
        config: CanvasRuntimeConfig(
          commitResolver: (request) {
            proposed = request as CanvasTextEditCommitRequest;

            return acceptCommit(request);
          },
        ),
      );
      try {
        final request = await scenario.issueTextRequest();
        final session = _expectSession(
          scenario.root.textEditing.startFromContextAction(request),
        );
        session.updateText('retained draft');
        session.updateFormatting(isBold: true, isUnderline: true);
        var notifications = 0;
        void listener() {
          notifications += 1;
          if (session.isActive) {
            session.updateText('listener replacement');
            session.dismiss();
          }
        }

        scenario.root.textEditing.activeSession.addListener(listener);
        try {
          expect(
            scenario.root.commands.commitTextEdit(
              request.requestId,
              'command terminal input',
              timestampMs: 82,
            ),
            isTrue,
          );
        } finally {
          scenario.root.textEditing.activeSession.removeListener(listener);
        }

        expect(proposed?.after.text, 'command terminal input');
        expect(proposed?.after.isBold, isTrue);
        expect(proposed?.after.isItalic, isFalse);
        expect(proposed?.after.isUnderline, isTrue);
        expect(_textValue(scenario.root), 'command terminal input');
        expect(session.liveText, 'retained draft');
        expect(notifications, 1);
        expect(session.isActive, isFalse);
        expect(scenario.actions, hasLength(1));
      } finally {
        await scenario.dispose();
      }
    },
  );

  test(
    'session and port commits validate timestamps before no-op closure',
    () async {
      final scenario = _Scenario();
      try {
        final request = await scenario.issueTextRequest();
        final session = _expectSession(
          scenario.root.textEditing.startFromContextAction(request),
        );

        expect(
          () => session.commit(timestampMs: -1),
          throwsA(isA<CanvasDataException>()),
        );
        expect(
          () => scenario.root.textEditing.finishActive(
            CanvasTextEditFinishIntent.commit,
            timestampMs: -2,
          ),
          throwsA(isA<CanvasDataException>()),
        );
        expect(session.isActive, isTrue);
        expect(scenario.root.textEditing.activeSession.value, same(session));
        _expectRequestFactsLive(scenario.root, request);
        expect(_textValue(scenario.root), 'hello');
        expect(scenario.actions, isEmpty);
      } finally {
        await scenario.dispose();
      }
    },
  );
}

// The terminal outcome matrix keeps each independently observable session
// lifecycle beside its shared public seam, which is clearer than scattering
// setup and state assertions across test-only helpers.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _testTypedFinishReportsNoActiveSession() {
  test(
    'typed finish validates an absent commit timestamp before its result',
    () async {
      var resolverCalls = 0;
      final scenario = _Scenario(
        config: CanvasRuntimeConfig(
          commitResolver: (_) {
            resolverCalls += 1;
            return const CanvasCommitCancel();
          },
        ),
      );
      try {
        final documentRevision = scenario.root.state.value.revisions.document;

        expect(
          () => scenario.root.textEditing.finishActive(
            CanvasTextEditFinishIntent.commit,
            timestampMs: -1,
          ),
          throwsA(
            isA<CanvasDataException>().having(
              (error) => error.path,
              'path',
              'textEdit.timestampMs',
            ),
          ),
        );
        expect(
          scenario.root.textEditing.finishActive(
            CanvasTextEditFinishIntent.commit,
            timestampMs: 4,
          ),
          CanvasTextEditFinishResult.noActiveSession,
        );
        expect(
          scenario.root.textEditing.finishActive(
            CanvasTextEditFinishIntent.commit,
          ),
          CanvasTextEditFinishResult.noActiveSession,
        );
        expect(scenario.root.textEditing.activeSession.value, isNull);
        expect(scenario.root.activeTextEditSuppressionForTesting, isNull);
        expect(_textValue(scenario.root), 'hello');
        expect(scenario.root.state.value.revisions.document, documentRevision);
        expect(resolverCalls, 0);
        expect(scenario.actions, isEmpty);
      } finally {
        await scenario.dispose();
      }
    },
  );

  test('typed finish reports an absent active session', () async {
    final scenario = _Scenario();
    try {
      expect(
        scenario.root.textEditing.finishActive(
          CanvasTextEditFinishIntent.commit,
        ),
        CanvasTextEditFinishResult.noActiveSession,
      );
      expect(_textValue(scenario.root), 'hello');
      expect(scenario.actions, isEmpty);
    } finally {
      await scenario.dispose();
    }
  });

  test('typed finish commits and closes a changed active draft', () async {
    final scenario = _Scenario();
    try {
      final session = await _startTextSession(scenario);
      session.updateText('typed finish');
      final projections = <StoreAffectedElementProjection>[];
      final work = <PreparedInteractionApplyWorkEvent>[];

      CommitApplier.observePreparedInteractionWork(
        work.add,
        () => DocumentStoreKernel.observeAffectedElementProjection(
          projections.add,
          () => expect(
            scenario.root.textEditing.finishActive(
              CanvasTextEditFinishIntent.commit,
              timestampMs: 81,
            ),
            CanvasTextEditFinishResult.committed,
          ),
        ),
      );
      expect(projections, hasLength(1));
      expect(work, [
        PreparedInteractionApplyWorkEvent.prepared,
        PreparedInteractionApplyWorkEvent.ownershipReleased,
        PreparedInteractionApplyWorkEvent.consumed,
      ]);
      expect(_textValue(scenario.root), 'typed finish');
      expect(session.isActive, isFalse);
      expect(scenario.actions, hasLength(1));
    } finally {
      await scenario.dispose();
    }
  });

  test('typed finish closes a net-equal draft as unchanged', () async {
    var resolverCalls = 0;
    final scenario = _Scenario(
      config: CanvasRuntimeConfig(
        commitResolver: (_) {
          resolverCalls += 1;
          return const CanvasCommitCancel();
        },
      ),
    );
    try {
      final session = await _startTextSession(scenario);

      expect(
        scenario.root.textEditing.finishActive(
          CanvasTextEditFinishIntent.commit,
        ),
        CanvasTextEditFinishResult.unchanged,
      );
      expect(_textValue(scenario.root), 'hello');
      expect(session.isActive, isFalse);
      expect(resolverCalls, 0);
      expect(scenario.actions, isEmpty);
    } finally {
      await scenario.dispose();
    }
  });

  test('typed finish cancels even a stale active draft', () async {
    final scenario = _Scenario();
    try {
      final session = await _startTextSession(scenario);
      session.updateText('discard this draft');
      _makeTextRequestStale(scenario);

      expect(
        scenario.root.textEditing.finishActive(
          CanvasTextEditFinishIntent.cancel,
        ),
        CanvasTextEditFinishResult.cancelled,
      );
      expect(_textValue(scenario.root), 'hello');
      expect(session.isActive, isFalse);
      expect(scenario.actions, isEmpty);
    } finally {
      await scenario.dispose();
    }
  });

  test('typed finish keeps a resolver-rejected draft retryable', () async {
    final scenario = _Scenario(
      config: CanvasRuntimeConfig(
        commitResolver: (_) => const CanvasCommitCancel(),
      ),
    );
    try {
      final session = await _startTextSession(scenario);
      session.updateText('retryable');

      expect(
        scenario.root.textEditing.finishActive(
          CanvasTextEditFinishIntent.commit,
        ),
        CanvasTextEditFinishResult.rejected,
      );
      expect(_textValue(scenario.root), 'hello');
      expect(session.isActive, isTrue);
      expect(session.liveText, 'retryable');
      expect(scenario.actions, isEmpty);
    } finally {
      await scenario.dispose();
    }
  });

  test('typed finish retains a stale draft', () async {
    final scenario = _Scenario();
    try {
      final session = await _startTextSession(scenario);
      session.updateText('retained stale draft');
      _makeTextRequestStale(scenario);

      expect(
        scenario.root.textEditing.finishActive(
          CanvasTextEditFinishIntent.commit,
        ),
        CanvasTextEditFinishResult.stale,
      );
      expect(_textValue(scenario.root), 'hello');
      expect(session.isActive, isTrue);
      expect(session.liveText, 'retained stale draft');
      expect(scenario.actions, isEmpty);
    } finally {
      await scenario.dispose();
    }
  });
}

void _testCandidateLookup() {
  test(
    'candidate lookup observes request without consuming or mutating',
    () async {
      final scenario = _Scenario();
      try {
        final request = await scenario.issueTextRequest();
        final beforeRevision = scenario.root.state.value.revisions.document;

        final candidate = scenario.root.textEditing.sessionCandidateFor(
          request,
        );

        _expectInitialCandidate(candidate, request);
        expect(scenario.root.textEditing.activeSession.value, isNull);
        expect(scenario.root.activeTextEditSuppressionForTesting, isNull);
        _expectRequestFactsLive(scenario.root, request);
        expect(scenario.root.state.value.revisions.document, beforeRevision);
        expect(_textValue(scenario.root), 'hello');
      } finally {
        await scenario.dispose();
      }
    },
  );
}

void _testNonTextCandidateLookup() {
  test('non-text context requests do not start text editing', () async {
    final scenario = _Scenario();
    try {
      _expectNonTextRequestRejected(
        scenario,
        await scenario.issueRectRequest(),
      );
      _expectNonTextRequestRejected(
        scenario,
        await scenario.issueEmptyCanvasRequest(),
      );
      expect(scenario.root.textEditing.activeSession.value, isNull);
    } finally {
      await scenario.dispose();
    }
  });
}

// One scenario must retain every public admission route and its shared guard
// facts; splitting it would hide cross-route policy disagreement.
// ignore: halstead-volume, source-lines-of-code
void _testReadOnlyAdmission() {
  test('read-only admission refuses every text admission route', () async {
    final scenario = _Scenario();
    try {
      final readOnlyRequest = await scenario.issueTextRequest();
      final candidate = _expectSession(
        scenario.root.textEditing.sessionCandidateFor(readOnlyRequest),
      );
      scenario.root.textEditing.setReadOnly(true);
      expect(
        await _observeAdmissionRefusal(
          scenario,
          () => scenario.root.textEditing.start(candidate),
        ),
        isNull,
      );
      expect(
        await _observeAdmissionRefusal(
          scenario,
          () => scenario.root.textEditing.startForElement(_textId),
          reason: CanvasTextEditStartRefusalReason.readOnly,
        ),
        isA<CanvasTextEditStartRefusal>(),
      );
      expect(
        await _observeAdmissionRefusal(
          scenario,
          () => scenario.root.textEditing.sessionCandidateFor(readOnlyRequest),
        ),
        isNull,
      );
      expect(
        await _observeAdmissionRefusal(
          scenario,
          () => scenario.root.textEditing.startFromContextAction(readOnlyRequest),
        ),
        isNull,
      );
      expect(scenario.root.textEditing.activeSession.value, isNull);
      expect(scenario.root.textEditCandidateStateCountForTesting, 1);
      _expectRequestFactsLive(scenario.root, readOnlyRequest);
    } finally {
      await scenario.dispose();
    }
  });
}

void _testSingleActiveAdmission() {
  test('single-active admission preserves competing request facts', () async {
    final scenario = _Scenario();
    try {
      final firstSession = await _startIdempotentTextSession(scenario);
      expect(scenario.root.activeTextEditSuppressionForTesting, isNotNull);

      await _expectCompetingRequestRejected(scenario, firstSession);

      scenario.root.textEditing.setReadOnly(true);
      expect(scenario.root.textEditing.activeSession.value, isNull);
      expect(scenario.root.activeTextEditSuppressionForTesting, isNull);
      expect(_textValue(scenario.root), 'hello');
      expect(scenario.actions, isEmpty);
    } finally {
      await scenario.dispose();
    }
  });
}

// ID admission must classify actual addressed frame facts and share the active
// slot policy with context candidates without fabricating a context event.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _testIdAdmission() {
  test('ID admission returns typed outcomes and retains valid session policy', () async {
    final scenario = _Scenario();
    try {
      final beforeDocument = scenario.root.readDocument();
      final first = _expectStartSuccess(
        _observeNoTextAdmissionWork(
          scenario.root,
          () => scenario.root.textEditing.startForElement(
            _textId,
            emptyTextBehavior: CanvasTextEditEmptyTextBehavior.deleteElement,
          ),
        ),
      );
      expect(scenario.requests, isEmpty);
      expect(scenario.root.textEditing.activeSession.value, same(first));
      expect(first.emptyTextBehavior, CanvasTextEditEmptyTextBehavior.deleteElement);
      await Future<void>.delayed(Duration.zero);
      expect(scenario.requests, isEmpty);
      expect(scenario.actions, isEmpty);

      first.updateText('ID-origin draft');
      first.updateFormatting(isBold: true);
      final repeated = _expectStartSuccess(
        _observeNoTextAdmissionWork(
          scenario.root,
          () => scenario.root.textEditing.startForElement(_textId),
        ),
      );
      expect(repeated, same(first));
      expect(repeated.emptyTextBehavior, CanvasTextEditEmptyTextBehavior.deleteElement);
      expect(repeated.liveText, 'ID-origin draft');
      expect(repeated.style.isBold, isTrue);
      expect(scenario.root.readDocument(), same(beforeDocument));
      expect(scenario.requests, isEmpty);
      await Future<void>.delayed(Duration.zero);
      expect(scenario.requests, isEmpty);
      expect(scenario.actions, isEmpty);
      expect(first.commit(), isTrue);
      expect(_textValue(scenario.root), 'ID-origin draft');

      await _observeAdmissionRefusal(
        scenario,
        () => scenario.root.textEditing.startForElement(CanvasElementId('missing')),
        reason: CanvasTextEditStartRefusalReason.notFound,
      );
      await _observeAdmissionRefusal(
        scenario,
        () => scenario.root.textEditing.startForElement(_rectId),
        reason: CanvasTextEditStartRefusalReason.unsupportedType,
      );

      scenario.root.edits.edit(
        (edit) => edit.updateElement(
          CanvasTextElementUpdate(
            id: _textId,
            isVisible: const CanvasFieldSet(false),
          ),
        ),
      );
      await _observeAdmissionRefusal(
        scenario,
        () => scenario.root.textEditing.startForElement(_textId),
        reason: CanvasTextEditStartRefusalReason.unavailable,
      );

      scenario.root.edits.edit((edit) {
        edit.removeElement(_textId);
        edit.addBackgroundElement(
          CanvasTextElement(
            id: _textId,
            text: 'background text',
            fontSize: 16,
            color: const Color(0xFF111111),
            textDirection: TextDirection.ltr,
          ),
        );
      });
      await _observeAdmissionRefusal(
        scenario,
        () => scenario.root.textEditing.startForElement(_textId),
        reason: CanvasTextEditStartRefusalReason.unavailable,
      );
    } finally {
      await scenario.dispose();
    }
  });

  test('ID admission retains stale and other active sessions', () async {
    final staleScenario = _Scenario();
    try {
      final stale = _expectStartSuccess(
        _observeNoTextAdmissionWork(
          staleScenario.root,
          () => staleScenario.root.textEditing.startForElement(_textId),
        ),
      );
      stale.updateText('retained stale draft');
      stale.updateFormatting(isItalic: true);
      _makeTextRequestStale(staleScenario);

      await _observeAdmissionRefusal(
        staleScenario,
        () => staleScenario.root.textEditing.startForElement(_textId),
        reason: CanvasTextEditStartRefusalReason.stale,
        expectedActive: stale,
      );
      expect(staleScenario.root.textEditing.activeSession.value, same(stale));
      expect(stale.liveText, 'retained stale draft');
      expect(stale.style.isItalic, isTrue);
      expect(staleScenario.requests, isEmpty);
    } finally {
      await staleScenario.dispose();
    }

    final otherScenario = _Scenario();
    try {
      otherScenario.addSecondTextElement();
      final active = _expectStartSuccess(
        _observeNoTextAdmissionWork(
          otherScenario.root,
          () => otherScenario.root.textEditing.startForElement(_textId),
        ),
      );
      await _observeAdmissionRefusal(
        otherScenario,
        () => otherScenario.root.textEditing.startForElement(_secondTextId),
        reason: CanvasTextEditStartRefusalReason.anotherSessionActive,
        expectedActive: active,
      );
      _makeTextRequestStale(otherScenario);
      await _observeAdmissionRefusal(
        otherScenario,
        () => otherScenario.root.textEditing.startForElement(_secondTextId),
        reason: CanvasTextEditStartRefusalReason.anotherSessionActive,
        expectedActive: active,
      );
      expect(otherScenario.root.textEditing.activeSession.value, same(active));
      expect(otherScenario.requests, isEmpty);
    } finally {
      await otherScenario.dispose();
    }
  });

  test('context candidate and start reuse the active ID session', () async {
    final scenario = _Scenario();
    try {
      final active = _expectStartSuccess(
        scenario.root.textEditing.startForElement(
          _textId,
          emptyTextBehavior: CanvasTextEditEmptyTextBehavior.deleteElement,
        ),
      );
      final request = await scenario.issueTextRequest();
      expect(scenario.root.textEditing.sessionCandidateFor(request), same(active));
      expect(scenario.root.textEditing.startFromContextAction(request), same(active));
      expect(active.emptyTextBehavior, CanvasTextEditEmptyTextBehavior.deleteElement);
      await Future<void>.delayed(Duration.zero);
      expect(scenario.requests, isEmpty);
      expect(scenario.actions, isEmpty);
      _expectRequestFactsLive(scenario.root, request);
    } finally {
      await scenario.dispose();
    }
  });

  test('ID start reuses a valid context candidate and its captured policy', () async {
    final scenario = _Scenario();
    try {
      final request = await scenario.issueTextRequest();
      final candidate = _expectSession(
        _observeNoTextAdmissionWork(
          scenario.root,
          () => scenario.root.textEditing.sessionCandidateFor(
            request,
            emptyTextBehavior: CanvasTextEditEmptyTextBehavior.deleteElement,
          ),
        ),
      );
      final started = _expectStartSuccess(
        _observeNoTextAdmissionWork(
          scenario.root,
          () => scenario.root.textEditing.startForElement(_textId),
        ),
      );
      expect(started, same(candidate));
      expect(started.requestId, request.requestId);
      expect(started.emptyTextBehavior, CanvasTextEditEmptyTextBehavior.deleteElement);
      await Future<void>.delayed(Duration.zero);
      expect(scenario.requests, isEmpty);
      expect(scenario.actions, isEmpty);
      started.updateText('candidate ID commit');
      expect(started.commit(), isTrue);
      expect(_textValue(scenario.root), 'candidate ID commit');
    } finally {
      await scenario.dispose();
    }
  });

  test('ID admission discards an expired inactive context candidate', () async {
    final scenario = _Scenario();
    try {
      final request = await scenario.issueTextRequest();
      final candidate = _expectSession(
        scenario.root.textEditing.sessionCandidateFor(request),
      );
      _makeTextRequestStale(scenario);

      final started = _expectStartSuccess(
        _observeNoTextAdmissionWork(
          scenario.root,
          () => scenario.root.textEditing.startForElement(_textId),
        ),
      );
      expect(started, isNot(same(candidate)));
      expect(started.requestId, isNot(request.requestId));
      expect(started.isStale, isFalse);
      expect(scenario.root.textEditing.activeSession.value, same(started));
      await Future<void>.delayed(Duration.zero);
      expect(scenario.requests, isEmpty);
      expect(scenario.actions, isEmpty);
    } finally {
      await scenario.dispose();
    }
  });

  test('ID admission accepts visible empty text', () async {
    final scenario = _Scenario(document: _document(text: ''));
    try {
      final session = _expectStartSuccess(
        _observeNoTextAdmissionWork(
          scenario.root,
          () => scenario.root.textEditing.startForElement(_textId),
        ),
      );
      expect(session.initialText, isEmpty);
      session.dismiss();
    } finally {
      await scenario.dispose();
    }
  });
}

void _testRuntimeUsesMeasuredLayoutBoundary() {
  test('runtime text editing does not own text measurement', () {
    final source = File('lib/src/runtime/runtime_root.dart').readAsStringSync();

    expect(source, contains('FrameTextLayoutMeasurer'));
    expect(source, contains('MeasuredTextLayoutInput'));
    expect(source, contains('measureTextLayout'));
    expect(source, isNot(contains('TextPainter')));
    expect(source, isNot(contains('text.length')));
  });
}

void _testActiveSessionPublishesLiveUpdates() {
  test(
    'active session listeners are notified when live text changes',
    () async {
      final scenario = _Scenario();
      var notifications = 0;
      void listener() {
        notifications += 1;
      }

      scenario.root.textEditing.activeSession.addListener(listener);
      try {
        final session = await _startTextSession(scenario);
        notifications = 0;

        session.updateText('listener update');

        expect(session.liveText, 'listener update');
        expect(notifications, 1);

        session.updateText('listener update');

        expect(session.liveText, 'listener update');
        expect(notifications, 1);
      } finally {
        scenario.root.textEditing.activeSession.removeListener(listener);
        await scenario.dispose();
      }
    },
  );
}

// The complete outer/listener/nested trace stays in one test so its required
// causal order and matching-session replacement stay auditable instead of being
// hidden across setup helpers; splitting the branches would obscure the order.
// ignore: cyclomatic-complexity, halstead-volume, source-lines-of-code, maintainability-index
void _testChangedTextListenerRunsAfterOuterDelivery() {
  test(
    'changed-text close notifies after outer delivery and preserves a listener session',
    () async {
      final trace = <String>[];
      final actions = <CanvasActionCommitted>[];
      late final RuntimeRoot root;
      late CanvasTextEditSession outerSession;
      late CanvasInteractionRequestId requestId;
      late CanvasContextActionRequested replacementRequest;
      CanvasTextEditSession? replacementSession;
      var committing = false;
      var listenerIsRunning = false;
      var interactionRevisionAtListener = -1;
      var outerInteractionRevisionAtState = -1;

      root = runtimeRootWithCommittedDocumentSeed(
        _document(),
        commitEffectObserver: (_) {
          if (!committing) {
            return;
          }
          trace.add(listenerIsRunning ? 'nested-observer' : 'outer-observer');
        },
      );
      final surface = Object();
      root.attachSurface(surface);
      root.edits.edit((edit) {
        edit.addElement(
          CanvasTextElement(
            id: _replacementTextId,
            text: 'replacement',
            fontSize: 16,
            color: const Color(0xFF111111),
            textDirection: TextDirection.ltr,
            transform: CanvasTransform.translation(const Offset(200, 0)),
          ),
        );
      });
      final requests = <CanvasContextActionRequested>[];
      final requestSubscription = root.contextActionRequests.listen(
        requests.add,
      );
      root.surfaceFrameSignal.addListener(() {
        if (!committing) {
          return;
        }
        trace.add(listenerIsRunning ? 'nested-frame' : 'outer-frame');
        if (!listenerIsRunning) {
          expect(root.activeTextEditSuppressionForTesting, isNull);
          expect(root.textEditing.activeSession.value, isNull);
          expect(_textValue(root), 'outer text');
        }
      });
      root.state.addListener(() {
        if (!committing) {
          return;
        }
        trace.add(listenerIsRunning ? 'nested-state' : 'outer-state');
        if (!listenerIsRunning) {
          outerInteractionRevisionAtState =
              root.state.value.revisions.interaction;
        }
      });
      final actionSubscription = root.actions.listen((action) {
        if (!committing) {
          return;
        }
        actions.add(action);
        trace.add('outer-action');
      });
      // This listener keeps the complete public close/replacement causal trace
      // together; extracting its assertions would hide the ordering it proves.
      // ignore: halstead-volume
      void listener() {
        if (root.textEditing.activeSession.value != null) {
          return;
        }
        trace.add('listener');
        expect(_textValue(root), 'outer text');
        expect(root.interactionEngine.requestFactsFor(requestId), isNull);
        expect(root.activeTextEditSuppressionForTesting, isNull);
        expect(outerSession.isActive, isFalse);
        expect(trace, [
          'outer-frame',
          'outer-state',
          'outer-action',
          'outer-observer',
          'listener',
        ]);
        interactionRevisionAtListener = root.state.value.revisions.interaction;
        expect(interactionRevisionAtListener, outerInteractionRevisionAtState);

        listenerIsRunning = true;
        root.edits.edit((edit) {
          edit.addElement(
            CanvasRectElement(
              id: _listenerNestedRectId,
              size: const Size(8, 8),
            ),
          );
        });
        listenerIsRunning = false;
        listenerIsRunning = true;
        replacementSession = _expectSession(
          root.textEditing.startFromContextAction(replacementRequest),
        );
        listenerIsRunning = false;
        trace.add('listener-return');
      }

      root.textEditing.activeSession.addListener(listener);
      try {
        root.handleDoubleTap(position: Offset.zero, timestampMs: 1);
        await Future<void>.delayed(Duration.zero);
        final request = requests.single;
        requestId = request.requestId;
        root.handleDoubleTap(position: const Offset(200, 0), timestampMs: 2);
        await Future<void>.delayed(Duration.zero);
        replacementRequest = requests.last;
        final session = _expectSession(
          root.textEditing.startFromContextAction(request),
        );
        outerSession = session;
        session.updateText('outer text');

        committing = true;
        expect(session.commit(timestampMs: 77), isTrue);
        committing = false;

        expect(trace, [
          'outer-frame',
          'outer-state',
          'outer-action',
          'outer-observer',
          'listener',
          'nested-frame',
          'nested-state',
          'nested-observer',
          'nested-frame',
          'nested-state',
          'listener-return',
        ]);
        expect(session.isActive, isFalse);
        expect(_textValue(root), 'outer text');
        expect(_containsElement(root, _listenerNestedRectId), isTrue);
        expect(root.textEditing.activeSession.value, same(replacementSession));
        expect(
          root.interactionEngine.requestFactsFor(request.requestId),
          isNull,
        );
        expect(root.state.value.revisions.document, 3);
        expect(
          root.state.value.revisions.interaction,
          interactionRevisionAtListener + 1,
        );
        expect(actions, hasLength(1));
        final payload = actions.single.payload as CanvasTextEditActionPayload;
        expect(payload.requestId, request.requestId);
        expect(payload.nextTextLength, 'outer text'.length);
      } finally {
        root.textEditing.activeSession.removeListener(listener);
        await actionSubscription.cancel();
        await requestSubscription.cancel();
        root.detachSurface(surface);
        root.dispose();
      }
    },
  );
}

// The listener owns one complete close/dispose lifecycle so the accepted
// ordering, deferred notifier disposal, and rejected follow-up stay visible.
// ignore: halstead-volume, source-lines-of-code
void _testLateCloseListenerCanDisposeRuntime() {
  test(
    'changed-text close listener can dispose the runtime after outer delivery',
    () async {
      final scenario = _Scenario();
      late CanvasTextEditSession session;
      var closeNotifications = 0;
      void listener() {
        if (scenario.root.textEditing.activeSession.value != null) {
          return;
        }
        closeNotifications += 1;
        expect(_textValue(scenario.root), 'disposed from close listener');
        expect(scenario.actions, hasLength(1));
        expect(scenario.root.activeTextEditSuppressionForTesting, isNull);
        expect(session.isActive, isFalse);
        scenario.root.dispose();
      }

      scenario.root.textEditing.activeSession.addListener(listener);
      try {
        final request = await scenario.issueTextRequest();
        session = _expectSession(
          scenario.root.textEditing.startFromContextAction(request),
        );
        session.updateText('disposed from close listener');

        expect(session.commit(timestampMs: 79), isTrue);

        expect(closeNotifications, 1);
        expect(_textValue(scenario.root), 'disposed from close listener');
        expect(scenario.actions, hasLength(1));
        expect(scenario.root.dispose, returnsNormally);
        expect(
          () => scenario.root.edits.edit(
            (edit) => edit.addElement(
              CanvasRectElement(
                id: CanvasElementId('disposed-close-listener-mutation'),
                size: const Size(1, 1),
              ),
            ),
          ),
          throwsA(isA<StateError>()),
        );
      } finally {
        await scenario.dispose();
      }
    },
  );
}

// The notifier/reporter failure and later delivery/guard probe form one
// containment proof; splitting them would obscure the required continuation.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _testChangedTextListenerFailureReportsAndContinuesDelivery() {
  test(
    'changed-text listener and reporter failures do not escape an accepted commit',
    () async {
      final trace = <String>[];
      final errors = <FlutterErrorDetails>[];
      final previousErrorHandler = FlutterError.onError;
      late final RuntimeRoot root;
      var committing = false;
      final listenerFailure = StateError('active-session listener failed');
      final reporterFailure = StateError('active-session reporter failed');
      void throwingReporter(FlutterErrorDetails details) {
        errors.add(details);
        throw reporterFailure;
      }

      root = runtimeRootWithCommittedDocumentSeed(
        _document(),
        commitEffectObserver: (_) {
          if (committing) {
            trace.add('outer-observer');
          }
        },
      );
      final surface = Object();
      root.attachSurface(surface);
      final requests = <CanvasContextActionRequested>[];
      final requestSubscription = root.contextActionRequests.listen(
        requests.add,
      );
      root.surfaceFrameSignal.addListener(() {
        if (committing) {
          trace.add('outer-frame');
        }
      });
      root.state.addListener(() {
        if (committing) {
          trace.add('outer-state');
        }
      });
      final actions = <CanvasActionCommitted>[];
      final actionSubscription = root.actions.listen((action) {
        if (committing) {
          actions.add(action);
          trace.add('outer-action');
        }
      });
      void listener() {
        if (root.textEditing.activeSession.value == null) {
          throw listenerFailure;
        }
      }

      root.textEditing.activeSession.addListener(listener);
      try {
        root.handleDoubleTap(position: Offset.zero, timestampMs: 1);
        await Future<void>.delayed(Duration.zero);
        final request = requests.single;
        final session = _expectSession(
          root.textEditing.startFromContextAction(request),
        );
        session.updateText('failure retained');

        committing = true;
        FlutterError.onError = throwingReporter;
        expect(session.commit(timestampMs: 78), isTrue);
        committing = false;

        expect(FlutterError.onError, same(throwingReporter));
        expect(errors, hasLength(1));
        expect(errors.single.exception, same(listenerFailure));
        expect(trace, [
          'outer-frame',
          'outer-state',
          'outer-action',
          'outer-observer',
        ]);
        expect(_textValue(root), 'failure retained');
        expect(session.isActive, isFalse);
        expect(root.textEditing.activeSession.value, isNull);
        expect(
          root.interactionEngine.requestFactsFor(request.requestId),
          isNull,
        );
        expect(root.state.value.revisions.document, 1);
        expect(root.state.value.revisions.interaction, 2);
        expect(actions, hasLength(1));

        root.edits.edit((edit) {
          edit.addElement(
            CanvasRectElement(
              id: _listenerFailureRectId,
              size: const Size(6, 6),
            ),
          );
        });
        expect(_containsElement(root, _listenerFailureRectId), isTrue);
      } finally {
        root.textEditing.activeSession.removeListener(listener);
        await actionSubscription.cancel();
        await requestSubscription.cancel();
        root.detachSurface(surface);
        FlutterError.onError = previousErrorHandler;
        root.dispose();
      }
    },
  );
}

void _testLiveUpdateRemeasuresGeometry() {
  test('live update remeasures geometry without document mutation', () async {
    final scenario = _Scenario();
    try {
      final request = await scenario.issueTextRequest();
      final session = _expectSession(
        scenario.root.textEditing.startFromContextAction(request),
      );
      final beforeHeight = session.geometry.editBoundsWorld.height;

      session.updateText('hello\nworld');

      expect(session.liveText, 'hello\nworld');
      expect(
        session.geometry.editBoundsWorld.height,
        greaterThan(beforeHeight),
      );
      expect(_textValue(scenario.root), 'hello');
      expect(scenario.root.state.value.revisions.document, 0);
    } finally {
      await scenario.dispose();
    }
  });
}

// One assertion path must retain the resolver proposal, committed fields,
// revision, action, and preparation observations together; splitting its
// independent flag case oracles would hide a partial update or work leak.
// ignore: halstead-volume, source-lines-of-code, maintainability-index, cyclomatic-complexity
void _testFormattingDraftCommitsOneCompleteUpdate() {
  const formattingCases =
      <
        ({
          String name,
          bool baseIsBold,
          bool baseIsItalic,
          bool baseIsUnderline,
          bool? isBold,
          bool? isItalic,
          bool? isUnderline,
        })
      >[
        (
          name: 'bold',
          baseIsBold: false,
          baseIsItalic: false,
          baseIsUnderline: false,
          isBold: true,
          isItalic: null,
          isUnderline: null,
        ),
        (
          name: 'italic',
          baseIsBold: false,
          baseIsItalic: false,
          baseIsUnderline: false,
          isBold: null,
          isItalic: true,
          isUnderline: null,
        ),
        (
          name: 'underline',
          baseIsBold: false,
          baseIsItalic: false,
          baseIsUnderline: false,
          isBold: null,
          isItalic: null,
          isUnderline: true,
        ),
        (
          name: 'bold and italic',
          baseIsBold: false,
          baseIsItalic: false,
          baseIsUnderline: false,
          isBold: true,
          isItalic: true,
          isUnderline: null,
        ),
        (
          name: 'clear bold',
          baseIsBold: true,
          baseIsItalic: false,
          baseIsUnderline: false,
          isBold: false,
          isItalic: null,
          isUnderline: null,
        ),
        (
          name: 'clear italic',
          baseIsBold: false,
          baseIsItalic: true,
          baseIsUnderline: false,
          isBold: null,
          isItalic: false,
          isUnderline: null,
        ),
        (
          name: 'clear underline',
          baseIsBold: false,
          baseIsItalic: false,
          baseIsUnderline: true,
          isBold: null,
          isItalic: null,
          isUnderline: false,
        ),
      ];
  for (final formatting in formattingCases) {
    test(
      'style-only ${formatting.name} draft commits one complete text update',
      () async {
        final expectedIsBold = formatting.isBold ?? formatting.baseIsBold;
        final expectedIsItalic =
            formatting.isItalic ?? formatting.baseIsItalic;
        final expectedIsUnderline =
            formatting.isUnderline ?? formatting.baseIsUnderline;
        CanvasTextEditCommitRequest? proposal;
        final scenario = _Scenario(
          document: _document(
            isBold: formatting.baseIsBold,
            isItalic: formatting.baseIsItalic,
            isUnderline: formatting.baseIsUnderline,
          ),
          config: CanvasRuntimeConfig(
            commitResolver: (request) {
              proposal = request as CanvasTextEditCommitRequest;

              return acceptCommit(request);
            },
          ),
        );
        try {
          final request = await scenario.issueTextRequest();
          final session = _expectSession(
            scenario.root.textEditing.startFromContextAction(request),
          );
          final documentRevision = scenario.root.state.value.revisions.document;
          final documentBeforeFormatting = scenario.root.readDocument();
          final projections = <StoreAffectedElementProjection>[];
          final work = <PreparedInteractionApplyWorkEvent>[];

          CommitApplier.observePreparedInteractionWork(
            work.add,
            () => DocumentStoreKernel.observeAffectedElementProjection(
              projections.add,
              () => session.updateFormatting(
                isBold: formatting.isBold,
                isItalic: formatting.isItalic,
                isUnderline: formatting.isUnderline,
              ),
            ),
          );

          expect(session.style.isBold, expectedIsBold);
          expect(session.style.isItalic, expectedIsItalic);
          expect(session.style.isUnderline, expectedIsUnderline);
          expect(_textElement(scenario.root).text, 'hello');
          expect(_textElement(scenario.root).isBold, formatting.baseIsBold);
          expect(_textElement(scenario.root).isItalic, formatting.baseIsItalic);
          expect(
            _textElement(scenario.root).isUnderline,
            formatting.baseIsUnderline,
          );
          expect(
            scenario.root.state.value.revisions.document,
            documentRevision,
          );
          expect(scenario.root.readDocument(), same(documentBeforeFormatting));
          expect(projections, isEmpty);
          expect(work, isEmpty);

          expect(
            CommitApplier.observePreparedInteractionWork(
              work.add,
              () => DocumentStoreKernel.observeAffectedElementProjection(
                projections.add,
                () => session.commit(timestampMs: 91),
              ),
            ),
            isTrue,
          );

          expect(proposal?.before.text, 'hello');
          expect(proposal?.before.isBold, formatting.baseIsBold);
          expect(proposal?.before.isItalic, formatting.baseIsItalic);
          expect(proposal?.before.isUnderline, formatting.baseIsUnderline);
          expect(proposal?.after.text, 'hello');
          expect(proposal?.after.isBold, expectedIsBold);
          expect(proposal?.after.isItalic, expectedIsItalic);
          expect(proposal?.after.isUnderline, expectedIsUnderline);
          final projectedBefore = _asTextElement(projections.single.before);
          final projectedAfter = _asTextElement(projections.single.after);
          expect(projectedBefore.text, 'hello');
          expect(projectedBefore.isBold, formatting.baseIsBold);
          expect(projectedBefore.isItalic, formatting.baseIsItalic);
          expect(
            projectedBefore.isUnderline,
            formatting.baseIsUnderline,
          );
          expect(projectedAfter.text, 'hello');
          expect(projectedAfter.isBold, expectedIsBold);
          expect(projectedAfter.isItalic, expectedIsItalic);
          expect(projectedAfter.isUnderline, expectedIsUnderline);
          final installed = _textElement(scenario.root);
          expect(installed.text, 'hello');
          expect(installed.isBold, expectedIsBold);
          expect(installed.isItalic, expectedIsItalic);
          expect(installed.isUnderline, expectedIsUnderline);
          expect(
            scenario.root.state.value.revisions.document,
            documentRevision + 1,
          );
          expect(projections, hasLength(1));
          expect(work, [
            PreparedInteractionApplyWorkEvent.prepared,
            PreparedInteractionApplyWorkEvent.ownershipReleased,
            PreparedInteractionApplyWorkEvent.consumed,
          ]);
          expect(scenario.actions, hasLength(1));
          final payload =
              scenario.actions.single.payload as CanvasTextEditActionPayload;
          expect(payload.requestId, request.requestId);
          expect(payload.previousTextLength, 5);
          expect(payload.nextTextLength, 5);
        } finally {
          await scenario.dispose();
        }
      },
    );
  }
}

// Revert and cancel share the same terminal-work absence oracle, so keeping
// their independent flag cases together makes a resolver or action leak visible.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _testFormattingNoOpAndCancelAreSilent() {
  const formattingCases =
      <({String name, bool? isBold, bool? isItalic, bool? isUnderline})>[
        (name: 'bold', isBold: true, isItalic: null, isUnderline: null),
        (name: 'italic', isBold: null, isItalic: true, isUnderline: null),
        (name: 'underline', isBold: null, isItalic: null, isUnderline: true),
        (
          name: 'bold and italic',
          isBold: true,
          isItalic: true,
          isUnderline: null,
        ),
      ];
  for (final formatting in formattingCases) {
    test(
      'reverted ${formatting.name} formatting draft has no terminal work',
      () async {
        var resolverCalls = 0;
        final scenario = _Scenario(
          config: CanvasRuntimeConfig(
            commitResolver: (_) {
              resolverCalls += 1;
              return const CanvasCommitCancel();
            },
          ),
        );
        try {
          final firstRequest = await scenario.issueTextRequest();
          final reverted = _expectSession(
            scenario.root.textEditing.startFromContextAction(firstRequest),
          );
          final initialRevision = scenario.root.state.value.revisions.document;
          final documentBeforeRevert = scenario.root.readDocument();
          final revertedProjections = <StoreAffectedElementProjection>[];
          final revertedWork = <PreparedInteractionApplyWorkEvent>[];

          CommitApplier.observePreparedInteractionWork(
            revertedWork.add,
            () => DocumentStoreKernel.observeAffectedElementProjection(
              revertedProjections.add,
              () => reverted.updateFormatting(
                isBold: formatting.isBold,
                isItalic: formatting.isItalic,
                isUnderline: formatting.isUnderline,
              ),
            ),
          );
          expect(scenario.root.readDocument(), same(documentBeforeRevert));
          expect(revertedProjections, isEmpty);
          expect(revertedWork, isEmpty);

          expect(
            CommitApplier.observePreparedInteractionWork(
              revertedWork.add,
              () => DocumentStoreKernel.observeAffectedElementProjection(
                revertedProjections.add,
                () {
                  reverted.updateFormatting(
                    isBold: formatting.isBold == null ? null : false,
                    isItalic: formatting.isItalic == null ? null : false,
                    isUnderline: formatting.isUnderline == null ? null : false,
                  );

                  return scenario.root.textEditing.finishActive(
                    CanvasTextEditFinishIntent.commit,
                    timestampMs: 94,
                  );
                },
              ),
            ),
            CanvasTextEditFinishResult.unchanged,
          );
          expect(_textElement(scenario.root).isBold, isFalse);
          expect(_textElement(scenario.root).isItalic, isFalse);
          expect(_textElement(scenario.root).isUnderline, isFalse);
          expect(scenario.root.state.value.revisions.document, initialRevision);
          expect(scenario.root.readDocument(), same(documentBeforeRevert));
          expect(revertedProjections, isEmpty);
          expect(revertedWork, isEmpty);
          expect(scenario.actions, isEmpty);
          expect(resolverCalls, 0);
        } finally {
          await scenario.dispose();
        }
      },
    );
  }

  test('cancelled formatting draft does not start terminal work', () async {
    var resolverCalls = 0;
    final scenario = _Scenario(
      config: CanvasRuntimeConfig(
        commitResolver: (_) {
          resolverCalls += 1;
          return const CanvasCommitCancel();
        },
      ),
    );
    try {
      final cancelRequest = await scenario.issueTextRequest();
      final cancelled = _expectSession(
        scenario.root.textEditing.startFromContextAction(cancelRequest),
      );
      final initialRevision = scenario.root.state.value.revisions.document;
      final documentBeforeCancel = scenario.root.readDocument();
      final cancelledProjections = <StoreAffectedElementProjection>[];
      final cancelledWork = <PreparedInteractionApplyWorkEvent>[];

      CommitApplier.observePreparedInteractionWork(
        cancelledWork.add,
        () => DocumentStoreKernel.observeAffectedElementProjection(
          cancelledProjections.add,
          () => cancelled.updateFormatting(isUnderline: true),
        ),
      );
      expect(scenario.root.readDocument(), same(documentBeforeCancel));
      expect(cancelledProjections, isEmpty);
      expect(cancelledWork, isEmpty);

      CommitApplier.observePreparedInteractionWork(
        cancelledWork.add,
        () => DocumentStoreKernel.observeAffectedElementProjection(
          cancelledProjections.add,
          cancelled.dismiss,
        ),
      );

      expect(_textElement(scenario.root).isUnderline, isFalse);
      expect(scenario.root.state.value.revisions.document, initialRevision);
      expect(scenario.root.readDocument(), same(documentBeforeCancel));
      expect(cancelledProjections, isEmpty);
      expect(cancelledWork, isEmpty);
      expect(scenario.actions, isEmpty);
      expect(resolverCalls, 0);
    } finally {
      await scenario.dispose();
    }
  });
}

// This keeps each draft beside its accepted actual frame comparison using
// metrics loaded from the installed Flutter SDK. The frame fixture separately
// proves the same font distinguishes normal, bold, and italic measurement inputs.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _testFormattedDraftGeometryMatchesAcceptedFrame() {
  test(
    'formatted draft geometry and anchor match the accepted frame',
    () async {
      await _loadRobotoForRuntimeStyleGeometry();
      final scenario = _Scenario(
        document: _document(
          align: TextAlign.right,
          maxWidth: null,
          fontFamily: _unit3RuntimeRobotoFamily,
          text: 'WMWMWM',
        ),
      );
      try {
        final initialRequest = await scenario.issueTextRequest();
        final initial = _expectSession(
          scenario.root.textEditing.startFromContextAction(initialRequest),
        );
        final baseGeometry = initial.geometry;
        final baseAnchor = _anchorValueFor(
          baseGeometry.editBoundsWorld,
          TextAlign.right,
        );

        initial.updateFormatting(isBold: true);
        final boldDraftGeometry = initial.geometry;
        expect(
          boldDraftGeometry.editBoundsWorld.width,
          isNot(equals(baseGeometry.editBoundsWorld.width)),
        );
        expect(
          _anchorValueFor(boldDraftGeometry.editBoundsWorld, TextAlign.right),
          moreOrLessEquals(baseAnchor, epsilon: 0.001),
        );
        expect(initial.commit(timestampMs: 92), isTrue);
        _expectAcceptedTextFrameMatchesDraftGeometry(
          scenario.root,
          draftGeometry: boldDraftGeometry,
          baseAnchor: baseAnchor,
          expectedRow: (
            elementId: _textId,
            text: 'WMWMWM',
            isBold: true,
            isItalic: false,
            isUnderline: false,
          ),
        );

        final boldRequest = await scenario.issueTextRequest();
        final boldAccepted = _expectSession(
          scenario.root.textEditing.sessionCandidateFor(boldRequest),
        );
        expect(boldAccepted.geometry, boldDraftGeometry);
        expect(boldAccepted.style.isBold, isTrue);
        expect(boldAccepted.style.isItalic, isFalse);

        final mixed = _expectSession(
          scenario.root.textEditing.start(boldAccepted),
        );
        mixed.updateText('WMWMWM\nitalic mixed draft');
        mixed.updateFormatting(isItalic: true);
        final mixedDraftGeometry = mixed.geometry;
        expect(
          _anchorValueFor(mixedDraftGeometry.editBoundsWorld, TextAlign.right),
          moreOrLessEquals(baseAnchor, epsilon: 0.001),
        );
        expect(mixed.commit(timestampMs: 93), isTrue);
        _expectAcceptedTextFrameMatchesDraftGeometry(
          scenario.root,
          draftGeometry: mixedDraftGeometry,
          baseAnchor: baseAnchor,
          expectedRow: (
            elementId: _textId,
            text: 'WMWMWM\nitalic mixed draft',
            isBold: true,
            isItalic: true,
            isUnderline: false,
          ),
        );

        final mixedRequest = await scenario.issueTextRequest();
        final mixedAccepted = _expectSession(
          scenario.root.textEditing.sessionCandidateFor(mixedRequest),
        );
        expect(mixedAccepted.geometry, mixedDraftGeometry);
        expect(mixedAccepted.style.isBold, isTrue);
        expect(mixedAccepted.style.isItalic, isTrue);
      } finally {
        await scenario.dispose();
      }
    },
  );
}

void _expectAcceptedTextFrameMatchesDraftGeometry(
  RuntimeRoot root, {
  required CanvasTextEditGeometry draftGeometry,
  required double baseAnchor,
  required ({
    CanvasElementId elementId,
    String text,
    bool isBold,
    bool isItalic,
    bool isUnderline,
  })
  expectedRow,
}) {
  final output = root.buildResourceFreeMainFrame(
    viewportWorldBounds: const Rect.fromLTWH(-20, -20, 220, 120),
    devicePixelRatio: 1,
    selectionStyle: CanvasSelectionStyle.defaultStyle,
    gridStyle: CanvasGridStyle.defaultStyle,
  );
  final record = output.ordinaryPlan.ordinaryRecords.singleWhere(
    (record) => record.id == expectedRow.elementId,
  );
  final row = record.row as TextRenderRow;

  expect(record.paintBoundsWorld, draftGeometry.paintBoundsWorld);
  expect(record.transform, draftGeometry.transform);
  expect(
    _anchorValueFor(record.paintBoundsWorld, TextAlign.right),
    moreOrLessEquals(baseAnchor, epsilon: 0.001),
  );
  expect((
    elementId: record.id,
      text: row.text,
      isBold: row.isBold,
      isItalic: row.isItalic,
      isUnderline: row.isUnderline,
  ), expectedRow);
  expect((
    elementId: record.id,
      text: row.layoutInput.text,
      isBold: row.layoutInput.isBold,
      isItalic: row.layoutInput.isItalic,
      isUnderline: row.layoutInput.isUnderline,
  ), expectedRow);
}

void _testLiveGeometryPreservesTextAlignmentAnchor() {
  test(
    'live geometry preserves the aligned text anchor before commit',
    () async {
      await _expectLiveGeometryPreservesAnchorFor(TextAlign.left);
      await _expectLiveGeometryPreservesAnchorFor(TextAlign.right);
      await _expectLiveGeometryPreservesAnchorFor(TextAlign.center);

      expect(TextAlign.values, contains(TextAlign.center));
    },
  );
}

void _testSessionCommitDelegatesToCommandPath() {
  test('session commit delegates to guarded command path', () async {
    final scenario = _Scenario();
    try {
      final request = await scenario.issueTextRequest();
      final session = _expectSession(
        scenario.root.textEditing.startFromContextAction(request),
      );
      session.updateText('updated');

      expect(session.commit(timestampMs: 42), isTrue);

      expect(_textValue(scenario.root), 'updated');
      expect(scenario.actions, hasLength(1));
      final payload =
          scenario.actions.single.payload as CanvasTextEditActionPayload;
      expect(payload.requestId, request.requestId);
      expect(scenario.root.textEditing.activeSession.value, isNull);
      expect(scenario.root.activeTextEditSuppressionForTesting, isNull);
      expect(
        scenario.root.interactionEngine.requestFactsFor(request.requestId),
        isNull,
      );
    } finally {
      await scenario.dispose();
    }
  });
}

void _testCommitPreservesTextAlignmentAnchor() {
  test('commit preserves the aligned text anchor when width changes', () async {
    await _expectCommitPreservesAnchorFor(TextAlign.left);
    await _expectCommitPreservesAnchorFor(TextAlign.right);
    await _expectCommitPreservesAnchorFor(TextAlign.center);

    expect(TextAlign.values, contains(TextAlign.center));
  });
}

void _testDirectCommandCommitClearsActiveSession() {
  test('direct command commit clears matching active session', () async {
    final scenario = _Scenario();
    try {
      final request = await scenario.issueTextRequest();
      final session = _expectSession(
        scenario.root.textEditing.startFromContextAction(request),
      );

      expect(
        scenario.root.commands.commitTextEdit(
          request.requestId,
          'command update',
        ),
        isTrue,
      );

      expect(_textValue(scenario.root), 'command update');
      expect(scenario.root.textEditing.activeSession.value, isNull);
      expect(scenario.root.activeTextEditSuppressionForTesting, isNull);
      expect(session.isActive, isFalse);
    } finally {
      await scenario.dispose();
    }
  });
}

// One route owns the listener, revision, document, and action observations:
// splitting them would hide that a direct commit has no close side effect.
// The direct-command assertion deliberately keeps the prepared-pair observer,
// commit, and public result together; extracting it would hide the ownership
// boundary that proves direct TextEdit seals action lengths from that pair.
// ignore: source-lines-of-code, halstead-volume
void _testDirectCommandCommitWithoutActiveSessionKeepsCloseStatePrivate() {
  test(
    'direct command commit without an active session does not notify close listeners',
    () async {
      final scenario = _Scenario();
      var activeSessionNotifications = 0;
      void listener() {
        activeSessionNotifications += 1;
      }

      scenario.root.textEditing.activeSession.addListener(listener);
      try {
        final request = await scenario.issueTextRequest();
        final interactionRevisionBeforeCommit =
            scenario.root.state.value.revisions.interaction;
        final projected = <StoreAffectedElementProjection>[];

        expect(scenario.root.textEditing.activeSession.value, isNull);
        expect(
          DocumentStoreKernel.observeAffectedElementProjection(
            projected.add,
            () => scenario.root.commands.commitTextEdit(
              request.requestId,
              'direct command update',
            ),
          ),
          isTrue,
        );

        expect(activeSessionNotifications, 0);
        expect(
          scenario.root.state.value.revisions.interaction,
          interactionRevisionBeforeCommit,
        );
        expect(scenario.root.state.value.revisions.document, 1);
        expect(_textValue(scenario.root), 'direct command update');
        expect(scenario.actions, hasLength(1));
        final payload =
            scenario.actions.single.payload as CanvasTextEditActionPayload;
        expect(payload.requestId, request.requestId);
        expect(projected, hasLength(1));
        final before = _asTextElement(projected.single.before);
        final after = _asTextElement(projected.single.after);
        expect(payload.previousTextLength, before.text.length);
        expect(payload.nextTextLength, after.text.length);
      } finally {
        scenario.root.textEditing.activeSession.removeListener(listener);
        await scenario.dispose();
      }
    },
  );
}

Future<void> _expectLiveGeometryPreservesAnchorFor(TextAlign align) async {
  final scenario = _Scenario(document: _document(align: align, maxWidth: null));
  try {
    final request = await scenario.issueTextRequest();
    final session = _expectSession(
      scenario.root.textEditing.startFromContextAction(request),
    );
    final beforeAnchor = _anchorValueFor(
      session.geometry.editBoundsWorld,
      align,
    );
    final beforeTop = session.geometry.editBoundsWorld.top;

    session.updateText('hello with more text\nsecond line');

    final liveAnchor = _anchorValueFor(session.geometry.editBoundsWorld, align);
    expect(liveAnchor, moreOrLessEquals(beforeAnchor, epsilon: 0.001));
    expect(
      session.geometry.editBoundsWorld.top,
      moreOrLessEquals(beforeTop, epsilon: 0.001),
    );
    expect(_textValue(scenario.root), 'hello');
  } finally {
    await scenario.dispose();
  }
}

Future<void> _expectCommitPreservesAnchorFor(TextAlign align) async {
  final scenario = _Scenario(document: _document(align: align, maxWidth: null));
  try {
    final request = await scenario.issueTextRequest();
    final session = _expectSession(
      scenario.root.textEditing.startFromContextAction(request),
    );
    final beforeAnchor = _anchorValueFor(
      session.geometry.editBoundsWorld,
      align,
    );
    final beforeTop = session.geometry.editBoundsWorld.top;

    session.updateText('hello with more text\nsecond line');
    expect(session.commit(timestampMs: 43), isTrue);

    final nextRequest = await scenario.issueTextRequest();
    final nextSession = _expectSession(
      scenario.root.textEditing.sessionCandidateFor(nextRequest),
    );
    final afterAnchor = _anchorValueFor(
      nextSession.geometry.editBoundsWorld,
      align,
    );
    expect(afterAnchor, moreOrLessEquals(beforeAnchor, epsilon: 0.001));
    expect(
      nextSession.geometry.editBoundsWorld.top,
      moreOrLessEquals(beforeTop, epsilon: 0.001),
    );
  } finally {
    await scenario.dispose();
  }
}

double _anchorValueFor(Rect bounds, TextAlign align) {
  return switch (align) {
    TextAlign.left || TextAlign.start || TextAlign.justify => bounds.left,
    TextAlign.right || TextAlign.end => bounds.right,
    TextAlign.center => bounds.center.dx,
  };
}

void _testSessionNoOpCommitUsesCommandPath() {
  test('session no-op commit consumes request without action', () async {
    var resolverCalls = 0;
    final scenario = _Scenario(
      config: CanvasRuntimeConfig(
        commitResolver: (_) {
          resolverCalls += 1;
          return const CanvasCommitCancel();
        },
      ),
    );
    try {
      final request = await scenario.issueTextRequest();
      final session = _expectSession(
        scenario.root.textEditing.startFromContextAction(request),
      );

      expect(session.commit(timestampMs: 44), isTrue);

      expect(_textValue(scenario.root), 'hello');
      expect(scenario.actions, isEmpty);
      expect(scenario.root.textEditing.activeSession.value, isNull);
      expect(scenario.root.activeTextEditSuppressionForTesting, isNull);
      expect(
        scenario.root.interactionEngine.requestFactsFor(request.requestId),
        isNull,
      );
      expect(resolverCalls, 0);
    } finally {
      await scenario.dispose();
    }
  });
}

// A rejected session must retain the same draft and request until the host
// accepts it; cancel, lease abort, and retry share one ordered public seam.
// Keeping those terminal transitions together is clearer than splitting them
// solely to reduce the metric.
// ignore: halstead-volume, source-lines-of-code
void _testSessionCancelPreservesDraftForRetry() {
  test('session cancel preserves the matching draft for retry', () async {
    var resolverAttempt = 0;
    final abortedLease = _TextCommitLease();
    final scenario = _Scenario(
      config: CanvasRuntimeConfig(
        commitResolver: (_) => switch (resolverAttempt++) {
          0 => const CanvasCommitCancel(),
          1 => CanvasMoveCommitAccept(
            delta: const Offset(1, 0),
            lease: abortedLease,
          ),
          _ => const CanvasCommitAccept(lease: testAcceptingCommitLease),
        },
      ),
    );
    try {
      final request = await scenario.issueTextRequest();
      final session = _expectSession(
        scenario.root.textEditing.startFromContextAction(request),
      );
      session.updateText('session retry');
      final geometryBeforeAbort = session.geometry;
      final styleBeforeAbort = session.style;
      ({
        bool isActive,
        bool isStale,
        String liveText,
        CanvasTextEditGeometry geometry,
        CanvasTextEditStyle style,
      })?
      abortedSessionReads;
      abortedLease.onAborted = () {
        abortedSessionReads = (
          isActive: session.isActive,
          isStale: session.isStale,
          liveText: session.liveText,
          geometry: session.geometry,
          style: session.style,
        );
      };
      final beforeDocument = scenario.root.readDocument();
      final beforeRevisions = scenario.root.state.value.revisions;
      final beforeSelection = scenario.root.selectedElementIds;

      expect(session.commit(timestampMs: 45), isFalse);
      expect(scenario.root.readDocument(), same(beforeDocument));
      expect(scenario.root.state.value.revisions, beforeRevisions);
      expect(scenario.root.selectedElementIds, beforeSelection);
      expect(session.commit(timestampMs: 46), isFalse);
      expect(abortedLease.abortedCalls, 1);
      expect(abortedSessionReads, (
        isActive: true,
        isStale: false,
        liveText: 'session retry',
        geometry: geometryBeforeAbort,
        style: styleBeforeAbort,
      ));
      expect(session.isActive, isTrue);
      expect(session.liveText, 'session retry');
      expect(scenario.root.textEditing.activeSession.value, same(session));
      _expectRequestFactsLive(scenario.root, request);
      expect(scenario.actions, isEmpty);

      expect(session.commit(timestampMs: 47), isTrue);
      expect(_textValue(scenario.root), 'session retry');
      expect(scenario.actions, hasLength(1));
    } finally {
      await scenario.dispose();
    }
  });
}

void _testCandidateStateReusedAndPrunedAfterCommit() {
  test('candidate state is reused and pruned after request commit', () async {
    final scenario = _Scenario();
    try {
      final candidate = await _expectRepeatedCandidateReuse(scenario);

      expect(scenario.root.textEditing.start(candidate), same(candidate));
      expect(candidate.commit(timestampMs: 45), isTrue);
      expect(scenario.root.textEditCandidateStateCountForTesting, 0);
    } finally {
      await scenario.dispose();
    }
  });
}

void _testStaleCandidateStatePruned() {
  test('stale candidate state is pruned during candidate lookup', () async {
    final scenario = _Scenario();
    try {
      final staleRequest = await scenario.issueTextRequest();
      expect(
        scenario.root.textEditing.sessionCandidateFor(staleRequest),
        isNotNull,
      );
      expect(scenario.root.textEditCandidateStateCountForTesting, 1);

      _makeTextRequestStale(scenario);

      expect(
        scenario.root.textEditing.sessionCandidateFor(staleRequest),
        isNull,
      );
      expect(scenario.root.textEditCandidateStateCountForTesting, 0);
    } finally {
      await scenario.dispose();
    }
  });
}

// This one scenario keeps the conflict, retained draft, retry, and explicit
// dismissal observations together so a stale false result cannot hide draft
// loss or a revision/action side effect across helper boundaries.
// ignore: halstead-volume, source-lines-of-code
void _testStaleCommitRetainsDraft() {
  test(
    'stale commit retains the immutable draft until explicit dismissal',
    () async {
      var resolverCalls = 0;
      final scenario = _Scenario(
        config: CanvasRuntimeConfig(
          commitResolver: (request) {
            resolverCalls += 1;

            return acceptCommit(request);
          },
        ),
      );
      try {
        final request = await scenario.issueTextRequest();
        final session = _expectSession(
          scenario.root.textEditing.startFromContextAction(request),
        );
        session.updateText('retained draft');
        session.updateFormatting(isBold: true, isItalic: true);
        final retainedGeometry = session.geometry;
        final retainedStyle = session.style;
        _makeTextRequestStale(scenario);
        final revisionsAfterExternalChange =
            scenario.root.state.value.revisions;
        session.updateText('must not replace retained draft');
        session.updateFormatting(isBold: false, isItalic: false);

        expect(session.isStale, isTrue);
        expect(session.commit(timestampMs: 43), isFalse);
        expect(_textValue(scenario.root), 'hello');
        expect(
          scenario.root.state.value.revisions,
          revisionsAfterExternalChange,
        );
        expect(session.liveText, 'retained draft');
        expect(session.style, retainedStyle);
        final staleGeometryLayoutEvents = <(String, Color)>[];
        FrameTextLayoutMeasurer.observeNewLayoutWork(
          (text, color) => staleGeometryLayoutEvents.add((text, color)),
          () => expect(session.geometry, retainedGeometry),
        );
        expect(staleGeometryLayoutEvents, isEmpty);
        expect(session.isActive, isTrue);
        expect(scenario.root.textEditing.activeSession.value, same(session));
        expect(scenario.root.activeTextEditSuppressionForTesting, isNull);
        expect(scenario.root.textEditCandidateStateCountForTesting, 1);
        expect(scenario.actions, isEmpty);
        expect(resolverCalls, 0);

        expect(session.commit(timestampMs: 44), isFalse);
        expect(session.liveText, 'retained draft');
        expect(session.isActive, isTrue);
        expect(scenario.root.textEditing.start(session), isNull);
        expect(
          scenario.root.textEditing.startFromContextAction(request),
          isNull,
        );
        expect(resolverCalls, 0);

        session.dismiss();
        expect(session.isActive, isFalse);
        expect(scenario.root.textEditing.activeSession.value, isNull);
        expect(scenario.root.textEditCandidateStateCountForTesting, 0);
      } finally {
        await scenario.dispose();
      }
    },
  );
}

// The direct terminal must share the retained-session behavior with the session
// terminal, so its request retirement and draft observations stay together.
// ignore: halstead-volume, source-lines-of-code
void _testDirectStaleCommandRetainsActiveSession() {
  test(
    'direct stale command retires its request without clearing the draft',
    () async {
      var resolverCalls = 0;
      final scenario = _Scenario(
        config: CanvasRuntimeConfig(
          commitResolver: (request) {
            resolverCalls += 1;

            return acceptCommit(request);
          },
        ),
      );
      try {
        final request = await scenario.issueTextRequest();
        final session = _expectSession(
          scenario.root.textEditing.startFromContextAction(request),
        );
        session.updateText('direct retained draft');
        final retainedGeometry = session.geometry;
        final retainedStyle = session.style;
        _makeTextRequestStale(scenario);
        final revisionsAfterExternalChange =
            scenario.root.state.value.revisions;

        expect(
          scenario.root.commands.commitTextEdit(request.requestId, 'stale'),
          isFalse,
        );
        expect(
          scenario.root.interactionEngine.requestFactsFor(request.requestId),
          isNull,
        );

        expect(_textValue(scenario.root), 'hello');
        expect(
          scenario.root.state.value.revisions,
          revisionsAfterExternalChange,
        );
        expect(scenario.root.textEditing.activeSession.value, same(session));
        expect(scenario.root.activeTextEditSuppressionForTesting, isNull);
        expect(session.isActive, isTrue);
        expect(session.isStale, isTrue);
        expect(session.liveText, 'direct retained draft');
        expect(session.style, retainedStyle);
        expect(session.geometry, retainedGeometry);
        session.updateText('must not change direct draft');
        expect(session.liveText, 'direct retained draft');
        expect(resolverCalls, 0);

        session.dismiss();
        expect(scenario.root.textEditing.activeSession.value, isNull);
        expect(session.isActive, isFalse);
      } finally {
        await scenario.dispose();
      }
    },
  );
}

// This assertion covers every external conflict variant in one lifecycle.
// Combining mutation, retained state, and terminal effects keeps a case-specific
// helper from concealing a different terminal path.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _testRemovalAndSameIdReplacementRetainStaleDrafts() {
  test(
    'removal and same-id replacement retain stale drafts without overwrite',
    () async {
      for (final scenarioCase in [
        (
          name: 'text change',
          apply: (_Scenario scenario) {
            scenario.root.edits.edit(
              (edit) => edit.updateElement(
                CanvasTextElementUpdate(
                  id: _textId,
                  text: const CanvasFieldSet('external text'),
                ),
              ),
            );
          },
          verifyCommitted: (_Scenario scenario) {
            expect(_textValue(scenario.root), 'external text');
          },
        ),
        (
          name: 'hidden target',
          apply: (_Scenario scenario) {
            scenario.root.edits.edit(
              (edit) => edit.updateElement(
                CanvasTextElementUpdate(
                  id: _textId,
                  isVisible: const CanvasFieldSet(false),
                ),
              ),
            );
          },
          verifyCommitted: (_Scenario scenario) {
            expect(_textElement(scenario.root).isVisible, isFalse);
          },
        ),
        (
          name: 'kind replacement',
          apply: (_Scenario scenario) {
            scenario.root.edits.edit((edit) {
              edit.removeElement(_textId);
              edit.addElement(
                CanvasRectElement(id: _textId, size: const Size(10, 10)),
              );
            });
          },
          verifyCommitted: (_Scenario scenario) {
            expect(_containsElement(scenario.root, _textId), isTrue);
          },
        ),
        (
          name: 'background relocation',
          apply: (_Scenario scenario) {
            scenario.root.edits.edit((edit) {
              edit.removeElement(_textId);
              edit.addBackgroundElement(
                CanvasTextElement(
                  id: _textId,
                  text: 'background replacement',
                  fontSize: 16,
                  color: const Color(0xFF111111),
                  textDirection: TextDirection.ltr,
                ),
              );
            });
          },
          verifyCommitted: (_Scenario scenario) {
            expect(
              scenario.root.readDocument().backgroundElements.any(
                (element) => element.id == _textId,
              ),
              isTrue,
            );
          },
        ),
        (
          name: 'removal',
          apply: (_Scenario scenario) {
            scenario.root.edits.edit((edit) => edit.removeElement(_textId));
          },
          verifyCommitted: (_Scenario scenario) {
            expect(_containsElement(scenario.root, _textId), isFalse);
          },
        ),
        (
          name: 'same-id replacement',
          apply: (_Scenario scenario) {
            scenario.root.edits.edit(
              (edit) =>
                  edit.replaceDraftDocument(_document(text: 'replacement')),
            );
          },
          verifyCommitted: (_Scenario scenario) {
            expect(_textValue(scenario.root), 'replacement');
          },
        ),
      ]) {
        var resolverCalls = 0;
        final scenario = _Scenario(
          config: CanvasRuntimeConfig(
            commitResolver: (request) {
              resolverCalls += 1;

              return acceptCommit(request);
            },
          ),
        );
        try {
          final request = await scenario.issueTextRequest();
          final session = _expectSession(
            scenario.root.textEditing.startFromContextAction(request),
          );
          final draft = 'retained ${scenarioCase.name} draft';
          session.updateText(draft);
          final retainedGeometry = session.geometry;
          final retainedStyle = session.style;

          scenarioCase.apply(scenario);
          final revisionsAfterExternalChange =
              scenario.root.state.value.revisions;
          scenarioCase.verifyCommitted(scenario);

          final projected = <StoreAffectedElementProjection>[];
          DocumentStoreKernel.observeAffectedElementProjection(
            projected.add,
            () {
              expect(session.isStale, isTrue);
              session.updateText('must not overwrite $draft');
              expect(session.commit(timestampMs: 45), isFalse);
              expect(session.commit(timestampMs: 46), isFalse);
            },
          );

          expect(projected, isEmpty);
          expect(
            scenario.root.state.value.revisions,
            revisionsAfterExternalChange,
          );
          scenarioCase.verifyCommitted(scenario);
          expect(session.liveText, draft);
          expect(session.style, retainedStyle);
          expect(session.geometry, retainedGeometry);
          expect(session.isActive, isTrue);
          expect(scenario.root.textEditing.activeSession.value, same(session));
          expect(scenario.root.activeTextEditSuppressionForTesting, isNull);
          expect(scenario.actions, isEmpty);
          expect(resolverCalls, 0);

          session.dismiss();
          expect(scenario.root.textEditing.activeSession.value, isNull);
        } finally {
          await scenario.dispose();
        }
      }
    },
  );
}

void _testUnrelatedDocumentRevisionIsObservationOnly() {
  test('unrelated document revision does not stale active session', () async {
    final scenario = _Scenario();
    try {
      final session = await _startTextSession(scenario);
      _addUnrelatedRect(scenario);
      session.updateText('updated after unrelated edit');

      expect(session.isStale, isFalse);
      expect(session.documentRevision, 0);
      expect(scenario.root.state.value.revisions.document, 1);
      expect(session.commit(timestampMs: 48), isTrue);
      expect(_textValue(scenario.root), 'updated after unrelated edit');
      expect(scenario.root.textEditing.activeSession.value, isNull);
      expect(scenario.root.activeTextEditSuppressionForTesting, isNull);
    } finally {
      await scenario.dispose();
    }
  });
}

void _testUnrelatedDocumentRevisionPreservesSuppressionIdentity() {
  test('unrelated document revision preserves suppression identity', () async {
    final scenario = _Scenario();
    try {
      await _startTextSession(scenario);
      final before = scenario.root.activeTextEditSuppressionIdentityForTesting;

      _addUnrelatedRect(scenario);

      expect(scenario.root.state.value.revisions.document, 1);
      expect(scenario.root.activeTextEditSuppressionIdentityForTesting, before);
    } finally {
      await scenario.dispose();
    }
  });
}

// The projection witness keeps preparation, pre-install state, installed facts,
// and action sealing in one causal scenario; splitting it would hide the seam.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _testPreparedTextFactsAreExactBeforeInstall() {
  test(
    'text action sealing reads the exact prepared pair before install',
    () async {
      final scenario = _Scenario(document: _richTextDocument());
      try {
        final request = await scenario.issueTextRequest();
        final session = _expectSession(
          scenario.root.textEditing.startFromContextAction(request),
        );
        final beforeDocument = scenario.root.readDocument();
        final beforeRevisions = scenario.root.state.value.revisions;
        final beforeSelection = scenario.root.selectedElementIds;
        final projected = <StoreAffectedElementProjection>[];
        final sparseTouchedReads = <(String? subject, String? side)>[];
        final layoutEvents = <(String, Color)>[];
        const nextText = 'expanded\nprepared text';
        final expectedBefore = _richTextElement();
        final expectedAfter = _richTextElement(
          text: nextText,
          revision: 8,
          transform: _expectedRichTextTransform(nextText),
        );
        session.updateText(nextText);

        final didCommit = CommittedDocument.observeSparseCandidateEvents(
          (event) {
            if (event.kind.name == 'touchedElementRead') {
              sparseTouchedReads.add((event.subject, event.side?.name));
            }
          },
          () => FrameTextLayoutMeasurer.observeNewLayoutWork(
            (text, color) => layoutEvents.add((text, color)),
            () => DocumentStoreKernel.observeAffectedElementProjection(
              projected.add,
              () {
                final committed = scenario.root.readDocument();
                expect(committed, same(beforeDocument));
                expect(scenario.root.state.value.revisions, beforeRevisions);
                expect(scenario.root.selectedElementIds, beforeSelection);
                expect(scenario.actions, isEmpty);
                expect(session.isActive, isTrue);
                _expectRequestFactsLive(scenario.root, request);

                return session.commit(timestampMs: 61);
              },
            ),
          ),
        );

        expect(didCommit, isTrue);
        expect(projected, hasLength(1));
        final facts = projected.single;
        final projectedBefore = _asTextElement(facts.before);
        final projectedAfter = _asTextElement(facts.after);
        _expectCompleteTextElement(projectedBefore, expectedBefore);
        final installed = _textElement(scenario.root);
        _expectCompleteTextElement(projectedAfter, expectedAfter);
        _expectCompleteTextElement(installed, expectedAfter);
        expect(projectedBefore.id, _textId);
        expect(projectedAfter.id, _textId);
        expect(projectedAfter.revision, projectedBefore.revision + 1);
        expect(projectedAfter.transform, isNot(projectedBefore.transform));
        expect(sparseTouchedReads, [
          (_textId.value, 'base'),
          (_textId.value, 'candidate'),
        ]);
        final action =
            scenario.actions.single.payload as CanvasTextEditActionPayload;
        expect(action.previousTextLength, projectedBefore.text.length);
        expect(action.nextTextLength, projectedAfter.text.length);
        expect(layoutEvents, [(nextText, const Color(0xB3221144))]);
      } finally {
        await scenario.dispose();
      }
    },
  );
}

// The session route keeps its prepared pair, public resolver request, lease,
// delivery, and late-close sequence in one witness to prevent temporal drift.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _testUnifiedSessionCommitRequestAndLeaseOrder() {
  test(
    'session commit exposes the sealed text pair before state lease action close',
    () async {
      CanvasTextEditCommitRequest? request;
      final lease = _TextCommitLease();
      final scenario = _Scenario(
        document: _richTextDocument(),
        config: CanvasRuntimeConfig(
          commitResolver: (candidate) {
            request = candidate as CanvasTextEditCommitRequest;
            return CanvasCommitAccept(lease: lease);
          },
        ),
      );
      final order = <String>[];
      final actionSubscription = scenario.root.actions.listen(
        (_) => order.add('action'),
      );
      void onState() => order.add('state');
      void onActiveSession() => order.add('close');
      scenario.root.state.addListener(onState);
      scenario.root.textEditing.activeSession.addListener(onActiveSession);
      try {
        final contextRequest = await scenario.issueTextRequest();
        final session = _expectSession(
          scenario.root.textEditing.startFromContextAction(contextRequest),
        );
        final original = _textElement(scenario.root);
        const nextText = 'expanded\nunified text';
        final expectedBefore = _richTextElement();
        final expectedAfter = _richTextElement(
          text: nextText,
          revision: 8,
          transform: _expectedRichTextTransform(nextText),
        );
        session.updateText(nextText);
        final geometryBeforeCommit = session.geometry;
        final styleBeforeCommit = session.style;
        ({
          bool isActive,
          bool isStale,
          String liveText,
          CanvasTextEditGeometry geometry,
          CanvasTextEditStyle style,
        })?
        committedSessionReads;
        order.clear();
        lease.onCommitted = () {
          order.add('lease');
          lease.snapshots.add((
            revision: scenario.root.state.value.revisions.document,
            actions: scenario.actions.length,
          ));
          committedSessionReads = (
            isActive: session.isActive,
            isStale: session.isStale,
            liveText: session.liveText,
            geometry: session.geometry,
            style: session.style,
          );
        };

        expect(session.commit(timestampMs: 71), isTrue);

        final received = request;
        if (received == null) fail('Expected a unified text commit request.');
        expect(
          received.documentSummary,
          const CanvasDocumentSummary(
            elementCount: 2,
            layerCount: 1,
            resourceCount: 0,
          ),
        );
        expect(received.documentRevision, 0);
        expect(received.selectedElementIdsBefore, isEmpty);
        expect(
          () => received.selectedElementIdsBefore.clear(),
          throwsUnsupportedError,
        );
        final committed = _textElement(scenario.root);
        _expectCompleteTextElement(received.before, expectedBefore);
        _expectCompleteTextElement(received.after, expectedAfter);
        _expectCompleteTextElement(original, expectedBefore);
        _expectCompleteTextElement(committed, expectedAfter);
        expect(received.before.text, 'hello');
        expect(received.after.text, 'expanded\nunified text');
        expect(received.after.revision, received.before.revision + 1);
        expect(received.after.transform, isNot(received.before.transform));
        expect(received.before.maxWidth, isNull);
        expect(received.after.maxWidth, isNull);
        expect(received.after.metadata, received.before.metadata);
        expect(lease.snapshots, [(revision: 1, actions: 0)]);
        expect(lease.committedCalls, 1);
        expect(lease.abortedCalls, 0);
        expect(committedSessionReads, (
          isActive: false,
          isStale: true,
          liveText: nextText,
          geometry: geometryBeforeCommit,
          style: styleBeforeCommit,
        ));
        expect(order, ['state', 'lease', 'action', 'close']);

        scenario.root.edits.edit((edit) {
          edit.updateElement(
            CanvasTextElementUpdate(
              id: _textId,
              text: const CanvasFieldSet('later edit'),
            ),
          );
        });
        expect(received.after.text, nextText);
        expect(received.before.text, 'hello');
        _expectCompleteTextElement(received.after, expectedAfter);
        _expectCompleteTextElement(received.before, expectedBefore);
      } finally {
        scenario.root.state.removeListener(onState);
        scenario.root.textEditing.activeSession.removeListener(onActiveSession);
        await actionSubscription.cancel();
        await scenario.dispose();
      }
    },
  );
}

// The failed projection path must compare every still-live session owner before
// retry, so its assertions remain together rather than duplicating snapshots.
// ignore: halstead-volume
void _testFailedPreparePreservesActiveSessionForRetry() {
  test(
    'actual candidate projection failure preserves session for retry',
    () async {
      final scenario = _Scenario();
      try {
        final request = await scenario.issueTextRequest();
        final session = _expectSession(
          scenario.root.textEditing.startFromContextAction(request),
        );
        session.updateText('retryable');
        final beforeDocument = scenario.root.readDocument();
        final beforeRevisions = scenario.root.state.value.revisions;
        final beforeSelection = scenario.root.selectedElementIds;
        final failure = StateError('prepared text projection failed');

        expect(
          () => DocumentStoreKernel.injectAffectedElementProjectionFailure(
            failure,
            () => session.commit(timestampMs: 46),
          ),
          throwsA(same(failure)),
        );
        expect(scenario.root.readDocument(), same(beforeDocument));
        expect(scenario.root.state.value.revisions, beforeRevisions);
        expect(scenario.root.selectedElementIds, beforeSelection);
        expect(session.isActive, isTrue);
        expect(session.liveText, 'retryable');
        expect(scenario.root.textEditing.activeSession.value, same(session));
        expect(scenario.root.activeTextEditSuppressionForTesting, isNotNull);
        _expectRequestFactsLive(scenario.root, request);
        expect(scenario.actions, isEmpty);
        expect(session.commit(timestampMs: 47), isTrue);
        expect(_textValue(scenario.root), 'retryable');
        expect(scenario.actions, hasLength(1));
      } finally {
        await scenario.dispose();
      }
    },
  );
}

void _testValidationFailurePreservesActiveSession() {
  test(
    'validation failure preserves active session and request facts',
    () async {
      final scenario = _Scenario();
      try {
        final request = await scenario.issueTextRequest();
        final session = _expectSession(
          scenario.root.textEditing.startFromContextAction(request),
        );
        session.updateText('x' * 100001);

        expect(() => session.commit(), throwsA(isA<CanvasDataException>()));
        expect(scenario.root.textEditing.activeSession.value, same(session));
        expect(
          scenario.root.interactionEngine.requestFactsFor(request.requestId),
          isNotNull,
        );
        expect(_textValue(scenario.root), 'hello');
      } finally {
        await scenario.dispose();
      }
    },
  );
}

void _testSuccessfulLoadClearsActiveSession() {
  test('successful load clears active session and suppression token', () async {
    final scenario = _Scenario();
    try {
      final request = await scenario.issueTextRequest();
      final session = _expectSession(
        scenario.root.textEditing.startFromContextAction(request),
      );

      scenario.root.edits.loadDocumentFromJson(
        encodeCanvasDocumentToJson(CanvasDocument()),
      );

      expect(session.isActive, isFalse);
      expect(scenario.root.textEditing.activeSession.value, isNull);
      expect(scenario.root.activeTextEditSuppressionForTesting, isNull);
      expect(scenario.root.textEditCandidateStateCountForTesting, 0);
      expect(
        scenario.root.interactionEngine.requestFactsFor(request.requestId),
        isNull,
      );
      expect(scenario.actions, isEmpty);
    } finally {
      await scenario.dispose();
    }
  });
}

void _testFailedLoadPreservesActiveSession() {
  test('failed load preserves active session and suppression token', () async {
    final scenario = _Scenario();
    try {
      final request = await scenario.issueTextRequest();
      final session = _expectSession(
        scenario.root.textEditing.startFromContextAction(request),
      );

      expect(
        () => scenario.root.edits.loadDocumentFromJson(
          encodeCanvasDocumentToJson(_invalidReplacementDocument()),
        ),
        throwsA(isA<CanvasDataException>()),
      );

      expect(session.isActive, isTrue);
      expect(scenario.root.textEditing.activeSession.value, same(session));
      expect(scenario.root.activeTextEditSuppressionForTesting, isNotNull);
      expect(
        scenario.root.interactionEngine.requestFactsFor(request.requestId),
        isNotNull,
      );
    } finally {
      await scenario.dispose();
    }
  });
}

void _testDisposedRuntimeRejectsTextEditingPortOperations() {
  test('disposed runtime rejects text editing port operations', () async {
    final scenario = _Scenario();
    try {
      final request = await scenario.issueTextRequest();
      final session = _expectSession(
        scenario.root.textEditing.startFromContextAction(request),
      );

      scenario.root.dispose();

      final throwsDisposed = throwsA(isA<StateError>());
      expect(
        () => scenario.root.textEditing.sessionCandidateFor(request),
        throwsDisposed,
      );
      expect(() => scenario.root.textEditing.start(session), throwsDisposed);
      expect(
        () => scenario.root.textEditing.startFromContextAction(request),
        throwsDisposed,
      );
      expect(() => scenario.root.textEditing.setReadOnly(true), throwsDisposed);
      expect(() => scenario.root.textEditing.dismissActive(), throwsDisposed);
    } finally {
      await scenario.dispose();
    }
  });
}

void _testDisposedRuntimeRejectsTextEditingSessionCallbacks() {
  test('disposed runtime rejects text editing session callbacks', () async {
    final scenario = _Scenario();
    try {
      final session = await _startTextSession(scenario);

      scenario.root.dispose();

      final throwsDisposed = throwsA(isA<StateError>());
      expect(() => session.updateText('after dispose'), throwsDisposed);
      expect(() => session.commit(), throwsDisposed);
      expect(() => session.dismiss(), throwsDisposed);
      expect(() => session.isActive, throwsDisposed);
      expect(() => session.isStale, throwsDisposed);
      expect(() => session.geometry, throwsDisposed);
      expect(() => session.style, throwsDisposed);
      expect(() => session.liveText, throwsDisposed);
    } finally {
      await scenario.dispose();
    }
  });
}

CanvasTextEditSession _expectSession(CanvasTextEditSession? session) {
  expect(session, isNotNull);

  return session as CanvasTextEditSession;
}

CanvasTextEditSession _expectStartSuccess(CanvasTextEditStartResult result) {
  expect(result, isA<CanvasTextEditStartSuccess>());

  return (result as CanvasTextEditStartSuccess).session;
}

T _observeNoTextAdmissionWork<T>(RuntimeRoot root, T Function() operation) {
  final projectionBuildCount = root.projectionBuildCount;
  final projections = <StoreAffectedElementProjection>[];
  final work = <PreparedInteractionApplyWorkEvent>[];
  final result = CommitApplier.observePreparedInteractionWork(
    work.add,
    () => DocumentStoreKernel.observeAffectedElementProjection(
      projections.add,
      operation,
    ),
  );

  expect(root.projectionBuildCount, projectionBuildCount);
  expect(projections, isEmpty);
  expect(work, isEmpty);

  return result;
}

// One observation must retain the complete no-effect boundary across an async
// turn; splitting it would separate the evidence from the rejected operation.
// ignore: halstead-volume
Future<T> _observeAdmissionRefusal<T>(
  _Scenario scenario,
  T Function() operation, {
  CanvasTextEditStartRefusalReason? reason,
  CanvasTextEditSession? expectedActive,
}) async {
  final documentBefore = scenario.root.readDocument();
  final revisionsBefore = scenario.root.state.value.revisions;
  final activeBefore = expectedActive ?? scenario.root.textEditing.activeSession.value;
  final draftTextBefore = activeBefore?.liveText;
  final draftStyleBefore = activeBefore?.style;
  final actionCountBefore = scenario.actions.length;
  final requestCountBefore = scenario.requests.length;
  final result = _observeNoTextAdmissionWork(scenario.root, operation);
  if (reason != null) {
    _expectStartRefusal(result as CanvasTextEditStartResult, reason);
  }

  await Future<void>.delayed(Duration.zero);

  expect(scenario.root.readDocument(), same(documentBefore));
  expect(scenario.root.state.value.revisions, revisionsBefore);
  expect(scenario.actions, hasLength(actionCountBefore));
  expect(scenario.requests, hasLength(requestCountBefore));
  expect(scenario.root.textEditing.activeSession.value, same(activeBefore));
  if (activeBefore != null) {
    expect(activeBefore.liveText, draftTextBefore);
    expect(activeBefore.style, draftStyleBefore);
  }

  return result;
}

void _expectStartRefusal(
  CanvasTextEditStartResult result,
  CanvasTextEditStartRefusalReason reason,
) {
  expect(result, isA<CanvasTextEditStartRefusal>());
  expect((result as CanvasTextEditStartRefusal).reason, reason);
}

Future<CanvasTextEditSession> _startTextSession(_Scenario scenario) async {
  final request = await scenario.issueTextRequest();
  final session = _expectSession(
    scenario.root.textEditing.startFromContextAction(request),
  );
  expect(scenario.root.textEditing.activeSession.value, same(session));

  return session;
}

Future<CanvasTextEditSession> _startIdempotentTextSession(
  _Scenario scenario,
) async {
  final request = await scenario.issueTextRequest();
  final session = _expectSession(
    scenario.root.textEditing.startFromContextAction(request),
  );
  expect(scenario.root.textEditing.start(session), same(session));
  expect(
    scenario.root.textEditing.startFromContextAction(request),
    same(session),
  );
  expect(scenario.root.textEditing.activeSession.value, same(session));

  return session;
}

Future<CanvasTextEditSession> _expectRepeatedCandidateReuse(
  _Scenario scenario,
) async {
  final request = await scenario.issueTextRequest();
  final first = _expectSession(
    scenario.root.textEditing.sessionCandidateFor(request),
  );
  final second = _expectSession(
    scenario.root.textEditing.sessionCandidateFor(request),
  );
  expect(second, same(first));
  expect(scenario.root.textEditCandidateStateCountForTesting, 1);

  return first;
}

Future<void> _expectCompetingRequestRejected(
  _Scenario scenario,
  CanvasTextEditSession activeSession,
) async {
  scenario.addSecondTextElement();
  final request = await scenario.issueSecondTextRequest();
  final candidate = scenario.root.textEditing.sessionCandidateFor(request);
  expect(candidate, isNull);
  expect(scenario.root.textEditing.startFromContextAction(request), isNull);
  expect(scenario.root.textEditing.activeSession.value, same(activeSession));
  _expectRequestFactsLive(scenario.root, request);
}

void _expectNonTextRequestRejected(
  _Scenario scenario,
  CanvasContextActionRequested request,
) {
  final beforeRevision = scenario.root.state.value.revisions.document;

  expect(scenario.root.textEditing.sessionCandidateFor(request), isNull);
  expect(scenario.root.textEditing.startFromContextAction(request), isNull);
  expect(scenario.root.textEditing.activeSession.value, isNull);
  expect(scenario.root.activeTextEditSuppressionForTesting, isNull);
  _expectRequestFactsLive(scenario.root, request);
  expect(scenario.root.state.value.revisions.document, beforeRevision);
  expect(_textValue(scenario.root), 'hello');
  expect(scenario.actions, isEmpty);
}

void _makeTextRequestStale(_Scenario scenario) {
  scenario.root.edits.edit(
    (edit) => edit.updateElement(
      CanvasTextElementUpdate(id: _textId, fontSize: const CanvasFieldSet(20)),
    ),
  );
}

void _addUnrelatedRect(_Scenario scenario) {
  scenario.root.edits.edit((edit) {
    edit.addElement(
      CanvasRectElement(
        id: CanvasElementId('unrelated-rect'),
        size: const Size(10, 10),
      ),
    );
  });
}

void _expectInitialCandidate(
  CanvasTextEditSession? candidate,
  CanvasContextActionRequested request,
) {
  final session = _expectSession(candidate);
  expect(session.isActive, isFalse);
  expect(session.isStale, isFalse);
  expect(session.requestId, request.requestId);
  expect(session.elementId, _textId);
  expect(session.initialText, 'hello');
  expect(session.liveText, 'hello');
  expect(session.geometry.editBoundsWorld.width, greaterThan(0));
  expect(session.style.fontSize, 16);
}

void _expectRequestFactsLive(
  RuntimeRoot root,
  CanvasContextActionRequested request,
) {
  expect(root.interactionEngine.requestFactsFor(request.requestId), isNotNull);
}

final class _Scenario {
  _Scenario({CanvasDocument? document, CanvasRuntimeConfig? config})
    : root = runtimeRootWithCommittedDocumentSeed(
        document ?? _document(),
        config:
            config ?? const CanvasRuntimeConfig(commitResolver: acceptCommit),
      ) {
    actionSubscription = root.actions.listen(actions.add);
    requestSubscription = root.contextActionRequests.listen(requests.add);
  }

  final RuntimeRoot root;
  late final StreamSubscription<CanvasActionCommitted> actionSubscription;
  late final StreamSubscription<CanvasContextActionRequested>
  requestSubscription;
  final List<CanvasActionCommitted> actions = [];
  final List<CanvasContextActionRequested> requests = [];
  var _disposed = false;

  Future<CanvasContextActionRequested> issueTextRequest() {
    root.handleDoubleTap(position: Offset.zero, timestampMs: 1);

    return _takeRequest();
  }

  Future<CanvasContextActionRequested> issueSecondTextRequest() {
    root.handleDoubleTap(position: const Offset(240, 0), timestampMs: 1);

    return _takeRequest();
  }

  void addSecondTextElement() {
    root.edits.edit((edit) {
      edit.addElement(
        CanvasTextElement(
          id: _secondTextId,
          text: 'second',
          fontSize: 16,
          color: const Color(0xFF111111),
          textDirection: TextDirection.ltr,
          transform: CanvasTransform.translation(const Offset(240, 0)),
        ),
      );
    });
  }

  Future<CanvasContextActionRequested> issueRectRequest() {
    root.handleDoubleTap(position: const Offset(130, 0), timestampMs: 1);

    return _takeRequest();
  }

  Future<CanvasContextActionRequested> issueEmptyCanvasRequest() {
    root.handleDoubleTap(position: const Offset(300, 300), timestampMs: 1);

    return _takeRequest();
  }

  Future<CanvasContextActionRequested> _takeRequest() async {
    await Future<void>.delayed(Duration.zero);
    final request = requests.single;
    requests.clear();
    actions.clear();

    return request;
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await actionSubscription.cancel();
    await requestSubscription.cancel();
    root.dispose();
  }
}

final class _TextCommitLease implements CanvasCommitLease {
  void Function()? onCommitted;
  void Function()? onAborted;
  int committedCalls = 0;
  int abortedCalls = 0;
  final List<({int revision, int actions})> snapshots = [];

  @override
  void committed() {
    committedCalls += 1;
    onCommitted?.call();
  }

  @override
  void aborted() {
    abortedCalls += 1;
    onAborted?.call();
  }
}

String _textValue(RuntimeRoot root) {
  return _textElement(root).text;
}

CanvasTextElement _textElement(RuntimeRoot root) {
  final text = root
      .readDocument()
      .layers
      .single
      .elements
      .whereType<CanvasTextElement>()
      .singleWhere((element) => element.id == _textId);

  return text;
}

CanvasTextElement _asTextElement(CanvasElement element) {
  if (element is! CanvasTextElement) {
    throw StateError('Expected a text element projection.');
  }
  return element;
}

CanvasTextElement _newTextSeed({required CanvasElementId id}) =>
    CanvasTextElement(
      id: id,
      revision: 7,
      text: 'seed',
      fontSize: 18,
      color: const Color(0xFF224466),
      textDirection: TextDirection.ltr,
      align: TextAlign.right,
      transform: CanvasTransform.translation(const Offset(12, 16)),
      fontFamily: 'Inter',
      lineHeight: 1.2,
      metadata: CanvasMetadata.fromMap({'seed': true}),
    );

// One complete field comparison prevents a future text request from omitting a
// common, nullable, formatting, or sizing fact behind smaller partial checks.
// ignore: halstead-volume
void _expectCompleteTextElement(
  CanvasTextElement actual,
  CanvasTextElement expected,
) {
  expect(actual.id, expected.id);
  expect(actual.revision, expected.revision);
  expect(actual.transform, expected.transform);
  expect(actual.opacity, expected.opacity);
  expect(actual.hitPadding, expected.hitPadding);
  expect(actual.isVisible, expected.isVisible);
  expect(actual.isSelectable, expected.isSelectable);
  expect(actual.isLocked, expected.isLocked);
  expect(actual.isDeletable, expected.isDeletable);
  expect(actual.isTransformable, expected.isTransformable);
  expect(actual.metadata, expected.metadata);
  expect(actual.text, expected.text);
  expect(actual.fontSize, expected.fontSize);
  expect(actual.color, expected.color);
  expect(actual.align, expected.align);
  expect(actual.textDirection, expected.textDirection);
  expect(actual.isBold, expected.isBold);
  expect(actual.isItalic, expected.isItalic);
  expect(actual.isUnderline, expected.isUnderline);
  expect(actual.fontFamily, expected.fontFamily);
  expect(actual.maxWidth, expected.maxWidth);
  expect(actual.lineHeight, expected.lineHeight);
}

bool _containsElement(RuntimeRoot root, CanvasElementId id) {
  return root.readDocument().layers.any(
    (layer) => layer.elements.any((element) => element.id == id),
  );
}

({int layerIndex, int elementIndex}) _ordinaryTextInsertionLocation(
  CanvasDocument document,
  CanvasTextElement element, {
  int? index,
}) {
  final root = runtimeRootWithCommittedDocumentSeed(document);
  try {
    root.edits.edit((edit) => edit.addElement(element, index: index));
    final layers = root.readDocument().layers;
    for (var layerIndex = 0; layerIndex < layers.length; layerIndex += 1) {
      final elementIndex = layers[layerIndex].elements.indexWhere(
        (candidate) => candidate.id == element.id,
      );
      if (elementIndex >= 0) {
        return (layerIndex: layerIndex, elementIndex: elementIndex);
      }
    }
    throw StateError('Ordinary insertion did not install the test element.');
  } finally {
    root.dispose();
  }
}

/// This fixture needs the complete original text entry for deletion assertions.
/// Keeping its construction inputs together makes that expected entry readable.
// ignore: number-of-parameters, reason: The one fixture helper keeps complete original deletion facts legible.
CanvasDocument _document({
  TextAlign align = TextAlign.left,
  double? maxWidth = 120,
  String text = 'hello',
  String? fontFamily,
  bool isBold = false,
  bool isItalic = false,
  bool isUnderline = false,
  bool isDeletable = true,
}) {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasTextElement(
            id: _textId,
            text: text,
            fontSize: 16,
            color: const Color(0xFF111111),
            textDirection: TextDirection.ltr,
            align: align,
            fontFamily: fontFamily,
            maxWidth: maxWidth,
            isBold: isBold,
            isItalic: isItalic,
            isUnderline: isUnderline,
            isDeletable: isDeletable,
          ),
          CanvasRectElement(
            id: _rectId,
            size: const Size(20, 20),
            transform: CanvasTransform.translation(const Offset(120, 0)),
          ),
        ],
      ),
    ],
  );
}

const _unit3RuntimeRobotoFamily = 'Unit3RuntimeRoboto';

Future<void> _loadRobotoForRuntimeStyleGeometry() async {
  final fontDirectory = _materialFontDirectoryForRuntimeTest();
  final fontFiles = [
    File('${fontDirectory.path}/Roboto-Regular.ttf'),
    File('${fontDirectory.path}/Roboto-Bold.ttf'),
    File('${fontDirectory.path}/Roboto-Italic.ttf'),
  ];
  for (final fontFile in fontFiles) {
    expect(fontFile.existsSync(), isTrue, reason: fontFile.path);
  }
  for (final fontFile in fontFiles) {
    await loadFontFromList(
      await fontFile.readAsBytes(),
      fontFamily: _unit3RuntimeRobotoFamily,
    );
  }
}

Directory _materialFontDirectoryForRuntimeTest() {
  var candidate = File(Platform.resolvedExecutable).parent;
  while (candidate.parent.path != candidate.path) {
    final fontDirectory = Directory.fromUri(
      candidate.uri.resolve('bin/cache/artifacts/material_fonts/'),
    );
    if (fontDirectory.existsSync()) {
      return fontDirectory;
    }
    candidate = candidate.parent;
  }
  fail('Flutter SDK material fonts were not found from the test executable.');
}

// This fixture intentionally spells out every persisted text/common field so
// the prepared pair has an independent complete expected value.
// ignore: halstead-volume, source-lines-of-code
CanvasDocument _richTextDocument() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          _richTextElement(),
          CanvasRectElement(
            id: _rectId,
            size: const Size(20, 20),
            transform: CanvasTransform.translation(const Offset(220, 0)),
          ),
        ],
      ),
    ],
  );
}

CanvasTextElement _richTextElement({
  String text = 'hello',
  int revision = 7,
  CanvasTransform? transform,
}) => CanvasTextElement(
  id: _textId,
  text: text,
  revision: revision,
  fontSize: 18,
  color: const Color(0xFF221144),
  align: TextAlign.right,
  textDirection: TextDirection.rtl,
  isBold: true,
  isItalic: true,
  isUnderline: true,
  fontFamily: 'Inter',
  lineHeight: 1.25,
  transform: transform ?? CanvasTransform.translation(const Offset(0, 15)),
  opacity: 0.7,
  hitPadding: 3,
  isDeletable: false,
  isTransformable: false,
  metadata: CanvasMetadata.fromMap({'label': 'rich', 'nullable': null}),
);

CanvasTransform _expectedRichTextTransform(String nextText) {
  final before = _expectedRichTextSize('hello');
  final after = _expectedRichTextSize(nextText);
  return CanvasTransform.translation(
    Offset(
      (before.width - after.width) / 2,
      15 + (after.height - before.height) / 2,
    ),
  );
}

Size _expectedRichTextSize(String text) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(
        color: Color(0xFF221144),
        fontSize: 18,
        fontFamily: 'Inter',
        fontWeight: FontWeight.bold,
        fontStyle: FontStyle.italic,
        decoration: TextDecoration.underline,
        height: 1.25,
      ),
    ),
    textAlign: TextAlign.right,
    textDirection: TextDirection.rtl,
  )..layout();
  final size = painter.size;
  painter.dispose();
  return size;
}

CanvasDocument _invalidReplacementDocument() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasTextElement(
            id: _textId,
            text: 'replacement',
            color: const Color(0xFF111111),
            textDirection: TextDirection.ltr,
          ),
          CanvasTextElement(
            id: _textId,
            text: 'duplicate',
            color: const Color(0xFF222222),
            textDirection: TextDirection.ltr,
          ),
        ],
      ),
    ],
  );
}

final _textId = CanvasElementId('text-a');
final _secondTextId = CanvasElementId('text-b');
final _replacementTextId = CanvasElementId('replacement-text');
final _rectId = CanvasElementId('rect-a');
final _listenerNestedRectId = CanvasElementId('listener-nested-rect');
final _listenerFailureRectId = CanvasElementId('listener-failure-rect');
