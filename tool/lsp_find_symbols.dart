import 'dart:convert';
import 'dart:io';

import 'src/lsp/language_server_client.dart';
import 'src/tool_command_result.dart';

// Query normalization, retry output, filtering, and rendering are one command
// operation; separating them would duplicate the LSP response shape handling.
// ignore: cyclomatic-complexity, halstead-volume, source-lines-of-code, maintainability-index, reason: Response shaping, filtering, and rendering share one LSP response.
Future<ToolCommandResult> runLspFindSymbolsTool(
  List<String> args, {
  Directory? root,
}) async {
  if (args.isEmpty) {
    return const ToolCommandResult(
      exitCode: 1,
      stderr:
          'Usage: dart run tool/lsp_find_symbols.dart <query> '
          '[--limit=N] [--path-contains=fragment] [--json]\n',
    );
  }
  final query = args.first;
  final limit = _parseIntFlag(args, '--limit') ?? 20;
  final pathFilter = _parseStringFlag(args, '--path-contains');
  final jsonOutput = args.contains('--json');
  final client = await LanguageServerClient.start(root: root);
  try {
    final raw = await _querySymbolsWithRetry(client, query);
    final symbols = (raw as List<Object?>? ?? const <Object?>[])
        .whereType<Map<Object?, Object?>>()
        .map((entry) => entry.cast<String, Object?>())
        .map((entry) {
          final location =
              (entry['location'] as Map<Object?, Object?>? ?? const {})
                  .cast<String, Object?>();
          final uri = location['uri'] as String? ?? '';
          return <String, Object?>{
            'name': entry['name'],
            'kind': entry['kind'],
            'containerName': entry['containerName'],
            'path': client.toRepoRelativePath(uri),
          };
        })
        .where((entry) {
          if (pathFilter == null) {
            return true;
          }
          return (entry['path'] as String).contains(pathFilter);
        })
        .take(limit)
        .toList(growable: false);

    if (jsonOutput) {
      return ToolCommandResult(
        exitCode: 0,
        stdout: '${const JsonEncoder.withIndent('  ').convert(symbols)}\n',
      );
    }

    final buffer = StringBuffer();
    if (symbols.isEmpty) {
      buffer.writeln('No symbols matched "$query".');
    } else {
      buffer.writeln('Symbols matching "$query":');
      for (final symbol in symbols) {
        final containerName = symbol['containerName'] as String?;
        final label = containerName == null || containerName.isEmpty
            ? '${symbol['name']}'
            : '$containerName.${symbol['name']}';
        buffer.writeln(
          '- $label '
          '(${symbol['path']}, kind=${symbol['kind']})',
        );
      }
    }
    return ToolCommandResult(exitCode: 0, stdout: buffer.toString());
  } on LanguageServerError catch (error) {
    return ToolCommandResult(
      exitCode: 1,
      stderr: 'FAIL: LSP workspace/symbol failed: ${error.message}\n',
    );
  } finally {
    await client.close();
  }
}

Future<Object?> _querySymbolsWithRetry(
  LanguageServerClient client,
  String query,
) async {
  for (var attempt = 0; attempt < 5; attempt++) {
    final raw = await client.request('workspace/symbol', <String, Object?>{
      'query': query,
    });
    final symbols = raw as List<Object?>? ?? const <Object?>[];
    if (symbols.isNotEmpty) {
      return symbols;
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  return const <Object?>[];
}

Future<void> main(List<String> args) async {
  final result = await runLspFindSymbolsTool(args);
  writeToolCommandResult(result);
  exitCode = result.exitCode;
}

int? _parseIntFlag(List<String> args, String name) {
  final value = _parseStringFlag(args, name);
  if (value == null) {
    return null;
  }
  return int.tryParse(value);
}

String? _parseStringFlag(List<String> args, String name) {
  for (final argument in args) {
    if (argument.startsWith('$name=')) {
      return argument.replaceFirst('$name=', '');
    }
  }
  return null;
}
