@Tags(['tool'])
library;

import 'dart:io';

import 'package:test/test.dart';

import '../support/guardrail_fixture_writer.dart';
import '../support/guardrails_sandbox_support.dart';
import '../support/tool_diagnostic_matchers.dart';
import '../support/tool_process_test_support.dart';

typedef _PreparedReplaceSceneAttackCase = ({
  String name,
  String filePath,
  String source,
});

void _writePreparedReplaceSceneBoundarySupportScaffold(Directory sandbox) {
  writeSandboxFile(sandbox, 'lib/src/contract/snapshot.dart', '''
typedef NodeId = String;
typedef LayerId = String;

class SceneSnapshot {}
class ClearSceneResult {}
class NodeSnapshot {}
''');
  writeSandboxFile(
    sandbox,
    'lib/src/contract/scene_write_txn.dart',
    'class SceneWriteTxn {}\n',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/contract/transform2d.dart',
    'class Transform2D {}\n',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/contract/node_spec.dart',
    'class NodeSpec {}\n',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/contract/node_patch.dart',
    'class NodePatch {}\n',
  );
  writeSandboxFile(sandbox, 'lib/src/contract/scene_render_state.dart', '''
import 'snapshot.dart';

abstract interface class SceneRenderState {
  SceneSnapshot get snapshot;
  Set<NodeId> get selectedNodeIds;
}
''');
  writeSandboxFile(
    sandbox,
    'lib/src/controller/scene_controller_commit_runtime.dart',
    '''
class SceneControllerCommittedWrite<T> {
  const SceneControllerCommittedWrite();
}
''',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/controller/scene_controller_commit_debug.dart',
    '''
class SceneStoreControllerDebugAccess {
  const SceneStoreControllerDebugAccess();
}
''',
  );
  _writeSceneStoreControllerPreparedReplaceSupportScaffold(sandbox);
  writeSandboxFile(
    sandbox,
    'lib/src/controller/scene_writer.dart',
    _sceneWriterFixture(),
  );
  writeSandboxFile(
    sandbox,
    'lib/src/controller/scene_store_controller.dart',
    _sceneStoreControllerFixture(),
  );
  writeSandboxFile(
    sandbox,
    'lib/src/controller/scene_controller_committed_mutation_access.dart',
    committedMutationAccessFixture(),
  );
}

void _writeSceneStoreControllerPreparedReplaceSupportScaffold(
  Directory sandbox,
) {
  writeSandboxFile(sandbox, 'lib/src/core/scene_spatial_index.dart', '''
import 'dart:ui';

typedef SceneSpatialCandidateLocation = ({int layerIndex, int nodeIndex});
typedef SceneSpatialCandidateReference = ({
  String nodeId,
  int layerIndex,
  int nodeIndex,
});

enum ScenePaintSpatialQueryScope {
  contentLayersOnly,
  backgroundAndContentLayers,
}

class SceneHitTestSpatialCandidate {
  const SceneHitTestSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.hitTestBoundsWorld,
  });

  final String nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect hitTestBoundsWorld;
}

class ScenePaintSpatialCandidate {
  const ScenePaintSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.paintBoundsWorld,
  });

  final String nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect paintBoundsWorld;
}
''');
}

String _sceneStoreControllerFixture({
  String classDeclaration =
      'class SceneStoreController extends _ChangeNotifier '
      'implements SceneRenderState {',
  bool includeCommittedReplacementExtension = true,
  String extraTopLevel = '',
  String extraClassMembers = '',
  String spatialAccessMembers = '''
  List<SceneHitTestSpatialCandidate> queryHitTestCandidates(Rect worldBounds) =>
      const <SceneHitTestSpatialCandidate>[];

  List<ScenePaintSpatialCandidate> queryPaintCandidates(
    Rect worldBounds, {
    ScenePaintSpatialQueryScope scope =
        ScenePaintSpatialQueryScope.contentLayersOnly,
  }) => const <ScenePaintSpatialCandidate>[];

  NodeSnapshot? resolveSpatialCandidateSnapshot(
    SceneSpatialCandidateReference candidate,
  ) => null;

  ({NodeSnapshot node, int layerIndex, int nodeIndex})? resolveSnapshotNodeById(
    NodeId nodeId,
  ) => null;

  Offset centerWorldForNodeSnapshots(Iterable<NodeSnapshot> snapshots) =>
      Offset.zero;
''',
  String extraExtensionMembers = '',
  String writeReplaceSceneDeclaration = '''
  void writeReplaceScene(SceneSnapshot snapshot) {
    writeWithSceneWriter<void>((writer) {
      writer.writeDocumentReplace(snapshot);
    });
  }
''',
}) {
  return '''
import 'dart:ui';

import '../contract/scene_render_state.dart';
import '../contract/scene_write_txn.dart';
import '../contract/snapshot.dart';
import '../core/scene_spatial_index.dart';
import 'scene_controller_commit_debug.dart';
import 'scene_controller_commit_runtime.dart';
import 'scene_writer.dart';

class _CommittedSignal {}
class _SceneCommands {}
class _MoveCommands {}
class _DrawCommands {}
class _ChangeNotifier {
  void notifyListeners() {}
  void dispose() {}
}

$classDeclaration
  final String? textFontFamilyByDefault = null;
  final commands = _SceneCommands();
  final move = _MoveCommands();
  final draw = _DrawCommands();

  SceneSnapshot get snapshot => SceneSnapshot();
  Set<String> get selectedNodeIds => <String>{};
  int get controllerEpoch => 0;
  int get structuralRevision => 0;
  int get selectionRevision => 0;
  int get boundsRevision => 0;
  int get visualRevision => 0;
  Stream<_CommittedSignal> get signals => const Stream<_CommittedSignal>.empty();
  SceneStoreControllerDebugAccess get debug => const SceneStoreControllerDebugAccess();

  T write<T>(T Function(SceneWriteTxn txn) fn) => throw UnimplementedError();
  SceneControllerCommittedWrite<T> writeCommitted<T>(
    T Function(SceneWriteTxn txn) fn,
  ) => const SceneControllerCommittedWrite<T>();
  T writeWithSceneWriter<T>(T Function(SceneWriter writer) fn) =>
      fn(SceneWriter());
  SceneControllerCommittedWrite<T> writeWithSceneWriterCommitted<T>(
    T Function(SceneWriter writer) fn,
  ) => const SceneControllerCommittedWrite<T>();
  void requestRepaint() {}
  void dispose() {}

$extraClassMembers
}

$extraTopLevel

extension SceneStoreControllerSpatialAccess on SceneStoreController {
${spatialAccessMembers.trimRight()}
}

${includeCommittedReplacementExtension ? '''
extension SceneStoreControllerCommittedSceneReplacementAccess
    on SceneStoreController {
${writeReplaceSceneDeclaration.trimRight()}

$extraExtensionMembers
}
''' : ''}
''';
}

String _sceneWriterFixture({
  String extraTopLevel = '',
  String extraMembers = '',
  String writeDocumentReplaceDeclaration =
      '  void writeDocumentReplace(SceneSnapshot snapshot) {}\n',
}) {
  return '''
import 'dart:ui';

import '../contract/node_patch.dart';
import '../contract/node_spec.dart';
import '../contract/snapshot.dart';
import '../contract/transform2d.dart';

class SceneWriter {
  SceneSnapshot get snapshot => SceneSnapshot();
  Set<String> get selectedNodeIds => <String>{};

  String writeNodeInsert(NodeSpec spec, {String? layerId, int? insertIndex}) =>
      'id';
  bool writeLayerEnsure(String layerId, {int? index}) => true;
  bool writeNodeErase(String nodeId) => true;
  bool writeNodePatch(NodePatch patch) => true;
  bool writeNodeTransformSet(String id, Transform2D transform) => true;
  bool writeSelectionReplace(Iterable<String> ids) => true;
  bool writeSelectionToggle(String id) => true;
  bool writeSelectionClear() => true;
  int writeSelectionSelectAll({bool onlySelectable = true}) => 0;
  int writeSelectionTranslate(Offset delta) => 0;
  int writeSelectionTransform(Transform2D delta) => 0;
  int writeDeleteSelection() => 0;
  List<String> writeClearSceneKeepBackground() => const <String>[];
  ClearSceneResult writeClearSceneKeepBackgroundResult() => ClearSceneResult();
  void writeCameraOffset(Offset offset) {}
  void writeGridEnable(bool enabled) {}
  void writeGridCellSize(double cellSize) {}
  void writeBackgroundColor(Color color) {}
${writeDocumentReplaceDeclaration.trimRight()}
  void writeSignalEnqueue({
    required String type,
    Iterable<String> nodeIds = const <String>[],
    Map<String, Object?>? payload,
  }) {}
  Object get runtime => Object();

$extraMembers
}

$extraTopLevel
''';
}

void _writeSelectionWriterRoutingSupportScaffold(Directory sandbox) {
  writeSandboxFile(
    sandbox,
    'lib/src/controller/scene_writer_support.dart',
    'typedef NodeId = String;\n',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/controller/scene_writer_types.dart',
    '// selection routing test support\n',
  );
  writeSandboxFile(sandbox, 'lib/src/controller/mutation_op.dart', '''
import 'scene_writer_support.dart';

final class ReplaceSelectionOp {
  ReplaceSelectionOp(Iterable<NodeId> ids);
}

final class ToggleSelectionOp {
  ToggleSelectionOp(NodeId id);
}

final class ClearSelectionOp {
  const ClearSelectionOp();
}

final class SelectAllSelectionOp {
  const SelectAllSelectionOp({this.onlySelectable = true});

  final bool onlySelectable;
}
''');
  writeSandboxFile(sandbox, 'lib/src/controller/scene_writer_runtime.dart', '''
import 'mutation_op.dart';
import 'scene_writer_support.dart';

final class SceneWriterRuntime {
  final _TxnContext ctx = _TxnContext();

  MutationApplyResult<TValue> execute<TValue extends Object?>(Object op) =>
      throw UnimplementedError();
}

final class MutationApplyResult<TValue extends Object?> {
  const MutationApplyResult(this.value);

  final TValue value;
}

final class _TxnContext {
  final Set<NodeId> workingSelection = <NodeId>{};
  final Object changeSet = Object();
}
''');
  writeSandboxFile(sandbox, 'lib/src/controller/scene_writer.dart', '''
import 'dart:ui';

import '../contract/node_patch.dart';
import '../contract/node_spec.dart';
import '../contract/snapshot.dart';
import '../contract/transform2d.dart';
import 'scene_writer_runtime.dart';

final class SceneWriter {
  SceneSnapshot get snapshot => SceneSnapshot();
  Set<String> get selectedNodeIds => <String>{};

  String writeNodeInsert(NodeSpec spec, {String? layerId, int? insertIndex}) =>
      'id';
  bool writeLayerEnsure(String layerId, {int? index}) => true;
  bool writeNodeErase(String nodeId) => true;
  bool writeNodePatch(NodePatch patch) => true;
  bool writeNodeTransformSet(String id, Transform2D transform) => true;
  bool writeSelectionReplace(Iterable<String> ids) => true;
  bool writeSelectionToggle(String id) => true;
  bool writeSelectionClear() => true;
  int writeSelectionSelectAll({bool onlySelectable = true}) => 0;
  int writeSelectionTranslate(Offset delta) => 0;
  int writeSelectionTransform(Transform2D delta) => 0;
  int writeDeleteSelection() => 0;
  List<String> writeClearSceneKeepBackground() => const <String>[];
  ClearSceneResult writeClearSceneKeepBackgroundResult() => ClearSceneResult();
  void writeCameraOffset(Offset offset) {}
  void writeGridEnable(bool enabled) {}
  void writeGridCellSize(double cellSize) {}
  void writeBackgroundColor(Color color) {}
  void writeDocumentReplace(SceneSnapshot snapshot) {}
  void writeSignalEnqueue({
    required String type,
    Iterable<String> nodeIds = const <String>[],
    Map<String, Object?>? payload,
  }) {}

  SceneWriterRuntime get runtime => SceneWriterRuntime();
}
''');
}

String _sceneWriterSelectionFixture({
  required String replaceSelectionBody,
  String toggleBody =
      'return writer.runtime.execute(ToggleSelectionOp(id)).value;',
  String clearBody =
      'return writer.runtime.execute(const ClearSelectionOp()).value;',
  String selectAllBody = '''
return writer.runtime
    .execute(SelectAllSelectionOp(onlySelectable: onlySelectable))
    .value;
''',
}) {
  return '''
import 'mutation_op.dart';
import 'scene_writer.dart';
import 'scene_writer_support.dart';
import 'scene_writer_types.dart';

List<NodeId>? sceneWriterWriteSelectionReplaceResult(
  SceneWriter writer,
  Iterable<NodeId> ids,
) {
  ${replaceSelectionBody.trim()}
}

bool sceneWriterWriteSelectionToggle(SceneWriter writer, NodeId id) {
  ${toggleBody.trim()}
}

bool sceneWriterWriteSelectionClear(SceneWriter writer) {
  ${clearBody.trim()}
}

({int selectedCount, bool changed}) sceneWriterWriteSelectionSelectAllResult(
  SceneWriter writer, {
  bool onlySelectable = true,
}) {
  ${selectAllBody.trim()}
}
''';
}

void _registerPreparedReplaceSceneBoundaryAttackTests() {
  final cases = <_PreparedReplaceSceneAttackCase>[
    (
      name:
          'rejects committed mutation access interface prepareScenePayload helper',
      filePath:
          'lib/src/controller/scene_controller_committed_mutation_access.dart',
      source: committedMutationAccessFixture(
        extraInterfaceMembers:
            '  Object prepareScenePayload(SceneSnapshot snapshot);\n',
      ),
    ),
    (
      name:
          'rejects committed mutation access interface stageSceneReplacement helper',
      filePath:
          'lib/src/controller/scene_controller_committed_mutation_access.dart',
      source: committedMutationAccessFixture(
        extraInterfaceMembers:
            '  Object stageSceneReplacement(SceneSnapshot snapshot);\n',
      ),
    ),
    (
      name:
          'rejects committed mutation access interface applySceneReplacement helper',
      filePath:
          'lib/src/controller/scene_controller_committed_mutation_access.dart',
      source: committedMutationAccessFixture(
        extraInterfaceMembers:
            '  void applySceneReplacement(Object payload);\n',
      ),
    ),
    (
      name:
          'rejects committed mutation access top-level sceneReplacementPayload getter',
      filePath:
          'lib/src/controller/scene_controller_committed_mutation_access.dart',
      source: committedMutationAccessFixture(
        extraTopLevel: 'Object get sceneReplacementPayload => Object();\n',
      ),
    ),
    (
      name:
          'rejects committed mutation access top-level preparedScenePayload field',
      filePath:
          'lib/src/controller/scene_controller_committed_mutation_access.dart',
      source: committedMutationAccessFixture(
        extraTopLevel: 'final Object preparedScenePayload = Object();\n',
      ),
    ),
    (
      name:
          'rejects committed mutation access top-level prepareScenePayload function',
      filePath:
          'lib/src/controller/scene_controller_committed_mutation_access.dart',
      source: committedMutationAccessFixture(
        extraTopLevel:
            'Object prepareScenePayload(SceneSnapshot snapshot) => snapshot;\n',
      ),
    ),
    (
      name:
          'rejects committed mutation access top-level PreparedScenePayloadBridge class',
      filePath:
          'lib/src/controller/scene_controller_committed_mutation_access.dart',
      source: committedMutationAccessFixture(
        extraTopLevel: 'final class PreparedScenePayloadBridge {}\n',
      ),
    ),
    (
      name: 'rejects committed mutation access top-level neutral bridge helper',
      filePath:
          'lib/src/controller/scene_controller_committed_mutation_access.dart',
      source: committedMutationAccessFixture(
        extraTopLevel: 'Object handoff(Object value) => value;\n',
      ),
    ),
    (
      name: 'rejects committed mutation access unnamed extension helper',
      filePath:
          'lib/src/controller/scene_controller_committed_mutation_access.dart',
      source: committedMutationAccessFixture(
        extraTopLevel: '''
extension on SceneStoreController {
  Object handoff(Object value) => value;
}
''',
      ),
    ),
    (
      name:
          'rejects committed mutation access exact PreparedSceneReplacement type leak',
      filePath:
          'lib/src/controller/scene_controller_committed_mutation_access.dart',
      source: committedMutationAccessFixture(
        extraTopLevel: 'class PreparedSceneReplacement {}\n',
      ),
    ),
    (
      name:
          'rejects committed mutation access private PreparedSceneReplacement type leak',
      filePath:
          'lib/src/controller/scene_controller_committed_mutation_access.dart',
      source: committedMutationAccessFixture(
        extraTopLevel: 'class _PreparedSceneReplacement {}\n',
      ),
    ),
    (
      name:
          'rejects committed mutation access adapter stageSceneReplacement helper',
      filePath:
          'lib/src/controller/scene_controller_committed_mutation_access.dart',
      source: committedMutationAccessFixture(
        extraAdapterMembers:
            '  Object stageSceneReplacement(SceneSnapshot snapshot) => snapshot;\n',
      ),
    ),
    (
      name:
          'rejects committed mutation access adapter applySceneReplacement helper',
      filePath:
          'lib/src/controller/scene_controller_committed_mutation_access.dart',
      source: committedMutationAccessFixture(
        extraAdapterMembers:
            '  void applySceneReplacement(Object payload) {}\n',
      ),
    ),
    (
      name:
          'rejects committed mutation access adapter private applySceneReplacement helper',
      filePath:
          'lib/src/controller/scene_controller_committed_mutation_access.dart',
      source: committedMutationAccessFixture(
        extraAdapterMembers:
            '  void _applySceneReplacement(Object payload) {}\n',
      ),
    ),
    (
      name: 'rejects committed mutation access SceneReplacementPayload typedef',
      filePath:
          'lib/src/controller/scene_controller_committed_mutation_access.dart',
      source: committedMutationAccessFixture(
        extraTopLevel: 'typedef SceneReplacementPayload = Object;\n',
      ),
    ),
    (
      name:
          'rejects committed mutation access preparedScenePayload getter on adapter',
      filePath:
          'lib/src/controller/scene_controller_committed_mutation_access.dart',
      source: committedMutationAccessFixture(
        extraAdapterMembers: '  Object get preparedScenePayload => Object();\n',
      ),
    ),
    (
      name: 'rejects committed mutation access adapter neutral bridge method',
      filePath:
          'lib/src/controller/scene_controller_committed_mutation_access.dart',
      source: committedMutationAccessFixture(
        extraAdapterMembers: '  Object handoff(Object value) => value;\n',
      ),
    ),
    (
      name: 'rejects committed mutation access interface neutral bridge method',
      filePath:
          'lib/src/controller/scene_controller_committed_mutation_access.dart',
      source: committedMutationAccessFixture(
        extraInterfaceMembers: '  Object handoff(Object value);\n',
      ),
    ),
    (
      name: 'rejects committed mutation access interface explicit constructor',
      filePath:
          'lib/src/controller/scene_controller_committed_mutation_access.dart',
      source: committedMutationAccessFixture(
        extraInterfaceMembers:
            '  SceneControllerCommittedMutationAccess.named();\n',
      ),
    ),
    (
      name:
          'rejects committed mutation access interface explicit unnamed constructor',
      filePath:
          'lib/src/controller/scene_controller_committed_mutation_access.dart',
      source: committedMutationAccessFixture(
        extraInterfaceMembers: '  SceneControllerCommittedMutationAccess();\n',
      ),
    ),
    (
      name:
          'rejects committed mutation access interface replaceScene signature drift',
      filePath:
          'lib/src/controller/scene_controller_committed_mutation_access.dart',
      source: committedMutationAccessFixture(
        interfaceReplaceSceneDeclaration: '''
  void replaceScene(
    SceneSnapshot snapshot, {
    required Object beforeApply,
  });
''',
      ),
    ),
    (
      name:
          'rejects committed mutation access adapter replaceScene return drift',
      filePath:
          'lib/src/controller/scene_controller_committed_mutation_access.dart',
      source: committedMutationAccessFixture(
        adapterReplaceSceneDeclaration: '''
  @override
  bool replaceScene(
    SceneSnapshot snapshot, {
    required VoidCallback beforeApply,
  }) => true;
''',
      ),
    ),
    (
      name: 'rejects scene store extension prepareScenePayload helper',
      filePath: 'lib/src/controller/scene_store_controller.dart',
      source: _sceneStoreControllerFixture(
        extraExtensionMembers:
            '  Object prepareScenePayload(SceneSnapshot snapshot) => snapshot;\n',
      ),
    ),
    (
      name: 'rejects scene store extension stageSceneReplacement helper',
      filePath: 'lib/src/controller/scene_store_controller.dart',
      source: _sceneStoreControllerFixture(
        extraExtensionMembers:
            '  Object stageSceneReplacement(SceneSnapshot snapshot) => snapshot;\n',
      ),
    ),
    (
      name: 'rejects scene store extension applySceneReplacement helper',
      filePath: 'lib/src/controller/scene_store_controller.dart',
      source: _sceneStoreControllerFixture(
        extraExtensionMembers:
            '  void applySceneReplacement(Object payload) {}\n',
      ),
    ),
    (
      name: 'rejects scene store extension sceneReplacementPayload getter',
      filePath: 'lib/src/controller/scene_store_controller.dart',
      source: _sceneStoreControllerFixture(
        extraExtensionMembers:
            '  Object get sceneReplacementPayload => Object();\n',
      ),
    ),
    (
      name: 'rejects scene store extension sceneReplacementPayload setter',
      filePath: 'lib/src/controller/scene_store_controller.dart',
      source: _sceneStoreControllerFixture(
        extraExtensionMembers:
            '  set sceneReplacementPayload(Object value) {}\n',
      ),
    ),
    (
      name:
          'rejects scene store extension exact prepareSceneReplacement helper',
      filePath: 'lib/src/controller/scene_store_controller.dart',
      source: _sceneStoreControllerFixture(
        extraExtensionMembers:
            '  Object prepareSceneReplacement(SceneSnapshot snapshot) => snapshot;\n',
      ),
    ),
    (
      name:
          'rejects scene store extension private prepareSceneReplacement helper',
      filePath: 'lib/src/controller/scene_store_controller.dart',
      source: _sceneStoreControllerFixture(
        extraExtensionMembers:
            '  Object _prepareSceneReplacement(SceneSnapshot snapshot) => snapshot;\n',
      ),
    ),
    (
      name:
          'rejects scene store extension reference to prepareSceneReplacement helper',
      filePath: 'lib/src/controller/scene_store_controller.dart',
      source: _sceneStoreControllerFixture(
        writeReplaceSceneDeclaration: '''
  void writeReplaceScene(SceneSnapshot snapshot) {
    prepareSceneReplacement(snapshot);
  }
''',
      ),
    ),
    (
      name:
          'rejects scene store extension reference to adoptPreparedSceneReplacement helper',
      filePath: 'lib/src/controller/scene_store_controller.dart',
      source: _sceneStoreControllerFixture(
        writeReplaceSceneDeclaration: '''
  void writeReplaceScene(SceneSnapshot snapshot) {
    adoptPreparedSceneReplacement(snapshot);
  }
''',
      ),
    ),
    (
      name: 'rejects scene store top-level PreparedScenePayloadBridge class',
      filePath: 'lib/src/controller/scene_store_controller.dart',
      source: _sceneStoreControllerFixture(
        extraTopLevel: 'final class PreparedScenePayloadBridge {}\n',
      ),
    ),
    (
      name: 'rejects scene store top-level neutral bridge class',
      filePath: 'lib/src/controller/scene_store_controller.dart',
      source: _sceneStoreControllerFixture(
        extraTopLevel: 'final class BridgeSurface {}\n',
      ),
    ),
    (
      name: 'rejects scene store SceneReplacementPayload typedef',
      filePath: 'lib/src/controller/scene_store_controller.dart',
      source: _sceneStoreControllerFixture(
        extraTopLevel: 'typedef SceneReplacementPayload = Object;\n',
      ),
    ),
    (
      name: 'rejects scene store top-level prepareScenePayload function',
      filePath: 'lib/src/controller/scene_store_controller.dart',
      source: _sceneStoreControllerFixture(
        extraTopLevel:
            'Object prepareScenePayload(SceneSnapshot snapshot) => snapshot;\n',
      ),
    ),
    (
      name: 'rejects scene store extension adoptScenePayload helper',
      filePath: 'lib/src/controller/scene_store_controller.dart',
      source: _sceneStoreControllerFixture(
        extraExtensionMembers:
            '  Object adoptScenePayload(Object payload) => payload;\n',
      ),
    ),
    (
      name: 'rejects scene store class neutral bridge method',
      filePath: 'lib/src/controller/scene_store_controller.dart',
      source: _sceneStoreControllerFixture(
        extraClassMembers: '\n  Object handoff(Object value) => value;\n',
      ),
    ),
    (
      name: 'rejects scene store setter on sealed snapshot getter surface',
      filePath: 'lib/src/controller/scene_store_controller.dart',
      source: _sceneStoreControllerFixture(
        extraClassMembers: '\n  set snapshot(SceneSnapshot value) {}\n',
      ),
    ),
    (
      name: 'rejects scene store named constructor on sealed boundary owner',
      filePath: 'lib/src/controller/scene_store_controller.dart',
      source: _sceneStoreControllerFixture(
        extraClassMembers: '\n  SceneStoreController.named();\n',
      ),
    ),
    (
      name: 'rejects scene store writeReplaceScene signature drift',
      filePath: 'lib/src/controller/scene_store_controller.dart',
      source: _sceneStoreControllerFixture(
        writeReplaceSceneDeclaration: '''
  bool writeReplaceScene(SceneSnapshot snapshot) => true;
''',
      ),
    ),
    (
      name:
          'rejects scene store class writeReplaceScene signature drift without dedicated extension',
      filePath: 'lib/src/controller/scene_store_controller.dart',
      source: _sceneStoreControllerFixture(
        includeCommittedReplacementExtension: false,
        extraClassMembers: '''

  bool writeReplaceScene(SceneSnapshot snapshot) => true;
''',
      ),
    ),
    (
      name:
          'rejects duplicate scene store writeReplaceScene entrypoints on class and extension',
      filePath: 'lib/src/controller/scene_store_controller.dart',
      source: _sceneStoreControllerFixture(
        extraClassMembers: '''

  void writeReplaceScene(SceneSnapshot snapshot) {
    writeWithSceneWriter<void>((writer) {
      writer.writeDocumentReplace(snapshot);
    });
  }
''',
      ),
    ),
    (
      name:
          'rejects scene store local private preparedScenePayload variable inside writeReplaceScene',
      filePath: 'lib/src/controller/scene_store_controller.dart',
      source: _sceneStoreControllerFixture(
        writeReplaceSceneDeclaration: '''
  void writeReplaceScene(SceneSnapshot snapshot) {
    final _preparedScenePayload = snapshot;
  }
''',
      ),
    ),
    (
      name:
          'rejects scene store snake_case prepared_scene_payload variable inside writeReplaceScene',
      filePath: 'lib/src/controller/scene_store_controller.dart',
      source: _sceneStoreControllerFixture(
        writeReplaceSceneDeclaration: '''
  void writeReplaceScene(SceneSnapshot snapshot) {
    final prepared_scene_payload = snapshot;
  }
''',
      ),
    ),
    (
      name: 'rejects scene writer exact writePreparedDocumentReplace helper',
      filePath: 'lib/src/controller/scene_writer.dart',
      source: _sceneWriterFixture(
        extraMembers:
            '  void writePreparedDocumentReplace(Object payload) {}\n',
      ),
    ),
    (
      name: 'rejects scene writer prepareScenePayload helper',
      filePath: 'lib/src/controller/scene_writer.dart',
      source: _sceneWriterFixture(
        extraMembers:
            '  Object prepareScenePayload(SceneSnapshot snapshot) => snapshot;\n',
      ),
    ),
    (
      name: 'rejects scene writer applySceneReplacement helper',
      filePath: 'lib/src/controller/scene_writer.dart',
      source: _sceneWriterFixture(
        extraMembers: '  void applySceneReplacement(Object payload) {}\n',
      ),
    ),
    (
      name: 'rejects scene writer stageSceneReplacement helper',
      filePath: 'lib/src/controller/scene_writer.dart',
      source: _sceneWriterFixture(
        extraMembers:
            '  Object stageSceneReplacement(SceneSnapshot snapshot) => snapshot;\n',
      ),
    ),
    (
      name: 'rejects scene writer sceneReplacementPayload getter',
      filePath: 'lib/src/controller/scene_writer.dart',
      source: _sceneWriterFixture(
        extraMembers: '  Object get sceneReplacementPayload => Object();\n',
      ),
    ),
    (
      name: 'rejects scene writer sceneReplacementPayload setter',
      filePath: 'lib/src/controller/scene_writer.dart',
      source: _sceneWriterFixture(
        extraMembers: '  set sceneReplacementPayload(Object value) {}\n',
      ),
    ),
    (
      name: 'rejects scene writer preparedScenePayload field',
      filePath: 'lib/src/controller/scene_writer.dart',
      source: _sceneWriterFixture(
        extraMembers: '  final Object preparedScenePayload = Object();\n',
      ),
    ),
    (
      name: 'rejects scene writer private preparedScenePayload field',
      filePath: 'lib/src/controller/scene_writer.dart',
      source: _sceneWriterFixture(
        extraMembers: '  final Object _preparedScenePayload = Object();\n',
      ),
    ),
    (
      name: 'rejects scene writer private applySceneReplacement helper',
      filePath: 'lib/src/controller/scene_writer.dart',
      source: _sceneWriterFixture(
        extraMembers: '  void _applySceneReplacement(Object payload) {}\n',
      ),
    ),
    (
      name: 'rejects scene writer snake_case prepared_scene_payload field',
      filePath: 'lib/src/controller/scene_writer.dart',
      source: _sceneWriterFixture(
        extraMembers: '  final Object prepared_scene_payload = Object();\n',
      ),
    ),
    (
      name: 'rejects scene writer forbidden parameter name reuse',
      filePath: 'lib/src/controller/scene_writer.dart',
      source: _sceneWriterFixture(
        extraMembers: '  void _handoff(Object preparedScenePayload) {}\n',
      ),
    ),
    (
      name: 'rejects scene writer neutral bridge method',
      filePath: 'lib/src/controller/scene_writer.dart',
      source: _sceneWriterFixture(
        extraMembers: '  Object handoff(Object value) => value;\n',
      ),
    ),
    (
      name: 'rejects scene writer setter on sealed snapshot getter surface',
      filePath: 'lib/src/controller/scene_writer.dart',
      source: _sceneWriterFixture(
        extraMembers: '  set snapshot(SceneSnapshot value) {}\n',
      ),
    ),
    (
      name: 'rejects scene writer unnamed extension helper',
      filePath: 'lib/src/controller/scene_writer.dart',
      source: _sceneWriterFixture(
        extraTopLevel: '''
extension on SceneWriter {
  Object handoff(Object value) => value;
}
''',
      ),
    ),
    (
      name: 'rejects scene writer named constructor on sealed boundary owner',
      filePath: 'lib/src/controller/scene_writer.dart',
      source: _sceneWriterFixture(extraMembers: '  SceneWriter.named();\n'),
    ),
    (
      name: 'rejects scene writer top-level PreparedScenePayloadBridge class',
      filePath: 'lib/src/controller/scene_writer.dart',
      source: _sceneWriterFixture(
        extraTopLevel: 'final class PreparedScenePayloadBridge {}\n',
      ),
    ),
    (
      name: 'rejects scene writer top-level prepareScenePayload function',
      filePath: 'lib/src/controller/scene_writer.dart',
      source: _sceneWriterFixture(
        extraTopLevel:
            'Object prepareScenePayload(SceneSnapshot snapshot) => snapshot;\n',
      ),
    ),
    (
      name: 'rejects scene writer SceneReplacementPayload typedef',
      filePath: 'lib/src/controller/scene_writer.dart',
      source: _sceneWriterFixture(
        extraTopLevel: 'typedef SceneReplacementPayload = Object;\n',
      ),
    ),
    (
      name: 'rejects scene writer writeDocumentReplace signature drift',
      filePath: 'lib/src/controller/scene_writer.dart',
      source: _sceneWriterFixture(
        writeDocumentReplaceDeclaration: '''
  void writeDocumentReplace(
    SceneSnapshot snapshot, {
    void Function()? beforeApply,
  }) {}
''',
      ),
    ),
  ];

  for (final attackCase in cases) {
    test(attackCase.name, () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        _writePreparedReplaceSceneBoundarySupportScaffold(sandbox);
        if (attackCase.filePath ==
            'lib/src/controller/scene_store_controller.dart') {
          _writeSceneStoreControllerPreparedReplaceSupportScaffold(sandbox);
        }
        writeSandboxFile(sandbox, attackCase.filePath, attackCase.source);

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(result.stderr.toString(), contains('controller API violation:'));
        expect(
          result.stderr.toString(),
          anyOf(
            contains('prepared replace-scene'),
            contains('must be routed through write*/txn* transaction API'),
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });
  }

  test(
    'allows SceneStoreController.writeReplaceScene on sealed class surface without dedicated extension',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        _writePreparedReplaceSceneBoundarySupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/controller/scene_store_controller.dart',
          _sceneStoreControllerFixture(
            includeCommittedReplacementExtension: false,
            extraClassMembers: '''

  void writeReplaceScene(SceneSnapshot snapshot) {
    writeWithSceneWriter<void>((writer) {
      writer.writeDocumentReplace(snapshot);
    });
  }
''',
          ),
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'allows prepared replace-scene tokens in comments inside boundary files',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        _writePreparedReplaceSceneBoundarySupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/controller/scene_writer.dart',
          _sceneWriterFixture(
            extraTopLevel:
                '// writePreparedDocumentReplace PreparedSceneReplacement\n',
          ),
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'allows prepared replace-scene tokens in string literals inside boundary files',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        _writePreparedReplaceSceneBoundarySupportScaffold(sandbox);
        _writeSceneStoreControllerPreparedReplaceSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/controller/scene_store_controller.dart',
          _sceneStoreControllerFixture(
            extraTopLevel:
                "const String _note = 'PreparedSceneReplacement prepareSceneReplacement writePreparedSceneReplacement';\n",
          ),
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );
}

void main() {
  group('tool/check_guardrails.dart', () {
    _registerPreparedReplaceSceneBoundaryAttackTests();
    // INV:INV-ENG-PREPARED-REPLACE-SCENE-BOUNDARY-HERMETICITY
    // INV:INV-ENG-CONTROLLER-NO-FULL-VIEW-RENDER-STATE
    test(
      'allows SceneStoreController to stay on SceneRenderState without full view render-state import',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          _writePreparedReplaceSceneBoundarySupportScaffold(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/src/controller/scene_store_controller.dart',
            _sceneStoreControllerFixture(
              classDeclaration:
                  'class SceneStoreController extends _ChangeNotifier '
                  'implements SceneRenderState {',
              extraClassMembers: '\n  SceneRenderState? _currentState;\n',
            ),
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, 0, reason: result.stderr.toString());
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
            'lib/src/contract/scene_view_render_state.dart',
            'abstract interface class SceneViewRenderState {}\n',
          );
          writeSandboxFile(
            sandbox,
            'lib/src/contract/view_state_alias.dart',
            '''
export 'scene_view_render_state.dart';
''',
          );
          writeSandboxFile(
            sandbox,
            'lib/src/controller/scene_store_controller.dart',
            '''
import '../contract/view_state_alias.dart';

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
          _writePreparedReplaceSceneBoundarySupportScaffold(sandbox);
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
          expect(result.exitCode, 0, reason: result.stderr.toString());
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'allows mutating-looking helper names outside forbidden controller boundaries',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          _writePreparedReplaceSceneBoundarySupportScaffold(sandbox);
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
          expect(result.exitCode, 0, reason: result.stderr.toString());
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'allows unrelated replaceScene spelling without forbidden sink',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeSandboxFile(sandbox, 'lib/src/controller/store.dart', '''
class Store {
  int controllerEpoch = 0;

  void replaceScene() {}
}
''');

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, 0, reason: result.stderr.toString());
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'accepts canonical selection writer routing through resolved mutation ops',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeMinimalControllerStore(sandbox);
          _writeSelectionWriterRoutingSupportScaffold(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/src/controller/scene_writer_selection.dart',
            _sceneWriterSelectionFixture(
              replaceSelectionBody:
                  'return writer.runtime.execute(ReplaceSelectionOp(ids)).value;',
            ),
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, 0, reason: result.stderr.toString());
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects direct selection writer mutation bypass outside canonical ops',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeMinimalControllerStore(sandbox);
          _writeSelectionWriterRoutingSupportScaffold(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/src/controller/scene_writer_selection.dart',
            _sceneWriterSelectionFixture(
              replaceSelectionBody: '''
final ctx = writer.runtime.ctx;
ctx.workingSelection
  ..clear()
  ..addAll(ids);
return ids.toList();
''',
            ),
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'controller API',
              detail:
                  'selection writer entrypoint '
                  '"sceneWriterWriteSelectionReplaceResult" must route through '
                  'canonical ReplaceSelectionOp execution',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects canonical selection helper routed through wrong op type',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeMinimalControllerStore(sandbox);
          _writeSelectionWriterRoutingSupportScaffold(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/src/controller/scene_writer_selection.dart',
            _sceneWriterSelectionFixture(
              replaceSelectionBody:
                  'return writer.runtime.execute(ToggleSelectionOp(\'id\')).value;',
            ),
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'controller API',
              detail:
                  'selection writer entrypoint '
                  '"sceneWriterWriteSelectionReplaceResult" must route through '
                  'canonical ReplaceSelectionOp execution',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects canonical selection route followed by direct sink mutation',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeMinimalControllerStore(sandbox);
          _writeSelectionWriterRoutingSupportScaffold(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/src/controller/scene_writer_selection.dart',
            _sceneWriterSelectionFixture(
              replaceSelectionBody: '''
final selectedIds =
    writer.runtime.execute(ReplaceSelectionOp(ids)).value;
writer.runtime.ctx.workingSelection.clear();
return selectedIds;
''',
            ),
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'controller API',
              detail:
                  'selection writer entrypoint '
                  '"sceneWriterWriteSelectionReplaceResult" must route through '
                  'canonical ReplaceSelectionOp execution',
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
          _writePreparedReplaceSceneBoundarySupportScaffold(sandbox);

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
          _writePreparedReplaceSceneBoundarySupportScaffold(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/src/controller/scene_store_controller.dart',
            _sceneStoreControllerFixture(
              extraTopLevel: 'Scene? _inspectUiScene() => null;\n',
              spatialAccessMembers: '''
  List<SceneHitTestSpatialCandidate> queryHitTestCandidates(Rect worldBounds) =>
      _inspectUiScene() == null
          ? const <SceneHitTestSpatialCandidate>[]
          : const <SceneHitTestSpatialCandidate>[];

  List<ScenePaintSpatialCandidate> queryPaintCandidates(
    Rect worldBounds, {
    ScenePaintSpatialQueryScope scope =
        ScenePaintSpatialQueryScope.contentLayersOnly,
  }) => const <ScenePaintSpatialCandidate>[];

  NodeSnapshot? resolveSpatialCandidateSnapshot(
    SceneSpatialCandidateReference candidate,
  ) => null;

  ({NodeSnapshot node, int layerIndex, int nodeIndex})? resolveSnapshotNodeById(
    NodeId nodeId,
  ) => null;

  Offset centerWorldForNodeSnapshots(Iterable<NodeSnapshot> snapshots) =>
      Offset.zero;
''',
            ),
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

typedef SceneSpatialCandidateLocation = ({int layerIndex, int nodeIndex});
typedef SceneSpatialCandidateReference = ({
  String nodeId,
  int layerIndex,
  int nodeIndex,
});

enum ScenePaintSpatialQueryScope {
  contentLayersOnly,
  backgroundAndContentLayers,
}

class SceneHitTestSpatialCandidate {
  const SceneHitTestSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.hitTestBoundsWorld,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect hitTestBoundsWorld;
}

class ScenePaintSpatialCandidate {
  const ScenePaintSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.paintBoundsWorld,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect paintBoundsWorld;
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
  List<SceneHitTestSpatialCandidate> queryHitTestCandidates(Rect worldBounds) =>
      const <SceneHitTestSpatialCandidate>[];

  List<ScenePaintSpatialCandidate> queryPaintCandidates(
    Rect worldBounds, {
    ScenePaintSpatialQueryScope scope =
        ScenePaintSpatialQueryScope.contentLayersOnly,
  }) => const <ScenePaintSpatialCandidate>[];

  LeakedNode? resolveSpatialCandidateSnapshot(
    SceneSpatialCandidateReference candidate,
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

typedef SceneSpatialCandidateLocation = ({int layerIndex, int nodeIndex});
typedef SceneSpatialCandidateReference = ({
  String nodeId,
  int layerIndex,
  int nodeIndex,
});

enum ScenePaintSpatialQueryScope {
  contentLayersOnly,
  backgroundAndContentLayers,
}

class SceneHitTestSpatialCandidate {
  const SceneHitTestSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.hitTestBoundsWorld,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect hitTestBoundsWorld;
}

class ScenePaintSpatialCandidate {
  const ScenePaintSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.paintBoundsWorld,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect paintBoundsWorld;
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

class SceneStoreController {
  final int controllerEpoch = 0;
}

extension SceneStoreControllerSpatialAccess on SceneStoreController {
  List<SceneHitTestSpatialCandidate> queryHitTestCandidates(Rect worldBounds) =>
      const <SceneHitTestSpatialCandidate>[];

  List<ScenePaintSpatialCandidate> queryPaintCandidates(
    Rect worldBounds, {
    ScenePaintSpatialQueryScope scope =
        ScenePaintSpatialQueryScope.contentLayersOnly,
  }) => const <ScenePaintSpatialCandidate>[];

  NodeSnapshot? resolveSpatialCandidateSnapshot(
    SceneSpatialCandidateReference candidate,
  ) => null;

  ({NodeSnapshot node, int layerIndex, int nodeIndex})?
  resolveSnapshotNodeById(NodeId nodeId) => null;

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

typedef SceneSpatialCandidateLocation = ({int layerIndex, int nodeIndex});
typedef SceneSpatialCandidateReference = ({
  String nodeId,
  int layerIndex,
  int nodeIndex,
});

enum ScenePaintSpatialQueryScope {
  contentLayersOnly,
  backgroundAndContentLayers,
}

class SceneHitTestSpatialCandidate {
  const SceneHitTestSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.hitTestBoundsWorld,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect hitTestBoundsWorld;
}

class ScenePaintSpatialCandidate {
  const ScenePaintSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.paintBoundsWorld,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect paintBoundsWorld;
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
  List<SceneHitTestSpatialCandidate> queryHitTestCandidates(Rect worldBounds) =>
      const <SceneHitTestSpatialCandidate>[];

  List<ScenePaintSpatialCandidate> queryPaintCandidates(
    Rect worldBounds, {
    ScenePaintSpatialQueryScope scope =
        ScenePaintSpatialQueryScope.contentLayersOnly,
  }) => const <ScenePaintSpatialCandidate>[];

  StrokeNode? resolveSpatialCandidateSnapshot(
    SceneSpatialCandidateReference candidate,
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

typedef SceneSpatialCandidateLocation = ({int layerIndex, int nodeIndex});
typedef SceneSpatialCandidateReference = ({
  String nodeId,
  int layerIndex,
  int nodeIndex,
});

enum ScenePaintSpatialQueryScope {
  contentLayersOnly,
  backgroundAndContentLayers,
}

class SceneHitTestSpatialCandidate {
  const SceneHitTestSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.hitTestBoundsWorld,
    required this.structuralRevision,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect hitTestBoundsWorld;
  final int structuralRevision;
}

class ScenePaintSpatialCandidate {
  const ScenePaintSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.paintBoundsWorld,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect paintBoundsWorld;
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
                  '"SceneHitTestSpatialCandidate.structuralRevision" must not extend '
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

typedef SceneSpatialCandidateLocation = ({int layerIndex, int nodeIndex});
typedef SceneSpatialCandidateReference = ({
  String nodeId,
  int layerIndex,
  int nodeIndex,
});

enum ScenePaintSpatialQueryScope {
  contentLayersOnly,
  backgroundAndContentLayers,
}

class SceneHitTestSpatialCandidate {
  const SceneHitTestSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.hitTestBoundsWorld,
    required this.leaked,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect hitTestBoundsWorld;
  final ({SceneNode node}) leaked;
}

class ScenePaintSpatialCandidate {
  const ScenePaintSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.paintBoundsWorld,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect paintBoundsWorld;
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
                  'committed spatial payload "SceneHitTestSpatialCandidate.leaked" '
                  'must not expose live runtime scene-graph types (SceneNode)',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects missing SceneSpatialCandidateLocation typedef owner',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          _writePreparedReplaceSceneBoundarySupportScaffold(sandbox);
          writeSandboxFile(sandbox, 'lib/src/core/scene_spatial_index.dart', '''
import 'dart:ui';

typedef SceneSpatialCandidateReference = ({
  String nodeId,
  int layerIndex,
  int nodeIndex,
});

enum ScenePaintSpatialQueryScope {
  contentLayersOnly,
  backgroundAndContentLayers,
}

class SceneHitTestSpatialCandidate {
  const SceneHitTestSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.hitTestBoundsWorld,
  });

  final String nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect hitTestBoundsWorld;
}

class ScenePaintSpatialCandidate {
  const ScenePaintSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.paintBoundsWorld,
  });

  final String nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect paintBoundsWorld;
}
''');

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'controller API',
              detail:
                  'committed spatial payload owner '
                  '"SceneSpatialCandidateLocation" is required in '
                  'scene_spatial_index.dart',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects missing SceneSpatialCandidateReference typedef owner',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          _writePreparedReplaceSceneBoundarySupportScaffold(sandbox);
          writeSandboxFile(sandbox, 'lib/src/core/scene_spatial_index.dart', '''
import 'dart:ui';

typedef SceneSpatialCandidateLocation = ({int layerIndex, int nodeIndex});

enum ScenePaintSpatialQueryScope {
  contentLayersOnly,
  backgroundAndContentLayers,
}

class SceneHitTestSpatialCandidate {
  const SceneHitTestSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.hitTestBoundsWorld,
  });

  final String nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect hitTestBoundsWorld;
}

class ScenePaintSpatialCandidate {
  const ScenePaintSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.paintBoundsWorld,
  });

  final String nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect paintBoundsWorld;
}
''');

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'controller API',
              detail:
                  'committed spatial payload owner '
                  '"SceneSpatialCandidateReference" is required in '
                  'scene_spatial_index.dart',
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

typedef SceneSpatialCandidateLocation = ({int layerIndex, int nodeIndex});
typedef SceneSpatialCandidateReference = ({
  String nodeId,
  int layerIndex,
  int nodeIndex,
});

enum ScenePaintSpatialQueryScope {
  contentLayersOnly,
  backgroundAndContentLayers,
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
                'committed spatial payload owner "SceneHitTestSpatialCandidate" '
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
  List<Object> queryHitTestCandidates(Object worldBounds) => const <Object>[];

  NodeSnapshot? resolveSpatialCandidateSnapshot(Object candidate) => null;

  ({NodeSnapshot node, int layerIndex, int nodeIndex})?
  resolveSnapshotNodeById(NodeId nodeId) => null;

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

    test(
      'rejects missing committed spatial payload file for class-owned helpers',
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
          writeSandboxFile(
            sandbox,
            'lib/src/controller/scene_store_controller.dart',
            '''
import '../contract/snapshot.dart';

class Offset {}
class Rect {}
enum ScenePaintSpatialQueryScope { contentLayersOnly }
typedef SceneSpatialCandidateReference = ({
  String nodeId,
  int layerIndex,
  int nodeIndex,
});

class SceneHitTestSpatialCandidate {}
class ScenePaintSpatialCandidate {}

class SceneStoreController {
  final int controllerEpoch = 0;

  List<SceneHitTestSpatialCandidate> queryHitTestCandidates(Rect worldBounds) =>
      const <SceneHitTestSpatialCandidate>[];

  List<ScenePaintSpatialCandidate> queryPaintCandidates(
    Rect worldBounds, {
    ScenePaintSpatialQueryScope scope =
        ScenePaintSpatialQueryScope.contentLayersOnly,
  }) => const <ScenePaintSpatialCandidate>[];

  NodeSnapshot? resolveSpatialCandidateSnapshot(
    SceneSpatialCandidateReference candidate,
  ) => null;

  ({NodeSnapshot node, int layerIndex, int nodeIndex})? resolveSnapshotNodeById(
    NodeId nodeId,
  ) => null;

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
      },
    );

    test('rejects missing committed read helper owner file', () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeSandboxFile(sandbox, 'lib/src/contract/snapshot.dart', '''
typedef NodeId = String;
''');
        writeSandboxFile(sandbox, 'lib/src/core/scene_spatial_index.dart', '''
import '../contract/snapshot.dart';

class Rect {}

typedef SceneSpatialCandidateLocation = ({int layerIndex, int nodeIndex});
typedef SceneSpatialCandidateReference = ({
  String nodeId,
  int layerIndex,
  int nodeIndex,
});

enum ScenePaintSpatialQueryScope {
  contentLayersOnly,
  backgroundAndContentLayers,
}

class SceneHitTestSpatialCandidate {
  const SceneHitTestSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.hitTestBoundsWorld,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect hitTestBoundsWorld;
}

class ScenePaintSpatialCandidate {
  const ScenePaintSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.paintBoundsWorld,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect paintBoundsWorld;
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

typedef SceneSpatialCandidateLocation = ({int layerIndex, int nodeIndex});
typedef SceneSpatialCandidateReference = ({
  String nodeId,
  int layerIndex,
  int nodeIndex,
});

enum ScenePaintSpatialQueryScope {
  contentLayersOnly,
  backgroundAndContentLayers,
}

class SceneHitTestSpatialCandidate {
  const SceneHitTestSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.hitTestBoundsWorld,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect hitTestBoundsWorld;
}

class ScenePaintSpatialCandidate {
  const ScenePaintSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.paintBoundsWorld,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect paintBoundsWorld;
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
      'rejects sealed SceneStoreControllerSpatialAccess declared on wrong owner type',
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

typedef SceneSpatialCandidateLocation = ({int layerIndex, int nodeIndex});
typedef SceneSpatialCandidateReference = ({
  String nodeId,
  int layerIndex,
  int nodeIndex,
});

enum ScenePaintSpatialQueryScope {
  contentLayersOnly,
  backgroundAndContentLayers,
}

class SceneHitTestSpatialCandidate {
  const SceneHitTestSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.hitTestBoundsWorld,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect hitTestBoundsWorld;
}

class ScenePaintSpatialCandidate {
  const ScenePaintSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.paintBoundsWorld,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect paintBoundsWorld;
}
''');
          writeSandboxFile(
            sandbox,
            'lib/src/controller/scene_store_controller.dart',
            '''
import '../contract/snapshot.dart';
import '../core/scene_spatial_index.dart';

class SceneStoreController {
  final int controllerEpoch = 0;
}

extension SceneStoreControllerSpatialAccess on Object {
  List<SceneHitTestSpatialCandidate> queryHitTestCandidates(Rect worldBounds) =>
      const <SceneHitTestSpatialCandidate>[];

  List<ScenePaintSpatialCandidate> queryPaintCandidates(
    Rect worldBounds, {
    ScenePaintSpatialQueryScope scope =
        ScenePaintSpatialQueryScope.contentLayersOnly,
  }) => const <ScenePaintSpatialCandidate>[];

  NodeSnapshot? resolveSpatialCandidateSnapshot(
    SceneSpatialCandidateReference candidate,
  ) => null;

  ({NodeSnapshot node, int layerIndex, int nodeIndex})?
  resolveSnapshotNodeById(NodeId nodeId) => null;

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
                  'sealed helper surface owner '
                  '"SceneStoreControllerSpatialAccess" must extend '
                  'SceneStoreController',
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

typedef SceneSpatialCandidateLocation = ({int layerIndex, int nodeIndex});
typedef SceneSpatialCandidateReference = ({
  String nodeId,
  int layerIndex,
  int nodeIndex,
});

enum ScenePaintSpatialQueryScope {
  contentLayersOnly,
  backgroundAndContentLayers,
}

class SceneHitTestSpatialCandidate {
  const SceneHitTestSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.hitTestBoundsWorld,
    required SceneNode leakedNode,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect hitTestBoundsWorld;
}

class ScenePaintSpatialCandidate {
  const ScenePaintSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.paintBoundsWorld,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect paintBoundsWorld;
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
                  '"SceneHitTestSpatialCandidate" must not expose live runtime '
                  'scene-graph types (SceneNode)',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects scene replacement helper left on sealed spatial access surface',
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

typedef SceneSpatialCandidateLocation = ({int layerIndex, int nodeIndex});
typedef SceneSpatialCandidateReference = ({
  String nodeId,
  int layerIndex,
  int nodeIndex,
});

class SceneHitTestSpatialCandidate {
  const SceneHitTestSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.hitTestBoundsWorld,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect hitTestBoundsWorld;
}

class ScenePaintSpatialCandidate {
  const ScenePaintSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.paintBoundsWorld,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect paintBoundsWorld;
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

class SceneStoreController {
  final int controllerEpoch = 0;
}

extension SceneStoreControllerSpatialAccess on SceneStoreController {
  List<SceneHitTestSpatialCandidate> queryHitTestCandidates(Rect worldBounds) =>
      const <SceneHitTestSpatialCandidate>[];

  List<ScenePaintSpatialCandidate> queryPaintCandidates(
    Rect worldBounds, {
    ScenePaintSpatialQueryScope scope =
        ScenePaintSpatialQueryScope.contentLayersOnly,
  }) => const <ScenePaintSpatialCandidate>[];

  NodeSnapshot? resolveSpatialCandidateSnapshot(
    SceneSpatialCandidateReference candidate,
  ) => null;

  ({NodeSnapshot node, int layerIndex, int nodeIndex})?
  resolveSnapshotNodeById(NodeId nodeId) => null;

  void writeReplaceScene(SceneSnapshot snapshot) {}

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
                  '"writeReplaceScene" must not extend the sealed helper '
                  'surface',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects committed read helper carrying extra snapshot override parameter',
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

typedef SceneSpatialCandidateLocation = ({int layerIndex, int nodeIndex});
typedef SceneSpatialCandidateReference = ({
  String nodeId,
  int layerIndex,
  int nodeIndex,
});

class SceneHitTestSpatialCandidate {
  const SceneHitTestSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.hitTestBoundsWorld,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect hitTestBoundsWorld;
}

class ScenePaintSpatialCandidate {
  const ScenePaintSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.paintBoundsWorld,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect paintBoundsWorld;
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

class SceneStoreController {
  final int controllerEpoch = 0;
}

extension SceneStoreControllerSpatialAccess on SceneStoreController {
  List<SceneHitTestSpatialCandidate> queryHitTestCandidates(Rect worldBounds) =>
      const <SceneHitTestSpatialCandidate>[];

  List<ScenePaintSpatialCandidate> queryPaintCandidates(
    Rect worldBounds, {
    ScenePaintSpatialQueryScope scope =
        ScenePaintSpatialQueryScope.contentLayersOnly,
  }) => const <ScenePaintSpatialCandidate>[];

  NodeSnapshot? resolveSpatialCandidateSnapshot(
    SceneSpatialCandidateReference candidate, {
    SceneSnapshot? snapshotOverride,
  }) => null;

  ({NodeSnapshot node, int layerIndex, int nodeIndex})?
  resolveSnapshotNodeById(NodeId nodeId) => null;

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
                  'committed read helper "resolveSpatialCandidateSnapshot" '
                  'must keep the exact sealed signature',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects queryPaintCandidates scope promoted to required named',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          _writePreparedReplaceSceneBoundarySupportScaffold(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/src/controller/scene_store_controller.dart',
            _sceneStoreControllerFixture(
              spatialAccessMembers: '''
  List<SceneHitTestSpatialCandidate> queryHitTestCandidates(Rect worldBounds) =>
      const <SceneHitTestSpatialCandidate>[];

  List<ScenePaintSpatialCandidate> queryPaintCandidates(
    Rect worldBounds, {
    required ScenePaintSpatialQueryScope scope,
  }) => const <ScenePaintSpatialCandidate>[];

  NodeSnapshot? resolveSpatialCandidateSnapshot(
    SceneSpatialCandidateReference candidate,
  ) => null;

  ({NodeSnapshot node, int layerIndex, int nodeIndex})? resolveSnapshotNodeById(
    NodeId nodeId,
  ) => null;

  Offset centerWorldForNodeSnapshots(Iterable<NodeSnapshot> snapshots) =>
      Offset.zero;
''',
            ),
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'controller API',
              detail:
                  'committed read helper "queryPaintCandidates" '
                  'must keep the exact sealed signature',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('rejects queryPaintCandidates scope default removal', () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        _writePreparedReplaceSceneBoundarySupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/controller/scene_store_controller.dart',
          _sceneStoreControllerFixture(
            spatialAccessMembers: '''
  List<SceneHitTestSpatialCandidate> queryHitTestCandidates(Rect worldBounds) =>
      const <SceneHitTestSpatialCandidate>[];

  List<ScenePaintSpatialCandidate> queryPaintCandidates(
    Rect worldBounds, {
    ScenePaintSpatialQueryScope scope,
  }) => const <ScenePaintSpatialCandidate>[];

  NodeSnapshot? resolveSpatialCandidateSnapshot(
    SceneSpatialCandidateReference candidate,
  ) => null;

  ({NodeSnapshot node, int layerIndex, int nodeIndex})? resolveSnapshotNodeById(
    NodeId nodeId,
  ) => null;

  Offset centerWorldForNodeSnapshots(Iterable<NodeSnapshot> snapshots) =>
      Offset.zero;
''',
          ),
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'controller API',
            detail:
                'committed read helper "queryPaintCandidates" '
                'must keep the exact sealed signature',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects queryPaintCandidates scope default change', () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        _writePreparedReplaceSceneBoundarySupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/controller/scene_store_controller.dart',
          _sceneStoreControllerFixture(
            spatialAccessMembers: '''
  List<SceneHitTestSpatialCandidate> queryHitTestCandidates(Rect worldBounds) =>
      const <SceneHitTestSpatialCandidate>[];

  List<ScenePaintSpatialCandidate> queryPaintCandidates(
    Rect worldBounds, {
    ScenePaintSpatialQueryScope scope =
        ScenePaintSpatialQueryScope.backgroundAndContentLayers,
  }) => const <ScenePaintSpatialCandidate>[];

  NodeSnapshot? resolveSpatialCandidateSnapshot(
    SceneSpatialCandidateReference candidate,
  ) => null;

  ({NodeSnapshot node, int layerIndex, int nodeIndex})? resolveSnapshotNodeById(
    NodeId nodeId,
  ) => null;

  Offset centerWorldForNodeSnapshots(Iterable<NodeSnapshot> snapshots) =>
      Offset.zero;
''',
          ),
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'controller API',
            detail:
                'committed read helper "queryPaintCandidates" '
                'must keep the exact sealed signature',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

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

typedef SceneSpatialCandidateLocation = ({int layerIndex, int nodeIndex});
typedef SceneSpatialCandidateReference = ({
  String nodeId,
  int layerIndex,
  int nodeIndex,
});

class SceneHitTestSpatialCandidate {
  const SceneHitTestSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.hitTestBoundsWorld,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect hitTestBoundsWorld;
}

class ScenePaintSpatialCandidate {
  const ScenePaintSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.paintBoundsWorld,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect paintBoundsWorld;
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
  List<SceneHitTestSpatialCandidate> queryHitTestCandidates(Rect worldBounds) =>
      const <SceneHitTestSpatialCandidate>[];

  List<ScenePaintSpatialCandidate> queryPaintCandidates(
    Rect worldBounds, {
    ScenePaintSpatialQueryScope scope =
        ScenePaintSpatialQueryScope.contentLayersOnly,
  }) => const <ScenePaintSpatialCandidate>[];

  LeakedNode? resolveSpatialCandidateSnapshot(
    SceneSpatialCandidateReference candidate,
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

typedef SceneSpatialCandidateLocation = ({int layerIndex, int nodeIndex});
typedef SceneSpatialCandidateReference = ({
  String nodeId,
  int layerIndex,
  int nodeIndex,
});

class SceneHitTestSpatialCandidate {
  const SceneHitTestSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.hitTestBoundsWorld,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect hitTestBoundsWorld;
}

class ScenePaintSpatialCandidate {
  const ScenePaintSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.paintBoundsWorld,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect paintBoundsWorld;
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
  List<SceneHitTestSpatialCandidate> queryHitTestCandidates<T extends SceneNode>(
    Rect worldBounds,
  ) => const <SceneHitTestSpatialCandidate>[];
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
                  'committed read helper "queryHitTestCandidates" must not '
                  'expose live runtime scene-graph types (SceneNode)',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects prepared replace-scene payload surface on sealed scene-store boundary',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          _writePreparedReplaceSceneBoundarySupportScaffold(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/src/controller/scene_store_controller.dart',
            _sceneStoreControllerFixture(
              extraTopLevel: 'class PreparedSceneReplacement {}\n',
              extraExtensionMembers: '''
  PreparedSceneReplacement prepareSceneReplacement(SceneSnapshot snapshot) =>
      PreparedSceneReplacement();
''',
            ),
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(result.stderr.toString(), contains('prepared replace-scene'));
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );
  });
}
