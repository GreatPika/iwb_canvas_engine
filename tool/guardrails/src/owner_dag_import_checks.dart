import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

import 'guardrail_violation.dart';
import 'repository_paths.dart';

const ownerDagGuardrailId = 'core.owner_dag_import_boundaries';

Future<List<GuardrailViolation>> checkOwnerDagImportBoundaries() async {
  final violations = ownerDagSelectionViolations();

  for (final file in dartFilesUnder('lib')) {
    final path = relativePath(file);
    final unit = parseFile(
      path: file.path,
      featureSet: FeatureSet.latestLanguageVersion(),
    ).unit;
    violations.addAll(ownerDagViolationsForFile(path: path, unit: unit));
  }

  return violations;
}

List<GuardrailViolation> checkOwnerDagFile({
  required String path,
  required String content,
}) {
  final unit = parseString(
    content: content,
    path: path,
    featureSet: FeatureSet.latestLanguageVersion(),
  ).unit;

  return ownerDagViolationsForFile(path: path, unit: unit);
}

List<GuardrailViolation> ownerDagSelectionViolations({
  List<OwnerEdge> allowedEdges = ownerDagAllowedEdges,
}) {
  return [
    for (final cycle in ownerDagCycles(allowedEdges: allowedEdges))
      GuardrailViolation(
        guardrailId: ownerDagGuardrailId,
        path: 'tool/guardrails/src/owner_dag_import_checks.dart',
        message: 'owner DAG allowed edge cycle: ${cycle.join(' -> ')}',
      ),
  ];
}

List<List<String>> ownerDagCycles({
  List<OwnerEdge> allowedEdges = ownerDagAllowedEdges,
}) {
  final graph = {for (final owner in ownerDagOwners) owner.name: <String>{}};

  for (final edge in allowedEdges) {
    if (edge.source != edge.target && !_isAcyclicFacadeWrapperExport(edge)) {
      graph[edge.source.name]?.add(edge.target.name);
    }
  }

  return _OwnerDagCycleFinder(graph).findCycles();
}

List<GuardrailViolation> ownerDagViolationsForFile({
  required String path,
  required CompilationUnit unit,
}) {
  final sourceOwner = ownerForPath(path);
  if (sourceOwner == null) {
    return const [];
  }

  final violations = <GuardrailViolation>[];
  for (final directive in unit.directives) {
    for (final reference in _directiveReferences(directive)) {
      final violation = _ownerDagViolationForReference(
        path: path,
        sourceOwner: sourceOwner,
        reference: reference,
      );
      if (violation != null) {
        violations.add(violation);
      }
    }
  }

  return violations;
}

GuardrailViolation? _ownerDagViolationForReference({
  required String path,
  required Owner sourceOwner,
  required ({String kind, String uri}) reference,
}) {
  final target = _targetPath(path, reference.uri);
  final targetOwner = target == null ? null : ownerForPath(target);
  if (target == null || targetOwner == null) {
    return null;
  }
  if (_isApiFacadeRootBarrelReference(path, target)) {
    return GuardrailViolation(
      guardrailId: ownerDagGuardrailId,
      path: path,
      message:
          'api facade files may not import the package root barrel '
          'through ${reference.kind} ${reference.uri}',
    );
  }

  final query = OwnerEdgeQuery(
    sourcePath: path,
    sourceOwner: sourceOwner,
    targetPath: target,
    targetOwner: targetOwner,
    directiveKind: reference.kind,
  );
  if (_isAllowedOwnerEdge(query)) {
    return null;
  }

  return GuardrailViolation(
    guardrailId: ownerDagGuardrailId,
    path: path,
    message:
        '${sourceOwner.name} owner may not reference '
        '${targetOwner.name} owner through ${reference.kind} '
        '${reference.uri}',
  );
}

bool _isApiFacadeRootBarrelReference(String sourcePath, String targetPath) {
  return sourcePath.startsWith('lib/src/api/') &&
      targetPath == 'lib/iwb_canvas_engine.dart';
}

Iterable<({String kind, String uri})> _directiveReferences(
  Directive directive,
) {
  switch (directive) {
    case ImportDirective(:final uri, :final configurations):
      return _literalReferences('import', uri, configurations);
    case ExportDirective(:final uri, :final configurations):
      return _literalReferences('export', uri, configurations);
    case LibraryDirective() || PartDirective() || PartOfDirective():
      return const [];
  }
}

Iterable<({String kind, String uri})> _literalReferences(
  String kind,
  StringLiteral uri,
  NodeList<Configuration> configurations,
) sync* {
  final value = uri.stringValue;
  if (value != null) {
    yield (kind: kind, uri: value);
  }

  for (final configuration in configurations) {
    final value = configuration.uri.stringValue;
    if (value != null) {
      yield (kind: kind, uri: value);
    }
  }
}

Owner? ownerForPath(String path) {
  for (final owner in ownerDagOwners) {
    if (owner.matches(path)) {
      return owner;
    }
  }

  return null;
}

String? _targetPath(String sourcePath, String uri) {
  if (uri.startsWith('package:iwb_canvas_engine/')) {
    return _normalizeRepoPath(
      'lib/${uri.substring('package:iwb_canvas_engine/'.length)}',
    );
  }
  if (uri.startsWith('dart:') || uri.startsWith('package:')) {
    return null;
  }
  if (Uri.tryParse(uri)?.hasScheme ?? false) {
    return null;
  }

  final sourceDirectory = sourcePath.substring(0, sourcePath.lastIndexOf('/'));

  return _normalizeRepoPath('$sourceDirectory/$uri');
}

String _normalizeRepoPath(String path) {
  final parts = <String>[];
  for (final segment in path.split('/')) {
    if (segment.isEmpty || segment == '.') {
      continue;
    }
    if (segment == '..') {
      if (parts.isNotEmpty) {
        parts.removeLast();
      }
      continue;
    }
    parts.add(segment);
  }

  return parts.join('/');
}

bool _isAllowedOwnerEdge(OwnerEdgeQuery query) {
  if (query.sourceOwner == query.targetOwner) {
    return true;
  }

  return ownerDagAllowedEdges.any((edge) => edge.allows(query));
}

final class Owner {
  const Owner({required this.name, required this.prefixes});

  final String name;
  final List<String> prefixes;

  bool matches(String path) => prefixes.any(path.startsWith);
}

final class OwnerEdge {
  const OwnerEdge({
    required this.source,
    required this.target,
    this.sourcePath,
    this.targetPath,
    this.directiveKinds = const {'import'},
  });

  final Owner source;
  final Owner target;
  final String? sourcePath;
  final String? targetPath;
  final Set<String> directiveKinds;

  bool allows(OwnerEdgeQuery query) {
    return query.sourceOwner == source &&
        query.targetOwner == target &&
        directiveKinds.contains(query.directiveKind) &&
        (sourcePath == null || sourcePath == query.sourcePath) &&
        (targetPath == null || targetPath == query.targetPath);
  }
}

bool _isAcyclicFacadeWrapperExport(OwnerEdge edge) {
  return edge.source == apiOwner &&
      edge.target == surfaceOwner &&
      edge.sourcePath == 'lib/src/api/canvas_surface.dart' &&
      (edge.targetPath == 'lib/src/surface/canvas_surface_widget.dart' ||
          edge.targetPath == 'lib/src/surface/text_editing_overlay.dart') &&
      edge.directiveKinds.length == 1 &&
      edge.directiveKinds.contains('export');
}

final class OwnerEdgeQuery {
  const OwnerEdgeQuery({
    required this.sourcePath,
    required this.sourceOwner,
    required this.targetPath,
    required this.targetOwner,
    required this.directiveKind,
  });

  final String sourcePath;
  final Owner sourceOwner;
  final String targetPath;
  final Owner targetOwner;
  final String directiveKind;
}

const apiOwner = Owner(
  name: 'api',
  prefixes: ['lib/src/api/', 'lib/iwb_canvas_engine.dart'],
);
const contractsPublicOwner = Owner(
  name: 'contracts/public',
  prefixes: ['lib/src/contracts/public/'],
);
const contractsInternalOwner = Owner(
  name: 'contracts/internal',
  prefixes: ['lib/src/contracts/internal/'],
);
const runtimeOwner = Owner(name: 'runtime', prefixes: ['lib/src/runtime/']);
const editOwner = Owner(name: 'edit', prefixes: ['lib/src/edit/']);
const storeOwner = Owner(name: 'store', prefixes: ['lib/src/store/']);
const selectionOwner = Owner(
  name: 'selection',
  prefixes: ['lib/src/selection/'],
);
const codecOwner = Owner(name: 'codec', prefixes: ['lib/src/codec/']);
const diagnosticsOwner = Owner(
  name: 'diagnostics',
  prefixes: ['lib/src/diagnostics/'],
);
const resourcesOwner = Owner(
  name: 'resources',
  prefixes: ['lib/src/resources/'],
);
const frameOwner = Owner(name: 'frame', prefixes: ['lib/src/frame/']);
const interactionOwner = Owner(
  name: 'interaction',
  prefixes: ['lib/src/interaction/'],
);
const spatialOwner = Owner(name: 'spatial', prefixes: ['lib/src/geometry/']);
const toolsOwner = Owner(name: 'tools', prefixes: ['lib/src/tools/']);
const surfaceOwner = Owner(name: 'surface', prefixes: ['lib/src/surface/']);

const ownerDagOwners = [
  contractsPublicOwner,
  contractsInternalOwner,
  apiOwner,
  runtimeOwner,
  editOwner,
  storeOwner,
  selectionOwner,
  codecOwner,
  diagnosticsOwner,
  resourcesOwner,
  frameOwner,
  interactionOwner,
  spatialOwner,
  toolsOwner,
  surfaceOwner,
];

const ownerDagAllowedEdges = [
  OwnerEdge(source: contractsInternalOwner, target: contractsPublicOwner),
  OwnerEdge(
    source: apiOwner,
    target: contractsPublicOwner,
    directiveKinds: {'import', 'export'},
  ),
  OwnerEdge(
    source: apiOwner,
    target: runtimeOwner,
    sourcePath: 'lib/src/api/canvas_runtime.dart',
    targetPath: 'lib/src/runtime/runtime_root.dart',
  ),
  OwnerEdge(
    source: apiOwner,
    target: runtimeOwner,
    sourcePath: 'lib/src/api/canvas_runtime_frame_bridge.dart',
    targetPath: 'lib/src/runtime/runtime_root.dart',
  ),
  OwnerEdge(
    source: apiOwner,
    target: runtimeOwner,
    sourcePath: 'lib/src/api/canvas_runtime_surface_bridge.dart',
    targetPath: 'lib/src/runtime/runtime_root.dart',
  ),
  OwnerEdge(
    source: apiOwner,
    target: contractsInternalOwner,
    sourcePath: 'lib/src/api/canvas_runtime_surface_bridge.dart',
    targetPath: 'lib/src/contracts/internal/resolver_mutation_guard.dart',
  ),
  OwnerEdge(
    source: apiOwner,
    target: contractsInternalOwner,
    sourcePath: 'lib/src/api/canvas_runtime_surface_bridge.dart',
    targetPath:
        'lib/src/contracts/internal/surface_resource_session_lifecycle.dart',
  ),
  OwnerEdge(
    source: apiOwner,
    target: frameOwner,
    sourcePath: 'lib/src/api/canvas_runtime_surface_bridge.dart',
    targetPath: 'lib/src/frame/frame_engine.dart',
  ),
  OwnerEdge(
    source: apiOwner,
    target: frameOwner,
    sourcePath: 'lib/src/api/canvas_runtime_surface_bridge.dart',
    targetPath: 'lib/src/frame/frame_paint_output.dart',
  ),
  OwnerEdge(
    source: apiOwner,
    target: surfaceOwner,
    sourcePath: 'lib/src/api/canvas_surface.dart',
    targetPath: 'lib/src/surface/canvas_surface_widget.dart',
    directiveKinds: {'export'},
  ),
  OwnerEdge(
    source: apiOwner,
    target: surfaceOwner,
    sourcePath: 'lib/src/api/canvas_surface.dart',
    targetPath: 'lib/src/surface/text_editing_overlay.dart',
    directiveKinds: {'export'},
  ),
  OwnerEdge(
    source: apiOwner,
    target: codecOwner,
    sourcePath: 'lib/src/api/canvas_codec.dart',
    targetPath: 'lib/src/codec/schema_v1_encoder.dart',
  ),
  OwnerEdge(
    source: apiOwner,
    target: codecOwner,
    sourcePath: 'lib/src/api/canvas_codec.dart',
    targetPath: 'lib/src/codec/schema_v1_decoder.dart',
  ),
  OwnerEdge(source: runtimeOwner, target: contractsPublicOwner),
  OwnerEdge(source: runtimeOwner, target: contractsInternalOwner),
  OwnerEdge(
    source: runtimeOwner,
    target: diagnosticsOwner,
    sourcePath: 'lib/src/runtime/runtime_root.dart',
    targetPath: 'lib/src/diagnostics/diagnostics_hub.dart',
  ),
  OwnerEdge(
    source: runtimeOwner,
    target: diagnosticsOwner,
    sourcePath: 'lib/src/runtime/runtime_interaction_diagnostics_adapter.dart',
    targetPath: 'lib/src/diagnostics/diagnostic_code.dart',
  ),
  OwnerEdge(
    source: runtimeOwner,
    target: diagnosticsOwner,
    sourcePath: 'lib/src/runtime/runtime_interaction_diagnostics_adapter.dart',
    targetPath: 'lib/src/diagnostics/diagnostics_hub.dart',
  ),
  OwnerEdge(source: runtimeOwner, target: editOwner),
  OwnerEdge(
    source: runtimeOwner,
    target: spatialOwner,
    sourcePath: 'lib/src/runtime/runtime_root.dart',
    targetPath: 'lib/src/geometry/geometry_policy.dart',
  ),
  OwnerEdge(
    source: runtimeOwner,
    target: spatialOwner,
    sourcePath: 'lib/src/runtime/runtime_root.dart',
    targetPath: 'lib/src/geometry/spatial_kernel.dart',
  ),
  OwnerEdge(
    source: runtimeOwner,
    target: spatialOwner,
    sourcePath: 'lib/src/runtime/runtime_command_facts_adapter.dart',
    targetPath: 'lib/src/geometry/geometry_policy.dart',
  ),
  OwnerEdge(
    source: runtimeOwner,
    target: spatialOwner,
    sourcePath: 'lib/src/runtime/runtime_interaction_move_read_models.dart',
    targetPath: 'lib/src/geometry/geometry_policy.dart',
  ),
  OwnerEdge(
    source: runtimeOwner,
    target: spatialOwner,
    sourcePath: 'lib/src/runtime/runtime_interaction_read_adapter.dart',
    targetPath: 'lib/src/geometry/hit_test_policy.dart',
  ),
  OwnerEdge(
    source: runtimeOwner,
    target: spatialOwner,
    sourcePath: 'lib/src/runtime/runtime_interaction_read_adapter.dart',
    targetPath: 'lib/src/geometry/spatial_kernel.dart',
  ),
  OwnerEdge(
    source: runtimeOwner,
    target: spatialOwner,
    sourcePath: 'lib/src/runtime/runtime_interaction_read_adapter.dart',
    targetPath: 'lib/src/geometry/spatial_query_policy.dart',
  ),
  OwnerEdge(
    source: runtimeOwner,
    target: spatialOwner,
    sourcePath: 'lib/src/runtime/runtime_interaction_read_adapter.dart',
    targetPath: 'lib/src/geometry/spatial_query_result.dart',
  ),
  OwnerEdge(
    source: runtimeOwner,
    target: spatialOwner,
    sourcePath: 'lib/src/runtime/runtime_interaction_read_mapping.dart',
    targetPath: 'lib/src/geometry/spatial_query_result.dart',
  ),
  OwnerEdge(
    source: runtimeOwner,
    target: resourcesOwner,
    sourcePath: 'lib/src/runtime/runtime_root.dart',
    targetPath: 'lib/src/resources/resource_kernel.dart',
  ),
  OwnerEdge(
    source: runtimeOwner,
    target: frameOwner,
    sourcePath: 'lib/src/runtime/runtime_root.dart',
    targetPath: 'lib/src/frame/frame_text_layout_measurer.dart',
  ),
  OwnerEdge(
    source: runtimeOwner,
    target: frameOwner,
    sourcePath: 'lib/src/runtime/runtime_root.dart',
    targetPath: 'lib/src/frame/captured_frame.dart',
  ),
  OwnerEdge(
    source: runtimeOwner,
    target: frameOwner,
    sourcePath: 'lib/src/runtime/runtime_root.dart',
    targetPath: 'lib/src/frame/frame_engine.dart',
  ),
  OwnerEdge(
    source: runtimeOwner,
    target: frameOwner,
    sourcePath: 'lib/src/runtime/runtime_root.dart',
    targetPath: 'lib/src/frame/frame_paint_output.dart',
  ),
  OwnerEdge(source: runtimeOwner, target: selectionOwner),
  OwnerEdge(source: runtimeOwner, target: storeOwner),
  OwnerEdge(
    source: runtimeOwner,
    target: interactionOwner,
    sourcePath: 'lib/src/runtime/runtime_root.dart',
    targetPath: 'lib/src/interaction/interaction_engine.dart',
  ),
  OwnerEdge(
    source: runtimeOwner,
    target: interactionOwner,
    sourcePath: 'lib/src/runtime/runtime_root.dart',
    targetPath: 'lib/src/interaction/interaction_pointer_context.dart',
  ),
  OwnerEdge(
    source: runtimeOwner,
    target: interactionOwner,
    sourcePath: 'lib/src/runtime/runtime_root.dart',
    targetPath: 'lib/src/interaction/interaction_read_port.dart',
  ),
  OwnerEdge(
    source: runtimeOwner,
    target: interactionOwner,
    sourcePath: 'lib/src/runtime/runtime_root.dart',
    targetPath: 'lib/src/interaction/interaction_request_registry.dart',
  ),
  OwnerEdge(
    source: runtimeOwner,
    target: interactionOwner,
    sourcePath: 'lib/src/runtime/runtime_root.dart',
    targetPath: 'lib/src/interaction/interaction_runtime_intents.dart',
  ),
  OwnerEdge(
    source: runtimeOwner,
    target: interactionOwner,
    sourcePath: 'lib/src/runtime/runtime_root.dart',
    targetPath: 'lib/src/interaction/pointer_cleanup_protocol.dart',
  ),
  OwnerEdge(
    source: runtimeOwner,
    target: interactionOwner,
    sourcePath: 'lib/src/runtime/runtime_root.dart',
    targetPath: 'lib/src/interaction/text_edit_guard_decision.dart',
  ),
  OwnerEdge(
    source: runtimeOwner,
    target: interactionOwner,
    sourcePath: 'lib/src/runtime/runtime_interaction_read_adapter.dart',
    targetPath: 'lib/src/interaction/interaction_read_port.dart',
  ),
  OwnerEdge(
    source: runtimeOwner,
    target: interactionOwner,
    sourcePath: 'lib/src/runtime/runtime_interaction_read_mapping.dart',
    targetPath: 'lib/src/interaction/interaction_read_port.dart',
  ),
  OwnerEdge(
    source: runtimeOwner,
    target: interactionOwner,
    sourcePath: 'lib/src/runtime/runtime_interaction_diagnostics_adapter.dart',
    targetPath: 'lib/src/interaction/interaction_diagnostics_sink.dart',
  ),
  OwnerEdge(source: editOwner, target: contractsPublicOwner),
  OwnerEdge(source: editOwner, target: contractsInternalOwner),
  OwnerEdge(source: editOwner, target: storeOwner),
  OwnerEdge(source: editOwner, target: codecOwner),
  OwnerEdge(source: editOwner, target: diagnosticsOwner),
  OwnerEdge(source: storeOwner, target: contractsPublicOwner),
  OwnerEdge(source: selectionOwner, target: contractsPublicOwner),
  OwnerEdge(source: selectionOwner, target: contractsInternalOwner),
  OwnerEdge(source: codecOwner, target: contractsPublicOwner),
  OwnerEdge(source: codecOwner, target: diagnosticsOwner),
  OwnerEdge(source: diagnosticsOwner, target: contractsPublicOwner),
  OwnerEdge(source: resourcesOwner, target: contractsPublicOwner),
  OwnerEdge(source: resourcesOwner, target: contractsInternalOwner),
  OwnerEdge(source: frameOwner, target: contractsPublicOwner),
  OwnerEdge(source: frameOwner, target: contractsInternalOwner),
  OwnerEdge(
    source: frameOwner,
    target: spatialOwner,
    sourcePath: 'lib/src/frame/captured_frame.dart',
    targetPath: 'lib/src/geometry/spatial_query_result.dart',
  ),
  OwnerEdge(
    source: frameOwner,
    target: spatialOwner,
    sourcePath: 'lib/src/frame/frame_capture_service.dart',
    targetPath: 'lib/src/geometry/spatial_query_policy.dart',
  ),
  OwnerEdge(
    source: frameOwner,
    target: spatialOwner,
    sourcePath: 'lib/src/frame/frame_capture_service.dart',
    targetPath: 'lib/src/geometry/spatial_query_result.dart',
  ),
  OwnerEdge(
    source: frameOwner,
    target: spatialOwner,
    sourcePath: 'lib/src/frame/frame_engine.dart',
    targetPath: 'lib/src/geometry/spatial_kernel.dart',
  ),
  OwnerEdge(
    source: frameOwner,
    target: spatialOwner,
    sourcePath: 'lib/src/frame/frame_spatial_paint_admission.dart',
    targetPath: 'lib/src/geometry/spatial_query_result.dart',
  ),
  OwnerEdge(
    source: frameOwner,
    target: spatialOwner,
    sourcePath: 'lib/src/frame/ordinary_paint_planner.dart',
    targetPath: 'lib/src/geometry/geometry_policy.dart',
  ),
  OwnerEdge(
    source: frameOwner,
    target: spatialOwner,
    sourcePath: 'lib/src/frame/ordinary_paint_planner.dart',
    targetPath: 'lib/src/geometry/spatial_query_result.dart',
  ),
  OwnerEdge(
    source: frameOwner,
    target: spatialOwner,
    sourcePath: 'lib/src/frame/render_element_record.dart',
    targetPath: 'lib/src/geometry/geometry_policy.dart',
  ),
  OwnerEdge(
    source: frameOwner,
    target: spatialOwner,
    sourcePath: 'lib/src/frame/selected_move_supplement_planner.dart',
    targetPath: 'lib/src/geometry/spatial_query_policy.dart',
  ),
  OwnerEdge(
    source: frameOwner,
    target: spatialOwner,
    sourcePath: 'lib/src/frame/selected_move_supplement_planner.dart',
    targetPath: 'lib/src/geometry/spatial_query_result.dart',
  ),
  OwnerEdge(
    source: frameOwner,
    target: resourcesOwner,
    sourcePath: 'lib/src/frame/frame_paint_output.dart',
    targetPath: 'lib/src/resources/resource_resolver_adapter.dart',
  ),
  OwnerEdge(
    source: frameOwner,
    target: resourcesOwner,
    sourcePath: 'lib/src/frame/main_frame_asset_images.dart',
    targetPath: 'lib/src/resources/resource_resolver_adapter.dart',
  ),
  OwnerEdge(
    source: frameOwner,
    target: resourcesOwner,
    sourcePath: 'lib/src/frame/paint_asset_binding_service.dart',
    targetPath: 'lib/src/resources/resource_resolver_adapter.dart',
  ),
  OwnerEdge(
    source: frameOwner,
    target: resourcesOwner,
    sourcePath: 'lib/src/frame/paint_asset_binding_service.dart',
    targetPath: 'lib/src/resources/surface_resource_session.dart',
  ),
  OwnerEdge(source: interactionOwner, target: contractsPublicOwner),
  OwnerEdge(source: interactionOwner, target: contractsInternalOwner),
  OwnerEdge(source: spatialOwner, target: contractsPublicOwner),
  OwnerEdge(source: spatialOwner, target: contractsInternalOwner),
  OwnerEdge(source: toolsOwner, target: contractsPublicOwner),
  OwnerEdge(source: toolsOwner, target: contractsInternalOwner),
  OwnerEdge(source: surfaceOwner, target: contractsPublicOwner),
  OwnerEdge(source: surfaceOwner, target: contractsInternalOwner),
  OwnerEdge(
    source: surfaceOwner,
    target: apiOwner,
    sourcePath: 'lib/src/surface/canvas_surface_widget.dart',
    targetPath: 'lib/src/api/canvas_runtime.dart',
  ),
  OwnerEdge(
    source: surfaceOwner,
    target: apiOwner,
    sourcePath: 'lib/src/surface/canvas_surface_widget.dart',
    targetPath: 'lib/src/api/canvas_runtime_surface_bridge.dart',
  ),
  OwnerEdge(
    source: surfaceOwner,
    target: apiOwner,
    sourcePath: 'lib/src/surface/text_editing_overlay.dart',
    targetPath: 'lib/src/api/canvas_runtime.dart',
  ),
  OwnerEdge(
    source: surfaceOwner,
    target: frameOwner,
    sourcePath: 'lib/src/surface/image_bridge.dart',
    targetPath: 'lib/src/frame/frame_engine.dart',
  ),
  OwnerEdge(
    source: surfaceOwner,
    target: frameOwner,
    sourcePath: 'lib/src/surface/image_bridge.dart',
    targetPath: 'lib/src/frame/paint_asset_binding_service.dart',
  ),
  OwnerEdge(
    source: surfaceOwner,
    target: resourcesOwner,
    sourcePath: 'lib/src/surface/image_bridge.dart',
    targetPath: 'lib/src/resources/surface_resource_session.dart',
  ),
  OwnerEdge(
    source: surfaceOwner,
    target: frameOwner,
    sourcePath: 'lib/src/surface/main_painter.dart',
    targetPath: 'lib/src/frame/frame_paint_output.dart',
  ),
  OwnerEdge(
    source: surfaceOwner,
    target: frameOwner,
    sourcePath: 'lib/src/surface/main_painter.dart',
    targetPath: 'lib/src/frame/main_frame_asset_images.dart',
  ),
  OwnerEdge(
    source: surfaceOwner,
    target: frameOwner,
    sourcePath: 'lib/src/surface/main_painter.dart',
    targetPath: 'lib/src/frame/main_frame_record_painter.dart',
  ),
  OwnerEdge(
    source: surfaceOwner,
    target: frameOwner,
    sourcePath: 'lib/src/surface/main_painter.dart',
    targetPath: 'lib/src/frame/render_element_record.dart',
  ),
  OwnerEdge(
    source: surfaceOwner,
    target: frameOwner,
    sourcePath: 'lib/src/surface/main_painter.dart',
    targetPath: 'lib/src/frame/selection_decoration_planner.dart',
  ),
  OwnerEdge(
    source: surfaceOwner,
    target: frameOwner,
    sourcePath: 'lib/src/surface/overlay_painter.dart',
    targetPath: 'lib/src/frame/frame_drawable_policy.dart',
  ),
  OwnerEdge(
    source: surfaceOwner,
    target: frameOwner,
    sourcePath: 'lib/src/surface/overlay_painter.dart',
    targetPath: 'lib/src/frame/frame_paint_output.dart',
  ),
  OwnerEdge(
    source: surfaceOwner,
    target: frameOwner,
    sourcePath: 'lib/src/surface/overlay_painter.dart',
    targetPath: 'lib/src/frame/overlay_preview_planner.dart',
  ),
  OwnerEdge(
    source: surfaceOwner,
    target: resourcesOwner,
    sourcePath: 'lib/src/surface/canvas_surface_widget.dart',
    targetPath: 'lib/src/resources/surface_resource_session.dart',
  ),
];

final class _OwnerDagCycleFinder {
  _OwnerDagCycleFinder(this._graph);

  final Map<String, Set<String>> _graph;
  final Set<String> _visiting = {};
  final Set<String> _visited = {};
  final List<String> _path = [];
  final List<List<String>> _cycles = [];

  List<List<String>> findCycles() {
    final nodes = _graph.keys.toList()..sort();
    for (final node in nodes) {
      if (!_visited.contains(node)) {
        _visit(node);
      }
    }

    return _cycles;
  }

  void _visit(String node) {
    _visiting.add(node);
    _path.add(node);

    final edges = (_graph[node] ?? const <String>{}).toList()..sort();
    for (final target in edges) {
      if (_visiting.contains(target)) {
        _cycles.add(_cycleEndingAt(target));
      } else if (!_visited.contains(target)) {
        _visit(target);
      }
    }

    _path.removeLast();
    _visiting.remove(node);
    _visited.add(node);
  }

  List<String> _cycleEndingAt(String target) {
    final start = _path.indexOf(target);

    return [..._path.skip(start), target];
  }
}
