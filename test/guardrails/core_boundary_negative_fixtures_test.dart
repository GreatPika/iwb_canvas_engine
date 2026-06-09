import 'package:test/test.dart';

import '../../tool/guardrails/src/core_boundary_checks.dart';

void main() {
  test('core boundary checks reject forbidden fixture shapes', () {
    for (final fixture in _fixtures) {
      expect(
        guardrailIdsFor(path: fixture.path, content: fixture.content),
        fixture.guardrailIds,
        reason: fixture.path,
      );
    }
  });
}

Iterable<String> guardrailIdsFor({
  required String path,
  required String content,
}) {
  final violations = checkCoreBoundaryFile(path: path, content: content);

  return violations.map((violation) => violation.guardrailId);
}

final class _Fixture {
  const _Fixture({
    required this.path,
    required this.content,
    required this.guardrailIds,
  });

  final String path;
  final String content;
  final List<String> guardrailIds;
}

const _fixtures = [
  _Fixture(
    path: 'lib/src/api/bad_runtime_import.dart',
    content: "import '../runtime/runtime_root.dart';",
    guardrailIds: ['core.import_boundaries'],
  ),
  _Fixture(
    path: 'lib/src/runtime/bad_tool_import.dart',
    content: "import '../../../tool/guardrails/src/core_boundary_checks.dart';",
    guardrailIds: ['core.import_boundaries'],
  ),
  _Fixture(
    path: 'lib/src/runtime/bad_retired_package_import.dart',
    content: "import '../../legacy/iwb_canvas_engine.dart';",
    guardrailIds: ['core.no_unapproved_external_package_imports'],
  ),
  _Fixture(
    path: 'lib/src/runtime/bad_package_src_import.dart',
    content: "import 'package:other_package/src/private.dart';",
    guardrailIds: ['core.import_boundaries'],
  ),
  _Fixture(
    path: 'lib/src/api/bad_flutter_src_import.dart',
    content: "import 'package:flutter/src/widgets/framework.dart';",
    guardrailIds: ['core.import_boundaries'],
  ),
  _Fixture(
    path: 'lib/src/codec/bad_flutter_widgets_import.dart',
    content: "import 'package:flutter/widgets.dart';",
    guardrailIds: ['core.import_boundaries'],
  ),
  _Fixture(
    path: 'lib/src/codec/bad_flutter_material_import.dart',
    content: "import 'package:flutter/material.dart';",
    guardrailIds: ['core.import_boundaries'],
  ),
  _Fixture(
    path: 'lib/src/selection/bad_store_import.dart',
    content: "import '../store/document_store_kernel.dart';",
    guardrailIds: ['core.import_boundaries'],
  ),
  _Fixture(
    path: 'lib/src/frame/bad_public_projection_import.dart',
    content: "import '../api/canvas_document.dart';",
    guardrailIds: [
      'core.import_boundaries',
      'frame.committed_facts_via_frame_facts_port',
    ],
  ),
  _Fixture(
    path: 'lib/src/geometry/bad_store_import.dart',
    content: "import '../store/document_store_kernel.dart';",
    guardrailIds: ['core.import_boundaries'],
  ),
  _Fixture(
    path: 'lib/src/geometry/bad_interaction_import.dart',
    content: "import '../interaction/interaction_engine.dart';",
    guardrailIds: ['core.import_boundaries'],
  ),
  _Fixture(
    path: 'lib/src/interaction/pointer_tool_cleanup_coordinator.dart',
    content: "import '../edit/edit_kernel.dart';",
    guardrailIds: ['core.import_boundaries'],
  ),
  _Fixture(
    path: 'lib/src/interaction/pointer_tool_cleanup_coordinator.dart',
    content: "import '../resources/surface_resource_session.dart';",
    guardrailIds: ['core.import_boundaries'],
  ),
  _Fixture(
    path: 'lib/src/interaction/interaction_read_port.dart',
    content: "import '../api/canvas_document.dart';",
    guardrailIds: ['core.import_boundaries'],
  ),
  _Fixture(
    path: 'lib/src/interaction/interaction_read_port.dart',
    content: "import '../resources/surface_resource_session.dart';",
    guardrailIds: ['core.import_boundaries'],
  ),
  _Fixture(
    path: 'lib/src/interaction/bad_store_import.dart',
    content: "import '../store/document_store_kernel.dart';",
    guardrailIds: ['core.import_boundaries'],
  ),
  _Fixture(
    path: 'lib/src/interaction/bad_selection_import.dart',
    content: "import '../selection/selection_kernel.dart';",
    guardrailIds: ['core.import_boundaries'],
  ),
  _Fixture(
    path: 'lib/src/runtime/bad_part.dart',
    content: "part 'generated.dart';",
    guardrailIds: ['core.no_unapproved_part_files'],
  ),
  _Fixture(
    path: 'lib/src/runtime/bad_part_of.dart',
    content: "part of 'runtime.dart';",
    guardrailIds: ['core.no_unapproved_part_files'],
  ),
  _Fixture(
    path: 'lib/src/runtime/bad_scene_controller.dart',
    content: 'final SceneController? controller = null;',
    guardrailIds: ['core.no_unapproved_controller_shape_dependency'],
  ),
  _Fixture(
    path: 'lib/src/runtime/bad_node_patch.dart',
    content:
        'final NodeSpec? spec = null; final NodePatch? patch = null; '
        'final PatchField? field = null;',
    guardrailIds: [
      'core.no_unapproved_patch_shape_dependency',
      'core.no_unapproved_patch_shape_dependency',
      'core.no_unapproved_patch_shape_dependency',
    ],
  ),
  _Fixture(
    path: 'lib/src/runtime/bad_node_spec_declaration.dart',
    content: 'class NodeSpec {}',
    guardrailIds: ['core.no_unapproved_patch_shape_dependency'],
  ),
  _Fixture(
    path: 'lib/src/runtime/bad_patch_field_typedef.dart',
    content: 'typedef PatchField = Object;',
    guardrailIds: ['core.no_unapproved_patch_shape_dependency'],
  ),
];
