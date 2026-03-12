import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';

import 'src/layer_guardrails.dart';

// Invariants enforced by this tool:
// INV:INV-G-LAYER-DAG
// INV:INV-G-LAYER-BOUNDARIES
// INV:INV-ENG-NO-EXTERNAL-MUTATION
// INV:INV-ENG-COMMANDS-NO-PART
// INV:INV-ENG-COMMANDS-NO-SCENE_CONTROLLER
// INV:INV-ENG-COMMANDS-NO-CROSS_IMPORTS
// INV:INV-ENG-INTERNAL-NO-SCENE_CONTROLLER
// INV:INV-ENG-INTERNAL-NO-COMMANDS-IMPORTS
// INV:INV-ENG-SHARED-CONTROLLER-HELPERS

class _Violation {
  _Violation({
    required this.filePath,
    required this.line,
    required this.directive,
    required this.target,
    required this.message,
  });

  final String filePath;
  final int line;
  final String directive;
  final String target;
  final String message;

  @override
  String toString() => '$filePath:$line: $message ($directive: $target)';
}

class _DirectiveUriRef {
  const _DirectiveUriRef({required this.uri, required this.offset});

  final String uri;
  final int offset;
}

class _BoundaryTarget {
  const _BoundaryTarget({
    required this.targetPosix,
    required this.diagnosticTarget,
    this.resolvedRepoRelPosix,
  });

  final String targetPosix;
  final String diagnosticTarget;
  final String? resolvedRepoRelPosix;

  bool get isDartSdk => targetPosix.startsWith('dart:');

  bool get isExternalPackage =>
      resolvedRepoRelPosix == null && targetPosix.startsWith('package:');
}

class _PublicLibraryExportResolver {
  _PublicLibraryExportResolver({
    required this.collection,
    required this.rootAbsPosixPath,
    required this.packageName,
  });

  final AnalysisContextCollection collection;
  final String rootAbsPosixPath;
  final String packageName;
  final Map<String, List<_BoundaryTarget>> _cache =
      <String, List<_BoundaryTarget>>{};

  Future<List<_BoundaryTarget>> exportedTargets(String repoRelPosixPath) async {
    final cached = _cache[repoRelPosixPath];
    if (cached != null) {
      return cached;
    }

    final targets = await _collectExports(
      repoRelPosixPath: repoRelPosixPath,
      seen: <String>{},
    );
    final sortedTargets = targets.toList(growable: false)
      ..sort((a, b) {
        final byRepoRel = (a.resolvedRepoRelPosix ?? '').compareTo(
          b.resolvedRepoRelPosix ?? '',
        );
        if (byRepoRel != 0) {
          return byRepoRel;
        }
        return a.targetPosix.compareTo(b.targetPosix);
      });
    _cache[repoRelPosixPath] = sortedTargets;
    return sortedTargets;
  }

  Future<Set<_BoundaryTarget>> _collectExports({
    required String repoRelPosixPath,
    required Set<String> seen,
  }) async {
    if (!_isTopLevelLibFile(repoRelPosixPath) || !seen.add(repoRelPosixPath)) {
      return const <_BoundaryTarget>{};
    }

    final parsed = await _parsePublicLibrary(repoRelPosixPath);
    if (parsed == null) {
      return const <_BoundaryTarget>{};
    }
    return _collectExportTargetsFromParsed(
      parsed: parsed,
      repoRelPosixPath: repoRelPosixPath,
      seen: seen,
    );
  }

  Future<ParsedUnitResult?> _parsePublicLibrary(String repoRelPosixPath) async {
    final absPath = _repoRelPosixToAbsPath(
      repoRelPosixPath: repoRelPosixPath,
      rootAbsPosixPath: rootAbsPosixPath,
    );
    if (!File(absPath).existsSync()) {
      return null;
    }
    return _parseUnitOrFail(
      collection: collection,
      absPath: absPath,
      repoRelPath: repoRelPosixPath,
    );
  }

  Future<Set<_BoundaryTarget>> _collectExportTargetsFromParsed({
    required ParsedUnitResult parsed,
    required String repoRelPosixPath,
    required Set<String> seen,
  }) async {
    final targets = <_BoundaryTarget>{};
    for (final directive
        in parsed.unit.directives.whereType<ExportDirective>()) {
      targets.addAll(
        await _collectExportTargetsFromDirective(
          directive: directive,
          repoRelPosixPath: repoRelPosixPath,
          seen: seen,
        ),
      );
    }
    return targets;
  }

  Future<Set<_BoundaryTarget>> _collectExportTargetsFromDirective({
    required ExportDirective directive,
    required String repoRelPosixPath,
    required Set<String> seen,
  }) async {
    final targets = <_BoundaryTarget>{};
    for (final uriRef in _collectDirectiveUriRefs(directive)) {
      final targetPosix = _toPosixPath(uriRef.uri);
      final resolvedRepoRelPosix = _resolveToRepoRelTargetPosix(
        targetPosix: targetPosix,
        packageName: packageName,
        fileDirRepoRelPosix: _posixDirname(repoRelPosixPath),
      );
      if (resolvedRepoRelPosix == null) {
        if (targetPosix.startsWith('package:')) {
          targets.add(
            _BoundaryTarget(
              targetPosix: targetPosix,
              diagnosticTarget: uriRef.uri,
            ),
          );
        }
        continue;
      }
      if (resolvedRepoRelPosix.startsWith('/lib/src/')) {
        targets.add(
          _BoundaryTarget(
            targetPosix: targetPosix,
            diagnosticTarget: uriRef.uri,
            resolvedRepoRelPosix: resolvedRepoRelPosix,
          ),
        );
        continue;
      }
      targets.addAll(
        await _collectExports(
          repoRelPosixPath: resolvedRepoRelPosix,
          seen: seen,
        ),
      );
    }
    return targets;
  }
}

enum _Layer {
  contract,
  core,
  model,
  controller,
  interactive,
  render,
  serialization,
  view,
}

const Map<_Layer, Set<_Layer>> _allowedLayerDependencies =
    <_Layer, Set<_Layer>>{
      _Layer.contract: <_Layer>{},
      _Layer.core: <_Layer>{_Layer.contract},
      _Layer.model: <_Layer>{_Layer.contract, _Layer.core},
      _Layer.controller: <_Layer>{_Layer.contract, _Layer.core, _Layer.model},
      _Layer.interactive: <_Layer>{
        _Layer.contract,
        _Layer.core,
        _Layer.controller,
        _Layer.model,
      },
      _Layer.render: <_Layer>{_Layer.contract, _Layer.core, _Layer.model},
      _Layer.serialization: <_Layer>{
        _Layer.contract,
        _Layer.core,
        _Layer.model,
      },
      _Layer.view: <_Layer>{
        _Layer.contract,
        _Layer.core,
        _Layer.controller,
        _Layer.interactive,
        _Layer.render,
        _Layer.model,
      },
    };

const Map<_Layer, Set<String>> _allowedExternalPackagePrefixesByLayer =
    <_Layer, Set<String>>{
      _Layer.contract: <String>{
        'package:flutter/foundation.dart',
        'package:path_drawing/',
      },
      _Layer.core: <String>{
        'package:flutter/painting.dart',
        'package:path_drawing/',
      },
      _Layer.model: <String>{},
      _Layer.controller: <String>{'package:flutter/foundation.dart'},
      _Layer.interactive: <String>{'package:flutter/foundation.dart'},
      _Layer.render: <String>{
        'package:flutter/foundation.dart',
        'package:flutter/rendering.dart',
      },
      _Layer.serialization: <String>{},
      _Layer.view: <String>{'package:flutter/widgets.dart'},
    };

const Set<String> _globallyAllowedExternalPackagePrefixes = <String>{
  'package:meta/',
};

List<_DirectiveUriRef> _collectDirectiveUriRefs(UriBasedDirective directive) {
  final refs = <_DirectiveUriRef>[];

  void addUri(StringLiteral literal) {
    final uri = literal.stringValue;
    if (uri == null || uri.isEmpty) {
      return;
    }
    refs.add(_DirectiveUriRef(uri: uri, offset: literal.offset));
  }

  addUri(directive.uri);
  if (directive is NamespaceDirective) {
    for (final configuration in directive.configurations) {
      addUri(configuration.uri);
    }
  }

  return refs;
}

List<_DirectiveUriRef> _collectBoundaryDirectiveUriRefs(Directive directive) {
  if (directive case UriBasedDirective uriDirective) {
    return _collectDirectiveUriRefs(uriDirective);
  }
  if (directive case PartOfDirective(uri: final uri?)) {
    return <_DirectiveUriRef>[
      _DirectiveUriRef(
        uri: uri.stringValue ?? uri.toSource(),
        offset: uri.offset,
      ),
    ];
  }
  return const <_DirectiveUriRef>[];
}

List<_DirectiveUriRef> _collectDocImportUriRefs(AstNode node) {
  final uriRefs = <_DirectiveUriRef>[];

  void visit(AstNode current) {
    if (current is Comment) {
      for (final docImport in current.docImports) {
        final uriValue = docImport.import.uri.stringValue;
        if (uriValue == null || uriValue.isEmpty) {
          continue;
        }
        uriRefs.add(_DirectiveUriRef(uri: uriValue, offset: docImport.offset));
      }
    }
    for (final child in current.childEntities) {
      if (child is AstNode) {
        visit(child);
      }
    }
  }

  visit(node);
  return uriRefs;
}

String _normalizePosixPath(String path) {
  final isAbs = path.startsWith('/');
  final parts = path.split('/').where((p) => p.isNotEmpty).toList();
  final out = <String>[];

  for (final part in parts) {
    if (part == '.') {
      continue;
    }
    if (part == '..') {
      if (out.isNotEmpty) {
        out.removeLast();
      }
      continue;
    }
    out.add(part);
  }

  return '${isAbs ? '/' : ''}${out.join('/')}';
}

String _posixJoin(String a, String b) {
  if (b.startsWith('/')) {
    return _normalizePosixPath(b);
  }
  if (a.isEmpty) {
    return _normalizePosixPath(b);
  }
  return _normalizePosixPath('${a.endsWith('/') ? a : '$a/'}$b');
}

String _toPosixPath(String path) => path.replaceAll('\\', '/');

_Layer? _layerForRepoRelPosixPath(String repoRelPosixPath) {
  switch (topLevelLibSrcLayerForRepoRelPosixPath(repoRelPosixPath)) {
    case 'contract':
      return _Layer.contract;
    case 'core':
      return _Layer.core;
    case 'model':
      return _Layer.model;
    case 'controller':
      return _Layer.controller;
    case 'interactive':
      return _Layer.interactive;
    case 'render':
      return _Layer.render;
    case 'serialization':
      return _Layer.serialization;
    case 'view':
      return _Layer.view;
    case null:
    case _:
      return null;
  }
}

String _layerLabel(_Layer layer) {
  switch (layer) {
    case _Layer.contract:
      return 'contract';
    case _Layer.core:
      return 'core';
    case _Layer.model:
      return 'model';
    case _Layer.controller:
      return 'controller';
    case _Layer.interactive:
      return 'interactive';
    case _Layer.render:
      return 'render';
    case _Layer.serialization:
      return 'serialization';
    case _Layer.view:
      return 'view';
  }
}

bool _isAllowedLayerDependency({required _Layer from, required _Layer to}) {
  if (from == to) {
    return true;
  }
  return _allowedLayerDependencies[from]?.contains(to) ?? false;
}

String _posixDirname(String posixPath) {
  final normalized = _normalizePosixPath(posixPath);
  if (normalized == '/' || normalized.isEmpty) {
    return normalized;
  }
  final slashIndex = normalized.lastIndexOf('/');
  if (slashIndex <= 0) {
    return normalized.startsWith('/') ? '/' : '';
  }
  return normalized.substring(0, slashIndex);
}

String _toRepoRelPosixPath({
  required String absPosixPath,
  required String rootAbsPosixPath,
}) {
  final abs = _normalizePosixPath(absPosixPath);
  final root = _normalizePosixPath(rootAbsPosixPath);
  if (abs == root) {
    return '/';
  }
  final rootPrefix = root.endsWith('/') ? root : '$root/';
  if (!abs.startsWith(rootPrefix)) {
    return abs;
  }
  final rel = abs.substring(root.length);
  return rel.startsWith('/') ? rel : '/$rel';
}

String _repoRelPosixToAbsPath({
  required String repoRelPosixPath,
  required String rootAbsPosixPath,
}) {
  final relPath = repoRelPosixPath.startsWith('/')
      ? repoRelPosixPath.substring(1)
      : repoRelPosixPath;
  return _posixJoin(rootAbsPosixPath, relPath);
}

String _readPackageNameOrFallback(Directory root) {
  final pubspec = File('${root.path}${Platform.pathSeparator}pubspec.yaml');
  if (!pubspec.existsSync()) {
    return 'iwb_canvas_engine';
  }
  for (final line in pubspec.readAsLinesSync()) {
    final trimmed = line.trimLeft();
    final match = RegExp(r'^name:\s*([A-Za-z0-9_]+)\s*$').firstMatch(trimmed);
    if (match != null) {
      final packageName = match.group(1);
      if (packageName != null) {
        return packageName;
      }
    }
  }
  return 'iwb_canvas_engine';
}

String? _commandGroupForFilePosix(String filePosixPath) {
  const marker = '/lib/src/controller/commands/';
  final idx = filePosixPath.indexOf(marker);
  if (idx == -1) {
    return null;
  }
  final after = filePosixPath.substring(idx + marker.length);
  final slash = after.indexOf('/');
  if (slash == -1) {
    final dot = after.indexOf('.');
    if (dot <= 0) {
      return after.isEmpty ? null : after;
    }
    return after.substring(0, dot);
  }
  return after.substring(0, slash);
}

String? _resolveToRepoRelTargetPosix({
  required String targetPosix,
  required String packageName,
  required String fileDirRepoRelPosix,
}) {
  if (targetPosix.startsWith('dart:')) {
    return null;
  }

  if (targetPosix.startsWith('package:')) {
    final prefix = 'package:$packageName/';
    if (!targetPosix.startsWith(prefix)) {
      return null;
    }
    final rest = targetPosix.substring(prefix.length);
    return _normalizePosixPath('/lib/$rest');
  }

  return _posixJoin(fileDirRepoRelPosix, targetPosix);
}

bool _isTopLevelLibFile(String repoRelPosixPath) {
  if (!repoRelPosixPath.startsWith('/lib/') ||
      repoRelPosixPath.startsWith('/lib/src/')) {
    return false;
  }
  final remainder = repoRelPosixPath.substring('/lib/'.length);
  return remainder.isNotEmpty && !remainder.contains('/');
}

bool _matchesAnyPrefix(String value, Set<String> prefixes) {
  for (final prefix in prefixes) {
    if (value == prefix || value.startsWith(prefix)) {
      return true;
    }
  }
  return false;
}

bool _isAllowedExternalPackageImport({
  required _Layer layer,
  required String targetPosix,
}) {
  if (_matchesAnyPrefix(targetPosix, _globallyAllowedExternalPackagePrefixes)) {
    return true;
  }
  final allowedPrefixes = _allowedExternalPackagePrefixesByLayer[layer];
  return allowedPrefixes != null &&
      _matchesAnyPrefix(targetPosix, allowedPrefixes);
}

bool _isAllowedForCommands({
  required String targetPosix,
  required String? resolvedRepoRelPosix,
  required String currentCommand,
}) {
  if (targetPosix.startsWith('dart:')) {
    return true;
  }

  if (resolvedRepoRelPosix == null) {
    return false;
  }
  if (resolvedRepoRelPosix.startsWith('/lib/src/controller/commands/')) {
    final importedCommand = _commandGroupForFilePosix(resolvedRepoRelPosix);
    return importedCommand == null || importedCommand == currentCommand;
  }
  return _isAllowedCommandRepoTarget(resolvedRepoRelPosix);
}

bool _isAllowedCommandRepoTarget(String resolvedRepoRelPosix) =>
    resolvedRepoRelPosix.startsWith('/lib/src/core/') ||
    resolvedRepoRelPosix.startsWith('/lib/src/contract/') ||
    resolvedRepoRelPosix.startsWith('/lib/src/controller/') ||
    resolvedRepoRelPosix.startsWith('/lib/src/model/') ||
    resolvedRepoRelPosix == '/lib/src/controller/change_set.dart' ||
    resolvedRepoRelPosix.startsWith('/lib/src/controller/internal/');

bool _isAllowedForInternal({
  required String targetPosix,
  required String? resolvedRepoRelPosix,
}) {
  if (targetPosix.startsWith('dart:')) {
    return true;
  }

  if (resolvedRepoRelPosix == null) {
    return false;
  }
  if (resolvedRepoRelPosix.startsWith('/lib/src/core/')) {
    return true;
  }
  if (resolvedRepoRelPosix.startsWith('/lib/src/contract/')) {
    return true;
  }
  if (resolvedRepoRelPosix.startsWith('/lib/src/model/')) {
    return true;
  }
  if (resolvedRepoRelPosix == '/lib/src/controller/change_set.dart') {
    return true;
  }
  if (resolvedRepoRelPosix.startsWith('/lib/src/controller/internal/')) {
    return true;
  }
  return false;
}

Future<ParsedUnitResult> _parseUnitOrFail({
  required AnalysisContextCollection collection,
  required String absPath,
  required String repoRelPath,
}) {
  final context = collection.contextFor(absPath);
  final result = context.currentSession.getParsedUnit(absPath);
  if (result is ParsedUnitResult) {
    return Future<ParsedUnitResult>.value(result);
  }

  stderr.writeln('FAIL: import boundary violations (1)');
  stderr.writeln(
    '- $repoRelPath:1: tool failure: unable to parse Dart unit '
    '(result: ${result.runtimeType}) (parse: $repoRelPath)',
  );
  exit(1);
}

int _lineForOffset(ParsedUnitResult result, int offset) {
  return result.lineInfo.getLocation(offset).lineNumber;
}

Future<List<_BoundaryTarget>> _expandBoundaryTargets({
  required _DirectiveUriRef uriRef,
  required String packageName,
  required String fileDirRepoRelPosix,
  required _PublicLibraryExportResolver exportResolver,
}) async {
  final targetPosix = _toPosixPath(uriRef.uri);
  final resolvedRepoRelPosix = _resolveToRepoRelTargetPosix(
    targetPosix: targetPosix,
    packageName: packageName,
    fileDirRepoRelPosix: fileDirRepoRelPosix,
  );
  if (resolvedRepoRelPosix == null ||
      !_isTopLevelLibFile(resolvedRepoRelPosix)) {
    return <_BoundaryTarget>[
      _BoundaryTarget(
        targetPosix: targetPosix,
        diagnosticTarget: uriRef.uri,
        resolvedRepoRelPosix: resolvedRepoRelPosix,
      ),
    ];
  }

  final exportedTargets = await exportResolver.exportedTargets(resolvedRepoRelPosix);
  if (exportedTargets.isEmpty) {
    return <_BoundaryTarget>[
      _BoundaryTarget(
        targetPosix: targetPosix,
        diagnosticTarget: uriRef.uri,
        resolvedRepoRelPosix: resolvedRepoRelPosix,
      ),
    ];
  }

  return exportedTargets
      .map(
        (exportedTarget) => _BoundaryTarget(
          targetPosix: exportedTarget.targetPosix,
          diagnosticTarget:
              '${uriRef.uri} -> ${exportedTarget.diagnosticTarget}',
          resolvedRepoRelPosix: exportedTarget.resolvedRepoRelPosix,
        ),
      )
      .toList(growable: false);
}

class _DirectiveBoundaryChecker {
  _DirectiveBoundaryChecker({
    required this.parsed,
    required this.filePosixPath,
    required this.fileLayer,
    required this.packageName,
    required this.exportResolver,
    required this.violations,
  }) : fileDirRepoRelPosix = _posixDirname(filePosixPath),
       isCommandScopeFile = filePosixPath.startsWith(
         '/lib/src/controller/commands/',
       ),
       isInternalFile = filePosixPath.startsWith(
         '/lib/src/controller/internal/',
       ),
       currentCommand =
           filePosixPath.startsWith('/lib/src/controller/commands/')
           ? _commandGroupForFilePosix(filePosixPath)
           : null;

  final ParsedUnitResult parsed;
  final String filePosixPath;
  final _Layer fileLayer;
  final String packageName;
  final _PublicLibraryExportResolver exportResolver;
  final List<_Violation> violations;
  final String fileDirRepoRelPosix;
  final bool isCommandScopeFile;
  final bool isInternalFile;
  final String? currentCommand;

  Future<void> checkDirective(Directive directive) async {
    _checkCommandPartBan(directive);
    final directiveKind = _directiveKind(directive);
    if (directiveKind == null) {
      return;
    }
    if (_hasNamedPartOfViolation(directive, directiveKind)) {
      return;
    }
    for (final uriRef in _collectBoundaryDirectiveUriRefs(directive)) {
      await _checkUriRef(directiveKind, uriRef);
    }
  }

  Future<void> checkDocumentationLinks() async {
    if (!filePosixPath.startsWith('/lib/src/')) {
      return;
    }
    for (final uriRef in _collectDocImportUriRefs(parsed.unit)) {
      await _checkUriRef('link', uriRef);
    }
  }

  Future<void> _checkUriRef(
    String directiveKind,
    _DirectiveUriRef uriRef,
  ) async {
    final lineNo = _lineForOffset(parsed, uriRef.offset);
    final boundaryTargets = await _expandBoundaryTargets(
      uriRef: uriRef,
      packageName: packageName,
      fileDirRepoRelPosix: fileDirRepoRelPosix,
      exportResolver: exportResolver,
    );
    for (final boundaryTarget in boundaryTargets) {
      _enforceBoundaryTarget(directiveKind, lineNo, boundaryTarget);
    }
  }

  void _enforceBoundaryTarget(
    String directiveKind,
    int lineNo,
    _BoundaryTarget boundaryTarget,
  ) {
    if (isCommandScopeFile || isInternalFile) {
      _enforceControllerStructurePolicy(directiveKind, lineNo, boundaryTarget);
      return;
    }
    _enforceGeneralLayerPolicy(directiveKind, lineNo, boundaryTarget);
  }

  void _enforceGeneralLayerPolicy(
    String directiveKind,
    int lineNo,
    _BoundaryTarget boundaryTarget,
  ) {
    if (boundaryTarget.isDartSdk) {
      return;
    }
    if (boundaryTarget.isExternalPackage) {
      if (_isAllowedExternalPackageImport(
        layer: fileLayer,
        targetPosix: boundaryTarget.targetPosix,
      )) {
        return;
      }
      _addViolation(
        line: lineNo,
        directive: directiveKind,
        target: boundaryTarget.diagnosticTarget,
        message:
            'external package violation: ${_layerLabel(fileLayer)}/** must not '
            '$directiveKind ${boundaryTarget.targetPosix}',
      );
      return;
    }

    final resolvedRepoRelPosix = boundaryTarget.resolvedRepoRelPosix;
    if (resolvedRepoRelPosix == null ||
        !resolvedRepoRelPosix.startsWith('/lib/src/')) {
      return;
    }

    _checkGeneralInternalTarget(
      directiveKind,
      lineNo,
      boundaryTarget,
      resolvedRepoRelPosix,
    );
  }

  void _checkGeneralInternalTarget(
    String directiveKind,
    int lineNo,
    _BoundaryTarget boundaryTarget,
    String resolvedRepoRelPosix,
  ) {
    final targetLayer = _layerForRepoRelPosixPath(resolvedRepoRelPosix);
    if (targetLayer == null) {
      _addLayoutViolation(
        line: lineNo,
        directiveKind: directiveKind,
        target: boundaryTarget.diagnosticTarget,
        repoRelPosixPath: resolvedRepoRelPosix,
      );
      return;
    }
    if (_isAllowedLayerDependency(from: fileLayer, to: targetLayer)) {
      return;
    }

    _addViolation(
      line: lineNo,
      directive: directiveKind,
      target: boundaryTarget.diagnosticTarget,
      message:
          'layer DAG violation: ${_layerLabel(fileLayer)}/** must not '
          '$directiveKind ${_layerLabel(targetLayer)}/** ($resolvedRepoRelPosix)',
    );
  }

  void _enforceControllerStructurePolicy(
    String directiveKind,
    int lineNo,
    _BoundaryTarget boundaryTarget,
  ) {
    if (boundaryTarget.isDartSdk) {
      return;
    }
    if (boundaryTarget.isExternalPackage) {
      _checkControllerExternalPackage(directiveKind, lineNo, boundaryTarget);
      return;
    }

    final resolvedRepoRelPosix = boundaryTarget.resolvedRepoRelPosix;
    if (_checkSceneControllerImport(
      directiveKind,
      lineNo,
      boundaryTarget,
      resolvedRepoRelPosix,
    )) {
      return;
    }

    final hasSpecificViolation = _checkControllerSpecificViolations(
      directiveKind,
      lineNo,
      boundaryTarget,
      resolvedRepoRelPosix,
    );
    if (hasSpecificViolation || _isAllowedControllerTarget(boundaryTarget)) {
      return;
    }

    _addViolation(
      line: lineNo,
      directive: directiveKind,
      target: boundaryTarget.diagnosticTarget,
      message:
          'controller structure violation: ${_controllerScope()} has a '
          'disallowed $directiveKind target '
          '(${resolvedRepoRelPosix ?? boundaryTarget.targetPosix})',
    );
  }

  void _checkControllerExternalPackage(
    String directiveKind,
    int lineNo,
    _BoundaryTarget boundaryTarget,
  ) {
    if (_isAllowedExternalPackageImport(
      layer: fileLayer,
      targetPosix: boundaryTarget.targetPosix,
    )) {
      return;
    }
    _addViolation(
      line: lineNo,
      directive: directiveKind,
      target: boundaryTarget.diagnosticTarget,
      message:
          'controller structure violation: ${_controllerScope()} has a '
          'disallowed external package $directiveKind',
    );
  }

  bool _checkSceneControllerImport(
    String directiveKind,
    int lineNo,
    _BoundaryTarget boundaryTarget,
    String? resolvedRepoRelPosix,
  ) {
    if (resolvedRepoRelPosix != '/lib/src/controller/scene_controller.dart') {
      return false;
    }
    _addViolation(
      line: lineNo,
      directive: directiveKind,
      target: boundaryTarget.diagnosticTarget,
      message:
          'controller structure violation: ${_controllerScope()} must not '
          '$directiveKind controller/scene_controller.dart',
    );
    return true;
  }

  bool _checkControllerSpecificViolations(
    String directiveKind,
    int lineNo,
    _BoundaryTarget boundaryTarget,
    String? resolvedRepoRelPosix,
  ) {
    var hasViolation = false;
    if (resolvedRepoRelPosix == null) {
      return false;
    }

    if (_checkInternalCommandsImport(
      directiveKind,
      lineNo,
      boundaryTarget,
      resolvedRepoRelPosix,
    )) {
      hasViolation = true;
    }
    if (_checkCrossCommandImport(
      directiveKind,
      lineNo,
      boundaryTarget,
      resolvedRepoRelPosix,
    )) {
      hasViolation = true;
    }
    if (_checkUnknownLibSrcTarget(
      directiveKind,
      lineNo,
      boundaryTarget,
      resolvedRepoRelPosix,
    )) {
      hasViolation = true;
    }
    return hasViolation;
  }

  bool _checkInternalCommandsImport(
    String directiveKind,
    int lineNo,
    _BoundaryTarget boundaryTarget,
    String resolvedRepoRelPosix,
  ) {
    if (!isInternalFile ||
        !resolvedRepoRelPosix.startsWith('/lib/src/controller/commands/')) {
      return false;
    }
    _addViolation(
      line: lineNo,
      directive: directiveKind,
      target: boundaryTarget.diagnosticTarget,
      message:
          'controller structure violation: internal/** must not '
          '$directiveKind commands/**',
    );
    return true;
  }

  bool _checkCrossCommandImport(
    String directiveKind,
    int lineNo,
    _BoundaryTarget boundaryTarget,
    String resolvedRepoRelPosix,
  ) {
    if (!isCommandScopeFile ||
        !resolvedRepoRelPosix.startsWith('/lib/src/controller/commands/')) {
      return false;
    }
    final importedCommand = _commandGroupForFilePosix(resolvedRepoRelPosix);
    if (currentCommand == null ||
        importedCommand == null ||
        importedCommand == currentCommand) {
      return false;
    }
    _addViolation(
      line: lineNo,
      directive: directiveKind,
      target: boundaryTarget.diagnosticTarget,
      message:
          'controller structure violation: commands/** must not '
          '$directiveKind other commands '
          '(current=$currentCommand, import=$importedCommand)',
    );
    return true;
  }

  bool _checkUnknownLibSrcTarget(
    String directiveKind,
    int lineNo,
    _BoundaryTarget boundaryTarget,
    String resolvedRepoRelPosix,
  ) {
    if (!_isLibSrcTarget(resolvedRepoRelPosix) ||
        _layerForRepoRelPosixPath(resolvedRepoRelPosix) != null) {
      return false;
    }
    _addLayoutViolation(
      line: lineNo,
      directiveKind: directiveKind,
      target: boundaryTarget.diagnosticTarget,
      repoRelPosixPath: resolvedRepoRelPosix,
    );
    return true;
  }

  bool _isAllowedControllerTarget(_BoundaryTarget boundaryTarget) {
    return isCommandScopeFile
        ? _isAllowedCommandTarget(boundaryTarget)
        : _isAllowedInternalTarget(boundaryTarget);
  }

  bool _isAllowedCommandTarget(_BoundaryTarget boundaryTarget) {
    final command = currentCommand;
    if (command == null) {
      return false;
    }
    return _isAllowedForCommands(
      targetPosix: boundaryTarget.targetPosix,
      resolvedRepoRelPosix: boundaryTarget.resolvedRepoRelPosix,
      currentCommand: command,
    );
  }

  bool _isAllowedInternalTarget(_BoundaryTarget boundaryTarget) {
    return _isAllowedForInternal(
      targetPosix: boundaryTarget.targetPosix,
      resolvedRepoRelPosix: boundaryTarget.resolvedRepoRelPosix,
    );
  }

  void _checkCommandPartBan(Directive directive) {
    if (!isCommandScopeFile ||
        (directive is! PartDirective && directive is! PartOfDirective)) {
      return;
    }
    _addViolation(
      line: _lineForOffset(parsed, directive.offset),
      directive: 'part',
      target: directive.toSource(),
      message:
          'controller structure violation: commands/** must not use '
          'part/part of directives',
    );
  }

  bool _hasNamedPartOfViolation(Directive directive, String directiveKind) {
    if (directive is! PartOfDirective) {
      return false;
    }
    final libraryName = directive.libraryName;
    if (libraryName == null) {
      return false;
    }
    _addViolation(
      line: _lineForOffset(parsed, libraryName.offset),
      directive: directiveKind,
      target: libraryName.toSource(),
      message:
          'part boundary violation: lib/src/** must use URI-based part of '
          'directives so boundary targets remain analyzable',
    );
    return true;
  }

  String? _directiveKind(Directive directive) => switch (directive) {
    ImportDirective() => 'import',
    ExportDirective() => 'export',
    PartDirective() => 'part',
    PartOfDirective() => 'part of',
    _ => null,
  };

  String _controllerScope() =>
      isCommandScopeFile ? 'commands/**' : 'internal/**';

  void _addLayoutViolation({
    required int line,
    required String directiveKind,
    required String target,
    required String repoRelPosixPath,
  }) {
    final layoutViolation = describeLibSrcLayoutViolation(repoRelPosixPath);
    _addViolation(
      line: line,
      directive: directiveKind,
      target: target,
      message:
          layoutViolation ??
          'layer layout violation: unresolved target layer for '
              '$repoRelPosixPath',
    );
  }

  void _addViolation({
    required int line,
    required String directive,
    required String target,
    required String message,
  }) {
    violations.add(
      _Violation(
        filePath: filePosixPath,
        line: line,
        directive: directive,
        target: target,
        message: message,
      ),
    );
  }
}

class _ImportBoundaryChecker {
  _ImportBoundaryChecker()
    : rootAbsPosix = _toPosixPath(Directory.current.absolute.path),
      packageName = _readPackageNameOrFallback(Directory.current),
      srcRoot = Directory(
        '${Directory.current.path}${Platform.pathSeparator}lib'
        '${Platform.pathSeparator}src',
      ),
      analysisCollection = AnalysisContextCollection(
        includedPaths: <String>[Directory.current.absolute.path],
      );

  final String rootAbsPosix;
  final String packageName;
  final Directory srcRoot;
  final AnalysisContextCollection analysisCollection;
  final List<_Violation> violations = <_Violation>[];

  late final _PublicLibraryExportResolver exportResolver =
      _PublicLibraryExportResolver(
        collection: analysisCollection,
        rootAbsPosixPath: rootAbsPosix,
        packageName: packageName,
      );

  bool get hasSourceRoot => srcRoot.existsSync();

  Future<List<_Violation>> collectViolations() async {
    final disallowedEntries = _recordTopLevelLayoutViolations();
    final dartFiles = _listDartFiles();
    for (final file in dartFiles) {
      await _checkFile(file, disallowedEntries);
    }
    return violations;
  }

  Set<String> _recordTopLevelLayoutViolations() {
    final disallowedEntries = <String>{};
    final topLevelLayoutViolations = collectTopLevelLibSrcLayoutViolations(
      srcRoot: srcRoot,
      rootAbsPosixPath: rootAbsPosix,
      toPosixPath: _toPosixPath,
      toRepoRelPosixPath: _toRepoRelPosixPath,
    );
    for (final layoutViolation in topLevelLayoutViolations) {
      disallowedEntries.add(layoutViolation.entry);
      violations.add(
        _Violation(
          filePath: layoutViolation.path,
          line: 1,
          directive: 'layer',
          target: layoutViolation.path,
          message: layoutViolation.message,
        ),
      );
    }
    return disallowedEntries;
  }

  List<File> _listDartFiles() {
    final files = srcRoot
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList(growable: false);
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  Future<void> _checkFile(File entity, Set<String> disallowedEntries) async {
    final filePosixPath = _fileRepoRelPosixPath(entity);
    if (_shouldSkipFile(filePosixPath, disallowedEntries)) {
      return;
    }

    final fileLayer = _layerForRepoRelPosixPath(filePosixPath);
    if (fileLayer == null) {
      _recordUnknownLayerFile(filePosixPath);
      return;
    }

    final parsed = await _parseUnitOrFail(
      collection: analysisCollection,
      absPath: entity.absolute.path,
      repoRelPath: filePosixPath,
    );
    final checker = _DirectiveBoundaryChecker(
      parsed: parsed,
      filePosixPath: filePosixPath,
      fileLayer: fileLayer,
      packageName: packageName,
      exportResolver: exportResolver,
      violations: violations,
    );
    for (final directive in parsed.unit.directives) {
      await checker.checkDirective(directive);
    }
    await checker.checkDocumentationLinks();
  }

  String _fileRepoRelPosixPath(File entity) {
    final fileAbsPosixPath = _toPosixPath(entity.absolute.path);
    return _toRepoRelPosixPath(
      absPosixPath: fileAbsPosixPath,
      rootAbsPosixPath: rootAbsPosix,
    );
  }

  bool _shouldSkipFile(String filePosixPath, Set<String> disallowedEntries) {
    final topLevelEntry = topLevelLibSrcEntryForRepoRelPosixPath(filePosixPath);
    return topLevelEntry != null && disallowedEntries.contains(topLevelEntry);
  }

  void _recordUnknownLayerFile(String filePosixPath) {
    if (!filePosixPath.startsWith('/lib/src/')) {
      return;
    }
    final layoutViolation = describeLibSrcLayoutViolation(filePosixPath);
    violations.add(
      _Violation(
        filePath: filePosixPath,
        line: 1,
        directive: 'layer',
        target: filePosixPath,
        message:
            layoutViolation ??
            'layer layout violation: file is under lib/src/** '
                'but has no known layer',
      ),
    );
  }
}

bool _isLibSrcTarget(String? resolvedRepoRelPosix) =>
    resolvedRepoRelPosix != null &&
    resolvedRepoRelPosix.startsWith('/lib/src/');

Future<void> main(List<String> _) async {
  final checker = _ImportBoundaryChecker();
  if (!checker.hasSourceRoot) {
    stderr.writeln('No lib/src directory found. Nothing to check.');
    exit(0);
  }

  final violations = await checker.collectViolations();
  if (violations.isEmpty) {
    stdout.writeln('OK: import boundaries');
    exit(0);
  }

  stderr.writeln('FAIL: import boundary violations (${violations.length})');
  for (final violation in violations) {
    stderr.writeln('- $violation');
  }
  exit(1);
}
