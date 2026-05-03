import 'package:analyzer/dart/element/element.dart';

import '../support/guardrail_context.dart';
import '../support/guardrail_path_utils.dart';
import 'guardrail_violation.dart';

int compareElementsBySourceOrder(Element left, Element right) {
  final leftPath = left.firstFragment.libraryFragment?.source.fullName ?? '';
  final rightPath = right.firstFragment.libraryFragment?.source.fullName ?? '';
  final pathCompare = leftPath.compareTo(rightPath);
  if (pathCompare != 0) {
    return pathCompare;
  }
  return left.firstFragment.offset.compareTo(right.firstFragment.offset);
}

bool isPublicNamedElement(Element element) {
  final name = element.displayName;
  return name.isNotEmpty && isPublicName(name);
}

bool isPublicConstructor(ConstructorElement constructor) {
  final typeName = constructor.enclosingElement.displayName;
  if (typeName.isEmpty || !isPublicName(typeName)) {
    return false;
  }

  final constructorName = normalizedConstructorName(constructor);
  return constructorName.isEmpty || isPublicName(constructorName);
}

String normalizedConstructorName(ConstructorElement constructor) {
  final constructorName = constructor.name ?? '';
  return constructorName == 'new' ? '' : constructorName;
}

int? lineForElement(Element element) {
  final lineInfo = element.firstFragment.libraryFragment?.lineInfo;
  if (lineInfo == null) {
    return null;
  }
  return lineInfo.getLocation(element.firstFragment.offset).lineNumber;
}

String? repoRelPathForElement({
  required Element? element,
  required GuardrailContext context,
  bool requireLibPrefix = false,
}) {
  if (element == null) {
    return null;
  }

  final source = element.firstFragment.libraryFragment?.source;
  if (source == null || source.uri.scheme == 'dart') {
    return null;
  }

  if (source.uri.scheme == 'package') {
    final segments = source.uri.pathSegments;
    if (segments.isNotEmpty && segments.first != context.packageName) {
      return null;
    }
  }

  final absPosixPath = toPosixPath(source.fullName);
  if (!absPosixPath.startsWith('${context.rootAbsPosixPath}/')) {
    return null;
  }

  final repoRelPath = toRepoRelPosixPath(
    absPosixPath: absPosixPath,
    rootAbsPosixPath: context.rootAbsPosixPath,
  );
  if (requireLibPrefix && !repoRelPath.startsWith('/lib/')) {
    return null;
  }
  return repoRelPath;
}
