```mermaid
flowchart LR
  N0["SceneViewRuntime.overlayPreviewRead"]
  N1["runtime_contract_interfaces_test.dart.main"]
  N1 --> N0
  N2["scene_controller_public_listener_contract_test.dart.main"]
  N2 --> N0
  N3["_SceneViewRuntimeHostState.build"]
  N3 --> N0
  N4["SceneController.get _overlayPreviewRead"]
  N4 --> N0
  N5["SceneController.get activeStrokePreviewPoints"]
  N5 --> N4
  N6["SceneController.get cameraOffset"]
  N6 --> N4
  N7["SceneController.get activeStrokePreviewThickness"]
  N7 --> N4
  N8["SceneController.get selectionRect"]
  N8 --> N4
  N9["SceneController.get activeStrokePreviewColor"]
  N9 --> N4
  N10["SceneController.get activeStrokePreviewOpacity"]
  N10 --> N4
  N11["SceneController.get hasActiveLinePreview"]
  N11 --> N4
  N12["SceneController.get activeLinePreviewStart"]
  N12 --> N4
  N13["SceneController.get activeLinePreviewEnd"]
  N13 --> N4
  N14["SceneController.get activeLinePreviewThickness"]
  N14 --> N4
  N15["SceneController.get activeLinePreviewColor"]
  N15 --> N4
  N16["SceneController.get hasActiveStrokePreview"]
  N16 --> N4

```
