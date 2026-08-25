import 'dart:convert';
import 'dart:io';

import 'src/lsp/language_server_client.dart';
import 'src/lsp/symbol_locator.dart';
import 'src/lsp/trace_support.dart';
import 'src/tool_command_result.dart';

Future<ToolCommandResult> runAuditRouteExpectationsTool(
  List<String> args, {
  Directory? root,
}) async {
  final workingRoot = root ?? Directory.current;
  final configPath = toolCommandStringFlag(args, '--config');
  if (configPath == null) {
    return const ToolCommandResult(
      exitCode: 1,
      stderr:
          'Usage: dart run tool/audit_route_expectations.dart '
          '--config=<json> [--json] [--json-out=file]\n',
    );
  }
  final jsonOutput = args.contains('--json');
  final jsonOutPath = toolCommandStringFlag(args, '--json-out');

  late final _RouteAuditConfig config;
  try {
    config = _readConfig(workingRoot, configPath);
  } on _MissingRouteAuditConfig catch (error) {
    return _failure('route-audit config not found: ${error.path}');
  }

  try {
    final results = await _runAudit(workingRoot, config);
    return _resultForAudit(
      _RouteAuditOutput(
        root: workingRoot,
        configPath: configPath,
        results: results,
        jsonOutput: jsonOutput,
        jsonOutPath: jsonOutPath,
      ),
    );
  } on SymbolLocateFailure catch (error) {
    return _failure(error.message);
  } on LanguageServerError catch (error) {
    return _failure('route audit failed: ${error.message}');
  }
}

ToolCommandResult _failure(String message) =>
    ToolCommandResult(exitCode: 1, stderr: 'FAIL: $message\n');

Future<void> main(List<String> args) async {
  final result = await runAuditRouteExpectationsTool(args);
  writeToolCommandResult(result);
  exitCode = result.exitCode;
}

_RouteAuditConfig _readConfig(Directory root, String configPath) {
  final configFile = File(
    configPath.startsWith('/')
        ? configPath
        : '${root.path}${Platform.pathSeparator}$configPath',
  );
  if (!configFile.existsSync()) {
    throw _MissingRouteAuditConfig(configFile.path);
  }
  return _parseConfig(jsonDecode(configFile.readAsStringSync()) as Object?);
}

Future<List<_RouteExpectationResult>> _runAudit(
  Directory root,
  _RouteAuditConfig config,
) async {
  final client = await LanguageServerClient.start(root: root);
  try {
    return [
      for (final check in config.checks)
        await _runCheck(client, root: root, check: check),
    ];
  } finally {
    await client.close();
  }
}

Map<String, Object?> _buildReport(
  String configPath,
  List<_RouteExpectationResult> results,
) => <String, Object?>{
  'configPath': configPath,
  'summary': <String, Object?>{
    'total': results.length,
    'passed': results.where((result) => result.isPass).length,
    'failed': results.where((result) => result.isFailure).length,
    'errors': results.where((result) => result.isError).length,
  },
  'results': [for (final result in results) result.toJson()],
};

ToolCommandResult _resultForAudit(_RouteAuditOutput output) {
  final report = _buildReport(output.configPath, output.results);
  final reportJson = encodeToolCommandJson(report);
  if (output.jsonOutPath case final jsonOutPath?) {
    writeToolCommandOutputFile(output.root, jsonOutPath, '$reportJson\n');
  }
  return ToolCommandResult(
    exitCode: _exitCodeForResults(output.results),
    stdout: output.jsonOutput
        ? '$reportJson\n'
        : _renderTextReport(output.configPath, output.results),
  );
}

// A route witness keeps locating, traversal, and expectation evaluation together.
// ignore: halstead-volume, source-lines-of-code, reason: One route witness keeps lookup, traversal, and expectation together.
Future<_RouteExpectationResult> _runCheck(
  LanguageServerClient client, {
  required Directory root,
  required _RouteAuditCheck check,
}) async {
  final located = locateSymbol(
    root: root,
    repoRelativePath: check.file,
    query: check.symbol,
  );
  final item = await prepareCallItemForSymbol(client, located);
  if (item == null) {
    return _RouteExpectationResult.error(
      check: check,
      message:
          'LSP did not return a call-hierarchy item for '
          '${check.symbol} in ${check.file}.',
    );
  }

  final visited = <String>{};
  final reachable = <_ReachableItem>[];
  await _collectReachableItems(
    client,
    item,
    direction: check.direction,
    remainingDepth: check.depth,
    includeExternal: false,
    visited: visited,
    reachable: reachable,
  );

  final matches = reachable.where(
    (candidate) => _matchesTarget(candidate, check.target),
  );
  final hasMatch = matches.isNotEmpty;

  return switch (check.expectation) {
    _RouteExpectation.contains when hasMatch => _RouteExpectationResult.pass(
      check: check,
      matchedLabels: matches
          .map((candidate) => candidate.label)
          .toSet()
          .toList(growable: false),
    ),
    _RouteExpectation.contains => _RouteExpectationResult.failure(
      check: check,
      message:
          'Expected route to reach ${check.target}, but it was absent from '
          '${check.direction.name} traversal.',
      matchedLabels: const <String>[],
    ),
    _RouteExpectation.absent when !hasMatch => _RouteExpectationResult.pass(
      check: check,
      matchedLabels: const <String>[],
    ),
    _RouteExpectation.absent => _RouteExpectationResult.failure(
      check: check,
      message:
          'Expected route to avoid ${check.target}, but traversal reached it.',
      matchedLabels: matches
          .map((candidate) => candidate.label)
          .toSet()
          .toList(growable: false),
    ),
  };
}

// The traversal's client, direction, depth, and visited/result accumulators are
// one recursive state bundle; a context object would only obscure that boundary.
// ignore: number-of-parameters, source-lines-of-code, reason: These values are one recursive traversal state bundle.
Future<void> _collectReachableItems(
  LanguageServerClient client,
  LspCallItem item, {
  required _RouteDirection direction,
  required int remainingDepth,
  required bool includeExternal,
  required Set<String> visited,
  required List<_ReachableItem> reachable,
}) async {
  if (!visited.add(item.key)) {
    return;
  }
  reachable.add(
    _ReachableItem(
      name: item.name,
      label: item.label,
      detail: item.detail,
      path: item.repoRelativePath,
    ),
  );
  if (remainingDepth <= 0) {
    return;
  }

  final neighbors = <LspCallItem>[
    if (direction case _RouteDirection.outgoing || _RouteDirection.both)
      ...await collectCallHierarchyItems(
        client,
        item,
        method: 'callHierarchy/outgoingCalls',
        includeExternal: includeExternal,
      ),
    if (direction case _RouteDirection.incoming || _RouteDirection.both)
      ...await collectCallHierarchyItems(
        client,
        item,
        method: 'callHierarchy/incomingCalls',
        includeExternal: includeExternal,
      ),
    ...await collectImplementationItems(
      client,
      item,
      includeExternal: includeExternal,
    ),
  ];

  for (final neighbor in neighbors) {
    await _collectReachableItems(
      client,
      neighbor,
      direction: direction,
      remainingDepth: remainingDepth - 1,
      includeExternal: includeExternal,
      visited: visited,
      reachable: reachable,
    );
  }
}

bool _matchesTarget(_ReachableItem candidate, String target) {
  return candidate.name == target ||
      candidate.label == target ||
      candidate.detail == target;
}

int _exitCodeForResults(List<_RouteExpectationResult> results) {
  if (results.any((result) => result.isError)) {
    return 2;
  }
  if (results.any((result) => result.isFailure)) {
    return 1;
  }
  return 0;
}

String _renderTextReport(
  String configPath,
  List<_RouteExpectationResult> results,
) {
  final buffer = StringBuffer()
    ..writeln('Route audit config: $configPath')
    ..writeln(
      'Summary: total=${results.length}, '
      'passed=${results.where((result) => result.isPass).length}, '
      'failed=${results.where((result) => result.isFailure).length}, '
      'errors=${results.where((result) => result.isError).length}',
    );
  for (final result in results) {
    buffer.writeln(
      '- ${result.status}: ${result.check.description} '
      '(${result.check.symbol} @ ${result.check.file})',
    );
    if (result.message case final message?) {
      buffer.writeln('  $message');
    }
    if (result.matchedLabels.isNotEmpty) {
      buffer.writeln('  matched: ${result.matchedLabels.join(', ')}');
    }
  }
  return buffer.toString();
}

_RouteAuditConfig _parseConfig(Object? raw) {
  if (raw is! Map<Object?, Object?>) {
    throw const FormatException('top-level JSON object is required');
  }
  final cast = raw.cast<String, Object?>();
  final checks = cast['checks'];
  if (checks is! List<Object?>) {
    throw const FormatException('"checks" must be a JSON array');
  }
  return _RouteAuditConfig(
    checks: checks.map(_parseCheck).toList(growable: false),
  );
}

// All fields are validated together so malformed configuration has one error boundary.
// ignore: cyclomatic-complexity, halstead-volume, source-lines-of-code, reason: All fields require one malformed-config boundary.
_RouteAuditCheck _parseCheck(Object? raw) {
  if (raw is! Map<Object?, Object?>) {
    throw const FormatException('each check must be a JSON object');
  }
  final cast = raw.cast<String, Object?>();
  final description = cast['description'];
  final file = cast['file'];
  final symbol = cast['symbol'];
  final target = cast['target'];
  final expectation = cast['expectation'];

  if (description is! String ||
      file is! String ||
      symbol is! String ||
      target is! String ||
      expectation is! String) {
    throw const FormatException(
      'each check requires string '
      '"description", "file", "symbol", "target", and "expectation"',
    );
  }

  final directionValue = cast['direction'];
  final direction = switch (directionValue) {
    null => _RouteDirection.outgoing,
    'outgoing' => _RouteDirection.outgoing,
    'incoming' => _RouteDirection.incoming,
    'both' => _RouteDirection.both,
    _ => throw FormatException(
      'unsupported direction "$directionValue" for $symbol',
    ),
  };
  final depthValue = cast['depth'];
  final depth = switch (depthValue) {
    null => 3,
    final int value when value >= 0 => value,
    _ => throw FormatException('depth must be a non-negative int for $symbol'),
  };

  return _RouteAuditCheck(
    description: description,
    file: file,
    symbol: symbol,
    target: target,
    expectation: switch (expectation) {
      'contains' => _RouteExpectation.contains,
      'absent' => _RouteExpectation.absent,
      _ => throw FormatException(
        'unsupported expectation "$expectation" for $symbol',
      ),
    },
    direction: direction,
    depth: depth,
  );
}

final class _RouteAuditConfig {
  const _RouteAuditConfig({required this.checks});

  final List<_RouteAuditCheck> checks;
}

final class _RouteAuditOutput {
  const _RouteAuditOutput({
    required this.root,
    required this.configPath,
    required this.results,
    required this.jsonOutput,
    required this.jsonOutPath,
  });

  final Directory root;
  final String configPath;
  final List<_RouteExpectationResult> results;
  final bool jsonOutput;
  final String? jsonOutPath;
}

final class _MissingRouteAuditConfig implements Exception {
  const _MissingRouteAuditConfig(this.path);

  final String path;
}

final class _RouteAuditCheck {
  const _RouteAuditCheck({
    required this.description,
    required this.file,
    required this.symbol,
    required this.target,
    required this.expectation,
    required this.direction,
    required this.depth,
  });

  final String description;
  final String file;
  final String symbol;
  final String target;
  final _RouteExpectation expectation;
  final _RouteDirection direction;
  final int depth;
}

enum _RouteExpectation { contains, absent }

enum _RouteDirection { outgoing, incoming, both }

final class _ReachableItem {
  const _ReachableItem({
    required this.name,
    required this.label,
    required this.detail,
    required this.path,
  });

  final String name;
  final String label;
  final String detail;
  final String path;
}

final class _RouteExpectationResult {
  const _RouteExpectationResult._({
    required this.status,
    required this.check,
    required this.message,
    required this.matchedLabels,
  });

  factory _RouteExpectationResult.pass({
    required _RouteAuditCheck check,
    required List<String> matchedLabels,
  }) {
    return _RouteExpectationResult._(
      status: 'PASS',
      check: check,
      message: null,
      matchedLabels: matchedLabels,
    );
  }

  factory _RouteExpectationResult.failure({
    required _RouteAuditCheck check,
    required String message,
    required List<String> matchedLabels,
  }) {
    return _RouteExpectationResult._(
      status: 'FAIL',
      check: check,
      message: message,
      matchedLabels: matchedLabels,
    );
  }

  factory _RouteExpectationResult.error({
    required _RouteAuditCheck check,
    required String message,
  }) {
    return _RouteExpectationResult._(
      status: 'ERROR',
      check: check,
      message: message,
      matchedLabels: const <String>[],
    );
  }

  final String status;
  final _RouteAuditCheck check;
  final String? message;
  final List<String> matchedLabels;

  bool get isPass => status == 'PASS';
  bool get isFailure => status == 'FAIL';
  bool get isError => status == 'ERROR';

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'status': status,
      'description': check.description,
      'file': check.file,
      'symbol': check.symbol,
      'target': check.target,
      'expectation': check.expectation.name,
      'direction': check.direction.name,
      'depth': check.depth,
      'message': message,
      'matchedLabels': matchedLabels,
    };
  }
}
