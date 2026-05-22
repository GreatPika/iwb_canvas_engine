import 'dart:io';

import 'src/actual_graph.dart';
import 'src/architecture_graph.dart';
import 'src/phase_closure.dart';

void main(List<String> arguments) {
  final phase = _phaseArgument(arguments);
  if (phase == null) {
    stderr.writeln(
      'Usage: dart run tool/architecture_graph/check.dart --phase Px',
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

  final actual = extractActualArchitectureGraph(expectedGraph: expected);
  final report = checkPhaseClosure(
    expected: expected,
    actual: actual,
    selectedPhase: phase,
  );
  stdout.write(formatPhaseClosureReport(report));
  exitCode = report.isClosed ? 0 : 1;
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
