import 'package:test/test.dart';

import '../../tool/guardrails/src/core_boundary_checks.dart';
import '../../tool/guardrails/src/guardrail_executor.dart';
import '../../tool/guardrails/src/guardrail_violation.dart';

void main() {
  _testProductionBoundaries();
  _testRunnerRejectsInjectedCoreBoundaryViolation();
  _testApiFacadeRuntimeRootImport();
  _testApiContractWrapperExports();
  _testFrameCannotUseResourceCatalogPort();
  _testResourcesCannotImportFlutterPackages();
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
