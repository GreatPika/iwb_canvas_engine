import 'package:test/test.dart';

void main() {
  test('frame donor mapping names copied, adapted, and avoided structures', () {
    final byDonor = {
      for (final mapping in _frameDonorMappings) mapping.donor: mapping,
    };

    expect(byDonor.keys, containsAll(_requiredMappings.keys));
    _expectRequiredMappings(byDonor);
    _expectForbiddenDonors(byDonor);
    expect(
      _frameDonorMappings
          .where(
            (mapping) => mapping.disposition != _FrameDonorDisposition.avoided,
          )
          .map((mapping) => mapping.donor),
      hasLength(14),
    );
    expect(
      _frameDonorMappings
          .where(
            (mapping) => mapping.disposition == _FrameDonorDisposition.avoided,
          )
          .map((mapping) => mapping.donor),
      hasLength(5),
    );
  });
}

const _requiredMappings = {
  'direct_local_bounds_policy': (
    disposition: _FrameDonorDisposition.copied,
    targetOwner: 'GeometryPolicy local bounds',
    proofSurface: 'geometry local bounds tests',
  ),
  'direct_paint_admission': (
    disposition: _FrameDonorDisposition.copied,
    targetOwner: 'paint admission policy',
    proofSurface: 'frame paint admission tests',
  ),
  'direct_scan_resistant_cache': (
    disposition: _FrameDonorDisposition.copied,
    targetOwner: 'render cache policy',
    proofSurface: 'bounded frame cache tests',
  ),
  'render_geometry_builder': (
    disposition: _FrameDonorDisposition.adapted,
    targetOwner: 'RenderElementRecord geometry construction',
    proofSurface: 'render element record tests',
  ),
  'spatial_index_cache': (
    disposition: _FrameDonorDisposition.adapted,
    targetOwner: 'SpatialKernel invalidation cache',
    proofSurface: 'spatial kernel invalidation tests',
  ),
  'snapshot_paint_admission_bounds': (
    disposition: _FrameDonorDisposition.adapted,
    targetOwner: 'FrameEngine paint bounds cache',
    proofSurface: 'frame capture and paint bounds tests',
  ),
  'snapshot_paint_candidates': (
    disposition: _FrameDonorDisposition.adapted,
    targetOwner: 'FrameEngine fallback candidate enumeration',
    proofSurface: 'frame capture candidate tests',
  ),
  'frame_render_state': (
    disposition: _FrameDonorDisposition.adapted,
    targetOwner: 'captured frame model',
    proofSurface: 'main and overlay capture tests',
  ),
  'scene_view_runtime_fast_path': (
    disposition: _FrameDonorDisposition.adapted,
    targetOwner: 'FrameEngine committed fast path',
    proofSurface: 'frame committed fast path tests',
  ),
  'paint_candidate_stage': (
    disposition: _FrameDonorDisposition.adapted,
    targetOwner: 'PaintPlan staging',
    proofSurface: 'ordinary paint plan staging tests',
  ),
  'scene_painter_frame': (
    disposition: _FrameDonorDisposition.adapted,
    targetOwner: 'main and overlay painters',
    proofSurface: 'widget paint proof',
  ),
  'scene_render_caches': (
    disposition: _FrameDonorDisposition.adapted,
    targetOwner: 'render cache owner lifecycle',
    proofSurface: 'render cache lifecycle tests',
  ),
  'static_layer_cache': (
    disposition: _FrameDonorDisposition.adapted,
    targetOwner: 'static background cache',
    proofSurface: 'static background cache tests',
  ),
  'text_stroke_path_metrics_caches': (
    disposition: _FrameDonorDisposition.adapted,
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

void _expectRequiredMappings(Map<String, _FrameDonorMapping> byDonor) {
  for (final entry in _requiredMappings.entries) {
    expect(
      byDonor[entry.key],
      isA<_FrameDonorMapping>()
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

void _expectForbiddenDonors(Map<String, _FrameDonorMapping> byDonor) {
  for (final donor in _forbiddenDonors) {
    expect(
      byDonor[donor],
      isA<_FrameDonorMapping>()
          .having(
            (mapping) => mapping.disposition,
            'disposition',
            _FrameDonorDisposition.avoided,
          )
          .having(
            (mapping) => mapping.targetOwner,
            'targetOwner',
            'forbidden donor structure',
          ),
    );
  }
}

enum _FrameDonorDisposition { copied, adapted, avoided }

final class _FrameDonorMapping {
  const _FrameDonorMapping({
    required this.donor,
    required this.disposition,
    required this.targetOwner,
    required this.proofSurface,
  });

  final String donor;
  final _FrameDonorDisposition disposition;
  final String targetOwner;
  final String proofSurface;
}

const List<_FrameDonorMapping> _frameDonorMappings = [
  _FrameDonorMapping(
    donor: 'direct_local_bounds_policy',
    disposition: _FrameDonorDisposition.copied,
    targetOwner: 'GeometryPolicy local bounds',
    proofSurface: 'geometry local bounds tests',
  ),
  _FrameDonorMapping(
    donor: 'direct_paint_admission',
    disposition: _FrameDonorDisposition.copied,
    targetOwner: 'paint admission policy',
    proofSurface: 'frame paint admission tests',
  ),
  _FrameDonorMapping(
    donor: 'direct_scan_resistant_cache',
    disposition: _FrameDonorDisposition.copied,
    targetOwner: 'render cache policy',
    proofSurface: 'bounded frame cache tests',
  ),
  _FrameDonorMapping(
    donor: 'render_geometry_builder',
    disposition: _FrameDonorDisposition.adapted,
    targetOwner: 'RenderElementRecord geometry construction',
    proofSurface: 'render element record tests',
  ),
  _FrameDonorMapping(
    donor: 'spatial_index_cache',
    disposition: _FrameDonorDisposition.adapted,
    targetOwner: 'SpatialKernel invalidation cache',
    proofSurface: 'spatial kernel invalidation tests',
  ),
  _FrameDonorMapping(
    donor: 'snapshot_paint_admission_bounds',
    disposition: _FrameDonorDisposition.adapted,
    targetOwner: 'FrameEngine paint bounds cache',
    proofSurface: 'frame capture and paint bounds tests',
  ),
  _FrameDonorMapping(
    donor: 'snapshot_paint_candidates',
    disposition: _FrameDonorDisposition.adapted,
    targetOwner: 'FrameEngine fallback candidate enumeration',
    proofSurface: 'frame capture candidate tests',
  ),
  _FrameDonorMapping(
    donor: 'frame_render_state',
    disposition: _FrameDonorDisposition.adapted,
    targetOwner: 'captured frame model',
    proofSurface: 'main and overlay capture tests',
  ),
  _FrameDonorMapping(
    donor: 'scene_view_runtime_fast_path',
    disposition: _FrameDonorDisposition.adapted,
    targetOwner: 'FrameEngine committed fast path',
    proofSurface: 'frame committed fast path tests',
  ),
  _FrameDonorMapping(
    donor: 'paint_candidate_stage',
    disposition: _FrameDonorDisposition.adapted,
    targetOwner: 'PaintPlan staging',
    proofSurface: 'ordinary paint plan staging tests',
  ),
  _FrameDonorMapping(
    donor: 'scene_painter_frame',
    disposition: _FrameDonorDisposition.adapted,
    targetOwner: 'main and overlay painters',
    proofSurface: 'widget paint proof',
  ),
  _FrameDonorMapping(
    donor: 'scene_render_caches',
    disposition: _FrameDonorDisposition.adapted,
    targetOwner: 'render cache owner lifecycle',
    proofSurface: 'render cache lifecycle tests',
  ),
  _FrameDonorMapping(
    donor: 'static_layer_cache',
    disposition: _FrameDonorDisposition.adapted,
    targetOwner: 'static background cache',
    proofSurface: 'static background cache tests',
  ),
  _FrameDonorMapping(
    donor: 'text_stroke_path_metrics_caches',
    disposition: _FrameDonorDisposition.adapted,
    targetOwner: 'render family caches',
    proofSurface: 'text, stroke, and path cache tests',
  ),
  _FrameDonorMapping(
    donor: 'avoid_scene_controller_facades',
    disposition: _FrameDonorDisposition.avoided,
    targetOwner: 'forbidden donor structure',
    proofSurface: 'donor mapping rejection test',
  ),
  _FrameDonorMapping(
    donor: 'avoid_interactive_runtime_whole',
    disposition: _FrameDonorDisposition.avoided,
    targetOwner: 'forbidden donor structure',
    proofSurface: 'donor mapping rejection test',
  ),
  _FrameDonorMapping(
    donor: 'avoid_scene_builder_public_architecture',
    disposition: _FrameDonorDisposition.avoided,
    targetOwner: 'forbidden donor structure',
    proofSurface: 'donor mapping rejection test',
  ),
  _FrameDonorMapping(
    donor: 'avoid_scene_codec_whole',
    disposition: _FrameDonorDisposition.avoided,
    targetOwner: 'forbidden donor structure',
    proofSurface: 'donor mapping rejection test',
  ),
  _FrameDonorMapping(
    donor: 'avoid_scene_store_controller_whole',
    disposition: _FrameDonorDisposition.avoided,
    targetOwner: 'forbidden donor structure',
    proofSurface: 'donor mapping rejection test',
  ),
];
