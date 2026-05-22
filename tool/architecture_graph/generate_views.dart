import 'dart:io';

import 'src/actual_graph.dart';
import 'src/architecture_graph.dart';
import 'src/graph_views.dart';

void main(List<String> arguments) {
  final phase = _phaseArgument(arguments);
  if (phase == null) {
    stderr.writeln(
      'Usage: dart run tool/architecture_graph/generate_views.dart --phase Px [--check]',
    );
    exitCode = 64;
    return;
  }

  final expected = loadExpectedArchitectureGraph();
  final validationDiagnostics = validateExpectedArchitectureGraph(expected);
  if (validationDiagnostics.isNotEmpty) {
    stderr.writeln('architecture_graph.yaml is invalid:');
    for (final diagnostic in validationDiagnostics) {
      stderr.writeln(diagnostic);
    }
    exitCode = 65;
    return;
  }
  if (!expected.phaseIds.contains(phase)) {
    stderr.writeln('Unknown architecture graph phase: $phase');
    exitCode = 64;
    return;
  }

  final actual = extractActualArchitectureGraph(expectedGraph: expected);
  final views = renderGraphViews(
    expected: expected,
    actual: actual,
    selectedPhase: phase,
  );

  if (arguments.contains('--check')) {
    final stale = checkGraphViews(views: views);
    if (stale.isNotEmpty) {
      stderr.writeln('Generated architecture graph views are stale:');
      for (final path in stale) {
        stderr.writeln('- $path');
      }
      exitCode = 1;
    }
    return;
  }

  final changed = writeGraphViews(views: views);
  for (final path in changed) {
    stdout.writeln('wrote $path');
  }
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
