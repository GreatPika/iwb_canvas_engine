enum P9DonorDisposition { copied, adapted, avoided }

final class P9FrameDonorMapping {
  const P9FrameDonorMapping({
    required this.donor,
    required this.disposition,
    required this.targetOwner,
    required this.proofSurface,
  });

  final String donor;
  final P9DonorDisposition disposition;
  final String targetOwner;
  final String proofSurface;
}

const List<P9FrameDonorMapping> p9FrameDonorMappings = [
  P9FrameDonorMapping(
    donor: 'direct_local_bounds_policy',
    disposition: P9DonorDisposition.copied,
    targetOwner: 'GeometryPolicy local bounds',
    proofSurface: 'geometry local bounds tests',
  ),
  P9FrameDonorMapping(
    donor: 'direct_paint_admission',
    disposition: P9DonorDisposition.copied,
    targetOwner: 'paint admission policy',
    proofSurface: 'frame paint admission tests',
  ),
  P9FrameDonorMapping(
    donor: 'direct_scan_resistant_cache',
    disposition: P9DonorDisposition.copied,
    targetOwner: 'render cache policy',
    proofSurface: 'bounded frame cache tests',
  ),
  P9FrameDonorMapping(
    donor: 'render_geometry_builder',
    disposition: P9DonorDisposition.adapted,
    targetOwner: 'RenderElementRecord geometry construction',
    proofSurface: 'render element record tests',
  ),
  P9FrameDonorMapping(
    donor: 'spatial_index_cache',
    disposition: P9DonorDisposition.adapted,
    targetOwner: 'SpatialKernel invalidation cache',
    proofSurface: 'spatial kernel invalidation tests',
  ),
  P9FrameDonorMapping(
    donor: 'snapshot_paint_admission_bounds',
    disposition: P9DonorDisposition.adapted,
    targetOwner: 'FrameEngine paint bounds cache',
    proofSurface: 'frame capture and paint bounds tests',
  ),
  P9FrameDonorMapping(
    donor: 'snapshot_paint_candidates',
    disposition: P9DonorDisposition.adapted,
    targetOwner: 'FrameEngine fallback candidate enumeration',
    proofSurface: 'frame capture candidate tests',
  ),
  P9FrameDonorMapping(
    donor: 'frame_render_state',
    disposition: P9DonorDisposition.adapted,
    targetOwner: 'captured frame model',
    proofSurface: 'main and overlay capture tests',
  ),
  P9FrameDonorMapping(
    donor: 'scene_view_runtime_fast_path',
    disposition: P9DonorDisposition.adapted,
    targetOwner: 'FrameEngine committed fast path',
    proofSurface: 'frame committed fast path tests',
  ),
  P9FrameDonorMapping(
    donor: 'paint_candidate_stage',
    disposition: P9DonorDisposition.adapted,
    targetOwner: 'PaintPlan staging',
    proofSurface: 'ordinary paint plan staging tests',
  ),
  P9FrameDonorMapping(
    donor: 'scene_painter_frame',
    disposition: P9DonorDisposition.adapted,
    targetOwner: 'main and overlay painters',
    proofSurface: 'widget paint proof',
  ),
  P9FrameDonorMapping(
    donor: 'scene_render_caches',
    disposition: P9DonorDisposition.adapted,
    targetOwner: 'render cache owner lifecycle',
    proofSurface: 'render cache lifecycle tests',
  ),
  P9FrameDonorMapping(
    donor: 'static_layer_cache',
    disposition: P9DonorDisposition.adapted,
    targetOwner: 'static background cache',
    proofSurface: 'static background cache tests',
  ),
  P9FrameDonorMapping(
    donor: 'text_stroke_path_metrics_caches',
    disposition: P9DonorDisposition.adapted,
    targetOwner: 'render family caches',
    proofSurface: 'text, stroke, and path cache tests',
  ),
  P9FrameDonorMapping(
    donor: 'avoid_scene_controller_facades',
    disposition: P9DonorDisposition.avoided,
    targetOwner: 'forbidden donor structure',
    proofSurface: 'donor mapping rejection test',
  ),
  P9FrameDonorMapping(
    donor: 'avoid_interactive_runtime_whole',
    disposition: P9DonorDisposition.avoided,
    targetOwner: 'forbidden donor structure',
    proofSurface: 'donor mapping rejection test',
  ),
  P9FrameDonorMapping(
    donor: 'avoid_scene_builder_public_architecture',
    disposition: P9DonorDisposition.avoided,
    targetOwner: 'forbidden donor structure',
    proofSurface: 'donor mapping rejection test',
  ),
  P9FrameDonorMapping(
    donor: 'avoid_scene_codec_whole',
    disposition: P9DonorDisposition.avoided,
    targetOwner: 'forbidden donor structure',
    proofSurface: 'donor mapping rejection test',
  ),
  P9FrameDonorMapping(
    donor: 'avoid_scene_store_controller_whole',
    disposition: P9DonorDisposition.avoided,
    targetOwner: 'forbidden donor structure',
    proofSurface: 'donor mapping rejection test',
  ),
];
