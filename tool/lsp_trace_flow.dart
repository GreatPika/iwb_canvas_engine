import 'dart:convert';
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
  final depth = _parseIntFlag(args, '--depth') ?? 6;
  final jsonOutput = args.contains('--json');

  final located = locateSymbol(
    root: workingRoot,
    repoRelativePath: repoRelativePath,
    query: symbolQuery,
  );

  final client = await LanguageServerClient.start(root: workingRoot);
  try {
    final start = await prepareCallItemForSymbol(client, located);
    if (start == null) {
      return ToolCommandResult(
        exitCode: 1,
        stderr:
            'FAIL: LSP did not return a call-hierarchy item for '
            '${located.displayName}.\n',
      );
    }
    final flow = await tracePrimaryOutgoingFlow(
      client,
      start,
      depth: depth,
      includeExternal: false,
    );
    final report = <String, Object?>{
      'start': <String, Object?>{
        'label': flow.start.label,
        'path': flow.start.repoRelativePath,
      },
      'steps': flow.steps
          .map(
            (step) => <String, Object?>{
              'transition': step.transition,
              'label': step.item.label,
              'path': step.item.repoRelativePath,
              'sideBranches': step.sideBranches
                  .map(
                    (branch) => <String, Object?>{
                      'label': branch.label,
                      'path': branch.repoRelativePath,
                    },
                  )
                  .toList(growable: false),
            },
          )
          .toList(growable: false),
    };

    if (jsonOutput) {
      return ToolCommandResult(
        exitCode: 0,
        stdout: '${const JsonEncoder.withIndent('  ').convert(report)}\n',
      );
    }

    final buffer = StringBuffer()
      ..writeln('Primary flow from ${flow.start.label}:')
      ..writeln(
        '- start: ${flow.start.label} (${flow.start.repoRelativePath})',
      );
    for (final step in flow.steps) {
      buffer.writeln(
        '- ${step.transition}: ${step.item.label} '
        '(${step.item.repoRelativePath})',
      );
      for (final branch in step.sideBranches) {
        buffer.writeln(
          '  side-branch: ${branch.label} (${branch.repoRelativePath})',
        );
      }
    }
    return ToolCommandResult(exitCode: 0, stdout: buffer.toString());
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

int? _parseIntFlag(List<String> args, String name) {
  for (final argument in args) {
    if (argument.startsWith('$name=')) {
      return int.tryParse(argument.substring(name.length + 1));
    }
  }
  return null;
}
