import 'dart:io';

import 'src/lsp/language_server_client.dart';
import 'src/lsp/symbol_locator.dart';
import 'src/lsp/trace_support.dart';
import 'src/tool_command_result.dart';

Future<ToolCommandResult> runLspTraceFlowTool(
  List<String> args, {
  Directory? root,
}) async {
  if (args.length < 2) {
    return const ToolCommandResult(
      exitCode: 1,
      stderr:
          'Usage: dart run tool/lsp_trace_flow.dart <file> <symbol> '
          '[--depth=N] [--json]\n',
    );
  }

  final workingRoot = root ?? Directory.current;
  final repoRelativePath = args[0];
  final symbolQuery = args[1];
  final depth = toolCommandIntFlag(args, '--depth') ?? 6;
  final jsonOutput = args.contains('--json');
  final located = locateSymbol(
    root: workingRoot,
    repoRelativePath: repoRelativePath,
    query: symbolQuery,
  );
  final client = await LanguageServerClient.start(root: workingRoot);
  try {
    return await _traceFlow(
      client: client,
      located: located,
      depth: depth,
      jsonOutput: jsonOutput,
    );
  } on SymbolLocateFailure catch (error) {
    return ToolCommandResult(exitCode: 1, stderr: 'FAIL: ${error.message}\n');
  } on LanguageServerError catch (error) {
    return ToolCommandResult(
      exitCode: 1,
      stderr: 'FAIL: LSP flow trace failed: ${error.message}\n',
    );
  } finally {
    await client.close();
  }
}

Future<void> main(List<String> args) async {
  final result = await runLspTraceFlowTool(args);
  writeToolCommandResult(result);
  exitCode = result.exitCode;
}

Future<ToolCommandResult> _traceFlow({
  required LanguageServerClient client,
  required LocatedSymbol located,
  required int depth,
  required bool jsonOutput,
}) async {
  final report = await _collectFlowReport(
    client: client,
    located: located,
    depth: depth,
  );
  if (report == null) {
    return ToolCommandResult(
      exitCode: 1,
      stderr:
          'FAIL: LSP did not return a call-hierarchy item for '
          '${located.displayName}.\n',
    );
  }
  return ToolCommandResult(
    exitCode: 0,
    stdout: jsonOutput
        ? '${encodeToolCommandJson(report)}\n'
        : _renderTextReport(report),
  );
}

Future<Map<String, Object?>?> _collectFlowReport({
  required LanguageServerClient client,
  required LocatedSymbol located,
  required int depth,
}) async {
  final start = await prepareCallItemForSymbol(client, located);
  if (start == null) {
    return null;
  }
  final flow = await tracePrimaryOutgoingFlow(
    client,
    start,
    depth: depth,
    includeExternal: false,
  );
  return _flowReport(flow);
}

Map<String, Object?> _flowReport(StitchedFlow flow) => <String, Object?>{
  'start': <String, Object?>{
    'label': flow.start.label,
    'path': flow.start.repoRelativePath,
  },
  'steps': [
    for (final step in flow.steps)
      <String, Object?>{
        'transition': step.transition,
        'label': step.item.label,
        'path': step.item.repoRelativePath,
        'sideBranches': [
          for (final branch in step.sideBranches)
            <String, Object?>{
              'label': branch.label,
              'path': branch.repoRelativePath,
            },
        ],
      },
  ],
};

String _renderTextReport(Map<String, Object?> report) {
  final start = (report['start'] as Map<String, Object?>);
  final buffer = StringBuffer()
    ..writeln('Primary flow from ${start['label']}:')
    ..writeln('- start: ${start['label']} (${start['path']})');
  for (final step
      in (report['steps'] as List<Object?>).cast<Map<String, Object?>>()) {
    buffer.writeln(
      '- ${step['transition']}: ${step['label']} (${step['path']})',
    );
    for (final branch
        in (step['sideBranches'] as List<Object?>)
            .cast<Map<String, Object?>>()) {
      buffer.writeln('  side-branch: ${branch['label']} (${branch['path']})');
    }
  }
  return buffer.toString();
}
