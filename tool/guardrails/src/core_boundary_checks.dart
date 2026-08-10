import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

import '../../src/directive_uri_references.dart';
import 'core_boundary_type_checks.dart';
import 'guardrail_violation.dart';
import 'repository_paths.dart';

const _vectorGraphicsImport = 'package:vector_graphics/vector_graphics.dart';
const _vectorPreparationCapabilityFreeExternalImports = {
  'dart:convert',
  'dart:math',
  'dart:typed_data',
  'package:flutter/gestures.dart',
  'package:characters/characters.dart',
};
const _vectorPreparationRestrictedNamespaces = <String, Set<String>>{
  'dart:ui': {'Offset', 'Picture', 'Size'},
  'package:flutter/foundation.dart': {'internal'},
  'package:flutter/widgets.dart': {'BuildContext'},
  _vectorGraphicsImport: {'BytesLoader', 'PictureInfo', 'vg'},
};

// Resolving every production unit and collecting each boundary outcome in one
// pass keeps the reported path tied to the resolved source that produced it.
// ignore: halstead-volume
Future<List<GuardrailViolation>> checkCoreBoundaries() async {
  final violations = <GuardrailViolation>[];
  final units = <String, CompilationUnit>{};
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
      units[path] = result.unit;

      violations
        ..addAll(_checkDirectives(path, result.unit))
        ..addAll(checkRetiredShapeReferences(path, result.unit))
        ..addAll(checkResourceResolverTypeReferences(path, result.unit));
    }
    violations.addAll(
      _checkVectorPreparationDependencyBoundary(
        units,
        requireResolvedElement: true,
      ),
    );
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

// Surface pointer admission keeps adapter and host obligations in one check.
// The combined assertion preserves their required ownership ordering.
// ignore: halstead-volume, source-lines-of-code
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
    'CanvasPointerTerminalCleanup(',
    'routeInput',
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
      !widgetContent.contains('port.handlePointer(_surfaceToken, input)')) {
    violations.add(
      const GuardrailViolation(
        guardrailId: 'surface.pointer_samples_normalized_before_runtime',
        path: widgetPath,
        message: 'CanvasSurface must route pointer input through active token',
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
  final unit = parseString(content: content, path: path).unit;

  return [
    ..._checkDirectives(path, unit),
    ...checkRetiredShapeReferences(path, unit),
    ...checkResourceResolverTypeReferences(
      path,
      unit,
      requireResolvedElement: false,
    ),
    ...checkVectorPreparationApiRuntimeReferences(
      path,
      unit,
      requireResolvedElement: false,
    ),
    ...checkPointerCleanupCoordinatorCallerFile(path: path, content: content),
  ];
}

List<GuardrailViolation> checkVectorPreparationDependencyBoundaryFiles(
  Map<String, String> files,
) {
  final units = <String, CompilationUnit>{
    for (final entry in files.entries)
      entry.key: parseString(content: entry.value, path: entry.key).unit,
  };

  return _checkVectorPreparationDependencyBoundary(
    units,
    requireResolvedElement: false,
  );
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
  final unit = parseString(content: content, path: path).unit;

  return _runtimeRootDeclarations(path, unit).toList();
}

List<GuardrailViolation> _checkDirectives(String path, CompilationUnit unit) {
  final violations = <GuardrailViolation>[];

  for (final directive in unit.directives) {
    switch (directive) {
      case ImportDirective():
        for (final reference in directiveUriReferences(directive)) {
          violations.addAll(_checkImport(path, reference.uri));
        }
      case ExportDirective():
        for (final reference in directiveUriReferences(directive)) {
          violations.addAll(_checkExport(path, reference.uri));
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
    ..._checkRetiredPackageImport(path, uri),
    ..._checkExternalPrivateImport(path, uri),
    ..._checkCodecFlutterImport(path, uri),
    ..._checkResourceFlutterImport(path, uri),
    ..._checkInteractionFlutterImport(path, uri),
    ..._checkResourcePlatformImport(path, uri),
    ..._checkResourceNetworkImport(path, uri),
    ..._checkVectorPreparationImports(path, uri),
  ];
  final target = _targetPath(path, uri);
  if (target != null) {
    violations.addAll(_checkResolvedImportTarget(path, uri, target));
  }

  return violations;
}

List<GuardrailViolation> _checkRetiredPackageImport(String path, String uri) {
  if (!_isRetiredPackageUri(uri)) {
    return const [];
  }

  return [
    GuardrailViolation(
      guardrailId: 'core.no_unapproved_external_package_imports',
      path: path,
      message: 'imports unapproved external package code through $uri',
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

List<GuardrailViolation> _checkVectorPreparationImports(
  String path,
  String uri,
) {
  if (uri == _vectorGraphicsImport &&
      path.startsWith(vectorPreparationApiOwnerPath)) {
    return const [];
  }

  if (uri.startsWith('package:vector_graphics/')) {
    return [_vectorPreparationImportViolation(path, uri)];
  }

  if (uri.startsWith('package:vector_graphics_codec/')) {
    return [_vectorPreparationImportViolation(path, uri)];
  }

  return const [];
}

GuardrailViolation _vectorPreparationImportViolation(String path, String uri) {
  return GuardrailViolation(
    guardrailId: 'core.import_boundaries',
    path: path,
    message:
        'production code may not import $uri; the unique vector graphics importer '
        'must be API-owned and vector preparation consumes caller bytes',
  );
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

// The closure walk preserves import order, resolved capability calls, and the
// root relationship; extracting branches would obscure which owner is reached.
// ignore: cyclomatic-complexity, halstead-volume, maximum-nesting-level, source-lines-of-code
List<GuardrailViolation> _checkVectorPreparationDependencyBoundary(
  Map<String, CompilationUnit> units, {
  required bool requireResolvedElement,
}) {
  final violations = <GuardrailViolation>[];
  final root = _findVectorPreparationClosureRoot(units, violations);
  if (root == null) {
    return violations;
  }

  final candidates = <String>[root];
  final visited = <String>{};

  for (var index = 0; index < candidates.length; index++) {
    final path = candidates[index];
    if (!visited.add(path)) {
      continue;
    }
    final unit = units[path];
    if (unit == null) {
      continue;
    }

    violations.addAll(
      checkVectorPreparationDependencyRuntimeReferences(
        path,
        unit,
        requireResolvedElement: requireResolvedElement,
      ),
    );
    for (final directive in unit.directives) {
      if (directive case ImportDirective() || ExportDirective()) {
        for (final reference in directiveUriReferences(directive)) {
          violations.addAll(
            _checkVectorPreparationCapabilityDirective(
              path,
              directive,
              reference.uri,
              root: root,
            ),
          );
          final target = _targetPath(path, reference.uri);
          if (target != null && units.containsKey(target)) {
            candidates.add(target);
          }
        }
      }
    }
  }

  return violations;
}

String? _findVectorPreparationClosureRoot(
  Map<String, CompilationUnit> units,
  List<GuardrailViolation> violations,
) {
  final importers = <String>{
    for (final entry in units.entries)
      if (entry.value.directives.whereType<ImportDirective>().any(
        (directive) => directiveUriReferences(
          directive,
        ).any((reference) => reference.uri == _vectorGraphicsImport),
      ))
        entry.key,
  };
  final apiImporters = importers
      .where((path) => path.startsWith(vectorPreparationApiOwnerPath))
      .toList();

  if (importers.length == 1 && apiImporters.length == 1) {
    return apiImporters.single;
  }

  violations.add(
    GuardrailViolation(
      guardrailId: 'core.import_boundaries',
      path: apiImporters.firstOrNull ?? vectorPreparationApiOwnerPath,
      message:
          'vector preparation requires exactly one API-owned importer of '
          '$_vectorGraphicsImport, found ${importers.join(', ')}',
    ),
  );
  return null;
}

List<GuardrailViolation> _checkVectorPreparationCapabilityDirective(
  String path,
  Directive directive,
  String uri, {
  required String root,
}) {
  if (!_isExternalImport(uri) || _isPackageOwnedImport(uri)) {
    return const [];
  }

  if (_isCapabilityFreeVectorPreparationImport(uri)) {
    return const [];
  }

  final allowedSymbols = _vectorPreparationRestrictedNamespaces[uri];
  if (allowedSymbols != null &&
      _isAllowedVectorPreparationNamespaceDirective(
        directive,
        allowedSymbols,
        uri == _vectorGraphicsImport && path == root,
      )) {
    return const [];
  }

  return [
    GuardrailViolation(
      guardrailId: 'core.import_boundaries',
      path: path,
      message:
          'vector preparation dependencies may import only approved '
          'capability-free namespaces, found $uri',
    ),
  ];
}

bool _isAllowedVectorPreparationNamespaceDirective(
  Directive directive,
  Set<String> allowedSymbols,
  bool isVectorPreparationRoot,
) {
  if (directive is! ImportDirective ||
      (directiveUriReferences(
            directive,
          ).any((reference) => reference.uri == _vectorGraphicsImport) &&
          !isVectorPreparationRoot)) {
    return false;
  }

  final combinators = directive.combinators;
  if (combinators.isEmpty || combinators.any((it) => it is! ShowCombinator)) {
    return false;
  }

  return combinators
      .whereType<ShowCombinator>()
      .expand((combinator) => combinator.shownNames)
      .every((name) => allowedSymbols.contains(name.name));
}

bool _isExternalImport(String uri) =>
    uri.startsWith('dart:') || uri.startsWith('package:');

bool _isPackageOwnedImport(String uri) =>
    uri.startsWith('package:iwb_canvas_engine/');

bool _isCapabilityFreeVectorPreparationImport(String uri) =>
    _vectorPreparationCapabilityFreeExternalImports.contains(uri);

bool _isRetiredPackageUri(String uri) {
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
    final packagePath = uri.replaceFirst('package:iwb_canvas_engine/', '');
    final resolved = File(
      '$repositoryRoot/lib/$packagePath',
    ).absolute.uri.normalizePath().toFilePath();
    final packageRoot = '$repositoryRoot/lib/';

    return resolved.startsWith(packageRoot)
        ? 'lib/${resolved.replaceFirst(packageRoot, '')}'
        : null;
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

// These exceptional ownership pairs stay visibly centralized so boundary
// reviewers can audit every cross-owner allowance in one place.
// ignore: cyclomatic-complexity
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
          target == 'lib/src/contracts/internal/surface_frame_signal.dart' ||
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
  return parseString(content: file.readAsStringSync(), path: file.path);
}
