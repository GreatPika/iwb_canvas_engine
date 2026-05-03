part of 'mutation_boundary_rules.dart';

final class _ResolvedInvocationCollector extends RecursiveAstVisitor<void> {
  _ResolvedInvocationCollector({
    required this.onMethodInvocation,
    required this.onFunctionInvocation,
    required this.onInstanceCreation,
  });

  final void Function(MethodInvocation node) onMethodInvocation;
  final void Function(FunctionExpressionInvocation node) onFunctionInvocation;
  final void Function(InstanceCreationExpression node) onInstanceCreation;

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    onFunctionInvocation(node);
    super.visitFunctionExpressionInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    onInstanceCreation(node);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    onMethodInvocation(node);
    super.visitMethodInvocation(node);
  }
}

final class _AssignmentCollector extends RecursiveAstVisitor<void> {
  _AssignmentCollector({required this.onAssignment});

  final void Function(AssignmentExpression node) onAssignment;

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    onAssignment(node);
    super.visitAssignmentExpression(node);
  }
}

final class _FieldAccessCollector extends RecursiveAstVisitor<void> {
  _FieldAccessCollector({required this.onFieldAccess});

  final void Function(String fieldName) onFieldAccess;

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    onFieldAccess(node.identifier.name);
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    onFieldAccess(node.propertyName.name);
    super.visitPropertyAccess(node);
  }
}

final class _ElementReferenceCollector extends RecursiveAstVisitor<void> {
  _ElementReferenceCollector({required this.onElement});

  final void Function(Element? element) onElement;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    onElement(node.element);
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    onElement(node.propertyName.element);
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    onElement(node.identifier.element);
    super.visitPrefixedIdentifier(node);
  }
}

final class _QualifiedMethodInvocationCollector
    extends RecursiveAstVisitor<void> {
  _QualifiedMethodInvocationCollector({required this.onInvocation});

  final void Function(String qualifiedTarget, String methodName) onInvocation;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target;
    if (target != null) {
      final qualifiedTarget = _qualifiedTargetName(target);
      if (qualifiedTarget != null) {
        onInvocation(qualifiedTarget, node.methodName.name);
      }
    }
    super.visitMethodInvocation(node);
  }
}

final class _IdentifierCollector extends RecursiveAstVisitor<void> {
  _IdentifierCollector({required this.onIdentifier});

  final void Function(String identifier) onIdentifier;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    onIdentifier(node.name);
    super.visitSimpleIdentifier(node);
  }
}

final class _VariableDeclarationCollector extends RecursiveAstVisitor<void> {
  _VariableDeclarationCollector({required this.onDeclaration});

  final void Function(VariableDeclaration declaration) onDeclaration;

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    onDeclaration(node);
    super.visitVariableDeclaration(node);
  }
}

final class _QualifiedNameCollector extends RecursiveAstVisitor<void> {
  _QualifiedNameCollector({required this.onName});

  final void Function(String name) onName;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final qualified = _qualifiedInvocationName(node);
    if (qualified != null) {
      onName(qualified);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    final qualified = _qualifiedTargetName(node);
    if (qualified != null) {
      onName(qualified);
    }
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    onName('${node.prefix.name}.${node.identifier.name}');
    super.visitPrefixedIdentifier(node);
  }
}

extension<T> on Iterable<T> {
  T? firstOrNullSafe() => isEmpty ? null : first;
}
