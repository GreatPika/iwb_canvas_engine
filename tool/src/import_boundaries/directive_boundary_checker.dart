import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';

import '../guardrail_support/guardrail_ast_utils.dart';
import '../guardrail_support/guardrail_path_utils.dart';
import '../layer_guardrails.dart';
import 'import_boundary_policy.dart';
import 'public_export_boundary_resolver.dart';

class ImportBoundaryViolation {
  ImportBoundaryViolation({
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

class DirectiveBoundaryChecker {
  DirectiveBoundaryChecker({
    required this.parsed,
    required this.filePosixPath,
    required this.fileLayer,
    required this.exportResolver,
    required this.violations,
  }) : fileDirRepoRelPosix = posixDirname(filePosixPath),
       isCommandScopeFile = filePosixPath.startsWith(
         '/lib/src/controller/commands/',
       ),
       isInternalFile = filePosixPath.startsWith(
         '/lib/src/controller/internal/',
       ),
       currentCommand =
           filePosixPath.startsWith('/lib/src/controller/commands/')
           ? commandGroupForFilePosix(filePosixPath)
           : null;

  final ParsedUnitResult parsed;
  final String filePosixPath;
  final ImportBoundaryLayer fileLayer;
  final PublicExportBoundaryResolver exportResolver;
  final List<ImportBoundaryViolation> violations;
  final String fileDirRepoRelPosix;
  final bool isCommandScopeFile;
  final bool isInternalFile;
  final String? currentCommand;

  void checkDirective(Directive directive) {
    _checkCommandPartBan(directive);
    final directiveKind = _directiveKind(directive);
    if (directiveKind == null) {
      return;
    }
    if (_hasNamedPartOfViolation(directive, directiveKind)) {
      return;
    }
    for (final uriRef in collectBoundaryDirectiveUriRefs(directive)) {
      _checkUriRef(directiveKind, uriRef);
    }
  }

  void checkDocumentationLinks() {
    if (!filePosixPath.startsWith('/lib/src/')) {
      return;
    }
    for (final uriRef in collectDocImportUriRefs(parsed.unit)) {
      _checkUriRef('link', uriRef);
    }
  }

  void _checkUriRef(String directiveKind, DirectiveUriRef uriRef) {
    final lineNo = lineForOffset(parsed, uriRef.offset);
    final boundaryTargets = exportResolver.expandBoundaryTargets(
      uriRef: uriRef,
      fileDirRepoRelPosix: fileDirRepoRelPosix,
    );
    for (final boundaryTarget in boundaryTargets) {
      _enforceBoundaryTarget(directiveKind, lineNo, boundaryTarget);
    }
  }

  void _enforceBoundaryTarget(
    String directiveKind,
    int lineNo,
    BoundaryTarget boundaryTarget,
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
    BoundaryTarget boundaryTarget,
  ) {
    if (boundaryTarget.isDartSdk) {
      return;
    }
    final externalPackageViolation = _externalPackageViolation(
      directiveKind: directiveKind,
      lineNo: lineNo,
      boundaryTarget: boundaryTarget,
    );
    if (externalPackageViolation) {
      return;
    }

    final resolvedRepoRelPosix = boundaryTarget.resolvedRepoRelPosix;
    if (resolvedRepoRelPosix == null ||
        !resolvedRepoRelPosix.startsWith('/lib/src/')) {
      return;
    }

    _enforceResolvedLayerTarget(
      directiveKind: directiveKind,
      lineNo: lineNo,
      boundaryTarget: boundaryTarget,
      resolvedRepoRelPosix: resolvedRepoRelPosix,
    );
  }

  bool _externalPackageViolation({
    required String directiveKind,
    required int lineNo,
    required BoundaryTarget boundaryTarget,
  }) {
    if (!boundaryTarget.isExternalPackage) {
      return false;
    }
    if (isAllowedExternalPackageImport(
      layer: fileLayer,
      targetPosix: boundaryTarget.targetPosix,
    )) {
      return true;
    }
    _addViolation(
      line: lineNo,
      directive: directiveKind,
      target: boundaryTarget.diagnosticTarget,
      message:
          'external package violation: ${layerLabel(fileLayer)}/** must not '
          '$directiveKind ${boundaryTarget.targetPosix}',
    );
    return true;
  }

  void _enforceResolvedLayerTarget({
    required String directiveKind,
    required int lineNo,
    required BoundaryTarget boundaryTarget,
    required String resolvedRepoRelPosix,
  }) {
    if (isViewPointerSemanticsBoundaryFile(filePosixPath) &&
        resolvedRepoRelPosix.startsWith('/lib/src/interactive/internal/') &&
        !isAllowedViewPointerSemanticsInternalTarget(resolvedRepoRelPosix)) {
      _addViolation(
        line: lineNo,
        directive: directiveKind,
        target: boundaryTarget.diagnosticTarget,
        message:
            'pointer-semantics boundary violation: '
            '${filePosixPath.substring('/lib/src/'.length)} must not '
            '$directiveKind interactive/internal/** outside '
            'scene_controller_internal_access.dart '
            '($resolvedRepoRelPosix)',
      );
      return;
    }
    final targetLayer = layerForRepoRelPosixPath(resolvedRepoRelPosix);
    if (targetLayer == null) {
      _addLayoutViolation(
        line: lineNo,
        directiveKind: directiveKind,
        target: boundaryTarget.diagnosticTarget,
        repoRelPosixPath: resolvedRepoRelPosix,
      );
      return;
    }
    if (isAllowedLayerDependency(from: fileLayer, to: targetLayer)) {
      return;
    }
    _addViolation(
      line: lineNo,
      directive: directiveKind,
      target: boundaryTarget.diagnosticTarget,
      message:
          'layer DAG violation: ${layerLabel(fileLayer)}/** must not '
          '$directiveKind ${layerLabel(targetLayer)}/** ($resolvedRepoRelPosix)',
    );
  }

  void _enforceControllerStructurePolicy(
    String directiveKind,
    int lineNo,
    BoundaryTarget boundaryTarget,
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
    BoundaryTarget boundaryTarget,
  ) {
    if (isAllowedExternalPackageImport(
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
    BoundaryTarget boundaryTarget,
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
    BoundaryTarget boundaryTarget,
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
    BoundaryTarget boundaryTarget,
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
    BoundaryTarget boundaryTarget,
    String resolvedRepoRelPosix,
  ) {
    if (!isCommandScopeFile ||
        !resolvedRepoRelPosix.startsWith('/lib/src/controller/commands/')) {
      return false;
    }
    final importedCommand = commandGroupForFilePosix(resolvedRepoRelPosix);
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
    BoundaryTarget boundaryTarget,
    String resolvedRepoRelPosix,
  ) {
    if (!isLibSrcTarget(resolvedRepoRelPosix) ||
        layerForRepoRelPosixPath(resolvedRepoRelPosix) != null) {
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

  bool _isAllowedControllerTarget(BoundaryTarget boundaryTarget) {
    return isCommandScopeFile
        ? _isAllowedCommandTarget(boundaryTarget)
        : _isAllowedInternalTarget(boundaryTarget);
  }

  bool _isAllowedCommandTarget(BoundaryTarget boundaryTarget) {
    final command = currentCommand;
    if (command == null) {
      return false;
    }
    return isAllowedForCommands(
      targetPosix: boundaryTarget.targetPosix,
      resolvedRepoRelPosix: boundaryTarget.resolvedRepoRelPosix,
      currentCommand: command,
    );
  }

  bool _isAllowedInternalTarget(BoundaryTarget boundaryTarget) {
    return isAllowedForInternal(
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
      line: lineForOffset(parsed, directive.offset),
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
      line: lineForOffset(parsed, libraryName.offset),
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
      ImportBoundaryViolation(
        filePath: filePosixPath,
        line: line,
        directive: directive,
        target: target,
        message: message,
      ),
    );
  }
}
