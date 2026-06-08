import 'dart:io';

import 'src/actual_graph.dart';
import 'src/architecture_graph.dart';
import 'src/graph_views.dart';

void main(List<String> arguments) {
  if (!_validArguments(arguments)) {
    _failUsage();
    return;
  }

  final expected = loadExpectedArchitectureGraph();
  if (!_validateExpected(expected)) {
    return;
  }

  final views = _buildViews(expected);

  if (arguments.contains('--check')) {
    _checkViews(views);
    return;
  }

  _writeViews(views);
}

bool _validArguments(List<String> arguments) {
  return arguments.isEmpty ||
      (arguments.length == 1 && arguments.single == '--check');
}

void _failUsage() {
  stderr.writeln(
    'Usage: dart run tool/architecture_graph/generate_views.dart [--check]',
  );
  exitCode = 64;
}

bool _validateExpected(ExpectedArchitectureGraph expected) {
  final diagnostics = validateExpectedArchitectureGraph(expected);
  if (diagnostics.isEmpty) {
    return true;
  }
  stderr.writeln('architecture_graph.yaml is invalid:');
  for (final diagnostic in diagnostics) {
    stderr.writeln(diagnostic);
  }
  exitCode = 65;

  return false;
}

Map<String, String> _buildViews(ExpectedArchitectureGraph expected) {
  return renderGraphViews(
    expected: expected,
    actual: extractActualArchitectureGraph(expectedGraph: expected),
  );
}

void _checkViews(Map<String, String> views) {
  final stale = checkGraphViews(views: views);
  if (stale.isEmpty) {
    return;
  }
  stderr.writeln('Generated architecture graph views are stale:');
  for (final path in stale) {
    stderr.writeln('- $path');
  }
  exitCode = 1;
}

void _writeViews(Map<String, String> views) {
  for (final path in writeGraphViews(views: views)) {
    stdout.writeln('wrote $path');
  }
}
