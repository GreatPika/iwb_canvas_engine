@Tags(['tool'])
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('docs/target_architecture top-level map', () {
    test('README defines the normalized directory contract', () {
      final source = _read('docs/target_architecture/README.md');

      expect(source, isNotEmpty);
      _expectSections(source, const <String>[
        '## Purpose',
        '## Directory Roles',
        '## Mechanical Evidence',
        '## Verification Workflow',
        '## Update Rules',
      ]);
      _expectContainsAll(source, const <String>[
        'overview.md',
        'families/*.md',
        'execution_flows.md',
        'evidence/',
        'PLAN.md',
        'dart run tool/lsp_find_symbols.dart <query>',
        'dart run tool/lsp_trace_symbol.dart <file> <symbol> --depth=N',
        'dart run tool/lsp_trace_flow.dart <file> <symbol> --depth=N',
        'dart run tool/lsp_find_boundary_bypasses.dart <file> <class> --must-pass=<seam>',
        'dart run tool/lsp_find_thin_wrappers.dart <file-or-dir>',
        'dart run tool/run_tool_tests.dart test/tool/target_architecture_map_tool_test.dart',
      ]);
      _expectNoInlineFlowContent(
        path: 'docs/target_architecture/README.md',
        source: source,
      );
    });

    test(
      'overview defines the shared status vocabulary and concise registry',
      () {
        final source = _read('docs/target_architecture/overview.md');

        _expectSections(source, const <String>[
          '## Purpose',
          '## Verification Status Vocabulary',
          '## Owner Family Registry',
          '## Mechanical Evidence',
          '## Update Rules',
        ]);
        _expectContainsAll(source, const <String>[
          '`locked`',
          '`provisional`',
          '`docs stale`',
          'View runtime and render seam',
          '| `locked` |',
          'test/tool/target_architecture_map_tool_test.dart',
        ]);
        expect(source, isNot(contains('`locked, needs slimming`')));

        final statuses = _ownerRegistryStatuses(source);
        expect(statuses, hasLength(5));
        for (final status in statuses) {
          expect(_allowedStatuses, contains(status));
        }

        _expectNoInlineFlowContent(
          path: 'docs/target_architecture/overview.md',
          source: source,
        );
      },
    );

    test('execution flows stays limited to the committed runtime-view set', () {
      final source = _read('docs/target_architecture/execution_flows.md');

      _expectSections(source, const <String>[
        '## Purpose',
        '## Runtime-View Registry',
        '## Update Rules',
      ]);
      _expectContainsAll(source, const <String>[
        'SceneControllerSceneOwner.addNode',
        'SceneViewInteractivePointerHost.handlePointerEvent',
        'SceneViewRuntime.mainSceneRenderRead',
        'SceneViewRuntime.overlayPreviewRead',
        'SceneControllerMutationBoundary',
        'SceneViewRenderSurface',
        'SceneViewInteractiveOverlayPainter',
      ]);
      expect(source, isNot(contains('Import And Build Flow')));
      expect(source, isNot(contains('Write And Commit Flow')));
      expect(source, isNot(contains('Interactive Input Flow')));
      expect(source, isNot(contains('Render Flow')));

      final evidenceLinks = _evidenceLinks(source);
      expect(evidenceLinks, equals(_expectedRuntimeViewEvidenceLinks));
      for (final link in evidenceLinks) {
        expect(
          File('docs/target_architecture/$link').existsSync(),
          isTrue,
          reason:
              'Missing runtime-view evidence artifact docs/target_architecture/$link',
        );
      }

      _expectNoInlineFlowContent(
        path: 'docs/target_architecture/execution_flows.md',
        source: source,
      );
    });

    test(
      'view runtime family records the landed split read surface with evidence',
      () {
        final source = _read(
          'docs/target_architecture/families/view_runtime_and_render_seam.md',
        );

        _expectSections(source, const <String>[
          '## Purpose',
          '## Target Rules',
          '## Owners',
          '## Forbidden Shapes',
          '## Mechanical Evidence',
          '## Status',
        ]);
        _expectContainsAll(source, const <String>[
          'SceneViewRuntime.mainSceneRenderRead',
          'SceneViewRuntime.overlayPreviewRead',
          'SceneViewRenderSurface',
          'SceneViewInteractiveOverlayPainter',
          'SceneViewRuntime.createPointerSession',
          'render_main_scene_read_flow.json',
          'render_overlay_preview_flow.json',
          'pointer_input_flow.json',
          '`locked`',
        ]);
        expect(source, isNot(contains('## Current Mismatch')));
        expect(source, isNot(contains('## Target Shape')));
        expect(source, isNot(contains('What Is Intentionally Not Locked Yet')));
        expect(source, isNot(contains('still mixed')));
        expect(source, isNot(contains('future work')));

        _expectNoInlineFlowContent(
          path:
              'docs/target_architecture/families/view_runtime_and_render_seam.md',
          source: source,
        );
      },
    );

    test('composition family keeps a compact root/facade contract', () {
      final source = _read(
        'docs/target_architecture/families/composition_root_and_facade.md',
      );

      _expectSections(source, const <String>[
        '## Purpose',
        '## Target Rules',
        '## Owners',
        '## Forbidden Shapes',
        '## Mechanical Evidence',
        '## Status',
      ]);
      _expectContainsAll(source, const <String>[
        'SceneController',
        'createSceneControllerGraph',
        'SceneControllerInteractionRuntime',
        'SceneControllerSceneViewRuntime',
        'composition_root_trace.json',
        'composition_root_trace.md',
        'SceneControllerGraphHandle',
        '`locked`',
      ]);
      expect(source, isNot(contains('## Current Mismatch')));
      expect(source, isNot(contains('## Target Shape')));
      expect(source, isNot(contains('## Locked Local Owner Inventory')));

      _expectNoInlineFlowContent(
        path:
            'docs/target_architecture/families/composition_root_and_facade.md',
        source: source,
      );
    });

    test('mutation gateway keeps one stable write boundary contract', () {
      final source = _read(
        'docs/target_architecture/families/mutation_gateway.md',
      );

      _expectSections(source, const <String>[
        '## Purpose',
        '## Target Rules',
        '## Owners',
        '## Forbidden Shapes',
        '## Mechanical Evidence',
        '## Status',
      ]);
      _expectContainsAll(source, const <String>[
        'SceneControllerMutationBoundary',
        'SceneControllerCommittedMutationAccess',
        'SceneControllerSceneOwner',
        'SceneControllerSelectionOwner',
        'scene_controller_interaction_runtime.dart',
        'add_node_write_flow.json',
        'add_node_write_flow.md',
        'lsp_find_boundary_bypasses.dart',
        'lsp_find_thin_wrappers.dart',
        '`locked`',
      ]);
      _expectContainsNone(source, const <String>[
        'SceneControllerSceneMutations',
        'SceneControllerSelectionMutations',
        'InteractiveSelectionActions',
      ]);
      expect(source, isNot(contains('## Current Mismatch')));
      expect(source, isNot(contains('## Target Shape')));
      expect(source, isNot(contains('## Locked Local Owner Inventory')));

      _expectNoInlineFlowContent(
        path: 'docs/target_architecture/families/mutation_gateway.md',
        source: source,
      );
    });

    test('store family keeps a compact committed-state contract', () {
      final source = _read(
        'docs/target_architecture/families/store_and_commit_path.md',
      );

      _expectSections(source, const <String>[
        '## Purpose',
        '## Target Rules',
        '## Owners',
        '## Forbidden Shapes',
        '## Mechanical Evidence',
        '## Status',
      ]);
      _expectContainsAll(source, const <String>[
        'SceneStoreController',
        'SceneControllerCommitRuntime',
        'TxnContext',
        'replace_scene_write_flow.json',
        'replace_scene_write_flow.md',
        '`locked`',
      ]);
      expect(source, isNot(contains('`locked, needs slimming`')));
      expect(source, isNot(contains('## Current Mismatch')));
      expect(source, isNot(contains('## Target Shape')));
      expect(source, isNot(contains('## Locked Local Owner Inventory')));

      _expectNoInlineFlowContent(
        path: 'docs/target_architecture/families/store_and_commit_path.md',
        source: source,
      );
    });

    test('interaction family records the locked local boundary', () {
      final source = _read(
        'docs/target_architecture/families/interaction_runtime.md',
      );

      _expectSections(source, const <String>[
        '## Purpose',
        '## Target Rules',
        '## Owners',
        '## Forbidden Shapes',
        '## Mechanical Evidence',
        '## Status',
      ]);
      _expectContainsAll(source, const <String>[
        'SceneControllerInteractionRuntime',
        'InteractiveRuntime',
        'SceneControllerPointerSession',
        'SceneControllerMutationBoundary',
        '_createInteractiveRuntime',
        'commit_move_selection_flow.json',
        'commit_move_selection_flow.md',
        'lsp_find_thin_wrappers.dart',
        '`locked`',
      ]);
      _expectContainsNone(source, const <String>[
        'InteractiveSelectionActions',
        'interactive_selection_actions.dart',
      ]);
      expect(source, isNot(contains('## Current Mismatch')));
      expect(source, isNot(contains('## Target Shape')));
      expect(source, isNot(contains('## Locked Local Owner Inventory')));

      _expectNoInlineFlowContent(
        path: 'docs/target_architecture/families/interaction_runtime.md',
        source: source,
      );
    });

    test('every family doc follows the normalized contract shape', () {
      for (final path in _familyDocPaths) {
        final source = _read(path);

        _expectSections(source, const <String>[
          '## Purpose',
          '## Target Rules',
          '## Owners',
          '## Forbidden Shapes',
          '## Mechanical Evidence',
          '## Status',
        ]);

        final statusSection = _sectionBody(source, '## Status');
        expect(
          _statusMatches(statusSection),
          hasLength(1),
          reason: '$path must declare exactly one normalized status.',
        );

        final evidenceSection = _sectionBody(source, '## Mechanical Evidence');
        expect(
          evidenceSection,
          contains('dart run tool/'),
          reason: '$path must name repository-local probe commands.',
        );
        expect(
          evidenceSection,
          contains('../evidence/'),
          reason: '$path must link to committed evidence artifacts.',
        );
      }
    });

    test('mutation-family evidence stays on live direct-route entrypoints', () {
      final addNodeJson = _read(
        'docs/target_architecture/evidence/add_node_write_flow.json',
      );
      final addNodeMermaid = _read(
        'docs/target_architecture/evidence/add_node_write_flow.md',
      );
      final replaceSceneJson = _read(
        'docs/target_architecture/evidence/replace_scene_write_flow.json',
      );
      final replaceSceneMermaid = _read(
        'docs/target_architecture/evidence/replace_scene_write_flow.md',
      );
      final commitMoveJson = _read(
        'docs/target_architecture/evidence/commit_move_selection_flow.json',
      );
      final commitMoveMermaid = _read(
        'docs/target_architecture/evidence/commit_move_selection_flow.md',
      );
      expect(<String>[
        addNodeJson,
        addNodeMermaid,
        replaceSceneJson,
        replaceSceneMermaid,
        commitMoveJson,
        commitMoveMermaid,
      ], hasLength(6));

      _expectContainsAll(addNodeJson, const <String>[
        '"symbol": "SceneControllerSceneOwner.addNode"',
        '"detail": "SceneControllerMutationBoundary"',
      ]);
      _expectContainsAll(addNodeMermaid, const <String>[
        'SceneControllerSceneOwner.addNode',
        'SceneControllerMutationBoundary.addNode',
      ]);

      _expectContainsAll(replaceSceneJson, const <String>[
        '"symbol": "SceneControllerSceneOwner.replaceScene"',
        '"detail": "SceneControllerCommittedMutationAccess"',
      ]);
      _expectContainsAll(replaceSceneMermaid, const <String>[
        'SceneControllerSceneOwner.replaceScene',
        'SceneControllerMutationBoundary.replaceScene',
      ]);

      _expectContainsAll(commitMoveJson, const <String>[
        '"symbol": "_createInteractiveRuntime"',
        '"name": "commitMoveSelection"',
        '"detail": "SceneControllerMutationBoundary"',
      ]);
      _expectContainsAll(commitMoveMermaid, const <String>[
        '_createInteractiveRuntime',
        'SceneControllerMutationBoundary.commitMoveSelection',
      ]);

      for (final source in <String>[
        addNodeJson,
        addNodeMermaid,
        replaceSceneJson,
        replaceSceneMermaid,
        commitMoveJson,
        commitMoveMermaid,
      ]) {
        _expectContainsNone(source, const <String>[
          'SceneControllerSceneMutations',
          'SceneControllerSelectionMutations',
          'InteractiveSelectionActions',
        ]);
      }
    });

    test(
      'composition root evidence reflects direct owner assembly without retired shells',
      () {
        final compositionJson = _read(
          'docs/target_architecture/evidence/composition_root_trace.json',
        );
        final compositionMermaid = _read(
          'docs/target_architecture/evidence/composition_root_trace.md',
        );
        expect(<String>[compositionJson, compositionMermaid], hasLength(2));

        for (final source in <String>[compositionJson, compositionMermaid]) {
          _expectContainsAll(source, const <String>[
            'SceneControllerSelectionOwner',
            'SceneControllerSceneOwner',
          ]);
          _expectContainsNone(source, const <String>[
            'SceneControllerSceneMutations',
            'SceneControllerSelectionMutations',
            'InteractiveSelectionActions',
          ]);
        }
      },
    );
  });
}

const Set<String> _allowedStatuses = <String>{
  'locked',
  'provisional',
  'docs stale',
};

const Set<String> _expectedRuntimeViewEvidenceLinks = <String>{
  'evidence/add_node_write_flow.json',
  'evidence/add_node_write_flow.md',
  'evidence/pointer_input_flow.json',
  'evidence/pointer_input_flow.md',
  'evidence/render_main_scene_read_flow.json',
  'evidence/render_main_scene_read_flow.md',
  'evidence/render_overlay_preview_flow.json',
  'evidence/render_overlay_preview_flow.md',
};

const List<String> _familyDocPaths = <String>[
  'docs/target_architecture/families/composition_root_and_facade.md',
  'docs/target_architecture/families/view_runtime_and_render_seam.md',
  'docs/target_architecture/families/interaction_runtime.md',
  'docs/target_architecture/families/mutation_gateway.md',
  'docs/target_architecture/families/store_and_commit_path.md',
];

String _read(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'Missing required file $path');
  return file.readAsStringSync();
}

void _expectSections(String source, List<String> headings) {
  var previousIndex = -1;
  for (final heading in headings) {
    final index = source.indexOf(heading);
    expect(index, isNonNegative, reason: 'Missing heading `$heading`');
    expect(
      index,
      greaterThan(previousIndex),
      reason: 'Heading `$heading` must appear after the previous section.',
    );
    previousIndex = index;
  }
}

void _expectContainsAll(String source, List<String> fragments) {
  for (final fragment in fragments) {
    expect(source, contains(fragment), reason: 'Missing `$fragment`');
  }
}

void _expectContainsNone(String source, List<String> fragments) {
  for (final fragment in fragments) {
    expect(source, isNot(contains(fragment)), reason: 'Unexpected `$fragment`');
  }
}

void _expectNoInlineFlowContent({
  required String path,
  required String source,
}) {
  expect(
    source,
    isNot(contains('```mermaid')),
    reason: '$path must not contain inline Mermaid blocks.',
  );
  expect(
    _inlineFlowchartPattern.hasMatch(source),
    isFalse,
    reason: '$path must not contain hand-written flowchart content.',
  );
  expect(
    _inlineGraphPattern.hasMatch(source),
    isFalse,
    reason: '$path must not contain hand-written graph content.',
  );
}

List<String> _ownerRegistryStatuses(String source) {
  final lines = source.split('\n');
  final tableLines = <String>[];
  var inRegistry = false;
  for (final line in lines) {
    if (line == '## Owner Family Registry') {
      inRegistry = true;
      continue;
    }
    if (!inRegistry) {
      continue;
    }
    if (line.startsWith('## ')) {
      break;
    }
    if (line.trim().startsWith('|')) {
      tableLines.add(line);
    }
  }

  expect(
    tableLines.length,
    greaterThanOrEqualTo(3),
    reason: 'Owner registry table must include a header and at least one row.',
  );

  final statuses = <String>[];
  for (final line in tableLines.skip(2)) {
    final columns = line
        .split('|')
        .skip(1)
        .takeWhile((_) => true)
        .map((value) => value.trim())
        .toList();
    expect(
      columns.length,
      greaterThanOrEqualTo(4),
      reason: 'Registry rows must keep four columns.',
    );
    final status = columns[2].replaceAll('`', '');
    statuses.add(status);
  }
  return statuses;
}

Set<String> _evidenceLinks(String source) {
  return RegExp(r'\((evidence/[^)]+)\)')
      .allMatches(source)
      .map((match) => match.group(1))
      .whereType<String>()
      .toSet();
}

String _sectionBody(String source, String heading) {
  final start = source.indexOf(heading);
  expect(start, isNonNegative, reason: 'Missing heading `$heading`');
  final bodyStart = source.indexOf('\n', start);
  final nextHeading = source.indexOf('\n## ', bodyStart + 1);
  if (nextHeading == -1) {
    return source.substring(bodyStart + 1).trim();
  }
  return source.substring(bodyStart + 1, nextHeading).trim();
}

List<String> _statusMatches(String sectionBody) {
  final matches = <String>[];
  for (final status in _allowedStatuses) {
    if (sectionBody.contains('`$status`')) {
      matches.add(status);
    }
  }
  return matches;
}

final RegExp _inlineFlowchartPattern = RegExp(
  r'(^|\n)\s*flowchart\s+(LR|RL|TD|TB|BT)\b',
  multiLine: true,
);

final RegExp _inlineGraphPattern = RegExp(
  r'(^|\n)\s*graph\s+(LR|RL|TD|TB|BT)\b',
  multiLine: true,
);
