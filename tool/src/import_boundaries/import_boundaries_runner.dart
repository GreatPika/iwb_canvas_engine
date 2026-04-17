import 'dart:io';

import '../guardrails/support/guardrail_ast_utils.dart';
import '../guardrails/support/guardrail_context.dart';
import '../guardrails/support/guardrail_path_utils.dart';
import '../layer_guardrails.dart';
import '../tool_command_result.dart';
import 'directive_boundary_checker.dart';
import 'import_boundary_policy.dart';
import 'public_export_boundary_resolver.dart';

ToolCommandResult evaluateImportBoundariesTool({Directory? root}) {
  final runner = ImportBoundariesRunner(root: root);
  try {
    if (!runner.hasSourceRoot) {
      return const ToolCommandResult(
        exitCode: 0,
        stderr: 'No lib/src directory found. Nothing to check.\n',
      );
    }

    final violations = runner.collectViolations();
    if (violations.isEmpty) {
      return const ToolCommandResult(
        exitCode: 0,
        stdout: 'OK: import boundaries\n',
      );
    }

    final stderrBuffer = StringBuffer()
      ..writeln('FAIL: import boundary violations (${violations.length})');
    for (final violation in violations) {
      stderrBuffer.writeln('- $violation');
    }
    return ToolCommandResult(exitCode: 1, stderr: stderrBuffer.toString());
  } on StateError catch (error) {
    return ToolCommandResult(exitCode: 1, stderr: error.message.toString());
  }
}

Future<void> runImportBoundariesTool({Directory? root}) async {
  final result = evaluateImportBoundariesTool(root: root);
  writeToolCommandResult(result);
  exitCode = result.exitCode;
}

class ImportBoundariesRunner {
  ImportBoundariesRunner({Directory? root})
    : context = GuardrailContext.forDirectory(
        Directory((root ?? Directory.current).absolute.path),
      ),
      srcRoot = Directory(
        '${Directory((root ?? Directory.current).absolute.path).path}${Platform.pathSeparator}lib'
        '${Platform.pathSeparator}src',
      );

  final GuardrailContext context;
  final Directory srcRoot;
  final List<ImportBoundaryViolation> violations = <ImportBoundaryViolation>[];

  late final PublicExportBoundaryResolver exportResolver =
      PublicExportBoundaryResolver(context: context);

  bool get hasSourceRoot => srcRoot.existsSync();

  List<ImportBoundaryViolation> collectViolations() {
    final disallowedEntries = _recordTopLevelLayoutViolations();
    for (final file in _listDartFiles()) {
      _checkFile(file, disallowedEntries);
    }
    return violations;
  }

  Set<String> _recordTopLevelLayoutViolations() {
    final disallowedEntries = <String>{};
    final topLevelLayoutViolations = collectTopLevelLibSrcLayoutViolations(
      srcRoot: srcRoot,
      rootAbsPosixPath: context.rootAbsPosixPath,
      toPosixPath: toPosixPath,
      toRepoRelPosixPath: toRepoRelPosixPath,
    );
    for (final layoutViolation in topLevelLayoutViolations) {
      disallowedEntries.add(layoutViolation.entry);
      violations.add(
        ImportBoundaryViolation(
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

  void _checkFile(File file, Set<String> disallowedEntries) {
    final filePosixPath = _fileRepoRelPosixPath(file);
    if (_shouldSkipFile(filePosixPath, disallowedEntries)) {
      return;
    }

    final fileLayer = layerForRepoRelPosixPath(filePosixPath);
    if (fileLayer == null) {
      _recordUnknownLayerFile(filePosixPath);
      return;
    }

    final parsed = parseUnitOrFail(
      context: context,
      absPath: file.absolute.path,
      filePathForDiag: filePosixPath,
      onFailure: _failParse,
    );
    final checker = DirectiveBoundaryChecker(
      parsed: parsed,
      filePosixPath: filePosixPath,
      fileLayer: fileLayer,
      exportResolver: exportResolver,
      violations: violations,
    );
    for (final directive in parsed.unit.directives) {
      checker.checkDirective(directive);
    }
    checker.checkDocumentationLinks();
  }

  String _fileRepoRelPosixPath(File file) {
    return toRepoRelPosixPath(
      absPosixPath: toPosixPath(file.absolute.path),
      rootAbsPosixPath: context.rootAbsPosixPath,
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
      ImportBoundaryViolation(
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

  Never _failParse({
    required String filePathForDiag,
    required String resultType,
  }) {
    throw StateError(
      'FAIL: import boundary violations (1)\n'
      '- $filePathForDiag:1: tool failure: unable to parse Dart unit '
      '(result: $resultType) (parse: $filePathForDiag)\n',
    );
  }
}
