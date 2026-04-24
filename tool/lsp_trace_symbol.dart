import 'dart:convert';
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
          '[--json-out=file] [--mermaid] [--mermaid-out=file]\n',
    );
  }

  final workingRoot = root ?? Directory.current;
  final repoRelativePath = args[0];
  final symbolQuery = args[1];
  final depth = _parseIntFlag(args, '--depth') ?? 1;
  final direction = _parseStringFlag(args, '--direction') ?? 'both';
  final includeExternal = args.contains('--include-external');
  final jsonOutput = args.contains('--json');
  final jsonOutPath = _parseStringFlag(args, '--json-out');
  final mermaidOutput = args.contains('--mermaid');
  final mermaidOutPath = _parseStringFlag(args, '--mermaid-out');

  final located = () {
    try {
      return locateSymbol(
        root: workingRoot,
        repoRelativePath: repoRelativePath,
        query: symbolQuery,
      );
    } on SymbolLocateFailure catch (error) {
      throw _TraceFailure(error.message);
    }
  }();

  final client = await LanguageServerClient.start(root: workingRoot);
  try {
    await client.openFile(located.repoRelativePath);
    final item = await prepareCallItemForSymbol(client, located);
    if (item == null) {
      throw _TraceFailure(
        'LSP did not return a call-hierarchy item for '
        '${located.displayName} in ${located.repoRelativePath}.',
      );
    }

    final references = await client.requestWithFileRetry(
      'textDocument/references',
      <String, Object?>{
        'textDocument': <String, Object?>{
          'uri': client.resolveUri(located.repoRelativePath).toString(),
        },
        'position': <String, Object?>{
          'line': located.line,
          'character': located.character,
        },
        'context': const <String, Object?>{'includeDeclaration': true},
      },
    );
    final implementations = await client.requestWithFileRetry(
      'textDocument/implementation',
      <String, Object?>{
        'textDocument': <String, Object?>{
          'uri': client.resolveUri(located.repoRelativePath).toString(),
        },
        'position': <String, Object?>{
          'line': located.line,
          'character': located.character,
        },
      },
    );

    final incoming = switch (direction) {
      'incoming' || 'both' => await _collectCallTree(
        client,
        item,
        depth: depth,
        method: 'callHierarchy/incomingCalls',
        includeExternal: includeExternal,
      ),
      _ => const <Map<String, Object?>>[],
    };
    final outgoing = switch (direction) {
      'outgoing' || 'both' => await _collectCallTree(
        client,
        item,
        depth: depth,
        method: 'callHierarchy/outgoingCalls',
        includeExternal: includeExternal,
      ),
      _ => const <Map<String, Object?>>[],
    };

    final report = <String, Object?>{
      'symbol': located.displayName,
      'kind': located.kind,
      'path': located.repoRelativePath,
      'referencesByFile': _countLocationsByFile(
        client,
        references as List<Object?>? ?? const <Object?>[],
      ),
      'implementations': _mapLocations(
        client,
        implementations as List<Object?>? ?? const <Object?>[],
      ),
      'incoming': incoming,
      'outgoing': outgoing,
    };
    final reportJson = const JsonEncoder.withIndent('  ').convert(report);
    final mermaid = _renderMermaid(report);

    if (jsonOutPath != null) {
      _writeOutputFile(workingRoot, jsonOutPath, '$reportJson\n');
    }
    if (mermaidOutPath != null) {
      _writeOutputFile(
        workingRoot,
        mermaidOutPath,
        '${_renderMermaidDocument(mermaid)}\n',
      );
    }

    if (jsonOutput) {
      return ToolCommandResult(exitCode: 0, stdout: '$reportJson\n');
    }
    if (mermaidOutput) {
      return ToolCommandResult(exitCode: 0, stdout: '$mermaid\n');
    }

    final buffer = StringBuffer()
      ..writeln('Symbol: ${report['symbol']} (${report['kind']})')
      ..writeln('File: ${report['path']}')
      ..writeln('References by file:');
    final referencesByFile = report['referencesByFile'] as Map<String, Object?>;
    if (referencesByFile.isEmpty) {
      buffer.writeln('- none');
    } else {
      final sortedKeys = referencesByFile.keys.toList()..sort();
      for (final key in sortedKeys) {
        buffer.writeln('- $key: ${referencesByFile[key]}');
      }
    }
    final implementationLocations =
        report['implementations'] as List<Map<String, Object?>>;
    buffer.writeln('Implementations:');
    if (implementationLocations.isEmpty) {
      buffer.writeln('- none');
    } else {
      for (final implementation in implementationLocations) {
        buffer.writeln(
          '- ${implementation['path']}:${implementation['line']}:'
          '${implementation['character']}',
        );
      }
    }
    buffer.writeln('Incoming calls:');
    _writeTree(buffer, incoming, indent: '');
    buffer.writeln('Outgoing calls:');
    _writeTree(buffer, outgoing, indent: '');
    return ToolCommandResult(exitCode: 0, stdout: buffer.toString());
  } on _TraceFailure catch (error) {
    return ToolCommandResult(exitCode: 1, stderr: 'FAIL: ${error.message}\n');
  } on LanguageServerError catch (error) {
    return ToolCommandResult(
      exitCode: 1,
      stderr: 'FAIL: LSP trace failed: ${error.message}\n',
    );
  } finally {
    await client.close();
  }
}

Future<void> main(List<String> args) async {
  final result = await runLspTraceSymbolTool(args);
  writeToolCommandResult(result);
  exitCode = result.exitCode;
}

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
  final result = <Map<String, Object?>>[];
  for (final mapped in entries) {
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

Map<String, int> _countLocationsByFile(
  LanguageServerClient client,
  List<Object?> rawLocations,
) {
  final counts = <String, int>{};
  for (final location in rawLocations.whereType<Map<Object?, Object?>>()) {
    final cast = location.cast<String, Object?>();
    final path = client.toRepoRelativePath(cast['uri'] as String? ?? '');
    counts.update(path, (value) => value + 1, ifAbsent: () => 1);
  }
  return counts;
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
      .toList(growable: false);
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
      return argument.substring(name.length + 1);
    }
  }
  return null;
}

final class _TraceFailure implements Exception {
  const _TraceFailure(this.message);

  final String message;
}

void _writeOutputFile(Directory root, String outputPath, String content) {
  final target = File(
    outputPath.startsWith('/')
        ? outputPath
        : '${root.path}${Platform.pathSeparator}$outputPath',
  );
  target.parent.createSync(recursive: true);
  target.writeAsStringSync(content);
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
