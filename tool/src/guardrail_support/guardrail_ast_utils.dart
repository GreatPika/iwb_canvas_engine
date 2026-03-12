import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';

import 'guardrail_context.dart';

class DirectiveUriRef {
  const DirectiveUriRef({required this.uri, required this.offset});

  final String uri;
  final int offset;
}

List<DirectiveUriRef> collectDirectiveUriRefs(UriBasedDirective directive) {
  final refs = <DirectiveUriRef>[];

  void addUri(StringLiteral literal) {
    final uri = literal.stringValue;
    if (uri == null || uri.isEmpty) {
      return;
    }
    refs.add(DirectiveUriRef(uri: uri, offset: literal.offset));
  }

  addUri(directive.uri);
  if (directive case NamespaceDirective(:final configurations)) {
    for (final configuration in configurations) {
      addUri(configuration.uri);
    }
  }
  return refs;
}

List<DirectiveUriRef> collectBoundaryDirectiveUriRefs(Directive directive) {
  if (directive case UriBasedDirective uriDirective) {
    return collectDirectiveUriRefs(uriDirective);
  }
  if (directive case PartOfDirective(uri: final uri?)) {
    return <DirectiveUriRef>[
      DirectiveUriRef(
        uri: uri.stringValue ?? uri.toSource(),
        offset: uri.offset,
      ),
    ];
  }
  return const <DirectiveUriRef>[];
}

List<DirectiveUriRef> collectDocImportUriRefs(AstNode node) {
  final uriRefs = <DirectiveUriRef>[];

  void visit(AstNode current) {
    if (current is Comment) {
      for (final docImport in current.docImports) {
        final uriValue = docImport.import.uri.stringValue;
        if (uriValue == null || uriValue.isEmpty) {
          continue;
        }
        uriRefs.add(DirectiveUriRef(uri: uriValue, offset: docImport.offset));
      }
    }
    for (final child in current.childEntities) {
      if (child is AstNode) {
        visit(child);
      }
    }
  }

  visit(node);
  return uriRefs;
}

int lineForOffset(ParsedUnitResult parsed, int offset) {
  return parsed.lineInfo.getLocation(offset).lineNumber;
}

ParsedUnitResult parseUnitOrFail({
  required GuardrailContext context,
  required String absPath,
  required String filePathForDiag,
  required Never Function({
    required String filePathForDiag,
    required String resultType,
  })
  onFailure,
}) {
  final result = context.getParsedUnitResult(absPath);
  if (result is ParsedUnitResult) {
    return result;
  }
  onFailure(
    filePathForDiag: filePathForDiag,
    resultType: result.runtimeType.toString(),
  );
}
