import 'dart:io';

import 'package:test/test.dart';

import '../../tool/guardrails/src/public_api_registry.dart';
import '../../tool/guardrails/src/repository_paths.dart';

void main() {
  _testDiagnosticsSurface();
  _testRetiredPublicExports();
  _testInlineTextEditingSurface();
  _testDiagnosticsMembershipValidation();
  _testRetiredPublicExportsRequired();
  _testRetiredPublicExportsTypeValidation();
  _testRetiredPublicExportsDuplicates();
  _testRetiredPublicExportsOverlap();
}

void _testDiagnosticsSurface() {
  const diagnosticsSurface = {
    'CanvasDiagnosticPolicy',
    'CanvasDiagnosticsDisabled',
    'CanvasDiagnosticsSummary',
    'CanvasDiagnosticsVerbose',
    'CanvasDataException',
    'CanvasDataErrorCode',
  };

  test('real registry exposes diagnostics public surface membership', () {
    final registry = readPublicApiRegistryFromYaml(
      File(
        '$repositoryRoot/docs/_registry/public_api_v1.yaml',
      ).readAsStringSync(),
    );

    expect(registry.diagnosticsPublicSurface, diagnosticsSurface);
    expect(
      registry.publicExports.containsAll(registry.diagnosticsPublicSurface),
      isTrue,
    );
  });
}

void _testRetiredPublicExports() {
  test('real registry owns the retired public export deny-list', () {
    final registry = readPublicApiRegistryFromYaml(
      File(
        '$repositoryRoot/docs/_registry/public_api_v1.yaml',
      ).readAsStringSync(),
    );

    expect(registry.retiredPublicExports, _retiredPublicExports);
    expect(
      registry.retiredPublicExports.intersection(registry.publicExports),
      isEmpty,
    );
  });
}

void _testInlineTextEditingSurface() {
  test('inline text editing public surface has exactly the feature names', () {
    final publicExports = readPublicApiRegistry();
    final featureNames = {
      for (final name in publicExports)
        if (_isInlineTextEditingFeatureName(name)) name,
    };
    const inlineTextEditingNames = {
      'CanvasTextEditSession',
      'CanvasTextEditGeometry',
      'CanvasTextEditStyle',
      'CanvasTextEditingPort',
      'CanvasTextEditingOverlay',
    };

    expect(featureNames, inlineTextEditingNames);
    expect(publicExports, isNot(contains('CanvasTextEditCandidate')));
    expect(publicExports, isNot(contains('CanvasTextEditToken')));
  });
}

bool _isInlineTextEditingFeatureName(String name) {
  if (name == 'CanvasTextEditActionPayload') {
    return false;
  }

  return name.startsWith('CanvasTextEdit') ||
      name.startsWith('CanvasTextEditing');
}

void _testDiagnosticsMembershipValidation() {
  test('diagnostics public surface entries must be public exports', () {
    expect(
      () => readPublicApiRegistryFromYaml('''
public_exports:
  - CanvasDataException
retired_public_exports: []
diagnostics_public_surface:
  - CanvasDataException
  - MissingDiagnosticsEntry
'''),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('MissingDiagnosticsEntry'),
        ),
      ),
    );
  });
}

void _testRetiredPublicExportsRequired() {
  test('retired public exports are required', () {
    expect(
      () => readPublicApiRegistryFromYaml('''
public_exports:
  - CanvasRuntime
diagnostics_public_surface: []
'''),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('retired_public_exports must be a YAML list'),
        ),
      ),
    );
  });
}

void _testRetiredPublicExportsTypeValidation() {
  test('retired public exports must be string entries', () {
    expect(
      () => readPublicApiRegistryFromYaml('''
public_exports:
  - CanvasRuntime
retired_public_exports:
  - 42
diagnostics_public_surface: []
'''),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('retired_public_exports must contain only strings'),
        ),
      ),
    );
  });
}

void _testRetiredPublicExportsDuplicates() {
  test('retired public exports reject duplicate entries', () {
    expect(
      () => readPublicApiRegistryFromYaml('''
public_exports:
  - CanvasRuntime
retired_public_exports:
  - Transform2D
  - Transform2D
diagnostics_public_surface: []
'''),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('retired_public_exports contains duplicate entries'),
        ),
      ),
    );
  });
}

void _testRetiredPublicExportsOverlap() {
  test('retired public exports must not overlap public exports', () {
    expect(
      () => readPublicApiRegistryFromYaml('''
public_exports:
  - CanvasRuntime
retired_public_exports:
  - CanvasRuntime
diagnostics_public_surface: []
'''),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('CanvasRuntime'),
        ),
      ),
    );
  });
}

const _retiredPublicExports = {
  'ActionCommitted',
  'ActionCommittedDelta',
  'ActionType',
  'BackgroundLayerSnapshot',
  'BackgroundSnapshot',
  'CameraSnapshot',
  'CanvasMode',
  'CanvasPointerInput',
  'CanvasPointerPhase',
  'ClearSceneResult',
  'CommonNodePatch',
  'ContentLayerSnapshot',
  'DrawTool',
  'EditTextRequested',
  'FiniteOffsetValue',
  'FontFamilyValue',
  'GridSnapshot',
  'ImageIdValue',
  'ImageNodePatch',
  'ImageNodeSnapshot',
  'ImageNodeSpec',
  'InstanceRevisionValue',
  'LayerId',
  'LayerIdValue',
  'LineNodePatch',
  'LineNodeSnapshot',
  'LineNodeSpec',
  'MoveCommitDeltaRequest',
  'MoveCommitDeltaResolver',
  'NodeId',
  'NodeIdValue',
  'NodePatch',
  'NodeSnapshot',
  'NodeSpec',
  'NonNegativeFiniteDoubleValue',
  'OpacityValue',
  'PatchField',
  'PatchFieldState',
  'PathFillRule',
  'PathNodePatch',
  'PathNodeSnapshot',
  'PathNodeSpec',
  'PointerInputSettings',
  'PositiveFiniteDoubleValue',
  'RectNodePatch',
  'RectNodeSnapshot',
  'RectNodeSpec',
  'SceneBuilder',
  'SceneController',
  'SceneControllerInteraction',
  'SceneControllerScene',
  'SceneControllerSelection',
  'SceneDataErrorCode',
  'SceneDataException',
  'ScenePaletteSnapshot',
  'SceneRenderState',
  'SceneSnapshot',
  'SceneView',
  'SceneViewInteractive',
  'SceneWriteTxn',
  'StrokeNodePatch',
  'StrokeNodeSnapshot',
  'StrokeNodeSpec',
  'SvgPathDataValue',
  'TextContentValue',
  'TextNodePatch',
  'TextNodeSnapshot',
  'TextNodeSpec',
  'Transform2D',
  'decodeScene',
  'decodeSceneFromJson',
  'encodeScene',
  'encodeSceneToJson',
  'parseLayerId',
  'parseNodeId',
  'schemaVersionWrite',
  'schemaVersionsRead',
};
