@Tags(['tool'])
library;

// INV:INV-ENG-PUBLIC-SIGNATURE-HERMETICITY
// INV:INV-ENG-PUBLIC-SURFACE-NO-MUTABLE-TYPES

import 'package:test/test.dart';

import '../support/guardrail_fixture_writer.dart';
import '../support/guardrails_sandbox_support.dart';
import '../support/public_entrypoint_contract.dart';
import '../support/tool_process_test_support.dart';

void main() {
  group('tool/check_guardrails.dart public signature hermeticity', () {
    test(
      'passes for exported signatures that stay within public or SDK types',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeCanonicalPublicExportScaffold(sandbox);
          writeSandboxFile(sandbox, 'lib/src/contract/snapshot.dart', '''
class SceneSnapshot {
  const SceneSnapshot();
}
''');
          writeSandboxFile(
            sandbox,
            'lib/src/interactive/scene_controller_scene.dart',
            '''
import '../contract/snapshot.dart';

abstract interface class SceneControllerScene {
  SceneSnapshot replace(SceneSnapshot snapshot);
  String get mode;
}

final class SceneControllerSceneOwner implements SceneControllerScene {
  final _ownerState = _SceneControllerSceneOwnerState();

  @override
  String get mode => 'move';

  @override
  SceneSnapshot replace(SceneSnapshot snapshot) => snapshot;

  void keepInternalState() {
    _ownerState.runtimeType;
  }
}

final class _SceneControllerSceneOwnerState {}
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
      'allows exported runtime owner types on interactive capability surfaces',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeMinimalControllerStore(sandbox);
          writeCanonicalPublicExportScaffold(sandbox);
          writeInteractiveArchitectureSupportScaffold(sandbox);

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, 0, reason: result.stderr.toString());
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects exported constructor parameter typed from internal path',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeCanonicalPublicExportScaffold(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/src/interactive/internal/internal_selection_runtime.dart',
            'class InternalSelectionRuntime {}\n',
          );
          writeSandboxFile(
            sandbox,
            'lib/src/interactive/scene_controller_selection.dart',
            '''
import 'internal/internal_selection_runtime.dart';

class SceneControllerSelection {
  const SceneControllerSelection(InternalSelectionRuntime runtime);
}
''',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            contains('public signature hermeticity violation'),
          );
          expect(
            result.stderr.toString(),
            contains('InternalSelectionRuntime'),
          );
          expect(
            result.stderr.toString(),
            contains(
              '/lib/src/interactive/internal/internal_selection_runtime.dart',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('rejects exported mutable core type in contract signature', () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeCanonicalPublicExportScaffold(sandbox);
        writeSandboxFile(sandbox, 'lib/src/contract/snapshot.dart', '''
abstract class Foo {
  Scene get scene;
}

class Scene {}
''');

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(result.stderr.toString(), contains('public contract violation'));
        expect(result.stderr.toString(), contains('Scene'));
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'rejects exported mutable runtime owner type outside interactive surfaces',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeMinimalControllerStore(sandbox);
          writeCanonicalPublicExportScaffold(sandbox);
          writeInteractiveArchitectureSupportScaffold(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/src/interactive/scene_controller.dart',
            '''
class SceneController {
  const SceneController();
}
''',
          );
          writeSandboxFile(sandbox, 'lib/src/contract/snapshot.dart', '''
import '../interactive/scene_controller.dart';

abstract class Foo {
  SceneController get controller;
}
''');

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            contains('public contract violation'),
          );
          expect(result.stderr.toString(), contains('SceneController'));
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects exported method signature typed with hidden helper',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeCanonicalPublicExportScaffold(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/src/interactive/scene_controller_selection.dart',
            '''
class SceneControllerSelection {
  SelectionHelper helper() => SelectionHelper();
}

class SelectionHelper {}
''',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            contains('public signature hermeticity violation'),
          );
          expect(result.stderr.toString(), contains('SelectionHelper'));
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects exported getter and setter typed with hidden helper',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeCanonicalPublicExportScaffold(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/src/interactive/scene_controller_scene.dart',
            '''
class SceneControllerScene {
  SelectionState get state => SelectionState();

  set state(SelectionState value) {}
}

class SelectionState {}
''',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            contains('public signature hermeticity violation'),
          );
          expect(result.stderr.toString(), contains('SelectionState'));
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects exported signature that uses hidden typedef helper',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeCanonicalPublicExportScaffold(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/src/interactive/scene_controller_scene.dart',
            '''
class SceneControllerScene {
  SelectionCallback get callback => () {};
}

typedef SelectionCallback = void Function();
''',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            contains('public signature hermeticity violation'),
          );
          expect(result.stderr.toString(), contains('SelectionCallback'));
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('rejects exported signature leaked from a part file', () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeCanonicalPublicExportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/iwb_canvas_engine.dart',
          canonicalPublicEntrypoint().replaceFirst(
            canonicalPublicExportDirectives.last,
            "export 'src/serialization/scene_codec.dart';",
          ),
        );
        writeSandboxFile(sandbox, 'lib/src/serialization/scene_codec.dart', '''
part 'codec_guards.dart';

class SceneCodec {
  const SceneCodec();
}
''');
        writeSandboxFile(sandbox, 'lib/src/serialization/codec_guards.dart', '''
part of 'scene_codec.dart';

class CodecPartApi {
  _HiddenCodecHelper helper() => _HiddenCodecHelper();
}

class _HiddenCodecHelper {}
''');

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains('public signature hermeticity violation'),
        );
        expect(
          result.stderr.toString(),
          contains('/lib/src/serialization/codec_guards.dart'),
        );
        expect(result.stderr.toString(), contains('_HiddenCodecHelper'));
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects exported static method typed with hidden helper', () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeCanonicalPublicExportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/model/internal/hidden_builder_state.dart',
          'class HiddenBuilderState {}\n',
        );
        writeSandboxFile(sandbox, 'lib/src/model/scene_builder_api.dart', '''
import 'internal/hidden_builder_state.dart';

class SceneBuilder {
  static HiddenBuilderState build() => HiddenBuilderState();
}
''');

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains('public signature hermeticity violation'),
        );
        expect(result.stderr.toString(), contains('HiddenBuilderState'));
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'rejects exported extension type representation typed with hidden helper',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeCanonicalPublicExportScaffold(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/src/interactive/scene_controller_scene.dart',
            '''
// @dart=3.10

extension type SceneControllerScene(SelectionState state) {}

class SelectionState {}
''',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            contains('public signature hermeticity violation'),
          );
          expect(result.stderr.toString(), contains('SelectionState'));
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects exported extension type members typed with hidden helper',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeCanonicalPublicExportScaffold(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/src/interactive/scene_controller_scene.dart',
            '''
// @dart=3.10

extension type SceneControllerScene(int raw) {
  SelectionState helper() => SelectionState();

  set state(SelectionState value) {}
}

class SelectionState {}
''',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            contains('public signature hermeticity violation'),
          );
          expect(result.stderr.toString(), contains('SelectionState'));
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );
  });
}
