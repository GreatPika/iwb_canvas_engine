import 'dart:io';

import 'src/lsp/wrapper_detector.dart';
import 'src/tool_command_result.dart';

Future<ToolCommandResult> runLspFindThinWrappersTool(
  List<String> args, {
  Directory? root,
}) async {
  if (args.isEmpty) {
    return const ToolCommandResult(
      exitCode: 1,
      stderr:
          'Usage: dart run tool/lsp_find_thin_wrappers.dart <file-or-dir> '
          '[--classification=kind] [--include-private] [--json]\n',
    );
  }

  final workingRoot = root ?? Directory.current;
  final targetPath = args.first;
  final classificationFilter = toolCommandStringFlag(args, '--classification');
  final includePrivate = args.contains('--include-private');
  final jsonOutput = args.contains('--json');
  final mapped = _collectMappedCandidates(
    root: workingRoot,
    targetPath: targetPath,
    classificationFilter: classificationFilter,
    includePrivate: includePrivate,
  );

  if (jsonOutput) {
    return ToolCommandResult(
      exitCode: 0,
      stdout: '${encodeToolCommandJson(mapped)}\n',
    );
  }

  return ToolCommandResult(
    exitCode: 0,
    stdout: _renderTextReport(targetPath, mapped),
  );
}

Future<void> main(List<String> args) async {
  final result = await runLspFindThinWrappersTool(args);
  writeToolCommandResult(result);
  exitCode = result.exitCode;
}

List<Map<String, Object?>> _collectMappedCandidates({
  required Directory root,
  required String targetPath,
  required String? classificationFilter,
  required bool includePrivate,
}) => [
  for (final candidate in collectWrapperCandidates(
    root: root,
    targetPath: targetPath,
    includePrivate: includePrivate,
  ))
    if (classificationFilter == null ||
        candidate.classification == classificationFilter)
      <String, Object?>{
        'path': candidate.repoRelativePath,
        'line': candidate.line,
        'owner': candidate.ownerName,
        'member': candidate.memberName,
        'target': candidate.targetName,
        'classification': candidate.classification,
        'forwardedParameters':
            '${candidate.forwardedParameterCount}/${candidate.parameterCount}',
        'guardCount': candidate.guardCount,
        'sameNameForwarding': candidate.sameNameForwarding,
      },
];

String _renderTextReport(String targetPath, List<Map<String, Object?>> mapped) {
  final buffer = StringBuffer()
    ..writeln('Thin-wrapper candidates under $targetPath: ${mapped.length}');
  for (final candidate in mapped) {
    buffer.writeln(
      '- ${candidate['classification']}: '
      '${candidate['owner']}.${candidate['member']} -> ${candidate['target']} '
      '(${candidate['path']}:${candidate['line']}, '
      'forwarded=${candidate['forwardedParameters']}, '
      'guards=${candidate['guardCount']}, '
      'sameName=${candidate['sameNameForwarding']})',
    );
  }
  return buffer.toString();
}
