import 'public_entrypoint_contract.dart';

final class GuardrailSceneControllerFixtureManifest {
  const GuardrailSceneControllerFixtureManifest({
    required this.methods,
    this.classDeclaration = 'class SceneController {',
    this.graphMembers = '''
  final Object _graph = createSceneControllerGraph(
    SceneControllerGraphRequest(),
  );
''',
    this.extraImports = '',
    this.extraMembers = '',
    this.extraDeclarations = '',
  });

  final String methods;
  final String classDeclaration;
  final String graphMembers;
  final String extraImports;
  final String extraMembers;
  final String extraDeclarations;
}

GuardrailSceneControllerFixtureManifest sceneControllerFixtureManifest({
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
  return GuardrailSceneControllerFixtureManifest(
    methods: methods,
    classDeclaration: classDeclaration,
    graphMembers: graphMembers,
    extraImports: extraImports,
    extraMembers: extraMembers,
    extraDeclarations: extraDeclarations,
  );
}

final class GuardrailCommittedMutationAccessFixtureManifest {
  const GuardrailCommittedMutationAccessFixtureManifest({
    this.extraTopLevel = '',
    this.extraInterfaceMembers = '',
    this.extraAdapterMembers = '',
    this.interfaceReplaceSceneDeclaration = '''
  void replaceScene(
    SceneSnapshot snapshot, {
    required VoidCallback beforeApply,
  });
''',
    this.adapterReplaceSceneDeclaration = '''
  @override
  void replaceScene(
    SceneSnapshot snapshot, {
    required VoidCallback beforeApply,
  }) {}
''',
  });

  final String extraTopLevel;
  final String extraInterfaceMembers;
  final String extraAdapterMembers;
  final String interfaceReplaceSceneDeclaration;
  final String adapterReplaceSceneDeclaration;
}

GuardrailCommittedMutationAccessFixtureManifest
committedMutationAccessFixtureManifest({
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
  return GuardrailCommittedMutationAccessFixtureManifest(
    extraTopLevel: extraTopLevel,
    extraInterfaceMembers: extraInterfaceMembers,
    extraAdapterMembers: extraAdapterMembers,
    interfaceReplaceSceneDeclaration: interfaceReplaceSceneDeclaration,
    adapterReplaceSceneDeclaration: adapterReplaceSceneDeclaration,
  );
}

final class GuardrailPublicExportScaffoldManifest {
  const GuardrailPublicExportScaffoldManifest({
    this.entrypointPath = 'lib/iwb_canvas_engine.dart',
    this.exportOwnerPaths = canonicalPublicExportFiles,
  });

  final String entrypointPath;
  final List<String> exportOwnerPaths;
}

GuardrailPublicExportScaffoldManifest publicExportScaffoldManifest({
  String entrypointPath = 'lib/iwb_canvas_engine.dart',
  List<String> exportOwnerPaths = canonicalPublicExportFiles,
}) {
  return GuardrailPublicExportScaffoldManifest(
    entrypointPath: entrypointPath,
    exportOwnerPaths: exportOwnerPaths,
  );
}
