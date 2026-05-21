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

import 'guardrail_violation.dart';
import 'repository_paths.dart';

Future<List<GuardrailViolation>> checkCoreBoundaries() async {
  final violations = <GuardrailViolation>[];
  final collection = AnalysisContextCollection(
    includedPaths: ['$repositoryRoot/lib'],
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
        ..addAll(_checkRetiredShapeReferences(path, result.unit));
    }
  } finally {
    await collection.dispose();
  }

  return violations;
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

List<GuardrailViolation> _checkSourceBoundary(String path, String target) {
  final violations = <GuardrailViolation>[];

  for (final rule in _boundaryRules) {
    violations.addAll(rule.check(path, target));
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
    return 'lib/${uri.substring('package:iwb_canvas_engine/'.length)}';
  }
  if (uri.startsWith('package:')) {
    return null;
  }

  final sourceDirectory = sourcePath.substring(0, sourcePath.lastIndexOf('/'));
  final resolved = File(
    '$repositoryRoot/$sourceDirectory/$uri',
  ).absolute.uri.normalizePath().toFilePath();
  final prefix = '$repositoryRoot/';

  return resolved.startsWith(prefix) ? resolved.substring(prefix.length) : null;
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

bool _isCodecRuntimeMutationTarget(String target) {
  return target.startsWith('lib/src/runtime/') ||
      target.startsWith('lib/src/store/') ||
      target.startsWith('lib/src/edit/') ||
      target.startsWith('lib/src/frame/') ||
      target.startsWith('lib/src/surface/');
}

const _sceneControllerShapeNames = {'SceneController', 'SceneSnapshot'};
const _nodeSpecPatchShapeNames = {'NodeSpec', 'NodePatch', 'PatchField'};

const _boundaryRules = [
  _BoundaryRule(
    guardrailId: 'core.import_boundaries',
    owner: 'lib/src/api/',
    forbiddenTargets: [
      'lib/src/runtime/',
      'lib/src/store/',
      'lib/src/selection/',
      'lib/src/edit/',
      'lib/src/frame/',
      'lib/src/interaction/',
      'lib/src/resources/',
      'lib/src/diagnostics/',
      'lib/src/spatial/',
      'lib/src/geometry/',
      'lib/src/flutter_bridge/',
    ],
  ),
  _BoundaryRule(
    guardrailId: 'core.import_boundaries',
    owner: 'lib/src/store/',
    forbiddenTargets: [
      'lib/src/interaction/',
      'lib/src/frame/',
      'lib/src/flutter_bridge/',
    ],
  ),
  _BoundaryRule(
    guardrailId: 'core.import_boundaries',
    owner: 'lib/src/edit/',
    forbiddenTargets: ['lib/src/flutter_bridge/'],
  ),
  _BoundaryRule(
    guardrailId: 'core.import_boundaries',
    owner: 'lib/src/selection/',
    forbiddenTargets: [
      'lib/src/store/',
      'lib/src/edit/',
      'lib/src/interaction/',
      'lib/src/frame/',
      'lib/src/flutter_bridge/',
    ],
  ),
  _BoundaryRule(
    guardrailId: 'core.import_boundaries',
    owner: 'lib/src/interaction/',
    forbiddenTargets: ['lib/src/store/'],
  ),
  _BoundaryRule(
    guardrailId: 'core.import_boundaries',
    owner: 'lib/src/interaction/',
    forbiddenTargets: ['lib/src/selection/'],
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
      'lib/src/flutter_bridge/',
      'lib/src/resources/',
      'lib/src/store/',
      'lib/src/selection/',
    ],
  ),
  _BoundaryRule(
    guardrailId: 'core.import_boundaries',
    owner: 'lib/src/resources/',
    forbiddenTargets: ['lib/src/interaction/'],
  ),
  _BoundaryRule(
    guardrailId: 'core.import_boundaries',
    owner: 'lib/src/codec/',
    forbiddenTargets: ['lib/src/flutter_bridge/', 'lib/src/interaction/'],
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
    ],
  ),
  _BoundaryRule(
    guardrailId: 'core.import_boundaries',
    owner: 'lib/src/frame/',
    forbiddenTargets: [
      'lib/src/store/',
      'lib/src/edit/',
      'lib/src/api/canvas_document.dart',
    ],
  ),
  _BoundaryRule(
    guardrailId: 'core.import_boundaries',
    owner: 'lib/src/spatial/',
    forbiddenTargets: [
      'lib/src/store/',
      'lib/src/interaction/',
      'lib/src/frame/',
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
  return path == 'lib/src/api/canvas_runtime.dart' &&
      target == 'lib/src/runtime/runtime_root.dart';
}

const _runtimeRootPath = 'lib/src/runtime/runtime_root.dart';

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
