import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';

import '../support/guardrail_ast_utils.dart';
import '../support/guardrail_context.dart';
import '../support/guardrail_path_utils.dart';
import 'guardrail_violation.dart';

typedef GuardrailParseFailureFormatter =
    String Function({
      required String filePathForDiag,
      required String resultType,
    });

List<File> collectSortedDartFiles(Directory directory) {
  if (!directory.existsSync()) {
    return const <File>[];
  }

  final files =
      directory
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  return files;
}

String repoRelPathForFile(GuardrailContext context, File file) {
  return toRepoRelPosixPath(
    absPosixPath: toPosixPath(file.absolute.path),
    rootAbsPosixPath: context.rootAbsPosixPath,
  );
}

ParsedUnitResult parseGuardrailUnitOrThrow({
  required GuardrailContext context,
  required File file,
  required String filePosixPath,
  required GuardrailParseFailureFormatter failureFormatter,
}) {
  return parseUnitOrFail(
    context: context,
    absPath: file.absolute.path,
    filePathForDiag: filePosixPath,
    onFailure: ({required String filePathForDiag, required String resultType}) {
      throw GuardrailToolFailure(
        GuardrailViolation(
          filePath: filePathForDiag,
          line: 1,
          message: failureFormatter(
            filePathForDiag: filePathForDiag,
            resultType: resultType,
          ),
        ),
      );
    },
  );
}

void failOnFirstViolation(List<GuardrailViolation> violations) {
  if (violations.isEmpty) {
    return;
  }
  throw GuardrailToolFailure(violations.first);
}

GuardrailViolation? checkPartDirectiveBan({
  required ParsedUnitResult parsed,
  required String filePosixPath,
  required String violationMessage,
}) {
  for (final directive in parsed.unit.directives) {
    if (directive is PartDirective || directive is PartOfDirective) {
      return GuardrailViolation(
        filePath: filePosixPath,
        line: lineForOffset(parsed, directive.offset),
        message: violationMessage,
      );
    }
  }
  return null;
}

GuardrailViolation? checkRemovedResidualFiles({
  required GuardrailContext context,
  required Iterable<String> removedResidualFiles,
  required String trimPrefix,
  required String Function(String tail) messageForTail,
}) {
  for (final filePosixPath in removedResidualFiles) {
    final file = File(
      repoRelPosixToAbsPath(
        repoRelPosixPath: filePosixPath,
        rootAbsPosixPath: context.rootAbsPosixPath,
      ),
    );
    if (!file.existsSync()) {
      continue;
    }

    final tail = filePosixPath.startsWith(trimPrefix)
        ? filePosixPath.substring(trimPrefix.length)
        : filePosixPath;
    return GuardrailViolation(
      filePath: filePosixPath,
      line: 1,
      message: messageForTail(tail),
    );
  }

  return null;
}

GuardrailViolation? checkDirectiveBoundaryViolation({
  required GuardrailContext context,
  required ParsedUnitResult parsed,
  required String filePosixPath,
  required bool Function(String targetRepoRelPath) isForbiddenTarget,
  required String Function(String targetRepoRelPath) messageForTarget,
}) {
  for (final directive
      in parsed.unit.directives.whereType<UriBasedDirective>()) {
    for (final uriRef in collectDirectiveUriRefs(directive)) {
      final target = resolveToRepoRelTargetPosix(
        targetPosix: uriRef.uri,
        packageName: context.packageName,
        fileDirRepoRelPosix: posixDirname(filePosixPath),
      );
      if (target == null || !isForbiddenTarget(target)) {
        continue;
      }

      return GuardrailViolation(
        filePath: filePosixPath,
        line: lineForOffset(parsed, uriRef.offset),
        message: messageForTarget(target),
      );
    }
  }

  return null;
}
