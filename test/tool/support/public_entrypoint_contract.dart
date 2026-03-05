const canonicalPublicExportFiles = <String>[
  'lib/src/contract/node_patch.dart',
  'lib/src/contract/node_spec.dart',
  'lib/src/contract/patch_field.dart',
  'lib/src/contract/canvas_pointer_input.dart',
  'lib/src/model/scene_builder_api.dart',
  'lib/src/contract/scene_data_exception.dart',
  'lib/src/contract/scene_render_state.dart',
  'lib/src/contract/scene_write_txn.dart',
  'lib/src/contract/snapshot.dart',
  'lib/src/core/action_events.dart',
  'lib/src/core/interaction_types.dart',
  'lib/src/core/pointer_input.dart',
  'lib/src/contract/transform2d.dart',
  'lib/src/interactive/scene_controller_interactive.dart',
  'lib/src/view/scene_view_interactive.dart',
  'lib/src/serialization/scene_codec.dart',
];

const canonicalPublicExportDirectives = <String>[
  "export 'src/contract/node_patch.dart';",
  "export 'src/contract/node_spec.dart';",
  "export 'src/contract/patch_field.dart';",
  "export 'src/contract/canvas_pointer_input.dart';",
  "export 'src/model/scene_builder_api.dart';",
  "export 'src/contract/scene_data_exception.dart';",
  "export 'src/contract/scene_render_state.dart';",
  "export 'src/contract/scene_write_txn.dart';",
  "export 'src/contract/snapshot.dart';",
  "export 'src/core/action_events.dart' show ActionCommitted, ActionCommittedDelta, ActionType, EditTextRequested;",
  "export 'src/core/interaction_types.dart' show CanvasMode, DrawTool;",
  "export 'src/core/pointer_input.dart' show PointerInputSettings;",
  "export 'src/contract/transform2d.dart' show Transform2D;",
  "export 'src/interactive/scene_controller_interactive.dart' show MoveCommitDeltaResolver, SceneController, SceneControllerInteractive;",
  "export 'src/view/scene_view_interactive.dart' show SceneView, SceneViewInteractive;",
  "export 'src/serialization/scene_codec.dart' show decodeScene, decodeSceneFromJson, encodeScene, encodeSceneToJson, schemaVersionWrite, schemaVersionsRead;",
];

const canonicalFirstPublicExportDirective =
    "export 'src/contract/node_patch.dart';";
const canonicalViewPublicExportDirective =
    "export 'src/view/scene_view_interactive.dart' show SceneView, SceneViewInteractive;";

String canonicalPublicEntrypoint({
  bool withInlineComments = false,
  bool withTrailingLogicAfterFirstExport = false,
}) {
  final lines = <String>['/// Public API exports for tests.', 'library;', ''];

  for (var i = 0; i < canonicalPublicExportDirectives.length; i++) {
    var line = canonicalPublicExportDirectives[i];
    if (i == 0 && withInlineComments) {
      lines.add('/* comment before export */');
      line = "export /* inline */ 'src/contract/node_patch.dart';";
    }
    if (i == 0 && withTrailingLogicAfterFirstExport) {
      line = "export 'src/contract/node_patch.dart'; /* c */ class A {}";
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

String _normalizeWhitespace(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}
