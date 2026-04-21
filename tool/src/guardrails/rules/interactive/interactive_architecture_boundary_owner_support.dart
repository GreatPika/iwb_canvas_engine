part of 'mutation_boundary_rules.dart';

bool _matchesOwnedMethodForBoundary({
  required Element? element,
  required GuardrailContext context,
  required String? filePath,
  required String ownerName,
  required String elementName,
}) {
  final normalizedElement = switch (element) {
    PropertyAccessorElement(:final variable) => variable,
    _ => element,
  };
  if (normalizedElement == null ||
      normalizedElement.displayName != elementName ||
      !_elementMatchesBoundaryOwner(
        normalizedElement.enclosingElement,
        ownerName: ownerName,
      )) {
    return false;
  }
  if (filePath == null) {
    return true;
  }
  return element_utils.repoRelPathForElement(
        element: normalizedElement,
        context: context,
      ) ==
      filePath;
}

bool _elementMatchesBoundaryOwner(Element? owner, {required String ownerName}) {
  if (owner == null) {
    return false;
  }
  if (owner.displayName == ownerName) {
    return true;
  }
  return switch (owner) {
    ExtensionElement(:final extendedType)
        when switch (extendedType) {
          InterfaceType(:final element) => element.name == ownerName,
          _ => false,
        } =>
      true,
    _ => false,
  };
}

bool _matchesOwnedTopLevelFunction({
  required Element? element,
  required GuardrailContext context,
  required String filePath,
  required String functionName,
}) {
  if (element is! ExecutableElement || element.displayName != functionName) {
    return false;
  }
  return element_utils.repoRelPathForElement(
        element: element,
        context: context,
      ) ==
      filePath;
}

bool _matchesOwnedConstructor({
  required ConstructorElement? element,
  required GuardrailContext context,
  required String? filePath,
  required String ownerName,
}) {
  if (element == null || element.enclosingElement.displayName != ownerName) {
    return false;
  }
  if (filePath == null) {
    return true;
  }
  return element_utils.repoRelPathForElement(
        element: element.enclosingElement,
        context: context,
      ) ==
      filePath;
}
