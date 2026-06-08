import 'dart:io';

import 'src/actual_graph.dart';
import 'src/architecture_graph.dart';
import 'src/current_closure.dart';

void main(List<String> arguments) {
  if (arguments.isNotEmpty) {
    stderr.writeln('Usage: dart run tool/architecture_graph/check.dart');
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
  final report = checkArchitectureClosure(expected: expected, actual: actual);
  stdout.write(formatArchitectureClosureReport(report));
  exitCode = report.isClosed ? 0 : 1;
}
