import 'dart:ui';

import '../../contract/scene_view_render_state.dart';
import '../../contract/snapshot.dart';

abstract interface class InteractiveMovePreviewRead {
  Offset previewDeltaForNode(NodeId nodeId);

  SceneViewFramePreview captureFramePreview();
}

extension InteractiveMovePreviewReadQueries on InteractiveMovePreviewRead {
  bool hasPreviewDeltaForNode(NodeId nodeId) {
    return previewDeltaForNode(nodeId) != Offset.zero;
  }
}
