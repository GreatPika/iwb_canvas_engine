import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// INV:INV-ENG-RUNTIME-SCENE-STRUCTURE-OWNER
// INV:INV-ENG-ID-INDEX-FROM-SCENE

void main() {
  test('controller write path does not repair topology locators manually', () {
    final txnWorkspaceSource = File(
      'lib/src/controller/txn_workspace.dart',
    ).readAsStringSync();

    expect(
      txnWorkspaceSource,
      isNot(contains('txnShiftNodeLocatorLayersFrom(')),
    );
    expect(txnWorkspaceSource, contains('txnEnsureContentLayerInScene('));
    expect(txnWorkspaceSource, contains('txnReplaceContentLayerSlotInScene('));
    expect(
      txnWorkspaceSource,
      isNot(contains('txnReplaceContentLayerInScene(')),
    );
  });

  test(
    'committed spatial consumers pass stable locator state without adapters',
    () {
      final storeControllerSource = File(
        'lib/src/controller/scene_store_controller.dart',
      ).readAsStringSync();
      final commitExecutionSource = File(
        'lib/src/controller/scene_controller_commit_execution.dart',
      ).readAsStringSync();

      expect(
        storeControllerSource,
        isNot(contains('_resolveCommittedSpatialCandidateLocator')),
      );
      expect(
        commitExecutionSource,
        isNot(contains('_resolveSpatialCandidateLocator')),
      );
      expect(
        storeControllerSource,
        contains('layerIndexById: _store.layerIndexById'),
      );
      expect(
        commitExecutionSource,
        contains('layerIndexById: committedStoreState.layerIndexById'),
      );
    },
  );

  test('stable locator carrier stores content-layer identity', () {
    final carrierSource = File(
      'lib/src/core/scene_node_locator.dart',
    ).readAsStringSync();
    final locatorSource = File(
      'lib/src/model/document_locator.dart',
    ).readAsStringSync();
    final writeLayerNodeLocationsSection = locatorSource.substring(
      locatorSource.indexOf('void txnWriteLayerNodeLocations('),
      locatorSource.indexOf('({List<SceneNode>? nodes, int layerIndex})?'),
    );

    expect(carrierSource, contains('contentLayerId'));
    expect(locatorSource, contains('contentLayerId: contentLayerId'));
    expect(
      writeLayerNodeLocationsSection,
      isNot(contains('layerIndex: layerIndex')),
    );
  });
}
