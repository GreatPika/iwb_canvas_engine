import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import '../../support/document_store_with_document.dart';
import 'interaction_commit_scenario_support.dart';

void main() {
  test(
    'interaction compensation skips augmentPlan and installs nothing',
    () => expect(_interactionCompensationSkipsAugmentPlan, returnsNormally),
  );
}

void _interactionCompensationSkipsAugmentPlan() {
  final store = documentStoreWithDocument(interactionCommitBaseDocument());
  final beforeDocumentRevision = store.documentRevision;
  final beforeProjectionBuilds = store.projectionBuildCount;
  final scenario = InteractionCommitScenario(store);
  final result = scenario.kernel.prepareInteractionCommit(
    (edit) {
      edit.setBackgroundColor(const Color(0xFF112233));
      edit.setBackgroundColor(const Color(0xFFFFFFFF));
    },
    augmentPlan: (_) {
      throw StateError('Accepted net no-op interaction must not augment.');
    },
  );

  expect(result.shouldPublishState, isFalse);
  expect(result.effects, isEmpty);
  expect(result.actionIntents, isEmpty);
  expect(scenario.installCount, 0);
  expect(scenario.deliverCount, 0);
  expect(scenario.loadCount, 0);
  expect(store.documentRevision, beforeDocumentRevision);
  expect(store.projectionBuildCount, beforeProjectionBuilds);
}
