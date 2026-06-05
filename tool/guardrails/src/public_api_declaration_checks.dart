import 'package:analyzer/dart/element/element.dart';

import 'guardrail_violation.dart';
import 'public_api_registry.dart';
import 'public_api_surface.dart';

Future<List<GuardrailViolation>> checkExportedDartdocComplete() async {
  final declarations = await _exportedRegistryDeclarations();
  final missing = [
    ...declarations.missingRegistryNames,
    for (final entry in declarations.elements.entries)
      if (!_hasDartdoc(entry.value)) entry.key,
  ];

  return [
    if (missing.isNotEmpty)
      GuardrailViolation(
        guardrailId: 'api.exported_dartdoc_complete',
        path: 'lib/iwb_canvas_engine.dart',
        message: 'exported declarations missing dartdoc: ${_list(missing)}',
      ),
  ];
}

Future<List<GuardrailViolation>> checkPublicClassModifiersExplicit() async {
  final declarations = await _exportedRegistryDeclarations();
  final implicit = [
    ...declarations.missingRegistryNames,
    for (final entry in declarations.elements.entries)
      if (entry.value is ClassElement &&
          !_hasExplicitClassModifier(entry.value as ClassElement))
        entry.key,
  ];

  return [
    if (implicit.isNotEmpty)
      GuardrailViolation(
        guardrailId: 'api.public_class_modifiers_explicit',
        path: 'lib/iwb_canvas_engine.dart',
        message:
            'public classes missing explicit modifiers: ${_list(implicit)}',
      ),
  ];
}

Future<_ExportedRegistryDeclarations> _exportedRegistryDeclarations() async {
  final registryNames = readPublicApiRegistry();
  final surface = await resolvePublicApiSurface();
  final elements = <String, Element>{};
  final missing = <String>{};

  for (final name in registryNames) {
    final element = surface.exportedElements[name];
    if (element == null) {
      missing.add(name);
    } else {
      elements[name] = element;
    }
  }

  return _ExportedRegistryDeclarations(
    elements: elements,
    missingRegistryNames: missing,
  );
}

bool _hasDartdoc(Element element) {
  final comment = switch (element) {
    PropertyAccessorElement(:final variable) => variable.documentationComment,
    _ => element.documentationComment,
  };

  return hasDartdocSummaryText(comment);
}

bool _hasExplicitClassModifier(ClassElement element) {
  return hasPublicSubtypePolicyModifier([
    element.isBase,
    element.isFinal,
    element.isInterface,
    element.isMixinClass,
    element.isSealed,
  ]);
}

bool hasDartdocSummaryText(String? comment) {
  return _dartdocSummaryText(comment).isNotEmpty;
}

bool hasPublicSubtypePolicyModifier(Iterable<bool> modifierFlags) {
  return modifierFlags.any((isPresent) => isPresent);
}

String _dartdocSummaryText(String? comment) {
  if (comment == null) {
    return '';
  }

  return comment.split('\n').map(_dartdocLineText).join('\n').trim();
}

String _dartdocLineText(String line) {
  var text = line.trim();
  if (text.startsWith('///')) {
    return text.replaceFirst('///', '').trim();
  }
  if (text.startsWith('/**')) {
    text = text.replaceFirst('/**', '').trim();
  } else if (text.startsWith('/*')) {
    text = text.replaceFirst('/*', '').trim();
  }
  if (text.endsWith('*/')) {
    text = text.replaceFirst(RegExp(r'\*/$'), '').trim();
  }
  if (text.startsWith('*')) {
    text = text.replaceFirst('*', '').trim();
  }

  return text.trim();
}

String _list(Iterable<String> names) {
  final sorted = names.toList()..sort();

  return sorted.join(', ');
}

final class _ExportedRegistryDeclarations {
  const _ExportedRegistryDeclarations({
    required this.elements,
    required this.missingRegistryNames,
  });

  final Map<String, Element> elements;
  final Set<String> missingRegistryNames;
}
