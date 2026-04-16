import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';

import '../../support/guardrail_ast_utils.dart';
import '../../support/guardrail_context.dart';
import '../../support/guardrail_path_utils.dart';
import '../../core/guardrail_violation.dart';
import '../../../layer_guardrails.dart';

enum ExportedApiScanMode { fullScan, targetedSkip }

class ExportedApiScanPolicy {
  const ExportedApiScanPolicy.fullScan()
    : bannedTypeNames = mutableContractTypeNames,
      mode = ExportedApiScanMode.fullScan,
      reason = null,
      skippedTopLevelNames = const <String>{};

  const ExportedApiScanPolicy.targetedSkip({
    required this.reason,
    required this.skippedTopLevelNames,
    this.bannedTypeNames = mutableContractTypeNames,
  }) : mode = ExportedApiScanMode.targetedSkip;

  final ExportedApiScanMode mode;
  final String? reason;
  final Set<String> skippedTopLevelNames;
  final Set<String> bannedTypeNames;
}

class ExportedLibrarySurface {
  const ExportedLibrarySurface({
    required this.repoRelPath,
    required this.directiveCombinators,
  });

  final String repoRelPath;
  final List<DirectiveCombinators> directiveCombinators;

  bool get exportsUnnamedExtensions =>
      directiveCombinators.any((directive) => directive.exportsAllNames);

  bool exportsTopLevelName(String name) {
    return directiveCombinators.any(
      (directive) => directive.exportsTopLevelName(name),
    );
  }
}

enum DirectiveFilterMode { show, hide }

class DirectiveFilter {
  const DirectiveFilter({required this.mode, required this.names});

  final DirectiveFilterMode mode;
  final Set<String> names;
}

class DirectiveCombinators {
  const DirectiveCombinators({
    required this.exportsAllNames,
    required this.filters,
  });

  final bool exportsAllNames;
  final List<DirectiveFilter> filters;

  bool exportsTopLevelName(String name) {
    var isVisible = exportsAllNames;
    for (final filter in filters) {
      switch (filter.mode) {
        case DirectiveFilterMode.show:
          isVisible = filter.names.contains(name);
        case DirectiveFilterMode.hide:
          if (filter.names.contains(name)) {
            isVisible = false;
          }
      }
    }
    return isVisible;
  }
}

class PublicSurfaceGuardrailResult {
  const PublicSurfaceGuardrailResult({
    required this.exportedSurfaces,
    required this.violations,
  });

  final Map<String, ExportedLibrarySurface> exportedSurfaces;
  final List<GuardrailViolation> violations;
}

const Set<String> mutableCoreTypeNames = <String>{
  'Scene',
  'ContentLayer',
  'SceneNode',
  'NodeType',
};

const Set<String> mutableRuntimeTypeNames = <String>{
  'SceneController',
  'SceneControllerInteraction',
  'SceneControllerSelection',
  'SceneControllerScene',
};

const Set<String> mutableContractTypeNames = <String>{
  ...mutableCoreTypeNames,
  ...mutableRuntimeTypeNames,
};

const Map<String, ExportedApiScanPolicy>
nonContractExportedApiScanPolicies = <String, ExportedApiScanPolicy>{
  '/lib/src/core/action_events.dart': ExportedApiScanPolicy.fullScan(),
  '/lib/src/core/interaction_types.dart': ExportedApiScanPolicy.fullScan(),
  '/lib/src/model/scene_builder_api.dart': ExportedApiScanPolicy.fullScan(),
  '/lib/src/interactive/scene_controller.dart':
      ExportedApiScanPolicy.targetedSkip(
        reason: 'SceneController may expose public runtime owner types.',
        skippedTopLevelNames: <String>{},
        bannedTypeNames: mutableCoreTypeNames,
      ),
  '/lib/src/interactive/scene_controller_interaction.dart':
      ExportedApiScanPolicy.targetedSkip(
        reason:
            'SceneControllerInteraction may expose public runtime owner '
            'types.',
        skippedTopLevelNames: <String>{},
        bannedTypeNames: mutableCoreTypeNames,
      ),
  '/lib/src/interactive/scene_controller_selection.dart':
      ExportedApiScanPolicy.targetedSkip(
        reason:
            'SceneControllerSelection may expose public runtime owner '
            'types.',
        skippedTopLevelNames: <String>{},
        bannedTypeNames: mutableCoreTypeNames,
      ),
  '/lib/src/interactive/scene_controller_scene.dart':
      ExportedApiScanPolicy.targetedSkip(
        reason: 'SceneControllerScene may expose public runtime owner types.',
        skippedTopLevelNames: <String>{},
        bannedTypeNames: mutableCoreTypeNames,
      ),
  '/lib/src/view/scene_view_interactive.dart':
      ExportedApiScanPolicy.targetedSkip(
        reason:
            'SceneView is a public alias that mirrors the scanned '
            'SceneViewInteractive class surface.',
        skippedTopLevelNames: <String>{'SceneView'},
        bannedTypeNames: mutableCoreTypeNames,
      ),
  '/lib/src/serialization/scene_codec.dart': ExportedApiScanPolicy.fullScan(),
};

const Set<String> _nodeIdBookkeepingNames = <String>{
  'writeNewNodeId',
  'writeContainsNodeId',
  'writeRegisterNodeId',
  'writeUnregisterNodeId',
  'writeRebuildNodeIdIndex',
};

enum _PublicSurfaceMemberBanKind { exact, writeMarkFamily, nodeIdBookkeeping }

class _PublicSurfaceMemberBanRule {
  const _PublicSurfaceMemberBanRule.exact({
    required this.memberName,
    required this.message,
  }) : kind = _PublicSurfaceMemberBanKind.exact;

  const _PublicSurfaceMemberBanRule.writeMarkFamily({required this.message})
    : kind = _PublicSurfaceMemberBanKind.writeMarkFamily,
      memberName = null;

  const _PublicSurfaceMemberBanRule.nodeIdBookkeeping({required this.message})
    : kind = _PublicSurfaceMemberBanKind.nodeIdBookkeeping,
      memberName = null;

  final _PublicSurfaceMemberBanKind kind;
  final String? memberName;
  final String message;

  bool matches(String candidate) {
    return switch (kind) {
      _PublicSurfaceMemberBanKind.exact => memberName == candidate,
      _PublicSurfaceMemberBanKind.writeMarkFamily => RegExp(
        r'^writeMark[A-Za-z0-9_]*$',
      ).hasMatch(candidate),
      _PublicSurfaceMemberBanKind.nodeIdBookkeeping =>
        _nodeIdBookkeepingNames.contains(candidate),
    };
  }
}

const List<_PublicSurfaceMemberBanRule> _sceneWriteTxnMemberBanRules =
    <_PublicSurfaceMemberBanRule>[
      _PublicSurfaceMemberBanRule.exact(
        memberName: 'scene',
        message:
            'public contract violation: exported SceneWriteTxn must not '
            'expose raw scene access.',
      ),
      _PublicSurfaceMemberBanRule.exact(
        memberName: 'writeFindNode',
        message:
            'public contract violation: exported SceneWriteTxn must not '
            'expose writeFindNode.',
      ),
      _PublicSurfaceMemberBanRule.writeMarkFamily(
        message:
            'public contract violation: exported SceneWriteTxn must not '
            'expose writeMark* escape hatches.',
      ),
      _PublicSurfaceMemberBanRule.exact(
        memberName: 'writeSignalEnqueue',
        message:
            'public contract violation: exported SceneWriteTxn must not '
            'expose writeSignalEnqueue.',
      ),
      _PublicSurfaceMemberBanRule.nodeIdBookkeeping(
        message:
            'public contract violation: exported SceneWriteTxn must not '
            'expose node-id bookkeeping methods.',
      ),
    ];

const List<_PublicSurfaceMemberBanRule> _exportedContractMemberBanRules =
    <_PublicSurfaceMemberBanRule>[
      _PublicSurfaceMemberBanRule.exact(
        memberName: 'internalBacking',
        message:
            'public contract violation: exported contract types must not '
            'expose internalBacking.',
      ),
      _PublicSurfaceMemberBanRule.exact(
        memberName: 'materialize',
        message:
            'public contract violation: exported contract types must not '
            'expose materialize(...).',
      ),
    ];

Future<PublicSurfaceGuardrailResult> runPublicSurfaceGuardrails({
  required GuardrailContext context,
}) async {
  final violations = <GuardrailViolation>[];
  _checkLibSrcStructuralGuardrails(context: context, violations: violations);
  if (violations.isNotEmpty) {
    return PublicSurfaceGuardrailResult(
      exportedSurfaces: const <String, ExportedLibrarySurface>{},
      violations: violations,
    );
  }

  final exportedSurfaces = _checkEntrypointGuardrails(
    context: context,
    violations: violations,
  );
  if (violations.isNotEmpty) {
    return PublicSurfaceGuardrailResult(
      exportedSurfaces: exportedSurfaces,
      violations: violations,
    );
  }
  validateExportedApiScanPolicies(
    exportedFiles: exportedSurfaces.keys.toSet(),
    violations: violations,
  );
  if (violations.isNotEmpty) {
    return PublicSurfaceGuardrailResult(
      exportedSurfaces: exportedSurfaces,
      violations: violations,
    );
  }

  _checkExportedApiImports(
    context: context,
    exportedFiles: exportedSurfaces.keys,
    violations: violations,
  );
  _checkExportedContractHermeticMembers(
    context: context,
    exportedFiles: exportedSurfaces.keys,
    violations: violations,
  );
  _checkRootLibFilesAreExportOnly(context: context, violations: violations);
  _checkSceneWriteTxnContract(context: context, violations: violations);
  return PublicSurfaceGuardrailResult(
    exportedSurfaces: exportedSurfaces,
    violations: violations,
  );
}

void validateExportedApiScanPolicies({
  required Set<String> exportedFiles,
  required List<GuardrailViolation> violations,
}) {
  if (exportedFiles.isEmpty) {
    return;
  }
  final policyKeys = nonContractExportedApiScanPolicies.keys.toSet();
  final nonContractExportSet = exportedFiles
      .where((path) => !path.startsWith('/lib/src/contract/'))
      .toSet();
  _addMissingPolicyViolation(nonContractExportSet, policyKeys, violations);
  _addStalePolicyViolation(nonContractExportSet, policyKeys, violations);
}

bool shouldScanDeclaration({
  required CompilationUnitMember declaration,
  required ExportedLibrarySurface surface,
  required ExportedApiScanPolicy policy,
}) {
  final primaryName = declarationPrimaryName(declaration);
  if (primaryName != null) {
    return _isScannableTopLevelName(
      primaryName,
      surface: surface,
      policy: policy,
    );
  }
  if (declaration is TopLevelVariableDeclaration) {
    return declaration.variables.variables.any(
      (variable) => _isScannableTopLevelName(
        variable.name.lexeme,
        surface: surface,
        policy: policy,
      ),
    );
  }
  return declaration is ExtensionDeclaration &&
      declaration.name == null &&
      surface.exportsUnnamedExtensions;
}

String? declarationPrimaryName(CompilationUnitMember member) {
  return switch (member) {
    ClassDeclaration(:final name) => name.lexeme,
    EnumDeclaration(:final name) => name.lexeme,
    MixinDeclaration(:final name) => name.lexeme,
    ExtensionDeclaration(:final name?) => name.lexeme,
    ClassTypeAlias(:final name) => name.lexeme,
    GenericTypeAlias(:final name) => name.lexeme,
    FunctionDeclaration(:final name) => name.lexeme,
    _ => null,
  };
}

DirectiveCombinators collectDirectiveCombinators(NamespaceDirective directive) {
  Set<String>? showNames;
  final filters = <DirectiveFilter>[];

  for (final combinator in directive.combinators) {
    if (combinator is ShowCombinator) {
      showNames ??= <String>{};
      final shownNames = Set<String>.unmodifiable(
        combinator.shownNames.map((identifier) => identifier.name).toSet(),
      );
      showNames.addAll(shownNames);
      filters.add(
        DirectiveFilter(mode: DirectiveFilterMode.show, names: shownNames),
      );
      continue;
    }
    if (combinator is HideCombinator) {
      filters.add(
        DirectiveFilter(
          mode: DirectiveFilterMode.hide,
          names: Set<String>.unmodifiable(
            combinator.hiddenNames.map((identifier) => identifier.name).toSet(),
          ),
        ),
      );
    }
  }

  return DirectiveCombinators(
    exportsAllNames: showNames == null,
    filters: List<DirectiveFilter>.unmodifiable(filters),
  );
}

void _checkLibSrcStructuralGuardrails({
  required GuardrailContext context,
  required List<GuardrailViolation> violations,
}) {
  final srcRoot = Directory(
    '${context.root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}src',
  );
  if (!srcRoot.existsSync()) {
    return;
  }

  final layoutViolations = collectTopLevelLibSrcLayoutViolations(
    srcRoot: srcRoot,
    rootAbsPosixPath: context.rootAbsPosixPath,
    toPosixPath: toPosixPath,
    toRepoRelPosixPath: toRepoRelPosixPath,
  );
  if (layoutViolations.isEmpty) {
    return;
  }
  final violation = layoutViolations.first;
  violations.add(
    GuardrailViolation(
      filePath: violation.path,
      line: 1,
      message: violation.message,
    ),
  );
}

Map<String, ExportedLibrarySurface> _checkEntrypointGuardrails({
  required GuardrailContext context,
  required List<GuardrailViolation> violations,
}) {
  final exports = _collectEntrypointExportSurfaces(
    context: context,
    violations: violations,
  );
  if (exports.isEmpty || violations.isNotEmpty) {
    return exports;
  }

  const forbiddenExports = <String>{
    '/lib/src/core/scene.dart',
    '/lib/src/core/nodes.dart',
  };
  for (final path in forbiddenExports) {
    if (exports.containsKey(path)) {
      violations.add(
        GuardrailViolation(
          filePath: '/lib/iwb_canvas_engine.dart',
          line: 1,
          message:
              'public export violation: lib/iwb_canvas_engine.dart must not '
              'export mutable core model ($path).',
        ),
      );
      break;
    }
  }
  return exports;
}

Map<String, ExportedLibrarySurface> _collectEntrypointExportSurfaces({
  required GuardrailContext context,
  required List<GuardrailViolation> violations,
}) {
  final entrypointFile = _entrypointFile(context);
  if (!entrypointFile.existsSync()) {
    return const <String, ExportedLibrarySurface>{};
  }

  final entrypointPosixPath = _entrypointPosixPath(context, entrypointFile);
  final parsed = _parseEntrypointFile(
    context: context,
    entrypointFile: entrypointFile,
    entrypointPosixPath: entrypointPosixPath,
    violations: violations,
  );
  final combinatorsByTarget = _collectEntrypointCombinatorsByTarget(
    context: context,
    parsed: parsed,
    entrypointPosixPath: entrypointPosixPath,
  );
  return _buildEntrypointSurfaces(combinatorsByTarget);
}

void _checkExportedApiImports({
  required GuardrailContext context,
  required Iterable<String> exportedFiles,
  required List<GuardrailViolation> violations,
}) {
  final filesToCheck = _exportedApiImportTargets(exportedFiles);

  for (final filePosixPath in filesToCheck) {
    final scan = _buildExportedApiFileScan(context, filePosixPath, violations);
    if (scan == null) {
      continue;
    }
    final violation = _exportedApiImportViolation(
      filePosixPath: filePosixPath,
      parsed: scan.parsed,
      fileDirRepoRelPosix: scan.fileDirRepoRelPosix,
      packageName: context.packageName,
    );
    if (violation != null) {
      violations.add(violation);
      return;
    }
  }
}

void _checkRootLibFilesAreExportOnly({
  required GuardrailContext context,
  required List<GuardrailViolation> violations,
}) {
  final rootLibFiles = _rootLibFiles(context);

  for (final file in rootLibFiles) {
    final filePosixPath = _rootLibFilePosixPath(context, file);
    final pathViolation = _additionalEntrypointViolation(filePosixPath);
    if (pathViolation != null) {
      violations.add(pathViolation);
      return;
    }
    final contentViolation = _rootLibContentsViolation(
      context: context,
      file: file,
      filePosixPath: filePosixPath,
      violations: violations,
    );
    if (contentViolation != null) {
      violations.add(contentViolation);
      return;
    }
  }
}

void _checkSceneWriteTxnContract({
  required GuardrailContext context,
  required List<GuardrailViolation> violations,
}) {
  final txnApiFile = _sceneWriteTxnFile(context);
  if (!txnApiFile.existsSync()) {
    return;
  }

  final filePosixPath = _sceneWriteTxnFilePosixPath(context, txnApiFile);
  final parsed = _parseSceneWriteTxnFile(
    context: context,
    txnApiFile: txnApiFile,
    filePosixPath: filePosixPath,
    violations: violations,
  );
  final violation = _sceneWriteTxnContractViolation(
    parsed: parsed,
    filePosixPath: filePosixPath,
  );
  if (violation != null) {
    violations.add(violation);
  }
}

void _checkExportedContractHermeticMembers({
  required GuardrailContext context,
  required Iterable<String> exportedFiles,
  required List<GuardrailViolation> violations,
}) {
  const targetFiles = <String>{
    '/lib/src/contract/snapshot.dart',
    '/lib/src/contract/node_spec.dart',
    '/lib/src/contract/node_patch.dart',
  };
  for (final filePosixPath in exportedFiles.where(targetFiles.contains)) {
    final scan = _buildExportedApiFileScan(context, filePosixPath, violations);
    if (scan == null) {
      continue;
    }
    final violation = _exportedContractHermeticMemberViolation(
      parsed: scan.parsed,
      filePosixPath: filePosixPath,
    );
    if (violation != null) {
      violations.add(violation);
      return;
    }
  }
}

void _addMissingPolicyViolation(
  Set<String> nonContractExportSet,
  Set<String> policyKeys,
  List<GuardrailViolation> violations,
) {
  final missingPolicyEntries =
      nonContractExportSet.difference(policyKeys).toList(growable: false)
        ..sort();
  if (missingPolicyEntries.isEmpty) {
    return;
  }
  final path = missingPolicyEntries.first;
  violations.add(
    GuardrailViolation(
      filePath: '/lib/iwb_canvas_engine.dart',
      line: 1,
      message:
          'public entrypoint violation: exported API owner $path must '
          'declare a mutable-type leak scan policy in '
          'tool/check_guardrails.dart.',
    ),
  );
}

void _addStalePolicyViolation(
  Set<String> nonContractExportSet,
  Set<String> policyKeys,
  List<GuardrailViolation> violations,
) {
  final stalePolicyEntries =
      policyKeys.difference(nonContractExportSet).toList(growable: false)
        ..sort();
  if (stalePolicyEntries.isEmpty) {
    return;
  }
  final path = stalePolicyEntries.first;
  final policy = nonContractExportedApiScanPolicies[path]!;
  final reasonSuffix =
      policy.mode == ExportedApiScanMode.targetedSkip && policy.reason != null
      ? ' Remove or update this targeted skip: ${policy.reason}.'
      : '';
  violations.add(
    GuardrailViolation(
      filePath: '/lib/iwb_canvas_engine.dart',
      line: 1,
      message:
          'public entrypoint violation: exported API policy entry $path is '
          'stale because lib/iwb_canvas_engine.dart no longer exports it.'
          '$reasonSuffix',
    ),
  );
}

File _entrypointFile(GuardrailContext context) {
  return File(
    '${context.root.path}${Platform.pathSeparator}lib'
    '${Platform.pathSeparator}iwb_canvas_engine.dart',
  );
}

String _entrypointPosixPath(GuardrailContext context, File entrypointFile) {
  return toRepoRelPosixPath(
    absPosixPath: toPosixPath(entrypointFile.absolute.path),
    rootAbsPosixPath: context.rootAbsPosixPath,
  );
}

ParsedUnitResult _parseEntrypointFile({
  required GuardrailContext context,
  required File entrypointFile,
  required String entrypointPosixPath,
  required List<GuardrailViolation> violations,
}) {
  return parseUnitOrFail(
    context: context,
    absPath: entrypointFile.absolute.path,
    filePathForDiag: entrypointPosixPath,
    onFailure:
        ({required String filePathForDiag, required String resultType}) =>
            _failParse(violations, filePathForDiag, resultType),
  );
}

Map<String, List<DirectiveCombinators>> _collectEntrypointCombinatorsByTarget({
  required GuardrailContext context,
  required ParsedUnitResult parsed,
  required String entrypointPosixPath,
}) {
  final combinatorsByTarget = <String, List<DirectiveCombinators>>{};
  for (final directive in parsed.unit.directives.whereType<ExportDirective>()) {
    final directiveCombinators = collectDirectiveCombinators(directive);
    for (final uriRef in collectDirectiveUriRefs(directive)) {
      final resolvedRepoRelPosix = resolveToRepoRelTargetPosix(
        targetPosix: toPosixPath(uriRef.uri),
        packageName: context.packageName,
        fileDirRepoRelPosix: posixDirname(entrypointPosixPath),
      );
      if (resolvedRepoRelPosix == null) {
        continue;
      }
      combinatorsByTarget
          .putIfAbsent(resolvedRepoRelPosix, () => <DirectiveCombinators>[])
          .add(directiveCombinators);
    }
  }
  return combinatorsByTarget;
}

Map<String, ExportedLibrarySurface> _buildEntrypointSurfaces(
  Map<String, List<DirectiveCombinators>> combinatorsByTarget,
) {
  final targets = <String, ExportedLibrarySurface>{};
  for (final MapEntry(key: target, value: combinators)
      in combinatorsByTarget.entries) {
    targets[target] = ExportedLibrarySurface(
      repoRelPath: target,
      directiveCombinators: List<DirectiveCombinators>.unmodifiable(
        combinators,
      ),
    );
  }
  return targets;
}

List<String> _exportedApiImportTargets(Iterable<String> exportedFiles) {
  final filesToCheck =
      exportedFiles
          .where(
            (path) =>
                path.startsWith('/lib/src/contract/') ||
                path == '/lib/src/model/scene_builder_api.dart',
          )
          .toList(growable: false)
        ..sort();
  return filesToCheck;
}

ExportedApiFileScan? _buildExportedApiFileScan(
  GuardrailContext context,
  String filePosixPath,
  List<GuardrailViolation> violations,
) {
  final file = File(posixJoin(context.root.path, filePosixPath.substring(1)));
  if (!file.existsSync()) {
    return null;
  }
  return ExportedApiFileScan(
    fileDirRepoRelPosix: posixDirname(filePosixPath),
    parsed: parseUnitOrFail(
      context: context,
      absPath: file.absolute.path,
      filePathForDiag: filePosixPath,
      onFailure:
          ({required String filePathForDiag, required String resultType}) =>
              _failParse(violations, filePathForDiag, resultType),
    ),
  );
}

GuardrailViolation? _exportedApiImportViolation({
  required String packageName,
  required String filePosixPath,
  required ParsedUnitResult parsed,
  required String fileDirRepoRelPosix,
}) {
  for (final directive in parsed.unit.directives) {
    final uriDirective =
        directive is ImportDirective || directive is ExportDirective
        ? directive as UriBasedDirective
        : null;
    if (uriDirective == null) {
      continue;
    }
    final violation = _directiveImportViolation(
      scan: ExportedApiDirectiveScan(
        packageName: packageName,
        filePosixPath: filePosixPath,
        parsed: parsed,
        fileDirRepoRelPosix: fileDirRepoRelPosix,
      ),
      directive: uriDirective,
    );
    if (violation != null) {
      return violation;
    }
  }
  return null;
}

GuardrailViolation? _directiveImportViolation({
  required ExportedApiDirectiveScan scan,
  required UriBasedDirective directive,
}) {
  for (final uriRef in collectDirectiveUriRefs(directive)) {
    final resolvedRepoRelPosix = resolveToRepoRelTargetPosix(
      targetPosix: toPosixPath(uriRef.uri),
      packageName: scan.packageName,
      fileDirRepoRelPosix: scan.fileDirRepoRelPosix,
    );
    if (_isDisallowedExportedApiTarget(resolvedRepoRelPosix)) {
      return GuardrailViolation(
        filePath: scan.filePosixPath,
        line: lineForOffset(scan.parsed, uriRef.offset),
        message:
            'public export violation: exported contract/** and the '
            'model facade must not import/export controller/**, '
            'render/**, view/**, or serialization/** '
            '($resolvedRepoRelPosix)',
      );
    }
  }
  return null;
}

List<File> _rootLibFiles(GuardrailContext context) {
  final libDir = Directory('${context.root.path}${Platform.pathSeparator}lib');
  if (!libDir.existsSync()) {
    return const <File>[];
  }
  final rootLibFiles =
      libDir
          .listSync(recursive: false, followLinks: false)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList(growable: false)
        ..sort((a, b) => a.path.compareTo(b.path));
  return rootLibFiles;
}

String _rootLibFilePosixPath(GuardrailContext context, File file) {
  return toRepoRelPosixPath(
    absPosixPath: toPosixPath(file.absolute.path),
    rootAbsPosixPath: context.rootAbsPosixPath,
  );
}

GuardrailViolation? _additionalEntrypointViolation(String filePosixPath) {
  if (filePosixPath == '/lib/iwb_canvas_engine.dart') {
    return null;
  }
  return GuardrailViolation(
    filePath: filePosixPath,
    line: 1,
    message:
        'public entrypoint violation: root lib/*.dart files must not '
        'introduce additional entrypoints; '
        'lib/iwb_canvas_engine.dart is the only supported root entrypoint.',
  );
}

GuardrailViolation? _rootLibContentsViolation({
  required GuardrailContext context,
  required File file,
  required String filePosixPath,
  required List<GuardrailViolation> violations,
}) {
  final parsed = parseUnitOrFail(
    context: context,
    absPath: file.absolute.path,
    filePathForDiag: filePosixPath,
    onFailure:
        ({required String filePathForDiag, required String resultType}) =>
            _failParse(violations, filePathForDiag, resultType),
  );
  final invalidDirective = _firstInvalidRootDirective(parsed.unit.directives);
  final invalidOffset =
      invalidDirective?.offset ?? _firstInvalidRootDeclarationOffset(parsed);
  if (invalidOffset == null) {
    return null;
  }
  return GuardrailViolation(
    filePath: filePosixPath,
    line: lineForOffset(parsed, invalidOffset),
    message:
        'public entrypoint violation: root lib/*.dart files must '
        'contain only library/docs/comments/export directives.',
  );
}

Directive? _firstInvalidRootDirective(NodeList<Directive> directives) {
  for (final directive in directives) {
    if (directive is LibraryDirective || directive is ExportDirective) {
      continue;
    }
    return directive;
  }
  return null;
}

int? _firstInvalidRootDeclarationOffset(ParsedUnitResult parsed) {
  return parsed.unit.declarations.isEmpty
      ? null
      : parsed.unit.declarations.first.offset;
}

File _sceneWriteTxnFile(GuardrailContext context) {
  return File(
    '${context.root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}'
    'src${Platform.pathSeparator}contract${Platform.pathSeparator}'
    'scene_write_txn.dart',
  );
}

String _sceneWriteTxnFilePosixPath(GuardrailContext context, File file) {
  return toRepoRelPosixPath(
    absPosixPath: toPosixPath(file.absolute.path),
    rootAbsPosixPath: context.rootAbsPosixPath,
  );
}

ParsedUnitResult _parseSceneWriteTxnFile({
  required GuardrailContext context,
  required File txnApiFile,
  required String filePosixPath,
  required List<GuardrailViolation> violations,
}) {
  return parseUnitOrFail(
    context: context,
    absPath: txnApiFile.absolute.path,
    filePathForDiag: filePosixPath,
    onFailure:
        ({required String filePathForDiag, required String resultType}) =>
            _failParse(violations, filePathForDiag, resultType),
  );
}

GuardrailViolation? _sceneWriteTxnContractViolation({
  required ParsedUnitResult parsed,
  required String filePosixPath,
}) {
  for (final declaration in parsed.unit.declarations) {
    if (declaration is! ClassDeclaration ||
        declaration.name.lexeme != 'SceneWriteTxn') {
      continue;
    }
    return _sceneWriteTxnMemberViolation(
      members: declaration.members,
      parsed: parsed,
      filePosixPath: filePosixPath,
    );
  }
  return null;
}

GuardrailViolation? _sceneWriteTxnMemberViolation({
  required NodeList<ClassMember> members,
  required ParsedUnitResult parsed,
  required String filePosixPath,
}) {
  return _firstMemberBanViolation(
    members: members,
    parsed: parsed,
    filePosixPath: filePosixPath,
    memberNameOf: _sceneWriteTxnMemberName,
    rules: _sceneWriteTxnMemberBanRules,
  );
}

GuardrailViolation? _exportedContractHermeticMemberViolation({
  required ParsedUnitResult parsed,
  required String filePosixPath,
}) {
  for (final declaration in parsed.unit.declarations) {
    if (declaration is! ClassDeclaration) {
      continue;
    }
    final violation = _firstMemberBanViolation(
      members: declaration.members,
      parsed: parsed,
      filePosixPath: filePosixPath,
      memberNameOf: _exportedContractMemberName,
      rules: _exportedContractMemberBanRules,
    );
    if (violation != null) {
      return violation;
    }
  }
  return null;
}

class ExportedApiFileScan {
  const ExportedApiFileScan({
    required this.fileDirRepoRelPosix,
    required this.parsed,
  });

  final String fileDirRepoRelPosix;
  final ParsedUnitResult parsed;
}

class ExportedApiDirectiveScan {
  const ExportedApiDirectiveScan({
    required this.packageName,
    required this.filePosixPath,
    required this.parsed,
    required this.fileDirRepoRelPosix,
  });

  final String packageName;
  final String filePosixPath;
  final ParsedUnitResult parsed;
  final String fileDirRepoRelPosix;
}

String? _sceneWriteTxnMemberName(ClassMember member) {
  return _exportedContractMemberName(member);
}

GuardrailViolation? _firstMemberBanViolation({
  required NodeList<ClassMember> members,
  required ParsedUnitResult parsed,
  required String filePosixPath,
  required String? Function(ClassMember member) memberNameOf,
  required List<_PublicSurfaceMemberBanRule> rules,
}) {
  for (final member in members) {
    final memberName = memberNameOf(member);
    if (memberName == null || !isPublicName(memberName)) {
      continue;
    }
    final rule = _matchingMemberBanRule(memberName, rules);
    if (rule == null) {
      continue;
    }
    return GuardrailViolation(
      filePath: filePosixPath,
      line: lineForOffset(parsed, member.offset),
      message: rule.message,
    );
  }
  return null;
}

_PublicSurfaceMemberBanRule? _matchingMemberBanRule(
  String memberName,
  List<_PublicSurfaceMemberBanRule> rules,
) {
  for (final rule in rules) {
    if (rule.matches(memberName)) {
      return rule;
    }
  }
  return null;
}

String? _exportedContractMemberName(ClassMember member) {
  if (member is MethodDeclaration) {
    return member.name.lexeme;
  }
  if (member is ConstructorDeclaration) {
    return member.name?.lexeme;
  }
  if (member is! FieldDeclaration) {
    return null;
  }
  for (final variable in member.fields.variables) {
    final name = variable.name.lexeme;
    if (isPublicName(name)) {
      return name;
    }
  }
  return null;
}

bool _isDisallowedExportedApiTarget(String? resolvedRepoRelPosix) {
  if (resolvedRepoRelPosix == null) {
    return false;
  }
  return const <String>[
    '/lib/src/controller/',
    '/lib/src/render/',
    '/lib/src/view/',
    '/lib/src/serialization/',
  ].any(resolvedRepoRelPosix.startsWith);
}

Never _failParse(
  List<GuardrailViolation> violations,
  String filePathForDiag,
  String resultType,
) {
  final violation = GuardrailViolation(
    filePath: filePathForDiag,
    line: 1,
    message: 'tool failure: unable to parse Dart unit (result: $resultType)',
  );
  violations.add(violation);
  throw GuardrailToolFailure(violation);
}

bool _isScannableTopLevelName(
  String name, {
  required ExportedLibrarySurface surface,
  required ExportedApiScanPolicy policy,
}) {
  return isPublicName(name) &&
      surface.exportsTopLevelName(name) &&
      !policy.skippedTopLevelNames.contains(name);
}
