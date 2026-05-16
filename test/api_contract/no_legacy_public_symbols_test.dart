import 'dart:io';

import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:test/test.dart';

import '../../tool/guardrails/src/public_api/public_api_boundary_check.dart';

void main() {
  group('api.no_legacy_public_types', () {
    test('root package imports through the public barrel', () {
      const config = CanvasRuntimeConfig();

      expect(config, isA<CanvasRuntimeConfig>());
    });

    test('passes for the root public barrel', () async {
      final result = await PublicApiBoundaryCheck(
        Directory.current,
      ).noLegacyPublicTypes();

      expect(result.violations, isEmpty);
    });

    test('fails when a legacy public golden symbol is exported', () async {
      final root = await _createTempRepoWithLegacyExport();

      final result = await PublicApiBoundaryCheck(root).noLegacyPublicTypes();

      expect(
        result.violations,
        contains('Legacy public symbol exported: SceneController'),
      );
    });

    test('fails when the legacy public golden is missing', () async {
      final root = await _createTempRepoWithoutLegacyGolden();

      final result = await PublicApiBoundaryCheck(root).noLegacyPublicTypes();

      expect(
        result.violations,
        contains('Missing legacy public symbol golden'),
      );
    });
  });
}

Future<Directory> _createTempRepoWithLegacyExport() async {
  final root = await Directory.systemTemp.createTemp('iwb_no_legacy_api_');
  final golden = File(
    '${root.path}/legacy/iwb_canvas_engine/tool/goldens/'
    'public_api_symbols.txt',
  );
  final api = File('${root.path}/lib/src/api/public.dart');
  final barrel = File('${root.path}/lib/iwb_canvas_engine.dart');
  final pubspec = File('${root.path}/pubspec.yaml');

  golden.createSync(recursive: true);
  api.createSync(recursive: true);
  barrel.createSync(recursive: true);
  pubspec.createSync(recursive: true);

  golden.writeAsStringSync('SceneController\n');
  api.writeAsStringSync(
    'final class SceneController { const SceneController(); }',
  );
  barrel.writeAsStringSync("export 'src/api/public.dart';");
  pubspec.writeAsStringSync('name: iwb_canvas_engine\n');
  _copyPackageConfig(root);

  return root;
}

Future<Directory> _createTempRepoWithoutLegacyGolden() async {
  final root = await Directory.systemTemp.createTemp('iwb_no_legacy_api_');
  final api = File('${root.path}/lib/src/api/public.dart');
  final barrel = File('${root.path}/lib/iwb_canvas_engine.dart');
  final pubspec = File('${root.path}/pubspec.yaml');

  api.createSync(recursive: true);
  barrel.createSync(recursive: true);
  pubspec.createSync(recursive: true);

  api.writeAsStringSync('final class PresentName { const PresentName(); }');
  barrel.writeAsStringSync("export 'src/api/public.dart';");
  pubspec.writeAsStringSync('name: iwb_canvas_engine\n');
  _copyPackageConfig(root);

  return root;
}

void _copyPackageConfig(Directory root) {
  final source = File(
    '${Directory.current.path}/.dart_tool/package_config.json',
  );
  if (!source.existsSync()) {
    return;
  }

  final target = File('${root.path}/.dart_tool/package_config.json');
  target.createSync(recursive: true);
  target.writeAsStringSync(source.readAsStringSync());
}
