import 'dart:convert';

import 'verification_contract_models.dart';

String renderVerificationPlanJson(ResolvedVerificationPlan plan) {
  return const JsonEncoder.withIndent('  ').convert(<String, Object>{
    'mode': plan.mode.code,
    'selectors': plan.selectors,
    'steps': <Map<String, Object>>[
      for (final step in plan.steps)
        <String, Object>{
          'id': step.id,
          'kind': step.kind.code,
          'cmd': step.command,
          'cwd': step.cwd,
          'reason': step.reason,
        },
    ],
  });
}
