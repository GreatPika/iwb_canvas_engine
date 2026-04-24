```mermaid
flowchart LR
  N0["_createInteractiveRuntime"]
  N1["InteractiveRuntime.InteractiveRuntime"]
  N0 --> N1
  N2["InteractiveMoveSession.InteractiveMoveSession"]
  N1 --> N2
  N3["InteractiveMovePreviewState.InteractiveMovePreviewState"]
  N2 --> N3
  N4["InteractiveMoveHitTestEngine.InteractiveMoveHitTestEngine"]
  N2 --> N4
  N5["InteractiveMoveSelectionCoordinator.InteractiveMoveSelectionCoordinator"]
  N2 --> N5
  N6["InteractiveMoveCommitCoordinator.InteractiveMoveCommitCoordinator"]
  N2 --> N6
  N7["InteractiveMoveSessionCallbacks.InteractiveMoveSessionCallbacks"]
  N1 --> N7
  N8["InteractiveEventDispatcher.emitAction"]
  N1 --> N8
  N9["ActionCommitted.ActionCommitted"]
  N8 --> N9
  N10["ActionCommitted.ActionCommitted._"]
  N9 --> N10
  N11["immutable_collections.dart.freezeList"]
  N9 --> N11
  N12["immutable_collections.dart.freezePayloadMap"]
  N9 --> N12
  N13["InteractiveDrawCoordinator.InteractiveDrawCoordinator"]
  N1 --> N13
  N14["InteractiveDrawStrokeEngine.InteractiveDrawStrokeEngine"]
  N13 --> N14
  N15["InteractiveDrawStrokeEngineCallbacks.InteractiveDrawStrokeEngineCallbacks"]
  N13 --> N15
  N16["InteractiveDrawLineEngine.InteractiveDrawLineEngine"]
  N13 --> N16
  N17["InteractiveDrawLineEngineCallbacks.InteractiveDrawLineEngineCallbacks"]
  N13 --> N17
  N18["InteractiveDrawEraserEngine.InteractiveDrawEraserEngine"]
  N13 --> N18
  N19["InteractiveDrawEraserEngineCallbacks.InteractiveDrawEraserEngineCallbacks"]
  N13 --> N19
  N20["InteractiveDrawTerminalRouter.InteractiveDrawTerminalRouter"]
  N13 --> N20
  N21["InteractiveDrawCoordinatorCallbacks.InteractiveDrawCoordinatorCallbacks"]
  N1 --> N21
  N22["InteractiveRuntimeCallbacks.InteractiveRuntimeCallbacks"]
  N0 --> N22
  N23["InteractiveNotifyScheduler.schedule"]
  N0 --> N23
  N24["SceneStoreControllerSpatialAccess.queryHitTestCandidates"]
  N0 --> N24
  N25["SpatialIndexCache.writeQueryHitTestCandidates"]
  N24 --> N25
  N26["SceneSpatialIndex.SceneSpatialIndex.build"]
  N25 --> N26
  N27["SceneSpatialIndex.SceneSpatialIndex._"]
  N26 --> N27
  N28["scene_spatial_index.dart._rebuildSpatialIndex"]
  N26 --> N28
  N29["scene_spatial_index.dart._buildStableNodeLocator"]
  N26 --> N29
  N30["scene_spatial_index.dart._buildLayerIndexById"]
  N26 --> N30
  N31["SceneSpatialIndex.queryHitTestCandidates"]
  N25 --> N31
  N32["scene_spatial_index.dart._querySceneSpatialIndexHitTest"]
  N31 --> N32
  N33["SceneControllerCommitRuntime.get spatialIndexCache"]
  N24 --> N33
  N34["SceneStoreControllerSpatialAccess.resolveSpatialCandidateSnapshot"]
  N0 --> N34
  N35["scene_store_controller.dart._resolveSnapshotAtLocationInSnapshot"]
  N34 --> N35
  N36["SceneControllerMutationBoundary.setSelection"]
  N0 --> N36
  N37["SceneControllerCommittedMutationAccess.replaceSelection"]
  N36 --> N37
  N38["SceneControllerMutationBoundary._scheduleSceneCommit"]
  N36 --> N38
  N39["SceneControllerMutationBoundary.clearSelection"]
  N0 --> N39
  N40["SceneControllerCommittedMutationAccess.clearSelection"]
  N39 --> N40
  N41["SceneControllerMutationBoundary._scheduleSceneCommit"]
  N39 --> N41
  N42["SceneControllerMutationBoundary.commitMoveSelection"]
  N0 --> N42
  N43["SceneControllerCommittedMutationAccess.write"]
  N42 --> N43
  N44["SceneWriteTxn.get snapshot"]
  N42 --> N44
  N45["immutable_collections.dart.freezeList"]
  N42 --> N45
  N46["_FrozenList._FrozenList"]
  N45 --> N46
  N47["interaction_eligibility_policy.dart.selectedCommitMovableNodesInSnapshotOrder"]
  N42 --> N47
  N48["interaction_eligibility_policy.dart.selectedNodesInSnapshotOrder"]
  N47 --> N48
  N49["interaction_eligibility_policy.dart.canCommitMove"]
  N47 --> N49
  N50["interaction_eligibility_policy.dart.canPreviewMove"]
  N49 --> N50
  N51["SceneWriteTxn.get selectedNodeIds"]
  N42 --> N51
  N52["MoveCommitDeltaRequest.MoveCommitDeltaRequest"]
  N42 --> N52
  N53["MoveCommitDeltaRequest.MoveCommitDeltaRequest._"]
  N52 --> N53
  N54["immutable_collections.dart.freezeList"]
  N52 --> N54
  N55["_FrozenList._FrozenList"]
  N54 --> N55
  N56["Transform2D.withTranslation"]
  N42 --> N56
  N57["Transform2D.Transform2D"]
  N56 --> N57
  N58["Transform2D.get translation"]
  N42 --> N58
  N59["SceneWriteTxn.writeNodeTransformSet"]
  N42 --> N59
  N60["SceneControllerMutationBoundary._scheduleSceneCommit"]
  N42 --> N60
  N61["SceneControllerMutationBoundary.commitDrawStroke"]
  N0 --> N61
  N62["SceneControllerCommittedMutationAccess.commitDrawStroke"]
  N61 --> N62
  N63["SceneControllerMutationBoundary._scheduleSceneCommit"]
  N61 --> N63
  N64["SceneControllerMutationBoundary.commitDrawLineFromWorldSegment"]
  N0 --> N64
  N65["SceneControllerCommittedMutationAccess.commitDrawLineFromWorldSegment"]
  N64 --> N65
  N66["SceneControllerMutationBoundary._scheduleSceneCommit"]
  N64 --> N66
  N67["SceneControllerMutationBoundary.commitEraseNodes"]
  N0 --> N67
  N68["SceneControllerCommittedMutationAccess.commitEraseNodes"]
  N67 --> N68
  N69["SceneControllerMutationBoundary._scheduleSceneCommit"]
  N67 --> N69

```
