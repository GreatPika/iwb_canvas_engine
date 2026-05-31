import 'package:test/test.dart';

import '../../tool/guardrails/src/core_boundary_checks.dart';
import '../../tool/guardrails/src/guardrail_executor.dart';
import '../../tool/guardrails/src/guardrail_violation.dart';

void main() {
  _testProductionBoundaries();
  _testRunnerRejectsInjectedCoreBoundaryViolation();
  _testApiFacadeRuntimeRootImport();
  _testP9ApiBridgeAndSurfaceAllowances();
  _testApiContractWrapperExports();
  _testFrameCannotUseResourceCatalogPort();
  _testResourcesCannotImportFlutterPackages();
  _testResourceSessionOwnerBoundaries();
  _testFrameOrSurfaceCannotOwnCanvasResourceResolverType();
}

void _testProductionBoundaries() {
  test(
    'production source paths obey import and retired-shape boundaries',
    () async {
      expect(await checkCoreBoundaries(), isEmpty);
    },
  );
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

void _testP9ApiBridgeAndSurfaceAllowances() {
  test(
    'P9 api bridge and passive surface imports are narrowly allowlisted',
    () {
      expect(
        checkCoreBoundaryFile(
          path: 'lib/src/api/canvas_runtime_frame_bridge.dart',
          content: "import '../runtime/runtime_root.dart';\n",
        ),
        isEmpty,
      );
      expect(
        checkCoreBoundaryFile(
          path: 'lib/src/api/canvas_surface.dart',
          content: "import '../frame/main_frame_painter.dart';\n",
        ),
        isEmpty,
      );
      expect(
        checkCoreBoundaryFile(
          path: 'lib/src/api/canvas_surface.dart',
          content: "import '../frame/frame_engine.dart';\n",
        ),
        contains(isA<GuardrailViolation>()),
      );
    },
  );
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
            "import '../surface/canvas_surface.dart';\n",
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
