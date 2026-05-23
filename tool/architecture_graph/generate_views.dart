import 'dart:io';

import 'src/actual_graph.dart';
import 'src/architecture_graph.dart';
import 'src/graph_views.dart';

void main(List<String> arguments) {
  final phase = _phaseArgument(arguments);
  if (phase == null) {
    _failUsage();
    return;
  }

  final expected = loadExpectedArchitectureGraph();
  if (!_validateExpected(expected) || !_validatePhase(expected, phase)) {
    return;
  }

  final views = _buildViews(expected, phase);

  if (arguments.contains('--check')) {
    _checkViews(views);
    return;
  }

  _writeViews(views);
}

String? _phaseArgument(List<String> arguments) {
  for (var index = 0; index < arguments.length; index++) {
    final argument = arguments[index];
    if (argument == '--phase' && index + 1 < arguments.length) {
      return arguments[index + 1];
    }
    if (argument.startsWith('--phase=')) {
      return argument.substring('--phase='.length);
    }
  }

  return null;
}

void _failUsage() {
  stderr.writeln(
    'Usage: dart run tool/architecture_graph/generate_views.dart --phase Px [--check]',
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

bool _validatePhase(ExpectedArchitectureGraph expected, String phase) {
  if (expected.phaseIds.contains(phase)) {
    return true;
  }
  stderr.writeln('Unknown architecture graph phase: $phase');
  exitCode = 64;

  return false;
}

Map<String, String> _buildViews(
  ExpectedArchitectureGraph expected,
  String phase,
) {
  return renderGraphViews(
    expected: expected,
    actual: extractActualArchitectureGraph(expectedGraph: expected),
    selectedPhase: phase,
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
