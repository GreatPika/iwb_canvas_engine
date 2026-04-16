import 'package:analyzer/dart/element/element.dart';

import '../support/guardrail_context.dart';
import 'guardrail_element_utils.dart' as element_utils;
import 'guardrail_violation.dart';

typedef ConstructorSurfaceViolationBuilder =
    GuardrailViolation? Function({
      required GuardrailContext context,
      required Element sourceElement,
      required String detail,
    });

typedef ConstructorTypeLeak = ({
  String forbiddenTypeName,
  Element sourceElement,
});

typedef ConstructorTypeLeakFinder =
    ConstructorTypeLeak? Function(ConstructorElement constructor);

GuardrailViolation? validatePublicConstructorSurface({
  required ConstructorElement constructor,
  required GuardrailContext context,
  required Set<String> allowedParameterNames,
  required ConstructorTypeLeakFinder findForbiddenSignatureLeak,
  required ConstructorSurfaceViolationBuilder buildViolation,
  required String namedConstructorDetail,
  required String Function(String forbiddenTypeName) forbiddenTypeDetail,
  required String Function(String parameterName) extraParameterDetail,
}) {
  if (!element_utils.isPublicConstructor(constructor)) {
    return null;
  }

  final constructorName = element_utils.normalizedConstructorName(constructor);
  if (constructorName.isNotEmpty) {
    return buildViolation(
      context: context,
      sourceElement: constructor,
      detail: namedConstructorDetail,
    );
  }

  final leak = findForbiddenSignatureLeak(constructor);
  if (leak != null) {
    return buildViolation(
      context: context,
      sourceElement: leak.sourceElement,
      detail: forbiddenTypeDetail(leak.forbiddenTypeName),
    );
  }

  for (final parameter in constructor.formalParameters) {
    if (allowedParameterNames.contains(parameter.displayName)) {
      continue;
    }
    return buildViolation(
      context: context,
      sourceElement: parameter,
      detail: extraParameterDetail(parameter.displayName),
    );
  }

  return null;
}
