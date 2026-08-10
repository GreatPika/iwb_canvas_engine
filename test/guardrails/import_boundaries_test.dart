import 'package:test/test.dart';

import '../../tool/guardrails/src/core_boundary_checks.dart';
import '../../tool/guardrails/src/guardrail_executor.dart';
import '../../tool/guardrails/src/guardrail_violation.dart';

void main() {
  _testRunnerRejectsInjectedCoreBoundaryViolation();
  _testApiFacadeRuntimeRootImport();
  _testApiBridgeAndPassiveSurfaceAllowances();
  _testSurfaceFacadeAllowances();
  _testSurfaceReservedRuntimeBoundaries();
  _testApiContractWrapperExports();
  _testVectorPreparationImportBoundary();
  _testVectorPreparationRuntimeBoundary();
  _testVectorPreparationDependencyRuntimeRejectsForbiddenImports();
  _testVectorPreparationDependencyRuntimeAllowsApprovedImports();
  _testRetiredFlutterBridgeOwnerCannotBeImported();
  _testFrameCannotUseResourceCatalogPort();
  _testFrameCannotImportApiFacades();
  _testOnlyAssetBindingServiceMayReceiveSurfaceResourceSession();
  _testResourcesCannotImportFlutterPackages();
  _testResourceSessionOwnerBoundaries();
  _testFrameOrSurfaceCannotOwnCanvasResourceResolverType();
  _testInteractionOwnerImportBoundary();
  _testPointerCleanupCoordinatorCallers();
}

void _testRunnerRejectsInjectedCoreBoundaryViolation() {
  test(
    'runner rejects interaction imports without writing fixtures into lib',
    () async {
      final violations = checkCoreBoundaryFile(
        path: 'lib/src/interaction/bad_import_boundary_fixture.dart',
        content: "import '../store/document_store_kernel.dart';\n",
      );
      expect(
        violations,
        contains(
          isA<GuardrailViolation>().having(
            (violation) => violation.guardrailId,
            'guardrailId',
            'core.import_boundaries',
          ),
        ),
      );

      final result = await runGuardrailsWithProofRunner(
        ['core.import_boundaries'],
        runDartTest: (_, _) async => 0,
        violationChecks: {'core.import_boundaries': () async => violations},
      );

      expect(result.exitCode, isNot(0));
      expect(result.ranGuardrailIds, ['core.import_boundaries']);
    },
  );
}

void _testApiFacadeRuntimeRootImport() {
  test('api facade may import only the runtime composition root', () {
    expect(
      checkCoreBoundaryFile(
        path: 'lib/src/api/canvas_runtime.dart',
        content: "import '../runtime/runtime_root.dart';\n",
      ),
      isEmpty,
    );
    expect(
      checkCoreBoundaryFile(
        path: 'lib/src/api/canvas_runtime.dart',
        content: "import '../runtime/runtime_config.dart';\n",
      ),
      contains(
        isA<GuardrailViolation>().having(
          (violation) => violation.guardrailId,
          'guardrailId',
          'core.import_boundaries',
        ),
      ),
    );
  });
}

void _testApiBridgeAndPassiveSurfaceAllowances() {
  test('api bridges and surface imports are narrowly allowlisted', () {
    expect(
      checkCoreBoundaryFile(
        path: 'lib/src/api/canvas_runtime_frame_bridge.dart',
        content: "import '../runtime/runtime_root.dart';\n",
      ),
      isEmpty,
    );
    expect(
      checkCoreBoundaryFile(
        path: 'lib/src/api/canvas_runtime_surface_bridge.dart',
        content: "import '../runtime/runtime_root.dart';\n",
      ),
      isEmpty,
    );
    expect(
      checkCoreBoundaryFile(
        path: 'lib/src/api/canvas_surface.dart',
        content: "import '../frame/main_frame_painter.dart';\n",
      ),
      contains(isA<GuardrailViolation>()),
    );
    expect(
      checkCoreBoundaryFile(
        path: 'lib/src/surface/bad_runtime_import.dart',
        content: "import '../runtime/runtime_root.dart';\n",
      ),
      contains(isA<GuardrailViolation>()),
    );
  });
}

void _testSurfaceFacadeAllowances() {
  test(
    'surface facade exports and runtime constructor types are allowlisted',
    () {
      expect(
        checkCoreBoundaryFile(
          path: 'lib/src/api/canvas_surface.dart',
          content: "export '../surface/text_editing_overlay.dart';\n",
        ),
        isEmpty,
      );
      expect(
        checkCoreBoundaryFile(
          path: 'lib/src/surface/canvas_surface_widget.dart',
          content: "import '../api/canvas_runtime.dart';\n",
        ),
        isEmpty,
      );
      expect(
        checkCoreBoundaryFile(
          path: 'lib/src/surface/text_editing_overlay.dart',
          content: "import '../api/canvas_runtime.dart';\n",
        ),
        isEmpty,
      );
    },
  );
}

void _testSurfaceReservedRuntimeBoundaries() {
  test('surface interactive-disabled cleanup is token-checked', () {
    expect(
      checkSurfaceInteractiveDisabledReservedBoundaryFile(
        path: 'lib/src/api/canvas_runtime_surface_bridge.dart',
        content: '''
void handleSurfaceInteractiveDisabled(Object token) {
  if (!_root.isActiveSurface(token)) {
    return;
  }
  _root.handleSurfaceInteractiveDisabled();
}
''',
      ),
      isEmpty,
    );
    expect(
      checkSurfaceInteractiveDisabledReservedBoundaryFile(
        path: 'lib/src/api/canvas_runtime_surface_bridge.dart',
        content: '''
void handleSurfaceInteractiveDisabled(Object token) {
  _root.handleSurfaceInteractiveDisabled();
}
''',
      ),
      contains(
        isA<GuardrailViolation>().having(
          (violation) => violation.guardrailId,
          'guardrailId',
          'surface.interactive_false_pending_line_preserved',
        ),
      ),
    );
  });
}

void _testApiContractWrapperExports() {
  test('api facade may export public contracts but not internal contracts', () {
    expect(
      checkCoreBoundaryFile(
        path: 'lib/src/api/canvas_ids.dart',
        content: "export '../contracts/public/canvas_ids.dart';\n",
      ),
      isEmpty,
    );
    expect(
      checkCoreBoundaryFile(
        path: 'lib/src/api/bad_internal_contract_import.dart',
        content: "import '../contracts/internal/owner_port.dart';\n",
      ),
      contains(
        isA<GuardrailViolation>().having(
          (violation) => violation.guardrailId,
          'guardrailId',
          'core.import_boundaries',
        ),
      ),
    );
    expect(
      checkCoreBoundaryFile(
        path: 'lib/src/api/bad_internal_contract_export.dart',
        content: "export '../contracts/internal/owner_port.dart';\n",
      ),
      contains(
        isA<GuardrailViolation>().having(
          (violation) => violation.guardrailId,
          'guardrailId',
          'core.import_boundaries',
        ),
      ),
    );
  });
}

// Importer location, uniqueness, and package restrictions form one closure
// rule; splitting them would hide the root relationship under test.
// ignore: source-lines-of-code
void _testVectorPreparationImportBoundary() {
  test(
    'one API-owned vector graphics importer roots the preparation closure',
    () {
      expect(
        checkCoreBoundaryFile(
          path: 'lib/src/api/relocated_vector_preparation.dart',
          content:
              "import 'package:vector_graphics/vector_graphics.dart' as vg;\n",
        ),
        isEmpty,
      );

      for (final fixture in {
        'lib/src/runtime/vector_preparation_helper.dart':
            "import 'package:vector_graphics/vector_graphics.dart';\n",
        'lib/src/contracts/public/vector_preparation_codec_helper.dart':
            "import 'package:vector_graphics_codec/vector_graphics_codec.dart';\n",
      }.entries) {
        expect(
          checkCoreBoundaryFile(path: fixture.key, content: fixture.value),
          contains(
            isA<GuardrailViolation>().having(
              (violation) => violation.guardrailId,
              'guardrailId',
              'core.import_boundaries',
            ),
          ),
          reason: fixture.key,
        );
      }

      expect(
        checkVectorPreparationDependencyBoundaryFiles({
          'lib/src/api/relocated_vector_preparation.dart':
              "import 'package:vector_graphics/vector_graphics.dart';\n",
          'lib/src/api/second_vector_preparation.dart':
              "import 'package:vector_graphics/vector_graphics.dart';\n",
        }),
        contains(isA<GuardrailViolation>()),
      );

      for (final fixture in {
        'lib/src/runtime/unrelated_io_helper.dart': "import 'dart:io';\n",
        'lib/src/runtime/unrelated_network_helper.dart':
            "import 'package:http/http.dart';\n",
      }.entries) {
        expect(
          checkCoreBoundaryFile(path: fixture.key, content: fixture.value),
          isEmpty,
          reason: fixture.key,
        );
      }
    },
  );
}

// The routes share one caller-bytes-only assertion; splitting the list would
// obscure that every asset-loading capability must produce the same violation.
// ignore: source-lines-of-code
void _testVectorPreparationRuntimeBoundary() {
  test(
    'vector preparation adapter cannot load assets or intercept Flutter errors',
    () {
      for (final content in [
        '''
import 'package:flutter/services.dart';

Future<ByteData> loadVectorBytes() => rootBundle.load('vector.vec');
''',
        '''
import 'package:flutter/foundation.dart';

void installVectorErrorHandler() {
  FlutterError.onError = (details) {};
}
''',
        '''
import 'package:flutter/services.dart';

Future<ByteData> loadPlatformVectorBytes(PlatformAssetBundle assets) =>
    assets.load('vector.vec');
''',
        '''
import 'package:flutter/services.dart';

Future<ByteData> loadNetworkVectorBytes(NetworkAssetBundle assets) =>
    assets.load('vector.vec');
''',
        '''
import 'package:flutter/widgets.dart';

Future<String> loadDefaultVectorString(BuildContext context) =>
    DefaultAssetBundle.of(context).loadString('vector.vec');
''',
        '''
import 'package:flutter/widgets.dart';

Future<ByteData> loadDefaultVectorBuffer(BuildContext context) =>
    DefaultAssetBundle.of(context).loadBuffer('vector.vec');
''',
        '''
import 'package:flutter/widgets.dart';

Future<Object> loadDefaultVectorData(BuildContext context) =>
    DefaultAssetBundle.of(context).loadStructuredData(
      'vector.vec',
      (value) async => value,
    );
''',
        '''
import 'dart:ui' as ui;

Future<ui.ImmutableBuffer> loadVectorAsset() =>
    ui.ImmutableBuffer.fromAsset('vector.vec');
''',
        '''
import 'dart:ui' as ui;

Future<ui.ImmutableBuffer> loadVectorFile() =>
    ui.ImmutableBuffer.fromFilePath('/tmp/vector.vec');
''',
        '''
import 'dart:ui' as ui;

Future<ui.ImmutableBuffer> loadVectorAssetTearOff() {
  final load = ui.ImmutableBuffer.fromAsset;
  return load('vector.vec');
}
''',
      ]) {
        expect(
          checkCoreBoundaryFile(
            path: 'lib/src/api/canvas_vector_preparation.dart',
            content: content,
          ),
          contains(
            isA<GuardrailViolation>().having(
              (violation) => violation.guardrailId,
              'guardrailId',
              'core.import_boundaries',
            ),
          ),
        );
      }
    },
  );
}

void _testVectorPreparationDependencyRuntimeRejectsForbiddenImports() {
  test(
    'vector preparation dependency closure rejects external capability helpers',
    () {
      for (final helper in _forbiddenVectorPreparationHelpers.entries) {
        expect(
          checkVectorPreparationDependencyBoundaryFiles({
            'lib/src/api/relocated_vector_preparation.dart':
                "import 'package:vector_graphics/vector_graphics.dart' "
                "as vg show BytesLoader, PictureInfo, vg;\n"
                "import '${helper.key}';\n",
            'lib/src/api/${helper.key}': helper.value,
          }),
          contains(
            isA<GuardrailViolation>()
                .having(
                  (violation) => violation.guardrailId,
                  'guardrailId',
                  'core.import_boundaries',
                )
                .having(
                  (violation) => violation.path,
                  'path',
                  'lib/src/api/${helper.key}',
                ),
          ),
          reason: helper.key,
        );
      }
      _expectPackageUriDotSegmentsStayInDependencyClosure();
    },
  );
}

void _expectPackageUriDotSegmentsStayInDependencyClosure() {
  expect(
    checkVectorPreparationDependencyBoundaryFiles({
      'lib/src/api/relocated_vector_preparation.dart':
          "import 'package:vector_graphics/vector_graphics.dart' "
          "as vg show BytesLoader, PictureInfo, vg;\n"
          "import 'package:iwb_canvas_engine/src/api/../api/"
          "vector_preparation_network_helper.dart';\n",
      'lib/src/api/vector_preparation_network_helper.dart':
          "import 'package:http/http.dart';\n",
    }),
    contains(
      isA<GuardrailViolation>()
          .having(
            (violation) => violation.guardrailId,
            'guardrailId',
            'core.import_boundaries',
          )
          .having(
            (violation) => violation.path,
            'path',
            'lib/src/api/vector_preparation_network_helper.dart',
          ),
    ),
  );
}

void _testVectorPreparationDependencyRuntimeAllowsApprovedImports() {
  test(
    'vector preparation closure allows explicit capability-free imports',
    () {
      expect(
        checkVectorPreparationDependencyBoundaryFiles({
          'lib/src/api/relocated_vector_preparation.dart':
              "import 'package:vector_graphics/vector_graphics.dart' "
              "as vg show BytesLoader, PictureInfo, vg;\n"
              "import 'vector_preparation_sdk_helper.dart';\n",
          'lib/src/api/vector_preparation_sdk_helper.dart':
              "import 'dart:convert';\n"
              "import 'dart:math';\n"
              "import 'dart:typed_data';\n"
              "import 'dart:ui' show Offset, Picture, Size;\n"
              "import 'package:flutter/foundation.dart' show internal;\n"
              "import 'package:flutter/gestures.dart';\n"
              "import 'package:flutter/widgets.dart' show BuildContext;\n"
              "import 'package:characters/characters.dart';\n",
        }),
        isEmpty,
      );
    },
  );
}

const _forbiddenVectorPreparationHelpers = <String, String>{
  'vector_preparation_image_network_helper.dart': '''
import 'package:flutter/widgets.dart' show BuildContext, Image;

final vectorImage = Image.network('https://example.com/vector.png');
''',
  'vector_preparation_platform_message_helper.dart': '''
import 'dart:ui' show PlatformDispatcher;

void sendVectorPlatformMessage() {
  PlatformDispatcher.instance.sendPlatformMessage('vectors', null, (_) {});
}
''',
  'vector_preparation_reexport_helper.dart': '''
export 'package:flutter/widgets.dart' hide Image;
''',
  'vector_preparation_network_image_helper.dart': '''
import 'package:flutter/widgets.dart';

final vectorImage = const NetworkImage('https://example.com/vector.png');
''',
  'vector_preparation_asset_image_helper.dart': '''
import 'package:flutter/widgets.dart';

final vectorImage = const AssetImage('vector.png');
''',
  'vector_preparation_image_asset_helper.dart': '''
import 'package:flutter/widgets.dart';

final vectorImage = const Image.asset('vector.png');
''',
  'vector_preparation_method_channel_helper.dart': '''
import 'package:flutter/services.dart';

final vectorChannel = MethodChannel('vectors');
''',
  'vector_preparation_isolate_helper.dart': "import 'dart:isolate';\n",
  'vector_preparation_platform_dispatcher_error_helper.dart': '''
import 'dart:ui';

void installVectorErrorHandler() {
  PlatformDispatcher.instance.onError = (_, _) => false;
}
''',
  'vector_preparation_root_bundle_helper.dart': '''
import 'package:flutter/services.dart';

Future<ByteData> loadVectorBytes() => rootBundle.load('vector.vec');
''',
  'vector_preparation_asset_bundle_helper.dart': '''
import 'package:flutter/services.dart';

Future<ByteData> loadVectorBytes(AssetBundle assets) =>
    assets.load('vector.vec');
''',
  'vector_preparation_default_asset_bundle_helper.dart': '''
import 'package:flutter/widgets.dart';

Future<ByteData> loadVectorBytes(BuildContext context) =>
    DefaultAssetBundle.of(context).load('vector.vec');
''',
  'vector_preparation_platform_asset_bundle_helper.dart': '''
import 'package:flutter/services.dart';

Future<ByteData> loadVectorBytes(PlatformAssetBundle assets) =>
    assets.load('vector.vec');
''',
  'vector_preparation_network_asset_bundle_helper.dart': '''
import 'package:flutter/services.dart';

Future<ByteData> loadVectorBytes(NetworkAssetBundle assets) =>
    assets.load('vector.vec');
''',
  'vector_preparation_flutter_error_helper.dart': '''
import 'package:flutter/foundation.dart' as foundation;

void installVectorErrorHandler() {
  foundation.FlutterError.onError = (details) {};
}
''',
  'vector_preparation_immutable_buffer_tear_off_helper.dart': '''
import 'dart:ui' as ui;

Future<ui.ImmutableBuffer> loadVectorBytes() {
  final load = ui.ImmutableBuffer.fromAsset;
  return load('vector.vec');
}
''',
  'vector_preparation_io_helper.dart': "import 'dart:io';\n",
  'vector_preparation_http_helper.dart': "import 'package:http/http.dart';\n",
  'vector_preparation_other_network_helper.dart':
      "import 'package:dio/dio.dart';\n",
};

void _testRetiredFlutterBridgeOwnerCannotBeImported() {
  test('retired flutter bridge owner remains a forbidden dependency', () {
    for (final entry in _retiredFlutterBridgeForbiddenFixtures.entries) {
      expect(
        checkCoreBoundaryFile(path: entry.key, content: entry.value),
        contains(
          isA<GuardrailViolation>().having(
            (violation) => violation.guardrailId,
            'guardrailId',
            'core.import_boundaries',
          ),
        ),
        reason: entry.key,
      );
    }
  });
}

const _retiredFlutterBridgeForbiddenFixtures = {
  'lib/src/api/bad_flutter_bridge_import.dart':
      "import '../flutter_bridge/canvas_surface.dart';\n",
  'lib/src/surface/bad_flutter_bridge_import.dart':
      "import '../flutter_bridge/canvas_surface.dart';\n",
  'lib/src/store/bad_flutter_bridge_import.dart':
      "import '../flutter_bridge/canvas_surface.dart';\n",
  'lib/src/edit/bad_flutter_bridge_import.dart':
      "import '../flutter_bridge/canvas_surface.dart';\n",
  'lib/src/selection/bad_flutter_bridge_import.dart':
      "import '../flutter_bridge/canvas_surface.dart';\n",
  'lib/src/interaction/bad_flutter_bridge_import.dart':
      "import '../flutter_bridge/canvas_surface.dart';\n",
  'lib/src/interaction/pointer_tool_cleanup_coordinator.dart':
      "import '../flutter_bridge/canvas_surface.dart';\n",
  'lib/src/resources/bad_flutter_bridge_import.dart':
      "import '../flutter_bridge/canvas_surface.dart';\n",
  'lib/src/codec/bad_flutter_bridge_import.dart':
      "import '../flutter_bridge/canvas_surface.dart';\n",
  'lib/src/diagnostics/bad_flutter_bridge_import.dart':
      "import '../flutter_bridge/canvas_surface.dart';\n",
  'lib/src/frame/bad_flutter_bridge_import.dart':
      "import '../flutter_bridge/canvas_surface.dart';\n",
  'lib/src/geometry/bad_flutter_bridge_import.dart':
      "import '../flutter_bridge/canvas_surface.dart';\n",
};

void _testFrameCannotUseResourceCatalogPort() {
  test('frame code cannot import the resource catalog port', () {
    expect(
      checkCoreBoundaryFile(
        path: 'lib/src/frame/bad_resource_catalog_import.dart',
        content: "import '../contracts/internal/resource_catalog_port.dart';\n",
      ),
      contains(
        isA<GuardrailViolation>().having(
          (violation) => violation.guardrailId,
          'guardrailId',
          'core.import_boundaries',
        ),
      ),
    );
    expect(
      checkCoreBoundaryFile(
        path: 'lib/src/frame/good_frame_facts_import.dart',
        content: "import '../contracts/internal/frame_facts_port.dart';\n",
      ),
      isEmpty,
    );
  });
}

void _testFrameCannotImportApiFacades() {
  test('frame code cannot import public api facades as type libraries', () {
    expect(
      checkCoreBoundaryFile(
        path: 'lib/src/frame/bad_api_facade_import.dart',
        content: "import '../api/canvas_runtime.dart';\n",
      ),
      contains(
        isA<GuardrailViolation>().having(
          (violation) => violation.guardrailId,
          'guardrailId',
          'frame.committed_facts_via_frame_facts_port',
        ),
      ),
    );
  });
}

void _testInteractionOwnerImportBoundary() {
  test('interaction code cannot import concrete implementation owners', () {
    for (final import in [
      '../store/document_store_kernel.dart',
      '../selection/selection_kernel.dart',
      '../resources/resource_kernel.dart',
      '../frame/frame_engine.dart',
      '../runtime/runtime_root.dart',
      '../surface/canvas_surface_widget.dart',
      '../contracts/internal/command_facts_port.dart',
      'package:flutter/widgets.dart',
    ]) {
      expect(
        checkCoreBoundaryFile(
          path: 'lib/src/interaction/bad_owner_import.dart',
          content: "import '$import';\n",
        ),
        contains(
          isA<GuardrailViolation>().having(
            (violation) => violation.guardrailId,
            'guardrailId',
            'core.import_boundaries',
          ),
        ),
        reason: import,
      );
    }
  });
}

void _testPointerCleanupCoordinatorCallers() {
  test('only InteractionEngine may call the cleanup coordinator', () {
    expect(
      checkPointerCleanupCoordinatorCallerFile(
        path: 'lib/src/interaction/interaction_engine.dart',
        content: 'final cleanup = PointerToolCleanupCoordinator();',
      ),
      isEmpty,
    );
    expect(
      checkPointerCleanupCoordinatorCallerFile(
        path: 'lib/src/runtime/bad_cleanup_caller.dart',
        content: 'final cleanup = PointerToolCleanupCoordinator();',
      ),
      contains(
        isA<GuardrailViolation>().having(
          (violation) => violation.guardrailId,
          'guardrailId',
          'interaction.pointer_cleanup_coordinator_only',
        ),
      ),
    );
  });
}

void _testOnlyAssetBindingServiceMayReceiveSurfaceResourceSession() {
  test('only asset binding service may import surface resource session', () {
    expect(
      checkCoreBoundaryFile(
        path: 'lib/src/frame/paint_asset_binding_service.dart',
        content: "import '../resources/surface_resource_session.dart';\n",
      ),
      isEmpty,
    );
    expect(
      checkCoreBoundaryFile(
        path: 'lib/src/frame/bad_session_owner.dart',
        content: "import '../resources/surface_resource_session.dart';\n",
      ),
      contains(
        isA<GuardrailViolation>().having(
          (violation) => violation.guardrailId,
          'guardrailId',
          'frame.committed_facts_via_frame_facts_port',
        ),
      ),
    );
  });
}

void _testResourcesCannotImportFlutterPackages() {
  test('resource code cannot import Flutter packages', () {
    expect(
      checkCoreBoundaryFile(
        path: 'lib/src/resources/bad_flutter_widgets_import.dart',
        content: "import 'package:flutter/widgets.dart';\n",
      ),
      contains(
        isA<GuardrailViolation>().having(
          (violation) => violation.guardrailId,
          'guardrailId',
          'core.import_boundaries',
        ),
      ),
    );
    expect(
      checkCoreBoundaryFile(
        path: 'lib/src/resources/bad_flutter_services_import.dart',
        content: "import 'package:flutter/services.dart';\n",
      ),
      contains(
        isA<GuardrailViolation>().having(
          (violation) => violation.guardrailId,
          'guardrailId',
          'core.import_boundaries',
        ),
      ),
    );
  });
}

void _testResourceSessionOwnerBoundaries() {
  test(
    'resource session code cannot import runtime, store, frame, or IO owners',
    () {
      const forbiddenImports = {
        'lib/src/resources/bad_runtime_import.dart':
            "import '../runtime/runtime_root.dart';\n",
        'lib/src/resources/bad_store_import.dart':
            "import '../store/document_store_kernel.dart';\n",
        'lib/src/resources/bad_frame_import.dart':
            "import '../frame/frame_engine.dart';\n",
        'lib/src/resources/bad_surface_import.dart':
            "import '../surface/canvas_surface_widget.dart';\n",
        'lib/src/resources/bad_interaction_import.dart':
            "import '../interaction/interaction_read_port.dart';\n",
        'lib/src/resources/bad_diagnostics_import.dart':
            "import '../diagnostics/diagnostics_hub.dart';\n",
        'lib/src/resources/bad_io_import.dart': "import 'dart:io';\n",
        'lib/src/resources/bad_http_import.dart':
            "import 'package:http/http.dart';\n",
        'lib/src/resources/bad_dio_import.dart':
            "import 'package:dio/dio.dart';\n",
      };

      for (final entry in forbiddenImports.entries) {
        expect(
          checkCoreBoundaryFile(path: entry.key, content: entry.value),
          contains(isA<GuardrailViolation>()),
        );
      }
    },
  );
}

void _testFrameOrSurfaceCannotOwnCanvasResourceResolverType() {
  test(
    'frame and painter code cannot own CanvasResourceResolver typed references',
    () {
      const badResolverReference = '''
import '../contracts/public/canvas_resource.dart';

void bad(CanvasResourceResolver resolver) {}
''';
      for (final path in [
        'lib/src/frame/bad_resolver_call.dart',
        'lib/src/surface/main_painter.dart',
        'lib/src/resources/bad_resolver_owner.dart',
      ]) {
        expect(
          checkCoreBoundaryFile(path: path, content: badResolverReference),
          contains(
            isA<GuardrailViolation>().having(
              (violation) => violation.guardrailId,
              'guardrailId',
              'resources.resolver_boundary_owned_by_surface_session',
            ),
          ),
        );
      }
      expect(
        checkCoreBoundaryFile(
          path: 'lib/src/resources/surface_resource_session.dart',
          content: badResolverReference,
        ),
        isEmpty,
      );
      expect(
        checkCoreBoundaryFile(
          path: 'lib/src/surface/canvas_surface.dart',
          content: badResolverReference,
        ),
        isEmpty,
      );
    },
  );
}
