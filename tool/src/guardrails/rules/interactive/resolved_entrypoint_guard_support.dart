part of 'mutation_boundary_rules.dart';

bool _matchesOwnedAccessRuntimeTarget({
  required Expression? target,
  required GuardrailContext context,
  required String filePath,
  required String ownerName,
}) {
  final rootTarget = switch (target?.unParenthesized) {
    PropertyAccess(:final target?, :final propertyName) => (
      root: _expressionElement(target),
      propertyName: propertyName.name,
    ),
    PrefixedIdentifier(:final prefix, :final identifier) => (
      root: prefix.element,
      propertyName: identifier.name,
    ),
    _ => null,
  };
  if (rootTarget == null) {
    return false;
  }
  return _matchesOwnedFieldReference(
        element: rootTarget.root,
        context: context,
        filePath: filePath,
        ownerName: ownerName,
        fieldName: '_access',
      ) &&
      rootTarget.propertyName == 'runtime';
}

Future<ResolvedUnitResult> _resolveInteractiveUnitOrFail({
  required GuardrailContext context,
  required File file,
  required String filePath,
}) async {
  final resolved = await context.getResolvedUnitResult(file.absolute.path);
  if (resolved != null) {
    return resolved;
  }
  throw GuardrailToolFailure(
    GuardrailViolation(
      filePath: filePath,
      line: 1,
      message: 'tool failure: unable to resolve Dart unit (result: null)',
    ),
  );
}

int _lineForResolvedOffset(ResolvedUnitResult resolved, int offset) {
  return resolved.lineInfo.getLocation(offset).lineNumber;
}

bool _matchesOwnedMethod({
  required Element? element,
  required GuardrailContext context,
  required String filePath,
  required String ownerName,
  required String elementName,
}) {
  final normalizedElement = switch (element) {
    PropertyAccessorElement(:final variable) => variable,
    _ => element,
  };
  if (normalizedElement == null ||
      normalizedElement.displayName != elementName) {
    return false;
  }
  if (normalizedElement.enclosingElement?.displayName != ownerName) {
    return false;
  }
  return element_utils.repoRelPathForElement(
        element: normalizedElement,
        context: context,
      ) ==
      filePath;
}

bool _matchesOwnedFieldReference({
  required Element? element,
  required GuardrailContext context,
  required String filePath,
  required String ownerName,
  required String fieldName,
}) {
  final Element? normalizedElement = switch (element) {
    FieldElement() => element,
    PropertyAccessorElement(:final variable, isSynthetic: true)
        when variable is FieldElement =>
      variable,
    PropertyAccessorElement() => element,
    _ => null,
  };
  if (normalizedElement == null || normalizedElement.displayName != fieldName) {
    return false;
  }
  if (normalizedElement.enclosingElement?.displayName != ownerName) {
    return false;
  }
  return element_utils.repoRelPathForElement(
        element: normalizedElement,
        context: context,
      ) ==
      filePath;
}

bool _matchesOwnedElement({
  required Element? element,
  required GuardrailContext context,
  required String filePath,
  required String ownerName,
  required String elementName,
}) {
  final normalizedElement = _normalizeOwnedElement(element);
  if (normalizedElement == null ||
      normalizedElement.displayName != elementName) {
    return false;
  }
  if (normalizedElement.enclosingElement?.displayName != ownerName) {
    return false;
  }
  return element_utils.repoRelPathForElement(
        element: normalizedElement,
        context: context,
      ) ==
      filePath;
}

Element? _normalizeOwnedElement(Element? element) {
  if (element is PropertyAccessorElement) {
    if (element.isSynthetic) {
      return element.variable;
    }
    return element;
  }
  return element;
}

Element? _expressionElement(Expression? expression) {
  if (expression == null) {
    return null;
  }
  return switch (expression.unParenthesized) {
    SimpleIdentifier(:final element) => element,
    PrefixedIdentifier(:final identifier) => identifier.element,
    PropertyAccess(:final propertyName) => propertyName.element,
    _ => null,
  };
}
