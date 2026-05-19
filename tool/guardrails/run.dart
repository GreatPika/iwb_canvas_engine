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
    return blockingGuardrailIds().toList()..sort();
  }

  if (arguments.length != 1) {
    stderr.writeln('Use one of: --suite=<name>, --guardrail=<id>, --changed');
    return null;
  }

  final argument = arguments.single;
  if (argument == '--changed') {
    return blockingGuardrailIds().toList()..sort();
  }

  if (argument.startsWith('--suite=')) {
    final suite = argument.substring('--suite='.length);
    final ids = suiteGuardrailIds(suite).toList()..sort();
    if (ids.isEmpty) {
      stderr.writeln('Unknown or empty guardrail suite: $suite');
      return null;
    }

    return ids;
  }

  if (argument.startsWith('--guardrail=')) {
    final id = argument.substring('--guardrail='.length);
    final entry = guardrailInventory()[id];
    if (entry == null || entry.status != GuardrailStatus.executable) {
      stderr.writeln('Unknown or deferred guardrail: $id');
      return null;
    }

    return [id];
  }

  stderr.writeln('Unknown argument: $argument');

  return null;
}
