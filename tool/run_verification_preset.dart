import 'dart:io';

import 'src/verification_contract/verification_contract_json_report.dart';
import 'src/verification_contract/verification_contract_models.dart';
import 'src/verification_contract/verification_contract_resolver.dart';
import 'src/verification_contract/verification_contract_runner.dart';

Future<void> main(List<String> args) async {
  try {
    final invocation = await parseVerificationInvocation(args);
    final plan = resolveVerificationPlan(invocation);

    switch (invocation.command) {
      case VerificationCommand.resolve:
        if (invocation.format == null || invocation.format == 'json') {
          stdout.writeln(renderVerificationPlanJson(plan));
          return;
        }
        throw VerificationExit(
          exitCode: 64,
          message:
              'Unsupported --format value: ${invocation.format}\n'
              '$verificationPresetUsage',
        );
      case VerificationCommand.run:
        if (invocation.format != null) {
          throw VerificationExit(
            exitCode: 64,
            message:
                '--format is only supported with resolve.\n'
                '$verificationPresetUsage',
          );
        }
        await runVerificationPlan(plan);
        return;
    }
  } on VerificationExit catch (error) {
    if (error.message.isNotEmpty) {
      final sink = error.exitCode == 0 ? stdout : stderr;
      sink.write(error.message);
      if (!error.message.endsWith('\n')) {
        sink.writeln();
      }
    }
    exitCode = error.exitCode;
  }
}
