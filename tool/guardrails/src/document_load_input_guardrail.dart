import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'repository_paths.dart';

Set<String> collectCanvasDocumentLoadInputHits({
  Map<String, String>? sourceOverrides,
}) {
  final hits = <String>{};
  for (final path in _documentLoadInputOwnerPaths) {
    final source =
        sourceOverrides?[path] ??
        File('$repositoryRoot/$path').readAsStringSync();
    hits.addAll(_canvasDocumentLoadInputHits(path: path, source: source));
  }

  return hits;
}

const _documentLoadInputOwnerPaths = [
  'lib/src/codec/validated_import_draft.dart',
  'lib/src/edit/edit_kernel.dart',
  'lib/src/runtime/runtime_root.dart',
  'lib/src/edit/staged_document_load.dart',
  'lib/src/store/document_store_kernel.dart',
  'lib/src/store/schema_v1_store_import.dart',
];

Set<String> _canvasDocumentLoadInputHits({
  required String path,
  required String source,
}) {
  if (source.trim().isEmpty) {
    return const {};
  }

  final unit = parseString(
    content: source,
    path: '$repositoryRoot/$path',
    throwIfDiagnostics: false,
  ).unit;
  final visitor = _CanvasDocumentParameterVisitor(path);
  unit.accept(visitor);

  return visitor.hits;
}

final class _CanvasDocumentParameterVisitor extends RecursiveAstVisitor<void> {
  _CanvasDocumentParameterVisitor(this.path);

  final String path;
  final Set<String> hits = {};
  final List<String> _classStack = [];

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    _classStack.add(node.namePart.typeName.lexeme);
    super.visitClassDeclaration(node);
    _classStack.removeLast();
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    _recordParameters(
      declarationName: _qualifiedName(_currentClassName, node.name?.lexeme),
      parameters: node.parameters,
    );
    super.visitConstructorDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _recordParameters(
      declarationName: node.name.lexeme,
      parameters: node.functionExpression.parameters,
    );
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitGenericTypeAlias(GenericTypeAlias node) {
    final functionType = node.functionType;
    if (functionType != null) {
      _recordParameters(
        declarationName: node.name.lexeme,
        parameters: functionType.parameters,
      );
    }
    super.visitGenericTypeAlias(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _recordParameters(
      declarationName: _qualifiedName(_currentClassName, node.name.lexeme),
      parameters: node.parameters,
    );
    super.visitMethodDeclaration(node);
  }

  String? get _currentClassName {
    if (_classStack.isEmpty) {
      return null;
    }

    return _classStack.last;
  }

  void _recordParameters({
    required String declarationName,
    required FormalParameterList? parameters,
  }) {
    if (_isAllowedCanvasDocumentInput(declarationName)) {
      return;
    }
    if (parameters == null ||
        !parameters.parameters.any(_parameterMentionsCanvasDocumentDeep)) {
      return;
    }

    hits.add('$path::$declarationName');
  }
}

String _qualifiedName(String? owner, String? member) {
  if (owner == null || owner.isEmpty) {
    return member ?? '';
  }
  if (member == null || member.isEmpty) {
    return owner;
  }

  return '$owner.$member';
}

bool _parameterMentionsCanvasDocumentDeep(FormalParameter parameter) {
  final normal = parameter is DefaultFormalParameter
      ? parameter.parameter
      : parameter;
  if (normal is FunctionTypedFormalParameter) {
    return normal.parameters.parameters.any(
      _parameterMentionsCanvasDocumentDeep,
    );
  }
  final typeSource = switch (normal) {
    SimpleFormalParameter(:final type?) => type.toSource(),
    FieldFormalParameter(:final type?) => type.toSource(),
    SuperFormalParameter(:final type?) => type.toSource(),
    _ => '',
  };

  return RegExp(r'\bCanvasDocument\b').hasMatch(typeSource);
}

bool _isAllowedCanvasDocumentInput(String declarationName) {
  return _allowedCanvasDocumentInputDeclarations.contains(declarationName);
}

const _allowedCanvasDocumentInputDeclarations = {
  'prepareDraftReplacement',
  'ValidatedImportDraft.fromDraftReplacement',
  'ValidatedImportDraft.fromEncodeDocument',
  'RuntimeRoot.deliverCommitPlanForTesting',
};
