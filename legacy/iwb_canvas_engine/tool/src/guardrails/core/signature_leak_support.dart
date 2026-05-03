import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

typedef SignatureTypeLeakFinder<TLeak> =
    TLeak? Function({required DartType? type, required Element sourceElement});

TLeak? findTypeParameterBoundLeak<TLeak>({
  required TypeParameterizedElement element,
  required SignatureTypeLeakFinder<TLeak> findTypeLeak,
}) {
  for (final typeParameter in element.typeParameters) {
    final leak = findTypeLeak(
      type: typeParameter.bound,
      sourceElement: typeParameter,
    );
    if (leak != null) {
      return leak;
    }
  }

  return null;
}

TLeak? findExecutableSignatureLeak<TLeak>({
  required ExecutableElement element,
  required SignatureTypeLeakFinder<TLeak> findTypeLeak,
}) {
  final typeParameterLeak = findTypeParameterBoundLeak<TLeak>(
    element: element,
    findTypeLeak: findTypeLeak,
  );
  if (typeParameterLeak != null) {
    return typeParameterLeak;
  }

  if (element is! ConstructorElement) {
    final returnTypeLeak = findTypeLeak(
      type: element.returnType,
      sourceElement: element,
    );
    if (returnTypeLeak != null) {
      return returnTypeLeak;
    }
  }

  for (final parameter in element.formalParameters) {
    final leak = findTypeLeak(type: parameter.type, sourceElement: parameter);
    if (leak != null) {
      return leak;
    }
  }

  return null;
}
