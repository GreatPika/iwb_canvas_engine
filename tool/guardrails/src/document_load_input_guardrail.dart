import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'repository_paths.dart';

Set<String> collectCanvasDocumentLoadInputHits({
  Map<String, String>? sourceOverrides,
}) {
  final hits = <String>{};
  final ownerPaths = _documentLoadInputOwnerPaths(sourceOverrides);
  final aliasPaths = _documentLoadInputAliasPaths(sourceOverrides);
  final parsedUnits = <String, CompilationUnit>{};
  for (final path in {...ownerPaths, ...aliasPaths}) {
    final source =
        sourceOverrides?[path] ??
        File('$repositoryRoot/$path').readAsStringSync();
    if (source.trim().isEmpty) {
      continue;
    }
    parsedUnits[path] = parseString(
      content: source,
      path: '$repositoryRoot/$path',
      throwIfDiagnostics: false,
    ).unit;
  }

  final aliases = _canvasDocumentTypeAliases(parsedUnits.values);
  for (final path in ownerPaths) {
    final unit = parsedUnits[path];
    if (unit == null) {
      continue;
    }
    hits.addAll(
      _canvasDocumentLoadInputHits(
        path: path,
        unit: unit,
        canvasDocumentAliases: aliases,
      ),
    );
  }

  return hits;
}

List<String> _documentLoadInputOwnerPaths(
  Map<String, String>? sourceOverrides,
) {
  if (sourceOverrides != null) {
    final paths =
        sourceOverrides.keys.where(_isDocumentLoadInputGuardrailPath).toList()
          ..sort();

    return paths;
  }

  final paths = <String>{
    for (final directory in _documentLoadInputOwnerDirectories)
      for (final file in dartSourceFilesUnder(directory)) file.path,
  }.toList()..sort();

  return paths;
}

List<String> _documentLoadInputAliasPaths(
  Map<String, String>? sourceOverrides,
) {
  if (sourceOverrides != null) {
    final paths =
        sourceOverrides.keys.where(_isDocumentLoadInputAliasPath).toList()
          ..sort();

    return paths;
  }

  final paths = <String>{
    for (final directory in _documentLoadInputAliasDirectories)
      for (final file in dartSourceFilesUnder(directory)) file.path,
  }.toList()..sort();

  return paths;
}

bool _isDocumentLoadInputGuardrailPath(String path) {
  return _documentLoadInputOwnerDirectories.any(
    (directory) => path.startsWith('$directory/'),
  );
}

bool _isDocumentLoadInputAliasPath(String path) {
  return _documentLoadInputAliasDirectories.any(
    (directory) => path.startsWith('$directory/'),
  );
}

const _documentLoadInputOwnerDirectories = {
  'lib/src/api',
  'lib/src/contracts/public',
  'lib/src/codec',
  'lib/src/edit',
  'lib/src/runtime',
  'lib/src/store',
};

const _documentLoadInputAliasDirectories = {
  ..._documentLoadInputOwnerDirectories,
  'lib/src/contracts/internal',
};

Set<String> _canvasDocumentLoadInputHits({
  required String path,
  required CompilationUnit unit,
  required Set<String> canvasDocumentAliases,
}) {
  final visitor = _CanvasDocumentParameterVisitor(path, canvasDocumentAliases);
  unit.accept(visitor);

  return visitor.hits;
}

final class _CanvasDocumentParameterVisitor extends RecursiveAstVisitor<void> {
  _CanvasDocumentParameterVisitor(this.path, this._canvasDocumentAliases);

  final String path;
  final Set<String> _canvasDocumentAliases;
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
    if (_isAllowedCanvasDocumentInput(path, declarationName)) {
      return;
    }
    if (parameters == null ||
        !parameters.parameters.any((parameter) {
          return _parameterMentionsCanvasDocumentDeep(
            parameter,
            _canvasDocumentAliases,
          );
        })) {
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

bool _parameterMentionsCanvasDocumentDeep(
  FormalParameter parameter,
  Set<String> canvasDocumentAliases,
) {
  final normal = parameter is DefaultFormalParameter
      ? parameter.parameter
      : parameter;
  if (normal is FunctionTypedFormalParameter) {
    final returnType = normal.returnType?.toSource() ?? '';

    return _typeMentionsCanvasDocumentOrAlias(
          returnType,
          canvasDocumentAliases,
        ) ||
        normal.parameters.parameters.any((parameter) {
          return _parameterMentionsCanvasDocumentDeep(
            parameter,
            canvasDocumentAliases,
          );
        });
  }
  final typeSource = switch (normal) {
    SimpleFormalParameter(:final type?) => type.toSource(),
    FieldFormalParameter(:final type?) => type.toSource(),
    SuperFormalParameter(:final type?) => type.toSource(),
    _ => '',
  };

  return _typeMentionsCanvasDocumentOrAlias(typeSource, canvasDocumentAliases);
}

Set<String> _canvasDocumentTypeAliases(Iterable<CompilationUnit> units) {
  final aliasSources = <String, String>{};
  for (final unit in units) {
    for (final declaration in unit.declarations) {
      if (declaration is GenericTypeAlias) {
        aliasSources[declaration.name.lexeme] = declaration.type.toSource();
      }
    }
  }

  final aliases = <String>{};
  var changed = true;
  while (changed) {
    changed = false;
    for (final MapEntry(key: name, value: source) in aliasSources.entries) {
      if (aliases.contains(name)) {
        continue;
      }
      if (_typeMentionsCanvasDocumentOrAlias(source, aliases)) {
        aliases.add(name);
        changed = true;
      }
    }
  }

  return aliases;
}

bool _typeMentionsCanvasDocumentOrAlias(
  String typeSource,
  Set<String> aliases,
) {
  return RegExp(r'\bCanvasDocument\b').hasMatch(typeSource) ||
      aliases.any((alias) {
        return RegExp('\\b${RegExp.escape(alias)}\\b').hasMatch(typeSource);
      });
}

bool _isAllowedCanvasDocumentInput(String path, String declarationName) {
  return _allowedCanvasDocumentInputDeclarations.contains(
    '$path::$declarationName',
  );
}

const _allowedCanvasDocumentInputDeclarations = {
  'lib/src/api/canvas_codec.dart::encodeCanvasDocument',
  'lib/src/api/canvas_codec.dart::encodeCanvasDocumentToJson',
  'lib/src/codec/schema_v1_decoder.dart::_validateDocumentReferences',
  'lib/src/codec/schema_v1_encoder.dart::encodeSchemaV1Document',
  'lib/src/codec/validated_import_draft.dart::ValidatedImportDraft.fromDraftReplacement',
  'lib/src/codec/validated_import_draft.dart::ValidatedImportDraft.fromEncodeDocument',
  'lib/src/contracts/public/canvas_runtime.dart::CanvasEdit.replaceDraftDocument',
  'lib/src/edit/draft_document.dart::DraftDocument',
  'lib/src/edit/draft_document.dart::DraftDocument.replaceDocument',
  'lib/src/edit/draft_document.dart::_DraftBacking.fromDocument',
  'lib/src/edit/draft_structure.dart::DraftStructure',
  'lib/src/edit/edit_kernel.dart::EditKernel',
  'lib/src/edit/edit_kernel.dart::MaterializedCommitPreparer',
  'lib/src/edit/edit_session.dart::EditSession.replaceDraftDocument',
  'lib/src/edit/edit_session.dart::_EditSessionBacking.replaceDraftDocument',
  'lib/src/edit/edit_session.dart::_MaterializedEditBacking.replaceDraftDocument',
  'lib/src/edit/edit_session.dart::_SparseEditBacking.replaceDraftDocument',
  'lib/src/edit/staged_document_load.dart::prepareDraftReplacement',
  'lib/src/runtime/runtime_root.dart::RuntimeRoot.deliverCommitPlanForTesting',
  'lib/src/store/committed_document.dart::CommittedDocument',
  'lib/src/store/committed_document.dart::CommittedDocument.withRevisions',
  'lib/src/store/document_store_kernel.dart::DocumentStoreKernel.prepareMaterializedCommit',
};
