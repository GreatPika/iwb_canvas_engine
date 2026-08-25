import 'dart:io';

import 'src/lsp/language_server_client.dart';
import 'src/lsp/symbol_locator.dart';
import 'src/lsp/trace_support.dart';
import 'src/tool_command_result.dart';

Future<ToolCommandResult> runLspTraceSymbolTool(
  List<String> args, {
  Directory? root,
}) async {
  if (args.length < 2) {
    return const ToolCommandResult(
      exitCode: 1,
      stderr:
          'Usage: dart run tool/lsp_trace_symbol.dart <file> <symbol> '
          '[--depth=N] [--direction=outgoing|incoming|both] [--json] '
          '[--json-out=file] [--mermaid] [--mermaid-out=file] '
          '[--omit-reference-path-prefix=prefix]\n',
    );
  }

  final request = _TraceRequest.fromArgs(args, root ?? Directory.current);
  try {
    final report = await _collectTraceReport(request);
    return _resultForTrace(request, report);
  } on SymbolLocateFailure catch (error) {
    return ToolCommandResult(exitCode: 1, stderr: 'FAIL: ${error.message}\n');
  } on _TraceFailure catch (error) {
    return ToolCommandResult(exitCode: 1, stderr: 'FAIL: ${error.message}\n');
  } on LanguageServerError catch (error) {
    return ToolCommandResult(
      exitCode: 1,
      stderr: 'FAIL: LSP trace failed: ${error.message}\n',
    );
  }
}

Future<void> main(List<String> args) async {
  final result = await runLspTraceSymbolTool(args);
  writeToolCommandResult(result);
  exitCode = result.exitCode;
}

Future<Map<String, Object?>> _collectTraceReport(_TraceRequest request) async {
  final located = locateSymbol(
    root: request.root,
    repoRelativePath: request.repoRelativePath,
    query: request.symbolQuery,
  );
  final client = await LanguageServerClient.start(root: request.root);
  try {
    final item = await prepareCallItemForSymbol(client, located);
    if (item == null) {
      throw _TraceFailure(
        'LSP did not return a call-hierarchy item for '
        '${located.displayName} in ${located.repoRelativePath}.',
      );
    }
    final locations = await _collectLocations(client, located);
    final trees = await _collectDirectionTrees(client, item, request);
    return _buildTraceReport(
      _TraceReportInput(
        client: client,
        located: located,
        locations: locations,
        trees: trees,
        request: request,
      ),
    );
  } finally {
    await client.close();
  }
}

Future<({Object? references, Object? implementations})> _collectLocations(
  LanguageServerClient client,
  LocatedSymbol located,
) async {
  final params = <String, Object?>{
    'textDocument': <String, Object?>{
      'uri': client.resolveUri(located.repoRelativePath).toString(),
    },
    'position': <String, Object?>{
      'line': located.line,
      'character': located.character,
    },
  };
  final references = await client.requestWithFileRetry(
    'textDocument/references',
    <String, Object?>{
      ...params,
      'context': const <String, Object?>{'includeDeclaration': true},
    },
  );
  final implementations = await client.requestWithFileRetry(
    'textDocument/implementation',
    params,
  );
  return (references: references, implementations: implementations);
}

Future<
  ({List<Map<String, Object?>> incoming, List<Map<String, Object?>> outgoing})
>
_collectDirectionTrees(
  LanguageServerClient client,
  LspCallItem item,
  _TraceRequest request,
) async {
  final incoming = switch (request.direction) {
    'incoming' || 'both' => await _collectCallTree(
      client,
      item,
      depth: request.depth,
      method: 'callHierarchy/incomingCalls',
      includeExternal: request.includeExternal,
    ),
    _ => const <Map<String, Object?>>[],
  };
  final outgoing = switch (request.direction) {
    'outgoing' || 'both' => await _collectCallTree(
      client,
      item,
      depth: request.depth,
      method: 'callHierarchy/outgoingCalls',
      includeExternal: request.includeExternal,
    ),
    _ => const <Map<String, Object?>>[],
  };
  return (incoming: incoming, outgoing: outgoing);
}

Map<String, Object?> _buildTraceReport(_TraceReportInput input) =>
    <String, Object?>{
      'symbol': input.located.displayName,
      'kind': input.located.kind,
      'path': input.located.repoRelativePath,
      'referencesByFile': _countLocationsByFile(
        input.client,
        input.locations.references as List<Object?>? ?? const <Object?>[],
        omittedPathPrefixes: input.request.omittedReferencePathPrefixes,
      ),
      'implementations': _mapLocations(
        input.client,
        input.locations.implementations as List<Object?>? ?? const <Object?>[],
      ),
      'incoming': input.trees.incoming,
      'outgoing': input.trees.outgoing,
    };

ToolCommandResult _resultForTrace(
  _TraceRequest request,
  Map<String, Object?> report,
) {
  final reportJson = encodeToolCommandJson(report);
  final mermaid = _renderMermaid(report);
  if (request.jsonOutPath case final path?) {
    writeToolCommandOutputFile(request.root, path, '$reportJson\n');
  }
  if (request.mermaidOutPath case final path?) {
    writeToolCommandOutputFile(
      request.root,
      path,
      '${_renderMermaidDocument(mermaid)}\n',
    );
  }
  return ToolCommandResult(
    exitCode: 0,
    stdout: request.jsonOutput
        ? '$reportJson\n'
        : request.mermaidOutput
        ? '$mermaid\n'
        : _renderTextReport(report),
  );
}

String _renderTextReport(Map<String, Object?> report) {
  final buffer = StringBuffer()
    ..writeln('Symbol: ${report['symbol']} (${report['kind']})')
    ..writeln('File: ${report['path']}')
    ..writeln('References by file:');
  _writeReferences(buffer, report['referencesByFile'] as Map<String, Object?>);
  buffer.writeln('Implementations:');
  _writeImplementations(
    buffer,
    report['implementations'] as List<Map<String, Object?>>,
  );
  buffer.writeln('Incoming calls:');
  _writeTree(
    buffer,
    report['incoming'] as List<Map<String, Object?>>,
    indent: '',
  );
  buffer.writeln('Outgoing calls:');
  _writeTree(
    buffer,
    report['outgoing'] as List<Map<String, Object?>>,
    indent: '',
  );
  return buffer.toString();
}

void _writeReferences(StringBuffer buffer, Map<String, Object?> references) {
  if (references.isEmpty) {
    buffer.writeln('- none');
    return;
  }
  final keys = references.keys.toList()..sort();
  for (final key in keys) {
    buffer.writeln('- $key: ${references[key]}');
  }
}

void _writeImplementations(
  StringBuffer buffer,
  List<Map<String, Object?>> implementations,
) {
  if (implementations.isEmpty) {
    buffer.writeln('- none');
    return;
  }
  for (final implementation in implementations) {
    buffer.writeln(
      '- ${implementation['path']}:${implementation['line']}:'
      '${implementation['character']}',
    );
  }
}

// These parameters are the recursive call-tree state; a context wrapper would
// conceal the direction-specific LSP request that the report must preserve.
// ignore: number-of-parameters, reason: These parameters are one recursive call-tree state.
Future<List<Map<String, Object?>>> _collectCallTree(
  LanguageServerClient client,
  LspCallItem item, {
  required int depth,
  required String method,
  required bool includeExternal,
}) async {
  if (depth <= 0) {
    return const <Map<String, Object?>>[];
  }
  final entries = await collectCallHierarchyItems(
    client,
    item,
    method: method,
    includeExternal: includeExternal,
  );
  final sortedEntries = entries.toList(growable: false)
    ..sort(_compareCallItems);
  final result = <Map<String, Object?>>[];
  for (final mapped in sortedEntries) {
    final next = <String, Object?>{
      'name': mapped.name,
      'detail': mapped.detail,
      'path': mapped.repoRelativePath,
      'children': await _collectCallTree(
        client,
        mapped,
        depth: depth - 1,
        method: method,
        includeExternal: includeExternal,
      ),
    };
    result.add(next);
  }
  return result;
}

int _compareCallItems(LspCallItem left, LspCallItem right) {
  final pathCompare = left.repoRelativePath.compareTo(right.repoRelativePath);
  if (pathCompare != 0) {
    return pathCompare;
  }
  final detailCompare = left.detail.compareTo(right.detail);
  if (detailCompare != 0) {
    return detailCompare;
  }
  final nameCompare = left.name.compareTo(right.name);
  if (nameCompare != 0) {
    return nameCompare;
  }
  final lineCompare = left.line.compareTo(right.line);
  if (lineCompare != 0) {
    return lineCompare;
  }
  return left.character.compareTo(right.character);
}

Map<String, int> _countLocationsByFile(
  LanguageServerClient client,
  List<Object?> rawLocations, {
  required List<String> omittedPathPrefixes,
}) {
  final counts = <String, int>{};
  for (final location in rawLocations.whereType<Map<Object?, Object?>>()) {
    final cast = location.cast<String, Object?>();
    final path = client.toRepoRelativePath(cast['uri'] as String? ?? '');
    if (_hasAnyPathPrefix(path, omittedPathPrefixes)) {
      continue;
    }
    counts.update(path, (value) => value + 1, ifAbsent: () => 1);
  }
  final sortedPaths = counts.keys.toList(growable: false)..sort();
  return <String, int>{for (final path in sortedPaths) path: counts[path]!};
}

bool _hasAnyPathPrefix(String path, List<String> prefixes) {
  for (final prefix in prefixes) {
    if (path.startsWith(prefix)) {
      return true;
    }
  }
  return false;
}

List<Map<String, Object?>> _mapLocations(
  LanguageServerClient client,
  List<Object?> rawLocations,
) {
  return rawLocations
      .whereType<Map<Object?, Object?>>()
      .map((location) {
        final cast = location.cast<String, Object?>();
        final range = (cast['range'] as Map<Object?, Object?>? ?? const {})
            .cast<String, Object?>();
        final start = (range['start'] as Map<Object?, Object?>? ?? const {})
            .cast<String, Object?>();
        return <String, Object?>{
          'path': client.toRepoRelativePath(cast['uri'] as String? ?? ''),
          'line': (start['line'] as int? ?? 0) + 1,
          'character': (start['character'] as int? ?? 0) + 1,
        };
      })
      .toList(growable: false)
    ..sort(_compareLocations);
}

int _compareLocations(Map<String, Object?> left, Map<String, Object?> right) {
  final pathCompare = (left['path'] as String).compareTo(
    right['path'] as String,
  );
  if (pathCompare != 0) {
    return pathCompare;
  }
  final lineCompare = (left['line'] as int).compareTo(right['line'] as int);
  if (lineCompare != 0) {
    return lineCompare;
  }
  return (left['character'] as int).compareTo(right['character'] as int);
}

void _writeTree(
  StringBuffer buffer,
  List<Map<String, Object?>> nodes, {
  required String indent,
}) {
  if (nodes.isEmpty) {
    buffer.writeln('$indent- none');
    return;
  }
  for (final node in nodes) {
    final detail = node['detail'] as String?;
    final label = detail == null || detail.isEmpty
        ? '${node['name']}'
        : '$detail.${node['name']}';
    buffer.writeln('$indent- $label (${node['path']})');
    _writeTree(
      buffer,
      (node['children'] as List<Map<String, Object?>>?) ??
          const <Map<String, Object?>>[],
      indent: '$indent  ',
    );
  }
}

final class _TraceRequest {
  const _TraceRequest({
    required this.root,
    required this.repoRelativePath,
    required this.symbolQuery,
    required this.depth,
    required this.direction,
    required this.includeExternal,
    required this.jsonOutput,
    required this.jsonOutPath,
    required this.mermaidOutput,
    required this.mermaidOutPath,
    required this.omittedReferencePathPrefixes,
  });

  factory _TraceRequest.fromArgs(List<String> args, Directory root) {
    return _TraceRequest(
      root: root,
      repoRelativePath: args[0],
      symbolQuery: args[1],
      depth: toolCommandIntFlag(args, '--depth') ?? 1,
      direction: toolCommandStringFlag(args, '--direction') ?? 'both',
      includeExternal: args.contains('--include-external'),
      jsonOutput: args.contains('--json'),
      jsonOutPath: toolCommandStringFlag(args, '--json-out'),
      mermaidOutput: args.contains('--mermaid'),
      mermaidOutPath: toolCommandStringFlag(args, '--mermaid-out'),
      omittedReferencePathPrefixes: toolCommandRepeatedStringFlag(
        args,
        '--omit-reference-path-prefix',
      ),
    );
  }

  final Directory root;
  final String repoRelativePath;
  final String symbolQuery;
  final int depth;
  final String direction;
  final bool includeExternal;
  final bool jsonOutput;
  final String? jsonOutPath;
  final bool mermaidOutput;
  final String? mermaidOutPath;
  final List<String> omittedReferencePathPrefixes;
}

final class _TraceReportInput {
  const _TraceReportInput({
    required this.client,
    required this.located,
    required this.locations,
    required this.trees,
    required this.request,
  });

  final LanguageServerClient client;
  final LocatedSymbol located;
  final ({Object? references, Object? implementations}) locations;
  final ({
    List<Map<String, Object?>> incoming,
    List<Map<String, Object?>> outgoing,
  })
  trees;
  final _TraceRequest request;
}

final class _TraceFailure implements Exception {
  const _TraceFailure(this.message);

  final String message;
}

String _renderMermaid(Map<String, Object?> report) {
  final buffer = StringBuffer('flowchart LR\n');
  var nextId = 0;
  final rootId = 'N${nextId++}';
  buffer.writeln(
    '  $rootId["${_escapeMermaidLabel(report['symbol'] as String)}"]',
  );
  _writeMermaidTree(
    buffer,
    parentId: rootId,
    nextId: () => 'N${nextId++}',
    nodes: report['incoming'] as List<Map<String, Object?>>,
    reverse: true,
  );
  _writeMermaidTree(
    buffer,
    parentId: rootId,
    nextId: () => 'N${nextId++}',
    nodes: report['outgoing'] as List<Map<String, Object?>>,
    reverse: false,
  );
  return buffer.toString();
}

String _renderMermaidDocument(String mermaid) {
  return '```mermaid\n$mermaid\n```';
}

// Rendering needs the node map, id cursor, and recursion state together to
// preserve one shared Mermaid namespace across both hierarchy directions.
// ignore: number-of-parameters, reason: Rendering must retain one shared Mermaid node namespace.
void _writeMermaidTree(
  StringBuffer buffer, {
  required String parentId,
  required String Function() nextId,
  required List<Map<String, Object?>> nodes,
  required bool reverse,
}) {
  for (final node in nodes) {
    final nodeId = nextId();
    final detail = node['detail'] as String?;
    final label = detail == null || detail.isEmpty
        ? '${node['name']}'
        : '$detail.${node['name']}';
    final escapedLabel = _escapeMermaidLabel(label);
    buffer.writeln('  $nodeId["$escapedLabel"]');
    buffer.writeln(
      reverse ? '  $nodeId --> $parentId' : '  $parentId --> $nodeId',
    );
    _writeMermaidTree(
      buffer,
      parentId: nodeId,
      nextId: nextId,
      nodes:
          (node['children'] as List<Map<String, Object?>>?) ??
          const <Map<String, Object?>>[],
      reverse: reverse,
    );
  }
}

String _escapeMermaidLabel(String value) {
  return value.replaceAll('"', r'\"').replaceAll('\n', ' ');
}
