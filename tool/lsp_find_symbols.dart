import 'dart:io';

import 'src/lsp/language_server_client.dart';
import 'src/tool_command_result.dart';

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
  final limit = toolCommandIntFlag(args, '--limit') ?? 20;
  final pathFilter = toolCommandStringFlag(args, '--path-contains');
  final jsonOutput = args.contains('--json');
  try {
    final symbols = await _findSymbols(
      root: root,
      query: query,
      pathFilter: pathFilter,
      limit: limit,
    );

    if (jsonOutput) {
      return ToolCommandResult(
        exitCode: 0,
        stdout: '${encodeToolCommandJson(symbols)}\n',
      );
    }

    return ToolCommandResult(
      exitCode: 0,
      stdout: _renderTextReport(query, symbols),
    );
  } on LanguageServerError catch (error) {
    return ToolCommandResult(
      exitCode: 1,
      stderr: 'FAIL: LSP workspace/symbol failed: ${error.message}\n',
    );
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

Future<List<Map<String, Object?>>> _findSymbols({
  required Directory? root,
  required String query,
  required String? pathFilter,
  required int limit,
}) async {
  final client = await LanguageServerClient.start(root: root);
  try {
    final raw = await _querySymbolsWithRetry(client, query);
    return _mapSymbols(
      client,
      raw,
      pathFilter: pathFilter,
    ).take(limit).toList();
  } finally {
    await client.close();
  }
}

Iterable<Map<String, Object?>> _mapSymbols(
  LanguageServerClient client,
  Object? raw, {
  required String? pathFilter,
}) sync* {
  for (final rawEntry
      in (raw as List<Object?>? ?? const <Object?>[])
          .whereType<Map<Object?, Object?>>()) {
    final entry = rawEntry.cast<String, Object?>();
    final location = (entry['location'] as Map<Object?, Object?>? ?? const {})
        .cast<String, Object?>();
    final path = client.toRepoRelativePath(location['uri'] as String? ?? '');
    if (pathFilter == null || path.contains(pathFilter)) {
      yield <String, Object?>{
        'name': entry['name'],
        'kind': entry['kind'],
        'containerName': entry['containerName'],
        'path': path,
      };
    }
  }
}

String _renderTextReport(String query, List<Map<String, Object?>> symbols) {
  final buffer = StringBuffer();
  if (symbols.isEmpty) {
    buffer.writeln('No symbols matched "$query".');
    return buffer.toString();
  }
  buffer.writeln('Symbols matching "$query":');
  for (final symbol in symbols) {
    final containerName = symbol['containerName'] as String?;
    final label = containerName == null || containerName.isEmpty
        ? '${symbol['name']}'
        : '$containerName.${symbol['name']}';
    buffer.writeln('- $label (${symbol['path']}, kind=${symbol['kind']})');
  }
  return buffer.toString();
}

Future<void> main(List<String> args) async {
  final result = await runLspFindSymbolsTool(args);
  writeToolCommandResult(result);
  exitCode = result.exitCode;
}
