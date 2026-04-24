```mermaid
flowchart LR
  N0["SceneControllerSceneOwner.addNode"]
  N1["SceneControllerInteractionRuntime.ensurePublicSideEffectAllowed"]
  N0 --> N1
  N2["SceneControllerSceneOwner._ensureExternalMutationAllowed"]
  N0 --> N2
  N3["SceneControllerInteractionRuntime.ensureExternalMutationAllowed"]
  N2 --> N3
  N4["InteractiveRuntime.get hasActiveGesture"]
  N3 --> N4
  N5["InteractiveGestureRouter.get hasActiveGesture"]
  N4 --> N5
  N6["InteractiveGestureMachine.get hasActiveGesture"]
  N5 --> N6
  N7["SceneControllerMutationBoundary.addNode"]
  N0 --> N7
  N8["SceneControllerCommittedMutationAccess.addNode"]
  N7 --> N8
  N9["SceneControllerMutationBoundary._scheduleSceneCommit"]
  N7 --> N9

```
