import 'package:test/test.dart';
import 'package:iwb_canvas_engine/src/frame/frame_donor_mapping.dart';

void main() {
  test('P9 donor mapping names copied, adapted, and avoided structures', () {
    final byDonor = {
      for (final mapping in p9FrameDonorMappings) mapping.donor: mapping,
    };

    expect(byDonor.keys, containsAll(_requiredMappings.keys));
    _expectRequiredMappings(byDonor);
    _expectForbiddenDonors(byDonor);
    expect(
      p9FrameDonorMappings
          .where((mapping) => mapping.disposition != P9DonorDisposition.avoided)
          .map((mapping) => mapping.donor),
      hasLength(14),
    );
    expect(
      p9FrameDonorMappings
          .where((mapping) => mapping.disposition == P9DonorDisposition.avoided)
          .map((mapping) => mapping.donor),
      hasLength(5),
    );
  });
}

const _requiredMappings = {
  'direct_local_bounds_policy': (
    disposition: P9DonorDisposition.copied,
    targetOwner: 'GeometryPolicy local bounds',
    proofSurface: 'geometry local bounds tests',
  ),
  'direct_paint_admission': (
    disposition: P9DonorDisposition.copied,
    targetOwner: 'paint admission policy',
    proofSurface: 'frame paint admission tests',
  ),
  'direct_scan_resistant_cache': (
    disposition: P9DonorDisposition.copied,
    targetOwner: 'render cache policy',
    proofSurface: 'bounded frame cache tests',
  ),
  'render_geometry_builder': (
    disposition: P9DonorDisposition.adapted,
    targetOwner: 'RenderElementRecord geometry construction',
    proofSurface: 'render element record tests',
  ),
  'spatial_index_cache': (
    disposition: P9DonorDisposition.adapted,
    targetOwner: 'SpatialKernel invalidation cache',
    proofSurface: 'spatial kernel invalidation tests',
  ),
  'snapshot_paint_admission_bounds': (
    disposition: P9DonorDisposition.adapted,
    targetOwner: 'FrameEngine paint bounds cache',
    proofSurface: 'frame capture and paint bounds tests',
  ),
  'snapshot_paint_candidates': (
    disposition: P9DonorDisposition.adapted,
    targetOwner: 'FrameEngine fallback candidate enumeration',
    proofSurface: 'frame capture candidate tests',
  ),
  'frame_render_state': (
    disposition: P9DonorDisposition.adapted,
    targetOwner: 'captured frame model',
    proofSurface: 'main and overlay capture tests',
  ),
  'scene_view_runtime_fast_path': (
    disposition: P9DonorDisposition.adapted,
    targetOwner: 'FrameEngine committed fast path',
    proofSurface: 'frame committed fast path tests',
  ),
  'paint_candidate_stage': (
    disposition: P9DonorDisposition.adapted,
    targetOwner: 'PaintPlan staging',
    proofSurface: 'ordinary paint plan staging tests',
  ),
  'scene_painter_frame': (
    disposition: P9DonorDisposition.adapted,
    targetOwner: 'main and overlay painters',
    proofSurface: 'widget paint proof',
  ),
  'scene_render_caches': (
    disposition: P9DonorDisposition.adapted,
    targetOwner: 'render cache owner lifecycle',
    proofSurface: 'render cache lifecycle tests',
  ),
  'static_layer_cache': (
    disposition: P9DonorDisposition.adapted,
    targetOwner: 'static background cache',
    proofSurface: 'static background cache tests',
  ),
  'text_stroke_path_metrics_caches': (
    disposition: P9DonorDisposition.adapted,
    targetOwner: 'render family caches',
    proofSurface: 'text, stroke, and path cache tests',
  ),
};

const _forbiddenDonors = {
  'avoid_scene_controller_facades',
  'avoid_interactive_runtime_whole',
  'avoid_scene_builder_public_architecture',
  'avoid_scene_codec_whole',
  'avoid_scene_store_controller_whole',
};

void _expectRequiredMappings(Map<String, P9FrameDonorMapping> byDonor) {
  for (final entry in _requiredMappings.entries) {
    expect(
      byDonor[entry.key],
      isA<P9FrameDonorMapping>()
          .having(
            (mapping) => mapping.disposition,
            'disposition',
            entry.value.disposition,
          )
          .having(
            (mapping) => mapping.targetOwner,
            'targetOwner',
            entry.value.targetOwner,
          )
          .having(
            (mapping) => mapping.proofSurface,
            'proofSurface',
            entry.value.proofSurface,
          ),
    );
  }
}

void _expectForbiddenDonors(Map<String, P9FrameDonorMapping> byDonor) {
  for (final donor in _forbiddenDonors) {
    expect(
      byDonor[donor],
      isA<P9FrameDonorMapping>()
          .having(
            (mapping) => mapping.disposition,
            'disposition',
            P9DonorDisposition.avoided,
          )
          .having(
            (mapping) => mapping.targetOwner,
            'targetOwner',
            'forbidden donor structure',
          ),
    );
  }
}
