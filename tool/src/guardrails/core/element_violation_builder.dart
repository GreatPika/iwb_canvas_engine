import 'package:analyzer/dart/element/element.dart';

import '../support/guardrail_context.dart';
import 'guardrail_element_utils.dart' as element_utils;
import 'guardrail_violation.dart';

GuardrailViolation? buildElementGuardrailViolation({
  required GuardrailContext context,
  required Element sourceElement,
  required String message,
}) {
  final filePath = element_utils.repoRelPathForElement(
    element: sourceElement,
    context: context,
  );
  final line = element_utils.lineForElement(sourceElement);
  if (filePath == null || line == null) {
    return null;
  }

  return GuardrailViolation(filePath: filePath, line: line, message: message);
}
