import 'dart:io';

import 'guardrail_fixture_manifest.dart';
import 'public_entrypoint_contract.dart';
import 'tool_process_test_support.dart';

String renderSceneControllerFixture(
  GuardrailSceneControllerFixtureManifest manifest,
) {
  return '''
import '../contract/scene_view_runtime.dart';
import 'internal/scene_controller_graph.dart';
${manifest.extraImports}

${manifest.classDeclaration}
${manifest.graphMembers}
${manifest.extraMembers}

  Object get actions => sceneControllerGraphActions(_graph);
  Object get editTextRequests => sceneControllerGraphEditTextRequests(_graph);

${manifest.methods}

  void _ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {}
}

SceneViewRuntime sceneControllerViewRuntimeOf(SceneController controller) {
  return controller._graph.sceneViewRuntime;
}

${manifest.extraDeclarations}
''';
}

String sceneControllerFixture({
  required String methods,
  String classDeclaration = 'class SceneController {',
  String graphMembers = '''
  final Object _graph = createSceneControllerGraph(
    SceneControllerGraphRequest(),
  );
''',
  String extraImports = '',
  String extraMembers = '',
  String extraDeclarations = '',
}) {
  return renderSceneControllerFixture(
    sceneControllerFixtureManifest(
      methods: methods,
      classDeclaration: classDeclaration,
      graphMembers: graphMembers,
      extraImports: extraImports,
      extraMembers: extraMembers,
      extraDeclarations: extraDeclarations,
    ),
  );
}

void writeSceneControllerFixture(
  Directory sandbox, {
  required String methods,
  String classDeclaration = 'class SceneController {',
  String graphMembers = '''
  final Object _graph = createSceneControllerGraph(
    SceneControllerGraphRequest(),
  );
''',
  String extraImports = '',
  String extraMembers = '',
  String extraDeclarations = '',
}) {
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/scene_controller.dart',
    sceneControllerFixture(
      methods: methods,
      classDeclaration: classDeclaration,
      graphMembers: graphMembers,
      extraImports: extraImports,
      extraMembers: extraMembers,
      extraDeclarations: extraDeclarations,
    ),
  );
}

String renderCommittedMutationAccessFixture(
  GuardrailCommittedMutationAccessFixtureManifest manifest,
) {
  return '''
import 'dart:ui';

import '../contract/node_patch.dart';
import '../contract/node_spec.dart';
import '../contract/scene_write_txn.dart';
import '../contract/snapshot.dart';
import '../contract/transform2d.dart';
import 'scene_store_controller.dart';

typedef SceneControllerCommittedMutationWriteResult<T> = ({
  T value,
  bool didChangeRenderState,
});

${manifest.extraTopLevel}

abstract interface class SceneControllerCommittedMutationAccess {
  T write<T>(T Function(SceneWriteTxn writer) fn);

  SceneControllerCommittedMutationWriteResult<T> writeExact<T>(
    T Function(SceneWriteTxn writer) fn,
  );

  NodeId addNode(NodeSpec node, {LayerId? layerId, int? insertIndex});

  bool ensureLayer(LayerId layerId, {int? index});

  bool patchNode(NodePatch patch);

  bool removeNode(NodeId id);

  bool setBackgroundColor(Color value);

  bool setGridEnabled(bool value);

  bool setGridCellSize(double value);

  bool setCameraOffset(Offset value);

  ClearSceneResult clearSceneExactResult();

${manifest.interfaceReplaceSceneDeclaration.trimRight()}

  void requestRepaint();

  bool replaceSelection(Iterable<NodeId> nodeIds);

  bool toggleSelection(NodeId nodeId);

  bool clearSelection();

  ({int selectedCount, bool changed}) selectAll({bool onlySelectable = true});

  int deleteSelection();

  int transformSelection(Transform2D delta);

  NodeId commitDrawStroke({
    required List<Offset> points,
    required double thickness,
    required Color color,
    required double opacity,
  });

  NodeId commitDrawLineFromWorldSegment({
    required Offset start,
    required Offset end,
    required double thickness,
    required Color color,
    required double opacity,
  });

  int commitEraseNodes(Iterable<NodeId> ids);

  SceneSnapshot get snapshot;

  Set<NodeId> get selectedNodeIds;

  Offset centerWorldForNodeSnapshots(Iterable<NodeSnapshot> snapshots);

${manifest.extraInterfaceMembers}
}

final class SceneStoreControllerCommittedMutationAccess
    implements SceneControllerCommittedMutationAccess {
  SceneStoreControllerCommittedMutationAccess(this._storeController);

  final SceneStoreController _storeController;

  @override
  T write<T>(T Function(SceneWriteTxn writer) fn) => throw UnimplementedError();

  @override
  SceneControllerCommittedMutationWriteResult<T> writeExact<T>(
    T Function(SceneWriteTxn writer) fn,
  ) => throw UnimplementedError();

  @override
  NodeId addNode(NodeSpec node, {LayerId? layerId, int? insertIndex}) => 'id';

  @override
  bool ensureLayer(LayerId layerId, {int? index}) => true;

  @override
  bool patchNode(NodePatch patch) => true;

  @override
  bool removeNode(NodeId id) => true;

  @override
  bool setBackgroundColor(Color value) => true;

  @override
  bool setGridEnabled(bool value) => true;

  @override
  bool setGridCellSize(double value) => true;

  @override
  bool setCameraOffset(Offset value) => true;

  @override
  ClearSceneResult clearSceneExactResult() => ClearSceneResult();

${manifest.adapterReplaceSceneDeclaration.trimRight()}

  @override
  void requestRepaint() {}

  @override
  bool replaceSelection(Iterable<NodeId> nodeIds) => true;

  @override
  bool toggleSelection(NodeId nodeId) => true;

  @override
  bool clearSelection() => true;

  @override
  ({int selectedCount, bool changed}) selectAll({bool onlySelectable = true}) =>
      (selectedCount: 0, changed: false);

  @override
  int deleteSelection() => 0;

  @override
  int transformSelection(Transform2D delta) => 0;

  @override
  NodeId commitDrawStroke({
    required List<Offset> points,
    required double thickness,
    required Color color,
    required double opacity,
  }) => 'id';

  @override
  NodeId commitDrawLineFromWorldSegment({
    required Offset start,
    required Offset end,
    required double thickness,
    required Color color,
    required double opacity,
  }) => 'id';

  @override
  int commitEraseNodes(Iterable<NodeId> ids) => 0;

  @override
  SceneSnapshot get snapshot => SceneSnapshot();

  @override
  Set<NodeId> get selectedNodeIds => <NodeId>{};

  @override
  Offset centerWorldForNodeSnapshots(Iterable<NodeSnapshot> snapshots) =>
      Offset.zero;

${manifest.extraAdapterMembers}
}
''';
}

String committedMutationAccessFixture({
  String extraTopLevel = '',
  String extraInterfaceMembers = '',
  String extraAdapterMembers = '',
  String interfaceReplaceSceneDeclaration = '''
  void replaceScene(
    SceneSnapshot snapshot, {
    required VoidCallback beforeApply,
  });
''',
  String adapterReplaceSceneDeclaration = '''
  @override
  void replaceScene(
    SceneSnapshot snapshot, {
    required VoidCallback beforeApply,
  }) {}
''',
}) {
  return renderCommittedMutationAccessFixture(
    committedMutationAccessFixtureManifest(
      extraTopLevel: extraTopLevel,
      extraInterfaceMembers: extraInterfaceMembers,
      extraAdapterMembers: extraAdapterMembers,
      interfaceReplaceSceneDeclaration: interfaceReplaceSceneDeclaration,
      adapterReplaceSceneDeclaration: adapterReplaceSceneDeclaration,
    ),
  );
}

void writeCommittedMutationAccessFixture(
  Directory sandbox, {
  String extraTopLevel = '',
  String extraInterfaceMembers = '',
  String extraAdapterMembers = '',
  String interfaceReplaceSceneDeclaration = '''
  void replaceScene(
    SceneSnapshot snapshot, {
    required VoidCallback beforeApply,
  });
''',
  String adapterReplaceSceneDeclaration = '''
  @override
  void replaceScene(
    SceneSnapshot snapshot, {
    required VoidCallback beforeApply,
  }) {}
''',
}) {
  writeSandboxFile(
    sandbox,
    'lib/src/controller/scene_controller_committed_mutation_access.dart',
    committedMutationAccessFixture(
      extraTopLevel: extraTopLevel,
      extraInterfaceMembers: extraInterfaceMembers,
      extraAdapterMembers: extraAdapterMembers,
      interfaceReplaceSceneDeclaration: interfaceReplaceSceneDeclaration,
      adapterReplaceSceneDeclaration: adapterReplaceSceneDeclaration,
    ),
  );
}

void writeCanonicalPublicExportScaffold(Directory sandbox) {
  final manifest = publicExportScaffoldManifest();
  writeSandboxFile(
    sandbox,
    manifest.entrypointPath,
    canonicalPublicEntrypoint(),
  );
  for (final filePath in manifest.exportOwnerPaths) {
    writeSandboxFile(sandbox, filePath, '// stub\n');
  }
}
