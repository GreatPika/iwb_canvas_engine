import '../frame/frame_engine.dart';
import '../frame/paint_asset_binding_service.dart';
import '../resources/surface_resource_session.dart';

final class CanvasSurfaceAssetBridge {
  const CanvasSurfaceAssetBridge();

  FrameAssetBindingBuilder bindAssets(SurfaceResourceSession session) {
    return ({required frame, required records}) {
      return const PaintAssetBindingService().bind(
        frame: frame,
        records: records,
        session: session,
      );
    };
  }
}
