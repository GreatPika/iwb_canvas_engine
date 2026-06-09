import 'package:analyzer/dart/ast/ast.dart';

final class DirectiveUriReference {
  const DirectiveUriReference({required this.uri, required this.sourceNode});

  final String uri;
  final AstNode sourceNode;
}

Iterable<DirectiveUriReference> directiveUriReferences(
  Directive directive,
) sync* {
  switch (directive) {
    case ImportDirective(:final uri, :final configurations):
      yield* _literalReferences(uri, configurations);
    case ExportDirective(:final uri, :final configurations):
      yield* _literalReferences(uri, configurations);
    case LibraryDirective() || PartDirective() || PartOfDirective():
      return;
  }
}

Iterable<DirectiveUriReference> _literalReferences(
  StringLiteral mainUri,
  NodeList<Configuration> configurations,
) sync* {
  final value = mainUri.stringValue;
  if (value != null) {
    yield DirectiveUriReference(uri: value, sourceNode: mainUri);
  }

  for (final configuration in configurations) {
    final value = configuration.uri.stringValue;
    if (value != null) {
      yield DirectiveUriReference(uri: value, sourceNode: configuration.uri);
    }
  }
}
