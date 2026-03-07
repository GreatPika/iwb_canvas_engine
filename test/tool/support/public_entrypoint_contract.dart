import 'dart:io';

const List<String> canonicalPublicExportFiles = <String>[
  'lib/src/contract/node_patch.dart',
  'lib/src/contract/node_spec.dart',
  'lib/src/contract/patch_field.dart',
  'lib/src/contract/canvas_pointer_input.dart',
  'lib/src/model/scene_builder_api.dart',
  'lib/src/contract/scene_data_exception.dart',
  'lib/src/contract/scene_render_state.dart',
  'lib/src/contract/scene_write_txn.dart',
  'lib/src/contract/snapshot.dart',
  'lib/src/contract/validated.dart',
  'lib/src/core/action_events.dart',
  'lib/src/core/interaction_types.dart',
  'lib/src/core/pointer_input.dart',
  'lib/src/contract/transform2d.dart',
  'lib/src/interactive/scene_controller_interactive.dart',
  'lib/src/view/scene_view_interactive.dart',
  'lib/src/serialization/scene_codec.dart',
];

final List<String> canonicalPublicExportDirectives = _loadCanonicalExports();

final String canonicalFirstPublicExportDirective =
    canonicalPublicExportDirectives.first;

final String canonicalViewPublicExportDirective =
    canonicalPublicExportDirectives.firstWhere(
      (directive) =>
          directive.contains("'src/view/scene_view_interactive.dart'"),
    );

String canonicalPublicEntrypoint({
  bool withInlineComments = false,
  bool withTrailingLogicAfterFirstExport = false,
}) {
  final lines = <String>['/// Public API exports for tests.', 'library;', ''];

  for (var i = 0; i < canonicalPublicExportDirectives.length; i++) {
    var line = canonicalPublicExportDirectives[i];
    if (i == 0 && withInlineComments) {
      lines.add('/* comment before export */');
      line = line.replaceFirst('export ', 'export /* inline */ ');
    }
    if (i == 0 && withTrailingLogicAfterFirstExport) {
      line = '$line /* c */ class A {}';
    }
    lines.add(line);
  }

  return '${lines.join('\n')}\n';
}

List<String> extractNormalizedExportDirectives(String source) {
  final directives = <String>[];
  StringBuffer? currentDirective;

  void flushIfComplete() {
    final buffer = currentDirective;
    if (buffer == null) {
      return;
    }

    final text = buffer.toString();
    final semicolonIndex = text.indexOf(';');
    if (semicolonIndex == -1) {
      return;
    }

    final directive = text.substring(0, semicolonIndex + 1);
    directives.add(_normalizeWhitespace(directive));
    currentDirective = null;
  }

  for (final line in source.split('\n')) {
    final trimmed = line.trim();
    if (currentDirective != null) {
      if (trimmed.isNotEmpty) {
        currentDirective!.write(' ');
        currentDirective!.write(trimmed);
      }
      flushIfComplete();
      continue;
    }

    if (trimmed.isEmpty ||
        trimmed.startsWith('//') ||
        trimmed.startsWith('///') ||
        trimmed == 'library;') {
      continue;
    }
    if (!trimmed.startsWith('export ')) {
      continue;
    }

    currentDirective = StringBuffer(trimmed);
    flushIfComplete();
  }

  return directives;
}

List<String> extractExportOwnerFiles(String source) {
  return extractNormalizedExportDirectives(
    source,
  ).map(exportDirectiveToFilePath).toList(growable: false);
}

String _normalizeWhitespace(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

List<String> _loadCanonicalExports() {
  final source = File('lib/iwb_canvas_engine.dart').readAsStringSync();
  final directives = extractNormalizedExportDirectives(source);
  if (directives.isEmpty) {
    throw StateError(
      'Expected lib/iwb_canvas_engine.dart to define at least one export '
      'directive for public-entrypoint tool tests.',
    );
  }

  final actualOwnerFiles = extractExportOwnerFiles(source);
  if (!_listsEqual(actualOwnerFiles, canonicalPublicExportFiles)) {
    throw StateError(
      'Public entrypoint export owners drifted from the canonical manifest.\n'
      'Expected: ${canonicalPublicExportFiles.join(', ')}\n'
      'Actual: ${actualOwnerFiles.join(', ')}',
    );
  }

  return List<String>.unmodifiable(directives);
}

String exportDirectiveToFilePath(String directive) {
  final match = RegExp(r"^export\s+'([^']+)").firstMatch(directive);
  if (match == null) {
    throw StateError(
      'Unsupported export directive format in lib/iwb_canvas_engine.dart: '
      '$directive',
    );
  }

  final target = match.group(1)!;
  if (!target.startsWith('src/')) {
    throw StateError(
      'Expected canonical public export to target src/**, got: $directive',
    );
  }
  return 'lib/$target';
}

bool _listsEqual(List<String> left, List<String> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) {
      return false;
    }
  }
  return true;
}
