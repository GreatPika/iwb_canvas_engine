import 'dart:convert';
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
  final classificationFilter = _parseStringFlag(args, '--classification');
  final includePrivate = args.contains('--include-private');
  final jsonOutput = args.contains('--json');
  final candidates =
      collectWrapperCandidates(
            root: workingRoot,
            targetPath: targetPath,
            includePrivate: includePrivate,
          )
          .where((candidate) {
            if (classificationFilter == null) {
              return true;
            }
            return candidate.classification == classificationFilter;
          })
          .toList(growable: false);

  final mapped = candidates
      .map(
        (candidate) => <String, Object?>{
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
      )
      .toList(growable: false);

  if (jsonOutput) {
    return ToolCommandResult(
      exitCode: 0,
      stdout: '${const JsonEncoder.withIndent('  ').convert(mapped)}\n',
    );
  }

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
  return ToolCommandResult(exitCode: 0, stdout: buffer.toString());
}

Future<void> main(List<String> args) async {
  final result = await runLspFindThinWrappersTool(args);
  writeToolCommandResult(result);
  exitCode = result.exitCode;
}

String? _parseStringFlag(List<String> args, String name) {
  for (final argument in args) {
    if (argument.startsWith('$name=')) {
      return argument.substring(name.length + 1);
    }
  }
  return null;
}
