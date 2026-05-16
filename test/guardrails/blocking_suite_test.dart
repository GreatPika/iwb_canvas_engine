import 'dart:io';

import 'package:test/test.dart';

import '../../tool/guardrails/src/guardrail_registry.dart';
import '../../tool/guardrails/src/public_api/public_api_boundary_check.dart';
import '../support/public_api_fixture.dart';

void main() {
  registerPublicApiGuardrailRegistryTests();
  registerPublicExportsCompleteTests();
  registerPublicTypesCompleteTests();
}

void registerPublicApiGuardrailRegistryTests() {
  group('public API guardrail registry', () {
    test('contains the Slice 1 public API guardrails', () {
      final ids = publicApiGuardrails()
          .map((guardrail) => guardrail.id)
          .toSet();

      expect(
        ids,
        containsAll(<String>{
          'api.no_legacy_public_types',
          'api.public_exports_complete',
          'api.public_types_complete',
        }),
      );
    });
  });
}

void registerPublicExportsCompleteTests() {
  group('api.public_exports_complete', () {
    _publicExportsPassForRoot();
    _publicExportsFailWhenRegistryNameIsMissing();
    _publicExportsFailForUnregisteredName();
    _publicExportsFailForBarrelOutsideApi();
    _publicExportsFailForEscapedApiPath();
    _publicExportsApplyHideCombinators();
    _publicExportsFailForConditionalBarrelOutsideApi();
    _publicExportsFailForNestedExportOutsideApi();
    _publicExportsIncludeApiOwnedTransitiveExports();
    _publicExportsFailForInvalidRegistryShape();
  });
}

void _publicExportsPassForRoot() {
  test('passes for the root registry and public barrel', () async {
    final result = await PublicApiBoundaryCheck(
      Directory.current,
    ).publicExportsComplete();

    expect(result.violations, isEmpty);
  });
}

void _publicExportsFailWhenRegistryNameIsMissing() {
  test('fails when a registry-owned public name is missing', () async {
    final root = await const PublicApiFixture(
      expectedNames: <String>['PresentName', 'MissingName'],
      apiSource: 'final class PresentName { const PresentName(); }',
    ).createTempRepo();

    final result = await PublicApiBoundaryCheck(root).publicExportsComplete();

    expect(result.violations, contains('Missing public export: MissingName'));
  });
}

void _publicExportsFailForUnregisteredName() {
  test('fails when an unregistered public name is exported', () async {
    final root = await const PublicApiFixture(
      expectedNames: <String>['PresentName'],
      apiSource: '''
final class PresentName { const PresentName(); }
final class ExtraName { const ExtraName(); }
''',
    ).createTempRepo();

    final result = await PublicApiBoundaryCheck(root).publicExportsComplete();

    expect(result.violations, contains('Unexpected public export: ExtraName'));
  });
}

void _publicExportsFailForBarrelOutsideApi() {
  test('fails when the public barrel exports outside lib/src/api', () async {
    final root = await const PublicApiFixture(
      expectedNames: <String>['PresentName'],
      barrel: "export 'src/runtime/runtime_root.dart';",
      apiSource: 'final class PresentName { const PresentName(); }',
    ).createTempRepo();

    final result = await PublicApiBoundaryCheck(root).publicExportsComplete();

    expect(
      result.violations,
      contains(
        'Public barrel export is outside lib/src/api/**: '
        'src/runtime/runtime_root.dart',
      ),
    );
  });
}

void _publicExportsFailForEscapedApiPath() {
  test(
    'fails when the public barrel escapes API through path segments',
    () async {
      final root = await const PublicApiFixture(
        expectedNames: <String>['PresentName'],
        barrel: "export 'src/api/../runtime/runtime_root.dart';",
        apiSource: 'final class PresentName { const PresentName(); }',
      ).createTempRepo();

      final result = await PublicApiBoundaryCheck(root).publicExportsComplete();

      expect(
        result.violations,
        contains(
          'Public barrel export is outside lib/src/api/**: '
          'src/api/../runtime/runtime_root.dart',
        ),
      );
    },
  );
}

void _publicExportsApplyHideCombinators() {
  test('applies root barrel hide combinators to exported names', () async {
    final root = await const PublicApiFixture(
      expectedNames: <String>['PresentName'],
      barrel: "export 'src/api/public.dart' hide PresentName;",
      apiSource: 'final class PresentName { const PresentName(); }',
    ).createTempRepo();

    final result = await PublicApiBoundaryCheck(root).publicExportsComplete();

    expect(result.violations, contains('Missing public export: PresentName'));
  });
}

void _publicExportsFailForConditionalBarrelOutsideApi() {
  test('fails when a conditional barrel export points outside API', () async {
    final root = await const PublicApiFixture(
      expectedNames: <String>['PresentName'],
      barrel: '''
export 'src/api/public.dart'
  if (dart.library.io) 'src/runtime/runtime_root.dart';
''',
      apiSource: 'final class PresentName { const PresentName(); }',
    ).createTempRepo();

    final result = await PublicApiBoundaryCheck(root).publicExportsComplete();

    expect(
      result.violations,
      contains(
        'Public barrel export is outside lib/src/api/**: '
        'src/runtime/runtime_root.dart',
      ),
    );
  });
}

void _publicExportsFailForNestedExportOutsideApi() {
  test('fails when an API file re-exports outside lib/src/api', () async {
    final root = await const PublicApiFixture(
      expectedNames: <String>['PresentName'],
      apiSource: '''
export '../runtime/runtime_root.dart';

final class PresentName { const PresentName(); }
''',
    ).createTempRepo();

    final result = await PublicApiBoundaryCheck(root).publicExportsComplete();

    expect(
      result.violations,
      contains(
        'Public API export is outside lib/src/api/**: '
        'lib/src/api/public.dart -> ../runtime/runtime_root.dart',
      ),
    );
  });
}

void _publicExportsIncludeApiOwnedTransitiveExports() {
  test(
    'includes API-owned transitive re-exports in public inventory',
    () async {
      final root = await const PublicApiFixture(
        expectedNames: <String>['PresentName'],
        apiSource: '''
export 'extra.dart';

final class PresentName { const PresentName(); }
''',
        extraApiFiles: <String, String>{
          'extra.dart': 'final class ExtraName { const ExtraName(); }',
        },
      ).createTempRepo();

      final result = await PublicApiBoundaryCheck(root).publicExportsComplete();

      expect(
        result.violations,
        contains('Unexpected public export: ExtraName'),
      );
    },
  );
}

void _publicExportsFailForInvalidRegistryShape() {
  test('fails when the public API registry has the wrong shape', () async {
    final root = await const PublicApiFixture(
      expectedNames: <String>[],
      registrySource: 'public_exports: PresentName',
      apiSource: 'final class PresentName { const PresentName(); }',
    ).createTempRepo();

    final result = await PublicApiBoundaryCheck(root).publicExportsComplete();

    expect(result.violations, contains('Invalid public API registry shape'));
  });
}

void registerPublicTypesCompleteTests() {
  group('api.public_types_complete', () {
    _publicTypesPassForRoot();
    _publicTypesFailForUndefinedType();
    _publicTypesFailForHiddenPublicType();
    _publicTypesFailForHiddenInheritedTypes();
    _publicTypesIgnorePrivateImplementationDetails();
    _publicTypesAllowApprovedExternalTypes();
    _publicTypesRejectDisallowedSdkTypes();
    _publicTypesRejectDirectSkyEngineImports();
  });
}

void _publicTypesPassForRoot() {
  test('passes for the root public skeleton signatures', () async {
    final result = await PublicApiBoundaryCheck(
      Directory.current,
    ).publicTypesComplete();

    expect(result.violations, isEmpty);
  });
}

void _publicTypesFailForUndefinedType() {
  test(
    'fails when an exported signature references an undefined type',
    () async {
      final root = await const PublicApiFixture(
        expectedNames: <String>['BrokenName'],
        apiSource: '''
final class BrokenName {
  const BrokenName(this.value);
  final MissingPublicType value;
}
''',
      ).createTempRepo();

      final result = await PublicApiBoundaryCheck(root).publicTypesComplete();

      expect(
        result.violations,
        contains(
          'Undefined public signature type InvalidType in '
          'lib/src/api/public.dart',
        ),
      );
    },
  );
}

void _publicTypesFailForHiddenPublicType() {
  test(
    'fails when an exported signature references a hidden public type',
    () async {
      final root = await const PublicApiFixture(
        expectedNames: <String>['UsesHiddenType'],
        barrel: "export 'src/api/public.dart' show UsesHiddenType;",
        apiSource: '''
final class HiddenType {
  const HiddenType();
}

final class UsesHiddenType {
  const UsesHiddenType(this.value);
  final HiddenType value;
}
''',
      ).createTempRepo();

      final result = await PublicApiBoundaryCheck(root).publicTypesComplete();

      expect(
        result.violations,
        contains(
          'Undefined public signature type HiddenType in '
          'lib/src/api/public.dart',
        ),
      );
    },
  );
}

void _publicTypesFailForHiddenInheritedTypes() {
  test('fails when an exported class inherits hidden public types', () async {
    final root = await const PublicApiFixture(
      expectedNames: <String>[
        'UsesHiddenBase',
        'UsesHiddenInterface',
        'UsesHiddenMixin',
      ],
      barrel: '''
export 'src/api/public.dart'
  show UsesHiddenBase, UsesHiddenInterface, UsesHiddenMixin;
''',
      apiSource: '''
final class HiddenBase {
  const HiddenBase();
}

abstract interface class HiddenInterface {}

mixin HiddenMixin {}

final class UsesHiddenBase extends HiddenBase {
  const UsesHiddenBase();
}

final class UsesHiddenInterface implements HiddenInterface {
  const UsesHiddenInterface();
}

final class UsesHiddenMixin with HiddenMixin {
  const UsesHiddenMixin();
}
''',
    ).createTempRepo();

    final result = await PublicApiBoundaryCheck(root).publicTypesComplete();

    expect(
      result.violations,
      contains(
        'Undefined public signature type HiddenBase in '
        'lib/src/api/public.dart',
      ),
    );
    expect(
      result.violations,
      contains(
        'Undefined public signature type HiddenInterface in '
        'lib/src/api/public.dart',
      ),
    );
    expect(
      result.violations,
      contains(
        'Undefined public signature type HiddenMixin in '
        'lib/src/api/public.dart',
      ),
    );
  });
}

void _publicTypesIgnorePrivateImplementationDetails() {
  test('ignores private implementation details and function bodies', () async {
    final root = await const PublicApiFixture(
      expectedNames: <String>['PublicApiName'],
      apiSource: '''
final class PublicApiName {
  const PublicApiName();

  void run() {
    final _PrivateBodyType value = _PrivateBodyType();
    value.toString();
  }

  _PrivateHelperType _privateHelper() => _PrivateHelperType();
}

final class _PrivateBodyType {
  const _PrivateBodyType();
}

final class _PrivateHelperType {
  const _PrivateHelperType();
}
''',
    ).createTempRepo();

    final result = await PublicApiBoundaryCheck(root).publicTypesComplete();

    expect(result.violations, isEmpty);
  });
}

void _publicTypesAllowApprovedExternalTypes() {
  test(
    'allows approved Flutter, dart:ui, and typed-data public types',
    () async {
      final root = await const PublicApiFixture(
        expectedNames: <String>['UsesApprovedExternalTypes'],
        apiSource: '''
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/widgets.dart';

final class UsesApprovedExternalTypes {
  const UsesApprovedExternalTypes(this.widget, this.color, this.bytes);

  final Widget widget;
  final Color color;
  final Uint8List bytes;
}
''',
      ).createTempRepo();

      final result = await PublicApiBoundaryCheck(root).publicTypesComplete();

      expect(result.violations, isEmpty);
    },
  );
}

void _publicTypesRejectDisallowedSdkTypes() {
  test('rejects SDK types outside approved public API libraries', () async {
    final root = await const PublicApiFixture(
      expectedNames: <String>['UsesDisallowedSdkType'],
      apiSource: '''
import 'dart:io';

final class UsesDisallowedSdkType {
  const UsesDisallowedSdkType(this.file);

  final File file;
}
''',
    ).createTempRepo();

    final result = await PublicApiBoundaryCheck(root).publicTypesComplete();

    expect(
      result.violations,
      contains(
        'Undefined public signature type File in lib/src/api/public.dart',
      ),
    );
  });
}

void _publicTypesRejectDirectSkyEngineImports() {
  test(
    'rejects direct sky_engine package imports outside approved owners',
    () async {
      final root = await const PublicApiFixture(
        expectedNames: <String>['UsesSkyEngineType'],
        apiSource: '''
import 'package:sky_engine/io/io.dart';

final class UsesSkyEngineType {
  const UsesSkyEngineType(this.file);

  final File file;
}
''',
      ).createTempRepo();

      final result = await PublicApiBoundaryCheck(root).publicTypesComplete();

      expect(
        result.violations,
        contains(
          'Undefined public signature type File in lib/src/api/public.dart',
        ),
      );
    },
  );
}
