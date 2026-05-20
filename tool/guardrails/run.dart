import 'dart:io';

import 'src/guardrail_executor.dart';
import 'src/guardrail_registry.dart';

Future<void> main(List<String> arguments) async {
  final selection = _selectGuardrails(arguments);
  if (selection == null) {
    exitCode = 64;
    return;
  }

  final result = await runGuardrails(selection);
  for (final id in result.ranGuardrailIds) {
    stdout.writeln('ran $id');
  }
  exitCode = result.exitCode;
}

List<String>? _selectGuardrails(List<String> arguments) {
  if (arguments.isEmpty) {
    return _sorted(blockingGuardrailIds());
  }

  if (arguments.length != 1) {
    _printUsage();
    return null;
  }

  final argument = arguments.single;
  if (argument.startsWith('--suite=')) {
    return _selectSuite(argument.substring('--suite='.length));
  }

  if (argument.startsWith('--guardrail=')) {
    return _selectGuardrail(argument.substring('--guardrail='.length));
  }

  stderr.writeln('Unknown argument: $argument');

  return null;
}

List<String>? _selectSuite(String suite) {
  final ids = _sorted(suiteGuardrailIds(suite));
  if (ids.isEmpty) {
    stderr.writeln('Unknown or empty guardrail suite: $suite');
    return null;
  }

  return ids;
}

List<String>? _selectGuardrail(String id) {
  final entry = guardrailInventory()[id];
  if (entry == null) {
    stderr.writeln('Unknown guardrail: $id');
    return null;
  }

  return [id];
}

List<String> _sorted(Set<String> ids) {
  return ids.toList()..sort();
}

void _printUsage() {
  stderr.writeln('Use one of: --suite=<name>, --guardrail=<id>');
}
