import 'package:analyzer/dart/element/type.dart';

typedef ResolvedTypeLeakClassifier<TLeak> = TLeak? Function(DartType type);
typedef ResolvedTypeAliasExpander = DartType? Function(DartType type);

TLeak? findFirstResolvedTypeLeak<TLeak>({
  required DartType? rootType,
  required ResolvedTypeLeakClassifier<TLeak> classifyType,
  ResolvedTypeAliasExpander? expandAlias,
}) {
  final visited = <DartType>{};

  TLeak? visit(DartType? type) {
    if (type == null || !visited.add(type)) {
      return null;
    }

    final directLeak = classifyType(type);
    if (directLeak != null) {
      return directLeak;
    }

    if (expandAlias case final expander?) {
      final aliasType = expander(type);
      final aliasLeak = visit(aliasType);
      if (aliasLeak != null) {
        return aliasLeak;
      }
    }

    if (type is ParameterizedType) {
      for (final argument in type.typeArguments) {
        final leak = visit(argument);
        if (leak != null) {
          return leak;
        }
      }
    }

    if (type is FunctionType) {
      final returnTypeLeak = visit(type.returnType);
      if (returnTypeLeak != null) {
        return returnTypeLeak;
      }

      for (final parameter in type.formalParameters) {
        final leak = visit(parameter.type);
        if (leak != null) {
          return leak;
        }
      }

      for (final typeParameter in type.typeParameters) {
        final leak = visit(typeParameter.bound);
        if (leak != null) {
          return leak;
        }
      }
    }

    if (type is RecordType) {
      for (final field in type.positionalFields) {
        final leak = visit(field.type);
        if (leak != null) {
          return leak;
        }
      }

      for (final field in type.namedFields) {
        final leak = visit(field.type);
        if (leak != null) {
          return leak;
        }
      }
    }

    if (type is TypeParameterType) {
      return visit(type.bound);
    }

    return null;
  }

  return visit(rootType);
}
