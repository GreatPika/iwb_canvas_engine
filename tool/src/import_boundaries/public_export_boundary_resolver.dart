import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';

import '../guardrail_support/guardrail_ast_utils.dart';
import '../guardrail_support/guardrail_context.dart';
import '../guardrail_support/guardrail_path_utils.dart';
import 'import_boundary_policy.dart';

class BoundaryTarget {
  const BoundaryTarget({
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

class PublicExportBoundaryResolver {
  PublicExportBoundaryResolver({required this.context});

  final GuardrailContext context;
  final Map<String, List<BoundaryTarget>> _cache =
      <String, List<BoundaryTarget>>{};

  List<BoundaryTarget> exportedTargets(String repoRelPosixPath) {
    final cached = _cache[repoRelPosixPath];
    if (cached != null) {
      return cached;
    }

    final targets = _collectExports(
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

  List<BoundaryTarget> expandBoundaryTargets({
    required DirectiveUriRef uriRef,
    required String fileDirRepoRelPosix,
  }) {
    final targetPosix = toPosixPath(uriRef.uri);
    final resolvedRepoRelPosix = resolveToRepoRelTargetPosix(
      targetPosix: targetPosix,
      packageName: context.packageName,
      fileDirRepoRelPosix: fileDirRepoRelPosix,
    );
    if (resolvedRepoRelPosix == null ||
        !isTopLevelLibFile(resolvedRepoRelPosix)) {
      return <BoundaryTarget>[
        BoundaryTarget(
          targetPosix: targetPosix,
          diagnosticTarget: uriRef.uri,
          resolvedRepoRelPosix: resolvedRepoRelPosix,
        ),
      ];
    }

    final resolvedExportedTargets = exportedTargets(resolvedRepoRelPosix);
    if (resolvedExportedTargets.isEmpty) {
      return <BoundaryTarget>[
        BoundaryTarget(
          targetPosix: targetPosix,
          diagnosticTarget: uriRef.uri,
          resolvedRepoRelPosix: resolvedRepoRelPosix,
        ),
      ];
    }

    return resolvedExportedTargets
        .map(
          (BoundaryTarget exportedTarget) => BoundaryTarget(
            targetPosix: exportedTarget.targetPosix,
            diagnosticTarget:
                '${uriRef.uri} -> ${exportedTarget.diagnosticTarget}',
            resolvedRepoRelPosix: exportedTarget.resolvedRepoRelPosix,
          ),
        )
        .toList(growable: false);
  }

  Set<BoundaryTarget> _collectExports({
    required String repoRelPosixPath,
    required Set<String> seen,
  }) {
    if (!isTopLevelLibFile(repoRelPosixPath) || !seen.add(repoRelPosixPath)) {
      return const <BoundaryTarget>{};
    }

    final absPath = _absPathForRepoRel(repoRelPosixPath);
    if (!File(absPath).existsSync()) {
      return const <BoundaryTarget>{};
    }

    final parsed = parseUnitOrFail(
      context: context,
      absPath: absPath,
      filePathForDiag: repoRelPosixPath,
      onFailure: _failParse,
    );
    final targets = <BoundaryTarget>{};
    for (final directive
        in parsed.unit.directives.whereType<ExportDirective>()) {
      targets.addAll(
        _exportTargetsForDirective(
          directive: directive,
          repoRelPosixPath: repoRelPosixPath,
          seen: seen,
        ),
      );
    }
    return targets;
  }

  String _absPathForRepoRel(String repoRelPosixPath) {
    return repoRelPosixToAbsPath(
      repoRelPosixPath: repoRelPosixPath,
      rootAbsPosixPath: context.rootAbsPosixPath,
    );
  }

  Set<BoundaryTarget> _exportTargetsForDirective({
    required ExportDirective directive,
    required String repoRelPosixPath,
    required Set<String> seen,
  }) {
    final targets = <BoundaryTarget>{};
    for (final uriRef in collectDirectiveUriRefs(directive)) {
      _collectExportTargetFromUriRef(
        targets: targets,
        uriRef: uriRef,
        repoRelPosixPath: repoRelPosixPath,
        seen: seen,
      );
    }
    return targets;
  }

  void _collectExportTargetFromUriRef({
    required Set<BoundaryTarget> targets,
    required DirectiveUriRef uriRef,
    required String repoRelPosixPath,
    required Set<String> seen,
  }) {
    final targetPosix = toPosixPath(uriRef.uri);
    final resolvedRepoRelPosix = resolveToRepoRelTargetPosix(
      targetPosix: targetPosix,
      packageName: context.packageName,
      fileDirRepoRelPosix: posixDirname(repoRelPosixPath),
    );
    if (resolvedRepoRelPosix == null) {
      _addExternalPackageTarget(
        targets: targets,
        targetPosix: targetPosix,
        diagnosticTarget: uriRef.uri,
      );
      return;
    }
    if (resolvedRepoRelPosix.startsWith('/lib/src/')) {
      targets.add(
        BoundaryTarget(
          targetPosix: targetPosix,
          diagnosticTarget: uriRef.uri,
          resolvedRepoRelPosix: resolvedRepoRelPosix,
        ),
      );
      return;
    }
    targets.addAll(
      _collectExports(repoRelPosixPath: resolvedRepoRelPosix, seen: seen),
    );
  }

  void _addExternalPackageTarget({
    required Set<BoundaryTarget> targets,
    required String targetPosix,
    required String diagnosticTarget,
  }) {
    if (!targetPosix.startsWith('package:')) {
      return;
    }
    targets.add(
      BoundaryTarget(
        targetPosix: targetPosix,
        diagnosticTarget: diagnosticTarget,
      ),
    );
  }

  Never _failParse({
    required String filePathForDiag,
    required String resultType,
  }) {
    stderr.writeln('FAIL: import boundary violations (1)');
    stderr.writeln(
      '- $filePathForDiag:1: tool failure: unable to parse Dart unit '
      '(result: $resultType) (parse: $filePathForDiag)',
    );
    exit(1);
  }
}
