import '../contracts/public/canvas_ids.dart';
import 'frame_paint_output.dart';
import 'paint_asset_binding_service.dart';

Map<CanvasResourceId, FrameAssetBinding> resolvedMainFrameAssets(
  MainFramePaintOutput output,
) {
  return output.assetBindings.assets;
}
