```mermaid
flowchart LR
  N0["createSceneControllerGraph"]
  N1["scene_controller_graph.dart._assembleSceneControllerGraph"]
  N0 --> N1
  N2["SceneStoreController.SceneStoreController"]
  N1 --> N2
  N3["SceneStore.SceneStore"]
  N2 --> N3
  N4["document.dart.txnSceneFromSnapshot"]
  N2 --> N4
  N5["SceneSnapshot.SceneSnapshot"]
  N2 --> N5
  N6["SceneControllerCommitRuntime.SceneControllerCommitRuntime"]
  N2 --> N6
  N7["scene_controller_graph.dart._createInteractionConfig"]
  N1 --> N7
  N8["SceneControllerInteractionConfig.SceneControllerInteractionConfig"]
  N7 --> N8
  N9["pointer_input.dart.validatePointerInputSettings"]
  N7 --> N9
  N10["SceneControllerSceneViewRuntime.SceneControllerSceneViewRuntime"]
  N1 --> N10
  N11["SceneControllerSceneViewMainSceneRenderRead.SceneControllerSceneViewMainSceneRenderRead"]
  N10 --> N11
  N12["SceneControllerSceneViewOverlayPreviewRead.SceneControllerSceneViewOverlayPreviewRead"]
  N10 --> N12
  N13["SceneControllerInteractionRuntime.ensurePublicSideEffectAllowed"]
  N1 --> N13
  N14["SceneStoreController.get snapshot"]
  N1 --> N14
  N15["document.dart.txnSceneToSnapshot"]
  N14 --> N15
  N16["SceneStoreController.get selectedNodeIds"]
  N1 --> N16
  N17["SceneControllerCommitRuntime.get selectedNodeIdsView"]
  N16 --> N17
  N18["SceneStoreController.get controllerEpoch"]
  N1 --> N18
  N19["SceneController.get interaction"]
  N1 --> N19
  N20["SceneControllerInteractionRuntimeStateApi.get movePreviewRead"]
  N1 --> N20
  N21["InteractiveRuntime.get movePreviewRead"]
  N20 --> N21
  N22["scene_controller_graph.dart._createInteractionRuntime"]
  N1 --> N22
  N23["scene_controller_interaction_runtime.dart.createSceneControllerInteractionRuntime"]
  N22 --> N23
  N24["SceneControllerInteractionRuntimeRequest.SceneControllerInteractionRuntimeRequest"]
  N22 --> N24
  N25["SceneControllerSceneViewRuntime.scheduleSceneRepaint"]
  N22 --> N25
  N26["SceneControllerSceneViewRuntime.scheduleOverlayRepaint"]
  N22 --> N26
  N27["SceneStoreControllerCommittedMutationAccess.SceneStoreControllerCommittedMutationAccess"]
  N22 --> N27
  N28["SceneStoreController.get snapshot"]
  N22 --> N28
  N29["SceneStoreController.get selectedNodeIds"]
  N22 --> N29
  N30["SceneControllerInteractionConfig.dragStartSlop"]
  N22 --> N30
  N31["SceneControllerInteractionConfig.currentDrawStyle"]
  N22 --> N31
  N32["SceneControllerInteractionConfig.requireFiniteOffset"]
  N22 --> N32
  N33["SceneControllerInteractionOwner.SceneControllerInteractionOwner"]
  N1 --> N33
  N34["SceneControllerInteractionRuntime.ensureExternalMutationAllowed"]
  N1 --> N34
  N35["InteractiveRuntime.get hasActiveGesture"]
  N34 --> N35
  N36["SceneControllerMutationBoundary.clearSelection"]
  N1 --> N36
  N37["SceneControllerCommittedMutationAccess.clearSelection"]
  N36 --> N37
  N38["SceneControllerMutationBoundary._scheduleSceneCommit"]
  N36 --> N38
  N39["SceneControllerGraphHandle.SceneControllerGraphHandle"]
  N1 --> N39
  N40["SceneControllerSelectionOwner.SceneControllerSelectionOwner"]
  N1 --> N40
  N41["SceneControllerSceneOwner.SceneControllerSceneOwner"]
  N1 --> N41
  N42["SceneControllerInternalAccessRegistration.SceneControllerInternalAccessRegistration"]
  N1 --> N42
  N43["SceneControllerInteractionRuntimeMutationApi.setBeforePointerDispatchHook"]
  N1 --> N43
  N44["InteractiveRuntime.setBeforePointerDispatchHook"]
  N43 --> N44
  N45["SceneControllerInteractionRuntime.runMoveCommitDeltaResolver"]
  N1 --> N45
  N46["SceneControllerInteractionRuntimeStateApi.get activeEraserPointsLength"]
  N1 --> N46
  N47["InteractiveRuntime.get activeEraserPointsLength"]
  N46 --> N47
  N48["SceneControllerInteractionRuntimeStateApi.get eraserSpatialQueryCount"]
  N1 --> N48
  N49["InteractiveRuntime.get debugEraserSpatialQueryCount"]
  N48 --> N49
  N50["SceneControllerInteractionRuntimeStateApi.get eraserPreciseSegmentCheckCount"]
  N1 --> N50
  N51["InteractiveRuntime.get debugEraserPreciseSegmentChecks"]
  N50 --> N51
  N52["scene_controller_internal_access.dart.registerSceneControllerInternalAccess"]
  N0 --> N52
  N53["_SceneControllerInternalAccess._SceneControllerInternalAccess"]
  N52 --> N53
  N54["SceneControllerGraphHandle.get internalAccessRegistration"]
  N0 --> N54

```
