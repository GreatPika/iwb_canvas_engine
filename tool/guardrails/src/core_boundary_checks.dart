// This guardrail intentionally keeps one analyzer-backed source scanner in one
// file so boundary rules, AST directives, and resolved retired-shape checks can
// be audited together instead of through metric-only proxy modules.
// ignore_for_file: type=metrics

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import 'guardrail_violation.dart';
import 'repository_paths.dart';

Future<List<GuardrailViolation>> checkCoreBoundaries() async {
  final violations = <GuardrailViolation>[];
  final collection = AnalysisContextCollection(
    includedPaths: ['$repositoryRoot/lib'],
    sdkPath: analysisDartSdkPath,
  );

  try {
    for (final file in dartFilesUnder('lib')) {
      final path = relativePath(file);
      final context = collection.contextFor(file.path);
      final result = await context.currentSession.getResolvedUnit(file.path);
      if (result is! ResolvedUnitResult) {
        violations.add(
          GuardrailViolation(
            guardrailId: 'core.import_boundaries',
            path: path,
            message: 'could not resolve production source file',
          ),
        );
        continue;
      }

      violations
        ..addAll(_checkDirectives(path, result.unit))
        ..addAll(_checkRetiredShapeReferences(path, result.unit))
        ..addAll(_checkResourceResolverTypeReferences(path, result.unit));
    }
  } finally {
    await collection.dispose();
  }

  violations.addAll(await checkPointerCleanupCoordinatorCallerOrigins());

  return violations;
}

Future<List<GuardrailViolation>>
checkPointerCleanupCoordinatorCallerOrigins() async {
  final violations = <GuardrailViolation>[];
  for (final file in dartFilesUnder('lib')) {
    final path = relativePath(file);
    if (path == _pointerCleanupCoordinatorPath ||
        path == _interactionEnginePath) {
      continue;
    }
    violations.addAll(
      checkPointerCleanupCoordinatorCallerFile(
        path: path,
        content: file.readAsStringSync(),
      ),
    );
  }

  return violations;
}

Future<List<GuardrailViolation>> checkSurfacePointerReservedBoundary() async {
  final violations = <GuardrailViolation>[];
  const adapterPath = 'lib/src/surface/pointer_adapter.dart';
  final adapterFile = File(adapterPath);
  if (!adapterFile.existsSync()) {
    return const [
      GuardrailViolation(
        guardrailId: 'surface.pointer_samples_normalized_before_runtime',
        path: adapterPath,
        message: 'CanvasSurfacePointerAdapter must own surface pointer routing',
      ),
    ];
  }
  final adapterContent = adapterFile.readAsStringSync();
  for (final requiredPattern in [
    'final class CanvasSurfacePointerAdapter',
    'Listener(',
    'CanvasPointerSample(',
    'localPosition',
    'isFinite',
  ]) {
    if (!adapterContent.contains(requiredPattern)) {
      violations.add(
        GuardrailViolation(
          guardrailId: 'surface.pointer_samples_normalized_before_runtime',
          path: adapterPath,
          message: 'pointer adapter is missing required $requiredPattern proof',
        ),
      );
    }
  }
  for (final forbiddenPattern in [
    'GestureDetector',
    'MouseRegion',
    'GestureRecognizer',
    'PointerSampleNormalizer',
    'viewCameraOffset',
    'worldPosition',
  ]) {
    if (adapterContent.contains(forbiddenPattern)) {
      violations.add(
        GuardrailViolation(
          guardrailId: 'surface.pointer_samples_normalized_before_runtime',
          path: adapterPath,
          message: 'pointer adapter must not contain $forbiddenPattern',
        ),
      );
    }
  }
  const widgetPath = 'lib/src/surface/canvas_surface_widget.dart';
  final widgetContent = File(widgetPath).readAsStringSync();
  if (!widgetContent.contains('CanvasSurfacePointerAdapter(') ||
      !widgetContent.contains('port.handlePointer(_surfaceToken, sample)')) {
    violations.add(
      const GuardrailViolation(
        guardrailId: 'surface.pointer_samples_normalized_before_runtime',
        path: widgetPath,
        message:
            'CanvasSurface must route pointer samples through active token',
      ),
    );
  }
  return violations;
}

Future<List<GuardrailViolation>>
checkSurfaceInteractiveDisabledReservedBoundary() async {
  final violations = <GuardrailViolation>[];
  const bridgePath = 'lib/src/api/canvas_runtime_surface_bridge.dart';
  final bridgeFile = File(bridgePath);
  if (!bridgeFile.existsSync()) {
    return const [
      GuardrailViolation(
        guardrailId: 'surface.interactive_false_pending_line_preserved',
        path: bridgePath,
        message: 'runtime-surface bridge must exist before surface cleanup',
      ),
    ];
  }
  violations.addAll(
    checkSurfaceInteractiveDisabledReservedBoundaryFile(
      path: bridgePath,
      content: bridgeFile.readAsStringSync(),
    ),
  );

  const widgetPath = 'lib/src/surface/canvas_surface_widget.dart';
  final widgetContent = File(widgetPath).readAsStringSync();
  for (final requiredPattern in [
    'oldWidget.interactive',
    '_activePort?.handleSurfaceInteractiveDisabled(_surfaceToken)',
    'widget.interactive',
    '_detachSurface();',
  ]) {
    if (!widgetContent.contains(requiredPattern)) {
      violations.add(
        const GuardrailViolation(
          guardrailId: 'surface.interactive_false_pending_line_preserved',
          path: widgetPath,
          message:
              'CanvasSurface must run interactive-disabled cleanup before detach/dispose',
        ),
      );
    }
  }

  return violations;
}

List<GuardrailViolation> checkSurfaceInteractiveDisabledReservedBoundaryFile({
  required String path,
  required String content,
}) {
  final violations = <GuardrailViolation>[];
  for (final requiredPattern in [
    'void handleSurfaceInteractiveDisabled(Object token)',
    'if (!_root.isActiveSurface(token))',
    '_root.handleSurfaceInteractiveDisabled();',
  ]) {
    if (!content.contains(requiredPattern)) {
      violations.add(
        GuardrailViolation(
          guardrailId: 'surface.interactive_false_pending_line_preserved',
          path: path,
          message:
              'interactive-disabled cleanup must be token-checked before runtime delegation',
        ),
      );
    }
  }

  return violations;
}

List<GuardrailViolation> checkPointerCleanupCoordinatorCallerFile({
  required String path,
  required String content,
}) {
  if (path == _pointerCleanupCoordinatorPath ||
      path == _interactionEnginePath) {
    return const [];
  }
  if (!content.contains('PointerToolCleanupCoordinator')) {
    return const [];
  }

  return [
    GuardrailViolation(
      guardrailId: 'interaction.pointer_cleanup_coordinator_only',
      path: path,
      message:
          'PointerToolCleanupCoordinator may be constructed or called only by InteractionEngine',
    ),
  ];
}

Future<List<GuardrailViolation>> checkCodecNoRuntimeImports() async {
  final violations = <GuardrailViolation>[];
  for (final file in dartFilesUnder('lib/src/codec')) {
    final path = relativePath(file);
    final unit = _parseFile(file).unit;
    for (final directive in unit.directives.whereType<ImportDirective>()) {
      final uri = directive.uri.stringValue;
      if (uri == null) {
        continue;
      }
      final target = _targetPath(path, uri);
      if (target == null || !_isCodecRuntimeMutationTarget(target)) {
        continue;
      }
      violations.add(
        GuardrailViolation(
          guardrailId: 'codec.no_runtime_side_effects',
          path: path,
          message: 'codec code may not import runtime mutation owner $target',
        ),
      );
    }
  }

  return violations;
}

List<GuardrailViolation> checkCoreBoundaryFile({
  required String path,
  required String content,
}) {
  final unit = parseString(
    content: content,
    path: path,
    featureSet: FeatureSet.latestLanguageVersion(),
  ).unit;

  return [
    ..._checkDirectives(path, unit),
    ..._checkRetiredShapeReferences(path, unit),
    ..._checkResourceResolverTypeReferences(
      path,
      unit,
      requireResolvedElement: false,
    ),
    ...checkPointerCleanupCoordinatorCallerFile(path: path, content: content),
  ];
}

List<GuardrailViolation> checkSingleRuntimeRoot() {
  final declarations = <String>[];

  for (final file in dartFilesUnder('lib')) {
    final path = relativePath(file);
    final unit = _parseFile(file).unit;
    declarations.addAll(_runtimeRootDeclarations(path, unit));
  }

  return checkRuntimeRootDeclarations(declarations);
}

List<GuardrailViolation> checkRuntimeRootDeclarations(
  List<String> declarations,
) {
  if (declarations.length == 1) {
    final path = declarations.single;
    if (path == _runtimeRootPath) {
      return const [];
    }
    return [
      GuardrailViolation(
        guardrailId: 'core.single_runtime_root',
        path: path,
        message: 'RuntimeRoot must be owned by $_runtimeRootPath',
      ),
    ];
  }

  return [
    GuardrailViolation(
      guardrailId: 'core.single_runtime_root',
      path: 'lib',
      message:
          'expected exactly one production RuntimeRoot, found '
          '${declarations.length}: ${declarations.join(', ')}',
    ),
  ];
}

List<String> runtimeRootDeclarationsForFile({
  required String path,
  required String content,
}) {
  final unit = parseString(
    content: content,
    path: path,
    featureSet: FeatureSet.latestLanguageVersion(),
  ).unit;

  return _runtimeRootDeclarations(path, unit).toList();
}

List<GuardrailViolation> _checkDirectives(String path, CompilationUnit unit) {
  final violations = <GuardrailViolation>[];

  for (final directive in unit.directives) {
    switch (directive) {
      case ImportDirective():
        final uri = directive.uri.stringValue;
        if (uri == null) {
          continue;
        }
        violations.addAll(_checkImport(path, uri));
      case ExportDirective():
        final uri = directive.uri.stringValue;
        if (uri != null) {
          violations.addAll(_checkExport(path, uri));
        }
      case PartDirective() || PartOfDirective():
        violations.add(
          GuardrailViolation(
            guardrailId: 'core.no_unapproved_part_files',
            path: path,
            message: 'production code may not use part directives',
          ),
        );
      case LibraryDirective():
        break;
    }
  }

  return violations;
}

List<GuardrailViolation> _checkImport(String path, String uri) {
  final violations = [
    ..._checkLegacyImport(path, uri),
    ..._checkExternalPrivateImport(path, uri),
    ..._checkCodecFlutterImport(path, uri),
    ..._checkResourceFlutterImport(path, uri),
    ..._checkInteractionFlutterImport(path, uri),
    ..._checkResourcePlatformImport(path, uri),
    ..._checkResourceNetworkImport(path, uri),
  ];
  final target = _targetPath(path, uri);
  if (target != null) {
    violations.addAll(_checkResolvedImportTarget(path, uri, target));
  }

  return violations;
}

List<GuardrailViolation> _checkLegacyImport(String path, String uri) {
  if (!_isLegacyUri(uri)) {
    return const [];
  }

  return [
    GuardrailViolation(
      guardrailId: 'core.no_legacy_imports',
      path: path,
      message: 'imports legacy code through $uri',
    ),
  ];
}

List<GuardrailViolation> _checkExternalPrivateImport(String path, String uri) {
  if (!_importsAnotherPackageSrc(uri)) {
    return const [];
  }

  return [
    GuardrailViolation(
      guardrailId: 'core.import_boundaries',
      path: path,
      message: 'imports another package private src library through $uri',
    ),
  ];
}

List<GuardrailViolation> _checkCodecFlutterImport(String path, String uri) {
  if (!path.startsWith('lib/src/codec/') || !_isFlutterWidgetSurface(uri)) {
    return const [];
  }

  return [
    GuardrailViolation(
      guardrailId: 'core.import_boundaries',
      path: path,
      message: 'codec code may not import Flutter widgets',
    ),
  ];
}

List<GuardrailViolation> _checkResourceFlutterImport(String path, String uri) {
  if (!path.startsWith('lib/src/resources/') || !_isFlutterPackage(uri)) {
    return const [];
  }

  return [
    GuardrailViolation(
      guardrailId: 'core.import_boundaries',
      path: path,
      message: 'resource code may not import Flutter packages',
    ),
  ];
}

List<GuardrailViolation> _checkInteractionFlutterImport(
  String path,
  String uri,
) {
  if (!path.startsWith('lib/src/interaction/') || !_isFlutterPackage(uri)) {
    return const [];
  }

  return [
    GuardrailViolation(
      guardrailId: 'core.import_boundaries',
      path: path,
      message: 'interaction code may not import Flutter packages',
    ),
  ];
}

List<GuardrailViolation> _checkResourcePlatformImport(String path, String uri) {
  if (!path.startsWith('lib/src/resources/') || uri != 'dart:io') {
    return const [];
  }

  return [
    GuardrailViolation(
      guardrailId: 'core.import_boundaries',
      path: path,
      message: 'resource code may not import dart:io',
    ),
  ];
}

List<GuardrailViolation> _checkResourceNetworkImport(String path, String uri) {
  if (!path.startsWith('lib/src/resources/') || !_isNetworkLoadingImport(uri)) {
    return const [];
  }

  return [
    GuardrailViolation(
      guardrailId: 'resources.resolver_boundary_owned_by_surface_session',
      path: path,
      message: 'resource code may not import network loading libraries',
    ),
  ];
}

List<GuardrailViolation> _checkResolvedImportTarget(
  String path,
  String uri,
  String target,
) {
  final violations = <GuardrailViolation>[];

  if (target.startsWith('tool/')) {
    violations.add(
      GuardrailViolation(
        guardrailId: 'core.import_boundaries',
        path: path,
        message: 'production code may not import tool-owned code through $uri',
      ),
    );
  }

  return violations..addAll(_checkSourceBoundary(path, target));
}

List<GuardrailViolation> _checkExport(String path, String uri) {
  if (path.startsWith('lib/src/api/')) {
    return _checkApiFacadeExport(path, uri);
  }

  if (path != 'lib/iwb_canvas_engine.dart') {
    return const [
      GuardrailViolation(
        guardrailId: 'core.import_boundaries',
        path: 'lib',
        message: 'production exports are owned by the root public barrel',
      ),
    ];
  }

  if (!uri.startsWith('src/api/')) {
    return [
      GuardrailViolation(
        guardrailId: 'core.import_boundaries',
        path: path,
        message: 'root barrel may export only lib/src/api/**, found $uri',
      ),
    ];
  }

  return const [];
}

List<GuardrailViolation> _checkApiFacadeExport(String path, String uri) {
  final target = _targetPath(path, uri);
  if (target != null && target.startsWith('lib/src/contracts/public/')) {
    return const [];
  }

  if (path == 'lib/src/api/canvas_surface.dart' &&
      (target == 'lib/src/surface/canvas_surface_widget.dart' ||
          target == 'lib/src/surface/text_editing_overlay.dart')) {
    return const [];
  }

  return [
    GuardrailViolation(
      guardrailId: 'core.import_boundaries',
      path: path,
      message:
          'api facade files may export only public contract declarations '
          'through $uri',
    ),
  ];
}

List<GuardrailViolation> _checkSourceBoundary(String path, String target) {
  final violations = <GuardrailViolation>[];
  final reportedGuardrails = <String>{};

  for (final rule in _boundaryRules) {
    for (final violation in rule.check(path, target)) {
      if (reportedGuardrails.add(violation.guardrailId)) {
        violations.add(violation);
      }
    }
  }

  return violations;
}

List<GuardrailViolation> _checkRetiredShapeReferences(
  String path,
  CompilationUnit unit,
) {
  final visitor = _RetiredShapeVisitor(path);
  unit.accept(visitor);

  return [..._checkRetiredShapeDeclarations(path, unit), ...visitor.violations];
}

List<GuardrailViolation> _checkResourceResolverTypeReferences(
  String path,
  CompilationUnit unit, {
  bool requireResolvedElement = true,
}) {
  final visitor = _ResourceResolverBoundaryVisitor(
    path,
    requireResolvedElement: requireResolvedElement,
  );
  unit.accept(visitor);

  return visitor.violations;
}

List<GuardrailViolation> _checkRetiredShapeDeclarations(
  String path,
  CompilationUnit unit,
) {
  return _topLevelDeclarationNames(unit)
      .where(_isRetiredShapeName)
      .map((name) => _retiredShapeViolation(path, name))
      .toList();
}

Iterable<String> _topLevelDeclarationNames(CompilationUnit unit) sync* {
  for (final declaration in unit.declarations) {
    final name = _compilationUnitDeclarationName(declaration);
    if (name != null) {
      yield name;
    }
    if (declaration case TopLevelVariableDeclaration(:final variables)) {
      for (final variable in variables.variables) {
        yield variable.name.lexeme;
      }
    }
  }
}

bool _isLegacyUri(String uri) {
  return uri.startsWith('../legacy/') ||
      uri.startsWith('../../legacy/') ||
      uri.startsWith('package:legacy/') ||
      uri.contains('/legacy/') ||
      uri.contains('legacy/iwb_canvas_engine');
}

bool _importsAnotherPackageSrc(String uri) {
  return uri.startsWith('package:') &&
      uri.contains('/src/') &&
      !uri.startsWith('package:iwb_canvas_engine/src/');
}

String? _targetPath(String sourcePath, String uri) {
  if (uri.startsWith('package:iwb_canvas_engine/')) {
    return 'lib/${uri.replaceFirst('package:iwb_canvas_engine/', '')}';
  }
  if (uri.startsWith('package:')) {
    return null;
  }

  final sourceDirectory = sourcePath.replaceRange(
    sourcePath.lastIndexOf('/'),
    sourcePath.length,
    '',
  );
  final resolved = File(
    '$repositoryRoot/$sourceDirectory/$uri',
  ).absolute.uri.normalizePath().toFilePath();
  final prefix = '$repositoryRoot/';

  return resolved.startsWith(prefix) ? resolved.replaceFirst(prefix, '') : null;
}

final class _RetiredShapeVisitor extends RecursiveAstVisitor<void> {
  _RetiredShapeVisitor(this.path);

  final String path;
  final List<GuardrailViolation> violations = [];

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    _recordName(node.name, node.element);
  }

  @override
  void visitNamedType(NamedType node) {
    _recordName(node.name.lexeme, node.element);
    super.visitNamedType(node);
  }

  void _recordName(String name, Element? element) {
    if (!_isRetiredShapeDependency(name, element)) {
      return;
    }
    violations.add(_retiredShapeViolation(path, name));
  }
}

final class _ResourceResolverBoundaryVisitor extends RecursiveAstVisitor<void> {
  _ResourceResolverBoundaryVisitor(
    this.path, {
    required this.requireResolvedElement,
  });

  final String path;
  final bool requireResolvedElement;
  final List<GuardrailViolation> violations = [];

  @override
  void visitNamedType(NamedType node) {
    _record(name: node.name.lexeme, element: node.element, type: node.type);
    super.visitNamedType(node);
  }

  void _record({
    required String name,
    required Element? element,
    required DartType? type,
  }) {
    if (!_isCanvasResourceResolverTypeReference(
      name: name,
      element: element,
      type: type,
      requireResolvedElement: requireResolvedElement,
    )) {
      return;
    }
    violations.addAll(_resolverBoundaryViolation(path));
  }
}

bool _isCanvasResourceResolverTypeReference({
  required String name,
  required Element? element,
  required DartType? type,
  required bool requireResolvedElement,
}) {
  if (_isPublicCanvasResourceResolverElement(type?.element) ||
      _isPublicCanvasResourceResolverElement(element)) {
    return true;
  }

  return !requireResolvedElement && name == 'CanvasResourceResolver';
}

bool _isPublicCanvasResourceResolverElement(Element? element) {
  final libraryUri = element?.library?.uri.toString();

  return element?.displayName == 'CanvasResourceResolver' &&
      libraryUri ==
          'package:iwb_canvas_engine/src/contracts/public/canvas_resource.dart';
}

List<GuardrailViolation> _resolverBoundaryViolation(String path) {
  if (_isUnauthorizedResourceResolverOwnerPath(path)) {
    return [
      GuardrailViolation(
        guardrailId: 'resources.resolver_boundary_owned_by_surface_session',
        path: path,
        message:
            'resource code must route typed CanvasResourceResolver ownership '
            'through SurfaceResourceSession',
      ),
    ];
  }
  if (!path.startsWith('lib/src/frame/') &&
      !path.startsWith('lib/src/interaction/') &&
      !_isSurfacePainterPath(path)) {
    return const [];
  }

  return [
    GuardrailViolation(
      guardrailId: 'resources.resolver_boundary_owned_by_surface_session',
      path: path,
      message:
          'frame, interaction, and surface painter code must not own typed '
          'CanvasResourceResolver references',
    ),
  ];
}

GuardrailViolation _retiredShapeViolation(String path, String name) {
  if (_sceneControllerShapeNames.contains(name)) {
    return GuardrailViolation(
      guardrailId: 'core.no_scene_controller_shape_dependency',
      path: path,
      message: 'references retired SceneController shape $name',
    );
  }

  return GuardrailViolation(
    guardrailId: 'core.no_node_spec_patch_shape_dependency',
    path: path,
    message: 'references retired node patch shape $name',
  );
}

bool _isRetiredShapeDependency(String name, Element? element) {
  final isRetiredName = _isRetiredShapeName(name);

  if (!isRetiredName) {
    return false;
  }

  return element == null ||
      _isLegacyElement(element) ||
      _isProductionElement(element);
}

bool _isRetiredShapeName(String name) {
  return _sceneControllerShapeNames.contains(name) ||
      _nodeSpecPatchShapeNames.contains(name);
}

bool _isLegacyElement(Element element) {
  final uri = element.library?.uri.toString();

  return uri != null && uri.contains('legacy/iwb_canvas_engine');
}

bool _isProductionElement(Element element) {
  final uri = element.library?.uri.toString();

  return uri != null && uri.startsWith('package:iwb_canvas_engine/src/');
}

bool _isFlutterWidgetSurface(String uri) {
  return uri == 'package:flutter/widgets.dart' ||
      uri == 'package:flutter/material.dart' ||
      uri == 'package:flutter/cupertino.dart';
}

bool _isFlutterPackage(String uri) {
  return uri.startsWith('package:flutter/');
}

bool _isCodecRuntimeMutationTarget(String target) {
  return target.startsWith('lib/src/runtime/') ||
      target.startsWith('lib/src/store/') ||
      target.startsWith('lib/src/edit/') ||
      target.startsWith('lib/src/frame/') ||
      target.startsWith('lib/src/surface/');
}

bool _isNetworkLoadingImport(String uri) {
  return uri == 'dart:html' ||
      uri == 'dart:js_interop' ||
      uri == 'package:http/http.dart' ||
      uri.startsWith('package:http/') ||
      uri.startsWith('package:dio/') ||
      uri.startsWith('package:chopper/') ||
      uri.startsWith('package:retrofit/');
}

bool _isSurfacePainterPath(String path) {
  if (!path.startsWith('lib/src/surface/')) {
    return false;
  }

  return path.split('/').last.contains('painter');
}

bool _isUnauthorizedResourceResolverOwnerPath(String path) {
  return path.startsWith('lib/src/resources/') &&
      path != 'lib/src/resources/surface_resource_session.dart';
}

const _sceneControllerShapeNames = {'SceneController', 'SceneSnapshot'};
const _nodeSpecPatchShapeNames = {'NodeSpec', 'NodePatch', 'PatchField'};

const _boundaryRules = [
  _BoundaryRule(
    guardrailId: 'core.import_boundaries',
    owner: 'lib/src/api/',
    forbiddenTargets: [
      'lib/src/contracts/internal/',
      'lib/src/runtime/',
      'lib/src/store/',
      'lib/src/selection/',
      'lib/src/edit/',
      'lib/src/frame/',
      'lib/src/interaction/',
      'lib/src/resources/',
      'lib/src/diagnostics/',
      'lib/src/geometry/',
      'lib/src/surface/',
      'lib/src/flutter_bridge/',
    ],
  ),
  _BoundaryRule(
    guardrailId: 'core.import_boundaries',
    owner: 'lib/src/surface/',
    forbiddenTargets: [
      'lib/iwb_canvas_engine.dart',
      'lib/src/api/',
      'lib/src/runtime/',
      'lib/src/store/',
      'lib/src/selection/',
      'lib/src/edit/',
      'lib/src/interaction/',
      'lib/src/flutter_bridge/',
    ],
  ),
  _BoundaryRule(
    guardrailId: 'core.import_boundaries',
    owner: 'lib/src/store/',
    forbiddenTargets: [
      'lib/src/interaction/',
      'lib/src/frame/',
      'lib/src/surface/',
      'lib/src/flutter_bridge/',
    ],
  ),
  _BoundaryRule(
    guardrailId: 'core.import_boundaries',
    owner: 'lib/src/edit/',
    forbiddenTargets: ['lib/src/surface/', 'lib/src/flutter_bridge/'],
  ),
  _BoundaryRule(
    guardrailId: 'core.import_boundaries',
    owner: 'lib/src/selection/',
    forbiddenTargets: [
      'lib/src/store/',
      'lib/src/edit/',
      'lib/src/interaction/',
      'lib/src/frame/',
      'lib/src/surface/',
      'lib/src/flutter_bridge/',
    ],
  ),
  _BoundaryRule(
    guardrailId: 'core.import_boundaries',
    owner: 'lib/src/interaction/',
    forbiddenTargets: [
      'lib/src/store/',
      'lib/src/selection/',
      'lib/src/resources/',
      'lib/src/frame/',
      'lib/src/runtime/',
      'lib/src/surface/',
      'lib/src/flutter_bridge/',
      'lib/src/contracts/internal/command_facts_port.dart',
    ],
  ),
  _BoundaryRule(
    guardrailId: 'core.import_boundaries',
    owner: 'lib/src/interaction/interaction_read_port.dart',
    forbiddenTargets: [
      'lib/src/api/canvas_document.dart',
      'lib/src/resources/',
      'lib/src/store/',
      'lib/src/selection/',
      'lib/src/edit/',
    ],
  ),
  _BoundaryRule(
    guardrailId: 'core.import_boundaries',
    owner: 'lib/src/interaction/pointer_tool_cleanup_coordinator.dart',
    forbiddenTargets: [
      'lib/src/edit/',
      'lib/src/frame/',
      'lib/src/surface/',
      'lib/src/flutter_bridge/',
      'lib/src/resources/',
      'lib/src/store/',
      'lib/src/selection/',
    ],
  ),
  _BoundaryRule(
    guardrailId: 'core.import_boundaries',
    owner: 'lib/src/resources/',
    forbiddenTargets: [
      'lib/src/runtime/',
      'lib/src/store/',
      'lib/src/frame/',
      'lib/src/surface/',
      'lib/src/flutter_bridge/',
      'lib/src/interaction/',
      'lib/src/diagnostics/',
    ],
  ),
  _BoundaryRule(
    guardrailId: 'core.import_boundaries',
    owner: 'lib/src/codec/',
    forbiddenTargets: [
      'lib/src/surface/',
      'lib/src/flutter_bridge/',
      'lib/src/interaction/',
    ],
  ),
  _BoundaryRule(
    guardrailId: 'core.import_boundaries',
    owner: 'lib/src/diagnostics/',
    forbiddenTargets: [
      'lib/src/codec/',
      'lib/src/runtime/',
      'lib/src/store/',
      'lib/src/edit/',
      'lib/src/frame/',
      'lib/src/surface/',
      'lib/src/flutter_bridge/',
    ],
  ),
  _BoundaryRule(
    guardrailId: 'core.import_boundaries',
    owner: 'lib/src/frame/',
    forbiddenTargets: [
      'lib/src/contracts/internal/resource_catalog_port.dart',
      'lib/src/store/',
      'lib/src/edit/',
      'lib/src/api/canvas_document.dart',
      'lib/src/flutter_bridge/',
    ],
  ),
  _BoundaryRule(
    guardrailId: 'frame.committed_facts_via_frame_facts_port',
    owner: 'lib/src/frame/',
    forbiddenTargets: [
      'lib/src/api/',
      'lib/src/resources/surface_resource_session.dart',
    ],
  ),
  _BoundaryRule(
    guardrailId: 'core.import_boundaries',
    owner: 'lib/src/geometry/',
    forbiddenTargets: [
      'lib/src/store/',
      'lib/src/interaction/',
      'lib/src/frame/',
      'lib/src/flutter_bridge/',
    ],
  ),
];

final class _BoundaryRule {
  const _BoundaryRule({
    required this.guardrailId,
    required this.owner,
    required this.forbiddenTargets,
  });

  final String guardrailId;
  final String owner;
  final List<String> forbiddenTargets;

  Iterable<GuardrailViolation> check(String path, String target) sync* {
    if (!path.startsWith(owner)) {
      return;
    }

    for (final prefix in forbiddenTargets) {
      if (!target.startsWith(prefix)) {
        continue;
      }
      if (_isAllowedBoundaryImport(path, target)) {
        continue;
      }
      yield GuardrailViolation(
        guardrailId: guardrailId,
        path: path,
        message: '$owner may not import $target',
      );
    }
  }
}

bool _isAllowedBoundaryImport(String path, String target) {
  if (path == 'lib/src/api/canvas_runtime.dart' &&
      target == 'lib/src/runtime/runtime_root.dart') {
    return true;
  }

  if (path == 'lib/src/api/canvas_runtime_frame_bridge.dart' &&
      target == 'lib/src/runtime/runtime_root.dart') {
    return true;
  }

  if (path == 'lib/src/api/canvas_runtime_surface_bridge.dart' &&
      target == 'lib/src/runtime/runtime_root.dart') {
    return true;
  }

  if (path == 'lib/src/api/canvas_runtime_surface_bridge.dart' &&
      (target == 'lib/src/contracts/internal/resolver_mutation_guard.dart' ||
          target ==
              'lib/src/contracts/internal/surface_resource_session_lifecycle.dart' ||
          target == 'lib/src/frame/frame_engine.dart' ||
          target == 'lib/src/frame/frame_paint_output.dart')) {
    return true;
  }

  if (path == 'lib/src/api/canvas_surface.dart' &&
      (target == 'lib/src/surface/canvas_surface_widget.dart' ||
          target == 'lib/src/surface/text_editing_overlay.dart')) {
    return true;
  }

  if (path == 'lib/src/surface/canvas_surface_widget.dart' &&
      (target == 'lib/src/api/canvas_runtime.dart' ||
          target == 'lib/src/api/canvas_runtime_surface_bridge.dart')) {
    return true;
  }

  if (path == 'lib/src/surface/text_editing_overlay.dart' &&
      target == 'lib/src/api/canvas_runtime.dart') {
    return true;
  }

  if (path == 'lib/src/frame/paint_asset_binding_service.dart' &&
      target == 'lib/src/resources/surface_resource_session.dart') {
    return true;
  }

  return false;
}

const _runtimeRootPath = 'lib/src/runtime/runtime_root.dart';
const _interactionEnginePath = 'lib/src/interaction/interaction_engine.dart';
const _pointerCleanupCoordinatorPath =
    'lib/src/interaction/pointer_tool_cleanup_coordinator.dart';

Iterable<String> _runtimeRootDeclarations(
  String path,
  CompilationUnit unit,
) sync* {
  for (final declaration in unit.declarations) {
    if (_compilationUnitDeclarationName(declaration) == 'RuntimeRoot') {
      yield path;
    }
    if (declaration case TopLevelVariableDeclaration(:final variables)) {
      for (final variable in variables.variables) {
        if (variable.name.lexeme == 'RuntimeRoot') {
          yield path;
        }
      }
    }
  }
}

String? _compilationUnitDeclarationName(CompilationUnitMember declaration) {
  return switch (declaration) {
    ClassDeclaration(:final namePart) => namePart.typeName.lexeme,
    ClassTypeAlias(:final name) => name.lexeme,
    EnumDeclaration(:final namePart) => namePart.typeName.lexeme,
    FunctionDeclaration(:final name) => name.lexeme,
    GenericTypeAlias(:final name) => name.lexeme,
    MixinDeclaration(:final name) => name.lexeme,
    _ => null,
  };
}

ParseStringResult _parseFile(File file) {
  return parseFile(
    path: file.path,
    featureSet: FeatureSet.latestLanguageVersion(),
  );
}
