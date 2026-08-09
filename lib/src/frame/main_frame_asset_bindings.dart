import '../contracts/public/canvas_ids.dart';
import '../resources/resource_resolver_adapter.dart';
import 'frame_paint_output.dart';

Map<CanvasResourceId, ResourceAsset> resolvedMainFrameAssets(
  MainFramePaintOutput output,
) {
  return {
    for (final entry in output.assetBindings.assets.entries)
      if (entry.value case final ResolvedResourceAsset result)
        entry.key: result.asset,
  };
}
