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

bool _isInDisallowedTopLevelLibSrcLayer(
  String repoRelPosixPath,
  Set<String> disallowedTopLevelLayers,
) {
  final topLevelLayer = topLevelLibSrcLayerForRepoRelPosixPath(
    repoRelPosixPath,
  );
  if (topLevelLayer == null) {
    return false;
  }
  return disallowedTopLevelLayers.contains(topLevelLayer);
}

String? _nestedLibSrcLayoutViolation(String repoRelPosixPath) {
  if (directChildUnderLibSrcForRepoRelPosixPath(repoRelPosixPath) != null) {
    return null;
  }
  return describeLibSrcLayoutViolation(repoRelPosixPath);
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
  final n = _normalizePosixPath(posixPath);
  if (n == '/' || n.isEmpty) {
    return n;
  }
  final idx = n.lastIndexOf('/');
  if (idx <= 0) {
    return n.startsWith('/') ? '/' : '';
  }
  return n.substring(0, idx);
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

String _readPackageNameOrFallback(Directory root) {
  final pubspec = File('${root.path}${Platform.pathSeparator}pubspec.yaml');
  if (!pubspec.existsSync()) {
    return 'iwb_canvas_engine';
  }
  for (final line in pubspec.readAsLinesSync()) {
    final trimmed = line.trimLeft();
    final match = RegExp(r'^name:\s*([A-Za-z0-9_]+)\s*$').firstMatch(trimmed);
    if (match != null) {
      return match.group(1)!;
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
  final isDart = targetPosix.startsWith('dart:');
  if (isDart) {
    return null;
  }

  final isPackage = targetPosix.startsWith('package:');
  if (isPackage) {
    final prefix = 'package:$packageName/';
    if (!targetPosix.startsWith(prefix)) {
      return null;
    }
    final rest = targetPosix.substring(prefix.length);
    return _normalizePosixPath('/lib/$rest');
  }

  return _posixJoin(fileDirRepoRelPosix, targetPosix);
}

bool _isAllowedForCommands({
  required String targetPosix,
  required String? resolvedRepoRelPosix,
  required String currentCommand,
}) {
  if (targetPosix.startsWith('dart:')) {
    return true;
  }
  if (targetPosix.startsWith('package:flutter/')) {
    return true;
  }
  if (targetPosix.startsWith('package:meta/')) {
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
  if (resolvedRepoRelPosix.startsWith('/lib/src/controller/')) return true;
  if (resolvedRepoRelPosix.startsWith('/lib/src/model/')) return true;
  if (resolvedRepoRelPosix.startsWith('/lib/src/controller/commands/')) {
    final importedCommand = _commandGroupForFilePosix(resolvedRepoRelPosix);
    return importedCommand == null || importedCommand == currentCommand;
  }
  if (resolvedRepoRelPosix.startsWith('/lib/src/controller/internal/')) {
    return true;
  }

  return false;
}

bool _isAllowedForInternal({
  required String targetPosix,
  required String? resolvedRepoRelPosix,
}) {
  if (targetPosix.startsWith('dart:')) {
    return true;
  }
  if (targetPosix.startsWith('package:flutter/')) {
    return true;
  }
  if (targetPosix.startsWith('package:meta/')) {
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

Future<void> main(List<String> args) async {
  final root = Directory.current;
  final rootAbsPosix = _toPosixPath(root.absolute.path);
  final packageName = _readPackageNameOrFallback(root);
  final srcRoot = Directory(
    '${root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}src',
  );

  if (!srcRoot.existsSync()) {
    stderr.writeln('No lib/src directory found. Nothing to check.');
    exit(0);
  }

  final analysisCollection = AnalysisContextCollection(
    includedPaths: <String>[root.absolute.path],
  );

  final violations = <_Violation>[];
  final topLevelLayoutViolations = collectTopLevelLibSrcLayoutViolations(
    srcRoot: srcRoot,
    rootAbsPosixPath: rootAbsPosix,
    toPosixPath: _toPosixPath,
    toRepoRelPosixPath: _toRepoRelPosixPath,
  );
  final disallowedTopLevelLayers = <String>{};
  for (final layoutViolation in topLevelLayoutViolations) {
    disallowedTopLevelLayers.add(layoutViolation.layer);
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

  final dartFiles =
      srcRoot
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList(growable: false)
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final entity in dartFiles) {
    final fileAbsPosixPath = _toPosixPath(entity.absolute.path);
    final filePosixPath = _toRepoRelPosixPath(
      absPosixPath: fileAbsPosixPath,
      rootAbsPosixPath: rootAbsPosix,
    );
    if (directChildUnderLibSrcForRepoRelPosixPath(filePosixPath) != null) {
      continue;
    }
    if (_isInDisallowedTopLevelLibSrcLayer(
      filePosixPath,
      disallowedTopLevelLayers,
    )) {
      continue;
    }
    final fileLayer = _layerForRepoRelPosixPath(filePosixPath);
    if (filePosixPath.startsWith('/lib/src/') && fileLayer == null) {
      final layoutViolation = _nestedLibSrcLayoutViolation(filePosixPath);
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
      continue;
    }
    if (fileLayer == null) {
      continue;
    }

    final parsed = await _parseUnitOrFail(
      collection: analysisCollection,
      absPath: entity.absolute.path,
      repoRelPath: filePosixPath,
    );

    final isCommandFile = filePosixPath.startsWith(
      '/lib/src/controller/commands/',
    );
    final isCommandScopeFile = isCommandFile;
    final isInternalFile = filePosixPath.startsWith(
      '/lib/src/controller/internal/',
    );

    final currentCommand = isCommandFile
        ? _commandGroupForFilePosix(filePosixPath)
        : null;
    final fileDirRepoRelPosix = _posixDirname(filePosixPath);

    for (final directive in parsed.unit.directives) {
      final directiveLineNo = _lineForOffset(parsed, directive.offset);

      if (isCommandScopeFile &&
          (directive is PartDirective || directive is PartOfDirective)) {
        violations.add(
          _Violation(
            filePath: filePosixPath,
            line: directiveLineNo,
            directive: 'part',
            target: directive.toSource(),
            message:
                'controller structure violation: commands/** must not use '
                'part/part of directives',
          ),
        );
      }

      final isImport = directive is ImportDirective;
      final isExport = directive is ExportDirective;
      if (!isImport && !isExport) {
        continue;
      }

      final directiveKind = isImport ? 'import' : 'export';
      final uriDirective = directive as UriBasedDirective;
      for (final uriRef in _collectDirectiveUriRefs(uriDirective)) {
        final lineNo = _lineForOffset(parsed, uriRef.offset);
        final target = uriRef.uri;
        final targetPosix = _toPosixPath(target);
        final resolvedRepoRelPosix = _resolveToRepoRelTargetPosix(
          targetPosix: targetPosix,
          packageName: packageName,
          fileDirRepoRelPosix: fileDirRepoRelPosix,
        );

        if (!isCommandScopeFile && !isInternalFile) {
          if (resolvedRepoRelPosix != null &&
              resolvedRepoRelPosix.startsWith('/lib/src/')) {
            final targetLayer = _layerForRepoRelPosixPath(resolvedRepoRelPosix);
            if (targetLayer == null) {
              final layoutViolation = _nestedLibSrcLayoutViolation(
                resolvedRepoRelPosix,
              );
              violations.add(
                _Violation(
                  filePath: filePosixPath,
                  line: lineNo,
                  directive: directiveKind,
                  target: target,
                  message:
                      layoutViolation ??
                      'layer layout violation: unresolved target '
                          'layer for $resolvedRepoRelPosix',
                ),
              );
            } else if (!_isAllowedLayerDependency(
              from: fileLayer,
              to: targetLayer,
            )) {
              violations.add(
                _Violation(
                  filePath: filePosixPath,
                  line: lineNo,
                  directive: directiveKind,
                  target: target,
                  message:
                      'layer DAG violation: '
                      '${_layerLabel(fileLayer)}/** must not $directiveKind '
                      '${_layerLabel(targetLayer)}/** '
                      '($resolvedRepoRelPosix)',
                ),
              );
            }
          }
          continue;
        }

        var hasSpecificViolation = false;
        final controllerScope = isCommandScopeFile
            ? 'commands/**'
            : 'internal/**';

        if (resolvedRepoRelPosix ==
            '/lib/src/controller/scene_controller.dart') {
          violations.add(
            _Violation(
              filePath: filePosixPath,
              line: lineNo,
              directive: directiveKind,
              target: target,
              message:
                  'controller structure violation: $controllerScope must not '
                  '$directiveKind controller/scene_controller.dart',
            ),
          );
          hasSpecificViolation = true;
        }

        if (resolvedRepoRelPosix != null) {
          if (isInternalFile &&
              resolvedRepoRelPosix.startsWith(
                '/lib/src/controller/commands/',
              )) {
            violations.add(
              _Violation(
                filePath: filePosixPath,
                line: lineNo,
                directive: directiveKind,
                target: target,
                message:
                    'controller structure violation: internal/** must not '
                    '$directiveKind commands/**',
              ),
            );
            hasSpecificViolation = true;
          }

          if (isCommandScopeFile &&
              resolvedRepoRelPosix.startsWith(
                '/lib/src/controller/commands/',
              )) {
            final importedCommand = _commandGroupForFilePosix(
              resolvedRepoRelPosix,
            );
            if (currentCommand != null &&
                importedCommand != null &&
                importedCommand != currentCommand) {
              violations.add(
                _Violation(
                  filePath: filePosixPath,
                  line: lineNo,
                  directive: directiveKind,
                  target: target,
                  message:
                      'controller structure violation: commands/** must not '
                      '$directiveKind other commands '
                      '(current=$currentCommand, import=$importedCommand)',
                ),
              );
              hasSpecificViolation = true;
            }
          }
        }

        final allowed = isCommandScopeFile
            ? (currentCommand != null &&
                  _isAllowedForCommands(
                    targetPosix: targetPosix,
                    resolvedRepoRelPosix: resolvedRepoRelPosix,
                    currentCommand: currentCommand,
                  ))
            : _isAllowedForInternal(
                targetPosix: targetPosix,
                resolvedRepoRelPosix: resolvedRepoRelPosix,
              );
        if (!allowed && !hasSpecificViolation) {
          final details = resolvedRepoRelPosix ?? targetPosix;
          final isExternalPackage =
              resolvedRepoRelPosix == null &&
              targetPosix.startsWith('package:');
          final message = isExternalPackage
              ? 'controller structure violation: $controllerScope has a '
                    'disallowed external package $directiveKind'
              : 'controller structure violation: $controllerScope has a '
                    'disallowed $directiveKind target';
          violations.add(
            _Violation(
              filePath: filePosixPath,
              line: lineNo,
              directive: directiveKind,
              target: target,
              message: '$message ($details)',
            ),
          );
        }
      }
    }
  }

  if (violations.isEmpty) {
    stdout.writeln('OK: import boundaries');
    exit(0);
  }

  stderr.writeln('FAIL: import boundary violations (${violations.length})');
  for (final v in violations) {
    stderr.writeln('- $v');
  }
  exit(1);
}
