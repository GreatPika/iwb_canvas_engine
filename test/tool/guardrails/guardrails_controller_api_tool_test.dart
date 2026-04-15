@Tags(['tool'])
library;

import 'package:flutter_test/flutter_test.dart';

import '../support/guardrails_tool_test_support.dart';
import '../support/tool_process_test_support.dart';

void main() {
  group('tool/check_guardrails.dart', () {
    // INV:INV-ENG-CONTROLLER-NO-FULL-VIEW-RENDER-STATE
    test(
      'allows SceneStoreController to stay on SceneRenderState without full view render-state import',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeSandboxFile(
            sandbox,
            'lib/src/controller/scene_store_controller.dart',
            '''
import '../contract/scene_render_state.dart';

class SceneStoreController implements SceneRenderState {
  final int controllerEpoch = 0;

  SceneRenderState? currentState;
}
''',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, 0);
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects controller-layer import of scene_view_render_state.dart',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeSandboxFile(
            sandbox,
            'lib/src/controller/scene_store_controller.dart',
            '''
import '../contract/scene_view_render_state.dart';

class SceneStoreController {
  final int controllerEpoch = 0;
}
''',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'controller API',
              detail:
                  'controller layer must not import '
                  'scene_view_render_state.dart',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects SceneStoreController implementing SceneViewRenderState',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeSandboxFile(
            sandbox,
            'lib/src/controller/scene_store_controller.dart',
            '''
class SceneStoreController implements SceneViewRenderState {
  final int controllerEpoch = 0;
}
''',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'controller API',
              detail:
                  'SceneStoreController must not implement SceneViewRenderState',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    // INV:INV-ENG-WRITE-ONLY-MUTATION
    test(
      'allows controller-private committed mutation access contract by declaration shape',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeSandboxFile(
            sandbox,
            'lib/src/controller/scene_store_controller.dart',
            '''
class SceneStoreController {
  final int controllerEpoch = 0;
}
''',
          );
          writeSandboxFile(
            sandbox,
            'lib/src/controller/controller_private_mutation_bridge.dart',
            '''
abstract interface class SceneControllerCommittedMutationAccess {
  void replaceSelection(Object nodeIds);

  int commitEraseNodes(Object ids);
}

final class SceneStoreControllerCommittedMutationAccess
    implements SceneControllerCommittedMutationAccess {
  SceneStoreControllerCommittedMutationAccess(this._storeController);

  final SceneStoreController _storeController;

  @override
  void replaceSelection(Object nodeIds) {}

  @override
  int commitEraseNodes(Object ids) => 0;
}
''',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, 0);
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects extra mutating symbol outside whitelisted mutation bridge declarations',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeSandboxFile(
            sandbox,
            'lib/src/controller/scene_store_controller.dart',
            '''
class SceneStoreController {
  final int controllerEpoch = 0;
}
''',
          );
          writeSandboxFile(
            sandbox,
            'lib/src/controller/controller_private_mutation_bridge.dart',
            '''
abstract interface class SceneControllerCommittedMutationAccess {
  void replaceSelection(Object nodeIds);
}

final class SceneStoreControllerCommittedMutationAccess
    implements SceneControllerCommittedMutationAccess {
  SceneStoreControllerCommittedMutationAccess(this._storeController);

  final SceneStoreController _storeController;

  @override
  void replaceSelection(Object nodeIds) {}
}

void clearSelectionCache() {}
''',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'controller API',
              detail:
                  'mutating symbol "clearSelectionCache" must be routed through '
                  'write*/txn* transaction API',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('rejects mutating symbol outside write/txn prefixes', () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeSandboxFile(sandbox, 'lib/src/controller/store.dart', '''
class Store {
  int controllerEpoch = 0;

  void replaceScene() {}
}
''');

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'controller API',
            detail:
                'mutating symbol "replaceScene" must be routed through '
                'write*/txn* transaction API',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'rejects direct selection writer mutation bypass outside canonical ops',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeSandboxFile(
            sandbox,
            'lib/src/controller/scene_writer_selection.dart',
            '''
List<String>? sceneWriterWriteSelectionReplaceResult(Object writer, Set<String> ids) {
  final ctx = writer.runtime.ctx;
  ctx.workingSelection
    ..clear()
    ..addAll(ids);
  return ids.toList();
}
''',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'controller API',
              detail:
                  'selection writer entrypoints must route through canonical '
                  'selection-state mutation ops instead of touching '
                  'workingSelection/changeSet directly',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    // INV:INV-ENG-COMMITTED-READ-SIDE-HERMETICITY
    test(
      'accepts snapshot-only committed read-side controller helpers',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeSandboxFile(sandbox, 'lib/src/contract/snapshot.dart', '''
typedef NodeId = String;

class NodeSnapshot {
  const NodeSnapshot({required this.id});

  final NodeId id;
}
''');
          writeSandboxFile(sandbox, 'lib/src/core/scene_spatial_index.dart', '''
import '../contract/snapshot.dart';

class Rect {}
class Offset {}

class SceneSpatialCandidate {
  const SceneSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.candidateBoundsWorld,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect candidateBoundsWorld;
}
''');
          writeSandboxFile(
            sandbox,
            'lib/src/controller/scene_store_controller.dart',
            '''
import '../contract/snapshot.dart';
import '../core/scene_spatial_index.dart';

class Offset {}
class SceneSnapshot {}
class PreparedSceneReplacement {}

class SceneStoreController {
  final int controllerEpoch = 0;
}

extension SceneStoreControllerSpatialAccess on SceneStoreController {
  List<SceneSpatialCandidate> querySpatialCandidates(Rect worldBounds) =>
      const <SceneSpatialCandidate>[];

  NodeSnapshot? resolveSpatialCandidateSnapshot(
    SceneSpatialCandidate candidate, {
    SceneSnapshot? snapshotOverride,
  }) => null;

  ({NodeSnapshot node, int layerIndex, int nodeIndex})?
  resolveSnapshotNodeById(
    NodeId nodeId, {
    SceneSnapshot? snapshotOverride,
  }) => null;

  void writeReplaceScene(SceneSnapshot snapshot) {}

  PreparedSceneReplacement prepareSceneReplacement(SceneSnapshot snapshot) =>
      PreparedSceneReplacement();

  void writePreparedSceneReplacement(PreparedSceneReplacement replacement) {}

  Offset centerWorldForNodeSnapshots(Iterable<NodeSnapshot> snapshots) =>
      Offset();
}
''',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, 0, reason: result.stderr.toString());
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'accepts committed read helper using dart ui Scene without false runtime leak',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeSandboxFile(sandbox, 'lib/src/contract/snapshot.dart', '''
typedef NodeId = String;

class NodeSnapshot {
  const NodeSnapshot({required this.id});

  final NodeId id;
}
''');
          writeSandboxFile(sandbox, 'lib/src/core/scene_spatial_index.dart', '''
import '../contract/snapshot.dart';

class Rect {}
class Offset {}

class SceneSpatialCandidate {
  const SceneSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.candidateBoundsWorld,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect candidateBoundsWorld;
}
''');
          writeSandboxFile(
            sandbox,
            'lib/src/controller/scene_store_controller.dart',
            '''
import 'dart:ui' show Scene;

import '../contract/snapshot.dart';
import '../core/scene_spatial_index.dart';

class Offset {}
class SceneSnapshot {}
class PreparedSceneReplacement {}

class SceneStoreController {
  final int controllerEpoch = 0;
}

extension SceneStoreControllerSpatialAccess on SceneStoreController {
  List<SceneSpatialCandidate> querySpatialCandidates(Rect worldBounds) =>
      const <SceneSpatialCandidate>[];

  NodeSnapshot? resolveSpatialCandidateSnapshot(
    SceneSpatialCandidate candidate, {
    Scene? uiScene,
    SceneSnapshot? snapshotOverride,
  }) => null;

  ({NodeSnapshot node, int layerIndex, int nodeIndex})?
  resolveSnapshotNodeById(
    NodeId nodeId, {
    SceneSnapshot? snapshotOverride,
  }) => null;

  void writeReplaceScene(SceneSnapshot snapshot) {}

  PreparedSceneReplacement prepareSceneReplacement(SceneSnapshot snapshot) =>
      PreparedSceneReplacement();

  void writePreparedSceneReplacement(PreparedSceneReplacement replacement) {}

  Offset centerWorldForNodeSnapshots(Iterable<NodeSnapshot> snapshots) =>
      Offset();
}
''',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, 0, reason: result.stderr.toString());
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects committed read helper returning runtime scene node through typedef alias',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeSandboxFile(sandbox, 'lib/src/core/scene_node.dart', '''
class SceneNode {}
''');
          writeSandboxFile(sandbox, 'lib/src/contract/snapshot.dart', '''
typedef NodeId = String;

class NodeSnapshot {
  const NodeSnapshot({required this.id});

  final NodeId id;
}
''');
          writeSandboxFile(sandbox, 'lib/src/core/scene_spatial_index.dart', '''
import '../contract/snapshot.dart';

class Rect {}

class SceneSpatialCandidate {
  const SceneSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.candidateBoundsWorld,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect candidateBoundsWorld;
}
''');
          writeSandboxFile(
            sandbox,
            'lib/src/controller/scene_store_controller.dart',
            '''
import '../contract/snapshot.dart';
import '../core/scene_node.dart';
import '../core/scene_spatial_index.dart';

typedef LeakedNode = SceneNode;

class SceneSnapshot {}

class SceneStoreController {
  final int controllerEpoch = 0;
}

extension SceneStoreControllerSpatialAccess on SceneStoreController {
  List<SceneSpatialCandidate> querySpatialCandidates(Rect worldBounds) =>
      const <SceneSpatialCandidate>[];

  LeakedNode? resolveSpatialCandidateSnapshot(
    SceneSpatialCandidate candidate, {
    SceneSnapshot? snapshotOverride,
  }) => null;
}
''',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'controller API',
              detail:
                  'committed read helper "resolveSpatialCandidateSnapshot" '
                  'must not expose live runtime scene-graph types (SceneNode)',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects public helper outside sealed SceneStoreControllerSpatialAccess surface',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeSandboxFile(sandbox, 'lib/src/contract/snapshot.dart', '''
typedef NodeId = String;

class NodeSnapshot {
  const NodeSnapshot({required this.id});

  final NodeId id;
}
''');
          writeSandboxFile(sandbox, 'lib/src/core/scene_spatial_index.dart', '''
import '../contract/snapshot.dart';

class Rect {}
class Offset {}

class SceneSpatialCandidate {
  const SceneSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.candidateBoundsWorld,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect candidateBoundsWorld;
}
''');
          writeSandboxFile(
            sandbox,
            'lib/src/controller/scene_store_controller.dart',
            '''
import '../contract/snapshot.dart';
import '../core/scene_spatial_index.dart';

class Offset {}
class SceneSnapshot {}
class PreparedSceneReplacement {}

class SceneStoreController {
  final int controllerEpoch = 0;
}

extension SceneStoreControllerSpatialAccess on SceneStoreController {
  List<SceneSpatialCandidate> querySpatialCandidates(Rect worldBounds) =>
      const <SceneSpatialCandidate>[];

  NodeSnapshot? resolveSpatialCandidateSnapshot(
    SceneSpatialCandidate candidate, {
    SceneSnapshot? snapshotOverride,
  }) => null;

  ({NodeSnapshot node, int layerIndex, int nodeIndex})?
  resolveSnapshotNodeById(
    NodeId nodeId, {
    SceneSnapshot? snapshotOverride,
  }) => null;

  void writeReplaceScene(SceneSnapshot snapshot) {}

  PreparedSceneReplacement prepareSceneReplacement(SceneSnapshot snapshot) =>
      PreparedSceneReplacement();

  void writePreparedSceneReplacement(PreparedSceneReplacement replacement) {}

  NodeSnapshot? leakedNodeHelper(NodeId nodeId) => null;

  Offset centerWorldForNodeSnapshots(Iterable<NodeSnapshot> snapshots) =>
      Offset();
}
''',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'controller API',
              detail:
                  'SceneStoreControllerSpatialAccess public member '
                  '"leakedNodeHelper" must not extend the sealed helper '
                  'surface',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects committed read helper returning runtime scene node subtype',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeSandboxFile(sandbox, 'lib/src/core/scene_node.dart', '''
class SceneNode {}
''');
          writeSandboxFile(sandbox, 'lib/src/core/vector_nodes.dart', '''
import 'scene_node.dart';

class StrokeNode extends SceneNode {}
''');
          writeSandboxFile(sandbox, 'lib/src/contract/snapshot.dart', '''
typedef NodeId = String;

class NodeSnapshot {
  const NodeSnapshot({required this.id});

  final NodeId id;
}
''');
          writeSandboxFile(sandbox, 'lib/src/core/scene_spatial_index.dart', '''
import '../contract/snapshot.dart';

class Rect {}

class SceneSpatialCandidate {
  const SceneSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.candidateBoundsWorld,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect candidateBoundsWorld;
}
''');
          writeSandboxFile(
            sandbox,
            'lib/src/controller/scene_store_controller.dart',
            '''
import '../core/vector_nodes.dart';
import '../core/scene_spatial_index.dart';

class SceneStoreController {
  final int controllerEpoch = 0;
}

extension SceneStoreControllerSpatialAccess on SceneStoreController {
  List<SceneSpatialCandidate> querySpatialCandidates(Rect worldBounds) =>
      const <SceneSpatialCandidate>[];

  StrokeNode? resolveSpatialCandidateSnapshot(
    SceneSpatialCandidate candidate,
  ) => null;
}
''',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'controller API',
              detail:
                  'committed read helper "resolveSpatialCandidateSnapshot" '
                  'must not expose live runtime scene-graph types (StrokeNode)',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects committed spatial payload field outside sealed locator-only surface',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeSandboxFile(sandbox, 'lib/src/contract/snapshot.dart', '''
typedef NodeId = String;
''');
          writeSandboxFile(sandbox, 'lib/src/core/scene_spatial_index.dart', '''
import '../contract/snapshot.dart';

class Rect {}

class SceneSpatialCandidate {
  const SceneSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.candidateBoundsWorld,
    required this.structuralRevision,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect candidateBoundsWorld;
  final int structuralRevision;
}
''');
          writeSandboxFile(
            sandbox,
            'lib/src/controller/scene_store_controller.dart',
            '''
class SceneStoreController {
  final int controllerEpoch = 0;
}
''',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'controller API',
              detail:
                  'committed spatial payload '
                  '"SceneSpatialCandidate.structuralRevision" must not extend '
                  'the sealed locator-only field surface',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects committed spatial payload record field that contains runtime scene node',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeSandboxFile(sandbox, 'lib/src/core/scene_node.dart', '''
class SceneNode {}
''');
          writeSandboxFile(sandbox, 'lib/src/contract/snapshot.dart', '''
typedef NodeId = String;
''');
          writeSandboxFile(sandbox, 'lib/src/core/scene_spatial_index.dart', '''
import '../contract/snapshot.dart';
import 'scene_node.dart';

class Rect {}

class SceneSpatialCandidate {
  const SceneSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.candidateBoundsWorld,
    required this.leaked,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect candidateBoundsWorld;
  final ({SceneNode node}) leaked;
}
''');
          writeSandboxFile(
            sandbox,
            'lib/src/controller/scene_store_controller.dart',
            '''
class SceneStoreController {
  final int controllerEpoch = 0;
}
''',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'controller API',
              detail:
                  'committed spatial payload "SceneSpatialCandidate.leaked" '
                  'must not expose live runtime scene-graph types (SceneNode)',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('rejects missing committed spatial payload owner class', () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeSandboxFile(sandbox, 'lib/src/contract/snapshot.dart', '''
typedef NodeId = String;
''');
        writeSandboxFile(sandbox, 'lib/src/core/scene_spatial_index.dart', '''
class Rect {}
''');
        writeSandboxFile(
          sandbox,
          'lib/src/controller/scene_store_controller.dart',
          '''
class SceneStoreController {
  final int controllerEpoch = 0;
}
''',
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'controller API',
            detail:
                'committed spatial payload owner "SceneSpatialCandidate" '
                'is required in scene_spatial_index.dart',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects missing committed spatial payload file', () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeSandboxFile(sandbox, 'lib/src/contract/snapshot.dart', '''
typedef NodeId = String;

class NodeSnapshot {
  const NodeSnapshot({required this.id});

  final NodeId id;
}
''');
        writeSandboxFile(
          sandbox,
          'lib/src/controller/scene_store_controller.dart',
          '''
import '../contract/snapshot.dart';

class Offset {}
class SceneSnapshot {}

class SceneStoreController {
  final int controllerEpoch = 0;
}

extension SceneStoreControllerSpatialAccess on SceneStoreController {
  List<Object> querySpatialCandidates(Object worldBounds) => const <Object>[];

  NodeSnapshot? resolveSpatialCandidateSnapshot(
    Object candidate, {
    SceneSnapshot? snapshotOverride,
  }) => null;

  ({NodeSnapshot node, int layerIndex, int nodeIndex})?
  resolveSnapshotNodeById(
    NodeId nodeId, {
    SceneSnapshot? snapshotOverride,
  }) => null;

  Offset centerWorldForNodeSnapshots(Iterable<NodeSnapshot> snapshots) =>
      Offset();
}
''',
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'controller API',
            detail:
                'committed spatial payload file scene_spatial_index.dart is '
                'required when committed read helpers exist',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects missing committed read helper owner file', () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeSandboxFile(sandbox, 'lib/src/contract/snapshot.dart', '''
typedef NodeId = String;
''');
        writeSandboxFile(sandbox, 'lib/src/core/scene_spatial_index.dart', '''
import '../contract/snapshot.dart';

class Rect {}

class SceneSpatialCandidate {
  const SceneSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.candidateBoundsWorld,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect candidateBoundsWorld;
}
''');

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'controller API',
            detail:
                'committed read helper owner file '
                'scene_store_controller.dart is required when '
                'scene_spatial_index.dart exists',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'rejects missing sealed SceneStoreControllerSpatialAccess owner',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeSandboxFile(sandbox, 'lib/src/contract/snapshot.dart', '''
typedef NodeId = String;

class NodeSnapshot {
  const NodeSnapshot({required this.id});

  final NodeId id;
}
''');
          writeSandboxFile(sandbox, 'lib/src/core/scene_spatial_index.dart', '''
import '../contract/snapshot.dart';

class Rect {}

class SceneSpatialCandidate {
  const SceneSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.candidateBoundsWorld,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect candidateBoundsWorld;
}
''');
          writeSandboxFile(
            sandbox,
            'lib/src/controller/scene_store_controller.dart',
            '''
class SceneStoreController {
  final int controllerEpoch = 0;
}
''',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'controller API',
              detail:
                  'sealed helper surface owner '
                  '"SceneStoreControllerSpatialAccess" is required in '
                  'scene_store_controller.dart',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects committed spatial payload constructor leaking runtime scene node',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeSandboxFile(sandbox, 'lib/src/core/scene_node.dart', '''
class SceneNode {}
''');
          writeSandboxFile(sandbox, 'lib/src/contract/snapshot.dart', '''
typedef NodeId = String;
''');
          writeSandboxFile(sandbox, 'lib/src/core/scene_spatial_index.dart', '''
import '../contract/snapshot.dart';
import 'scene_node.dart';

class Rect {}

class SceneSpatialCandidate {
  const SceneSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.candidateBoundsWorld,
    required SceneNode leakedNode,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect candidateBoundsWorld;
}
''');
          writeSandboxFile(
            sandbox,
            'lib/src/controller/scene_store_controller.dart',
            '''
class SceneStoreController {
  final int controllerEpoch = 0;
}
''',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'controller API',
              detail:
                  'committed spatial payload constructor for '
                  '"SceneSpatialCandidate" must not expose live runtime '
                  'scene-graph types (SceneNode)',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects committed controller mutator exposing runtime scene type',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeSandboxFile(sandbox, 'lib/src/core/scene.dart', '''
class Scene {}
''');
          writeSandboxFile(sandbox, 'lib/src/contract/snapshot.dart', '''
typedef NodeId = String;

class NodeSnapshot {
  const NodeSnapshot({required this.id});

  final NodeId id;
}
''');
          writeSandboxFile(sandbox, 'lib/src/core/scene_spatial_index.dart', '''
import '../contract/snapshot.dart';

class Rect {}
class Offset {}

class SceneSpatialCandidate {
  const SceneSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.candidateBoundsWorld,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect candidateBoundsWorld;
}
''');
          writeSandboxFile(
            sandbox,
            'lib/src/controller/scene_store_controller.dart',
            '''
import '../contract/snapshot.dart';
import '../core/scene.dart';
import '../core/scene_spatial_index.dart';

class Offset {}
class SceneSnapshot {}
class PreparedSceneReplacement {}

class SceneStoreController {
  final int controllerEpoch = 0;
}

extension SceneStoreControllerSpatialAccess on SceneStoreController {
  List<SceneSpatialCandidate> querySpatialCandidates(Rect worldBounds) =>
      const <SceneSpatialCandidate>[];

  NodeSnapshot? resolveSpatialCandidateSnapshot(
    SceneSpatialCandidate candidate,
  ) => null;

  ({NodeSnapshot node, int layerIndex, int nodeIndex})?
  resolveSnapshotNodeById(NodeId nodeId) => null;

  void writeReplaceScene(Scene scene) {}

  PreparedSceneReplacement prepareSceneReplacement(SceneSnapshot snapshot) =>
      PreparedSceneReplacement();

  void writePreparedSceneReplacement(PreparedSceneReplacement replacement) {}

  Offset centerWorldForNodeSnapshots(Iterable<NodeSnapshot> snapshots) =>
      Offset();
}
''',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'controller API',
              detail:
                  'committed controller surface member "writeReplaceScene" '
                  'must not expose live runtime scene-graph types (Scene)',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects committed read helper exposing runtime scene node via extension type',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeSandboxFile(sandbox, 'lib/src/core/scene_node.dart', '''
class SceneNode {}
''');
          writeSandboxFile(sandbox, 'lib/src/contract/snapshot.dart', '''
typedef NodeId = String;
''');
          writeSandboxFile(sandbox, 'lib/src/core/scene_spatial_index.dart', '''
import '../contract/snapshot.dart';

class Rect {}

class SceneSpatialCandidate {
  const SceneSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.candidateBoundsWorld,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect candidateBoundsWorld;
}
''');
          writeSandboxFile(
            sandbox,
            'lib/src/controller/scene_store_controller.dart',
            '''
import '../contract/snapshot.dart';
import '../core/scene_node.dart';
import '../core/scene_spatial_index.dart';

extension type LeakedNode(SceneNode node) {}

class Offset {
  const Offset();

  static const Offset zero = Offset();
}

class SceneStoreController {
  final int controllerEpoch = 0;
}

extension SceneStoreControllerSpatialAccess on SceneStoreController {
  List<SceneSpatialCandidate> querySpatialCandidates(Rect worldBounds) =>
      const <SceneSpatialCandidate>[];

  LeakedNode? resolveSpatialCandidateSnapshot(
    SceneSpatialCandidate candidate,
  ) => null;

  ({LeakedNode node, int layerIndex, int nodeIndex})? resolveSnapshotNodeById(
    NodeId nodeId,
  ) => null;

  Offset centerWorldForNodeSnapshots(Iterable<LeakedNode> snapshots) =>
      Offset.zero;
}
''',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'controller API',
              detail:
                  'committed read helper "resolveSpatialCandidateSnapshot" '
                  'must not expose live runtime scene-graph types '
                  '(SceneNode)',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects committed read helper generic bound leaking runtime scene node',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeSandboxFile(sandbox, 'lib/src/core/scene_node.dart', '''
class SceneNode {}
''');
          writeSandboxFile(sandbox, 'lib/src/contract/snapshot.dart', '''
typedef NodeId = String;
''');
          writeSandboxFile(sandbox, 'lib/src/core/scene_spatial_index.dart', '''
import '../contract/snapshot.dart';

class Rect {}

class SceneSpatialCandidate {
  const SceneSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.candidateBoundsWorld,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect candidateBoundsWorld;
}
''');
          writeSandboxFile(
            sandbox,
            'lib/src/controller/scene_store_controller.dart',
            '''
import '../core/scene_node.dart';
import '../core/scene_spatial_index.dart';

class SceneStoreController {
  final int controllerEpoch = 0;
}

extension SceneStoreControllerSpatialAccess on SceneStoreController {
  List<SceneSpatialCandidate> querySpatialCandidates<T extends SceneNode>(
    Rect worldBounds,
  ) => const <SceneSpatialCandidate>[];
}
''',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'controller API',
              detail:
                  'committed read helper "querySpatialCandidates" must not '
                  'expose live runtime scene-graph types (SceneNode)',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );
  });
}
