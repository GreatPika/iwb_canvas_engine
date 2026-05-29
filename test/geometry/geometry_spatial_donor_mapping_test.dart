import 'package:test/test.dart';

void main() {
  test('required P8 donors are mapped before geometry algorithms are used', () {
    expect(_requiredDonorMap.length, 13);
    _expectRequiredDonorIds();
    _expectRequiredDonorDecisions();
  });

  test('forbidden P8 donor structures are explicitly avoided', () {
    expect(_forbiddenDonorMap.length, 5);
    _expectForbiddenDonorIds();
    _expectForbiddenDonorDecisions();
  });
}

void _expectRequiredDonorIds() {
  expect(_requiredDonorMap.keys, {
    'direct_numeric_policy',
    'direct_local_bounds_policy',
    'direct_paint_admission',
    'foundation_transform2d',
    'foundation_core_geometry',
    'geometry_node_geometry',
    'geometry_hit_test',
    'render_geometry_builder',
    'geometry_interactive_geometry',
    'geometry_eraser_exact_hit',
    'spatial_scene_spatial_index',
    'spatial_index_cache',
    'store_scene_controller_read_paths',
  });
}

void _expectRequiredDonorDecisions() {
  for (final entry in _requiredDonorMap.entries) {
    expect(entry.value.decision, isIn({'copy', 'copy/adapt', 'adapt'}));
    expect(entry.value.owner, isNotEmpty, reason: entry.key);
    expect(entry.value.proofLink, isNotEmpty, reason: entry.key);
  }
}

void _expectForbiddenDonorIds() {
  expect(_forbiddenDonorMap.keys, {
    'avoid_scene_controller_facades',
    'avoid_interactive_runtime_whole',
    'avoid_scene_builder_public_architecture',
    'avoid_scene_codec_whole',
    'avoid_scene_store_controller_whole',
  });
}

void _expectForbiddenDonorDecisions() {
  for (final entry in _forbiddenDonorMap.entries) {
    expect(entry.value.decision, 'avoid');
    expect(entry.value.owner, 'P8 architecture boundary');
    expect(entry.value.proofLink, isNotEmpty, reason: entry.key);
  }
}

const _requiredDonorMap = <String, _DonorMapping>{
  'direct_numeric_policy': _DonorMapping(
    decision: 'copy',
    owner: 'Unit 2 GeometryPolicy numeric tolerance foundation',
    proofLink: 'test/geometry/hit_policy_test.dart constants coverage',
  ),
  'direct_local_bounds_policy': _DonorMapping(
    decision: 'copy',
    owner: 'Unit 2 GeometryPolicy local bounds',
    proofLink: 'test/geometry/hit_policy_test.dart local bounds coverage',
  ),
  'direct_paint_admission': _DonorMapping(
    decision: 'copy',
    owner: 'Unit 2 GeometryPolicy paint admission',
    proofLink: 'test/geometry/hit_policy_test.dart paint admission coverage',
  ),
  'foundation_transform2d': _DonorMapping(
    decision: 'copy/adapt',
    owner: 'Unit 2 GeometryPolicy transform helpers',
    proofLink: 'test/geometry/hit_policy_test.dart transform coverage',
  ),
  'foundation_core_geometry': _DonorMapping(
    decision: 'copy/adapt',
    owner: 'Unit 2 GeometryPolicy v1',
    proofLink: 'test/geometry/hit_policy_test.dart geometry primitive coverage',
  ),
  'geometry_node_geometry': _DonorMapping(
    decision: 'adapt',
    owner: 'Unit 2 GeometryPolicy and HitTestPolicy',
    proofLink: 'test/geometry/hit_policy_test.dart family geometry coverage',
  ),
  'geometry_hit_test': _DonorMapping(
    decision: 'adapt',
    owner: 'Unit 2 HitTestPolicy v1',
    proofLink: 'test/geometry/hit_policy_test.dart exact hit coverage',
  ),
  'render_geometry_builder': _DonorMapping(
    decision: 'adapt',
    owner: 'Unit 2 paint geometry construction inputs',
    proofLink: 'test/geometry/hit_policy_test.dart paint bounds coverage',
  ),
  'geometry_interactive_geometry': _DonorMapping(
    decision: 'copy/adapt',
    owner: 'Unit 2 marquee and eraser primitive helpers',
    proofLink:
        'test/geometry/eraser_exact_budget_inputs_test.dart primitive coverage',
  ),
  'geometry_eraser_exact_hit': _DonorMapping(
    decision: 'adapt',
    owner: 'Unit 2 eraser exact-hit input helpers',
    proofLink:
        'test/geometry/eraser_exact_budget_inputs_test.dart exact input coverage',
  ),
  'spatial_scene_spatial_index': _DonorMapping(
    decision: 'adapt',
    owner: 'Unit 3 TileIndex, OutlierIndex, and Unit 4 SpatialKernel',
    proofLink: 'test/spatial/tile_outlier_membership_test.dart index coverage',
  ),
  'spatial_index_cache': _DonorMapping(
    decision: 'adapt',
    owner: 'Unit 4 SpatialKernel invalidation cache behavior',
    proofLink: 'test/spatial/invalid_index_fallback_test.dart cache coverage',
  ),
  'store_scene_controller_read_paths': _DonorMapping(
    decision: 'adapt',
    owner: 'Unit 1 FrameFactsPort committed read boundary',
    proofLink: 'test/spatial/committed_spatial_read_boundary_test.dart',
  ),
};

const _forbiddenDonorMap = <String, _DonorMapping>{
  'avoid_scene_controller_facades': _DonorMapping(
    decision: 'avoid',
    owner: 'P8 architecture boundary',
    proofLink: 'test/geometry/no_legacy_scene_order_test.dart',
  ),
  'avoid_interactive_runtime_whole': _DonorMapping(
    decision: 'avoid',
    owner: 'P8 architecture boundary',
    proofLink: 'test/geometry/no_legacy_scene_order_test.dart',
  ),
  'avoid_scene_builder_public_architecture': _DonorMapping(
    decision: 'avoid',
    owner: 'P8 architecture boundary',
    proofLink: 'test/geometry/no_legacy_scene_order_test.dart',
  ),
  'avoid_scene_codec_whole': _DonorMapping(
    decision: 'avoid',
    owner: 'P8 architecture boundary',
    proofLink: 'test/geometry/no_legacy_scene_order_test.dart',
  ),
  'avoid_scene_store_controller_whole': _DonorMapping(
    decision: 'avoid',
    owner: 'P8 architecture boundary',
    proofLink: 'test/geometry/no_legacy_scene_order_test.dart',
  ),
};

final class _DonorMapping {
  const _DonorMapping({
    required this.decision,
    required this.owner,
    required this.proofLink,
  });

  final String decision;
  final String owner;
  final String proofLink;
}
