@Tags(['tool'])
library;

import 'dart:io';

import 'package:test/test.dart';

import '../support/guardrail_fixture_writer.dart';
import '../support/guardrails_sandbox_support.dart';
import '../support/tool_diagnostic_matchers.dart';
import '../support/tool_process_test_support.dart';

void main() {
  group('tool/check_guardrails.dart resolved entrypoint guards', () {
    _registerResolvedRootPreGuardRegressionTests();
    _registerResolvedCapabilityGuardRegressionTests();
    _registerResolvedEntrypointAcceptanceTests();
  });
}

String _canonicalControllerMethods({
  required String handlePointerSignature,
  required String handlePointerBody,
}) {
  return '''
  void handlePointer$handlePointerSignature {
$handlePointerBody
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''';
}

String _canonicalCapabilityControllerFixture() {
  return sceneControllerFixture(
    methods: _canonicalControllerMethods(
      handlePointerSignature: '(Object input)',
      handlePointerBody: "    _ensurePublicSideEffectAllowed('handlePointer');",
    ),
  );
}

void _writeNeutralCapabilityOwners(
  Directory sandbox, {
  String? exceptRelativePath,
}) {
  if (exceptRelativePath !=
      'lib/src/interactive/scene_controller_interaction.dart') {
    writeSandboxFile(
      sandbox,
      'lib/src/interactive/scene_controller_interaction.dart',
      'class SceneControllerInteractionOwner {}\n',
    );
  }
  if (exceptRelativePath !=
      'lib/src/interactive/scene_controller_selection.dart') {
    writeSandboxFile(
      sandbox,
      'lib/src/interactive/scene_controller_selection.dart',
      'class SceneControllerSelectionOwner {}\n',
    );
  }
  if (exceptRelativePath != 'lib/src/interactive/scene_controller_scene.dart') {
    writeSandboxFile(
      sandbox,
      'lib/src/interactive/scene_controller_scene.dart',
      'class SceneControllerSceneOwner {}\n',
    );
  }
}

void _registerResolvedRootPreGuardRegressionTests() {
  final scenarios =
      <
        ({
          String name,
          String extraMembers,
          String extraDeclarations,
          String prelude,
        })
      >[
        (
          name: 'direct getter condition',
          extraMembers: '''
  bool get hasPendingWork {
    print('side effect');
    return false;
  }
''',
          extraDeclarations: '',
          prelude: '''
    if (hasPendingWork) {
      return;
    }
''',
        ),
        (
          name: 'getter in local initializer',
          extraMembers: '''
  bool get hasPendingWork {
    print('side effect');
    return false;
  }
''',
          extraDeclarations: '',
          prelude: '''
    final shouldReturn = hasPendingWork;
    if (shouldReturn) {
      return;
    }
''',
        ),
        (
          name: 'getter in assert',
          extraMembers: '''
  bool get hasPendingWork {
    print('side effect');
    return false;
  }
''',
          extraDeclarations: '',
          prelude: '''
    assert(!hasPendingWork);
''',
        ),
        (
          name: 'getter in return expression',
          extraMembers: '''
  bool get hasPendingWork {
    print('side effect');
    return false;
  }
''',
          extraDeclarations: '',
          prelude: '''
    return hasPendingWork;
''',
        ),
        (
          name: 'getter in conditional expression',
          extraMembers: '''
  bool get hasPendingWork {
    print('side effect');
    return false;
  }
''',
          extraDeclarations: '',
          prelude: '''
    final shouldReturn = hasPendingWork ? true : false;
    if (shouldReturn) {
      return;
    }
''',
        ),
        (
          name: 'getter in binary expression',
          extraMembers: '''
  bool get hasPendingWork {
    print('side effect');
    return false;
  }
''',
          extraDeclarations: '',
          prelude: '''
    final shouldReturn = hasPendingWork || false;
    if (shouldReturn) {
      return;
    }
''',
        ),
        (
          name: 'getter in prefix expression',
          extraMembers: '''
  bool get hasPendingWork {
    print('side effect');
    return false;
  }
''',
          extraDeclarations: '',
          prelude: '''
    final shouldReturn = !hasPendingWork;
    if (shouldReturn) {
      return;
    }
''',
        ),
        (
          name: 'getter in cast expression',
          extraMembers: '''
  Object get payload {
    print('side effect');
    return 1;
  }
''',
          extraDeclarations: '',
          prelude: '''
    final value = payload as int;
    if (value > 0) {
      return;
    }
''',
        ),
        (
          name: 'getter in type test expression',
          extraMembers: '''
  Object get payload {
    print('side effect');
    return 1;
  }
''',
          extraDeclarations: '',
          prelude: '''
    final isInt = payload is int;
    if (isInt) {
      return;
    }
''',
        ),
        (
          name: 'getter in string interpolation',
          extraMembers: '''
  String get label {
    print('side effect');
    return 'unsafe';
  }
''',
          extraDeclarations: '',
          prelude: '''
    final message = '\$label';
    return;
''',
        ),
        (
          name: 'getter in list literal',
          extraMembers: '''
  bool get hasPendingWork {
    print('side effect');
    return false;
  }
''',
          extraDeclarations: '',
          prelude: '''
    final values = <bool>[hasPendingWork];
    return;
''',
        ),
        (
          name: 'getter in set literal',
          extraMembers: '''
  bool get hasPendingWork {
    print('side effect');
    return false;
  }
''',
          extraDeclarations: '',
          prelude: '''
    final values = <bool>{hasPendingWork};
    return;
''',
        ),
        (
          name: 'getter in map literal',
          extraMembers: '''
  bool get hasPendingWork {
    print('side effect');
    return false;
  }
''',
          extraDeclarations: '',
          prelude: '''
    final values = <String, bool>{'flag': hasPendingWork};
    return;
''',
        ),
        (
          name: 'getter in collection if element',
          extraMembers: '''
  bool get hasPendingWork {
    print('side effect');
    return false;
  }
''',
          extraDeclarations: '',
          prelude: '''
    final values = <int>[if (hasPendingWork) 1];
    return;
''',
        ),
        (
          name: 'getter in spread element',
          extraMembers: '''
  List<int> get items {
    print('side effect');
    return <int>[1];
  }
''',
          extraDeclarations: '',
          prelude: '''
    final values = <int>[...items];
    return;
''',
        ),
        (
          name: 'field property access',
          extraMembers: '''
  final _probe = _Probe();
''',
          extraDeclarations: '''
class _Probe {
  bool get unsafeFlag {
    print('side effect');
    return false;
  }
}
''',
          prelude: '''
    if (_probe.unsafeFlag) {
      return;
    }
''',
        ),
        (
          name: 'local alias property access',
          extraMembers: '''
  final _probe = _Probe();
''',
          extraDeclarations: '''
class _Probe {
  bool get unsafeFlag {
    print('side effect');
    return false;
  }
}
''',
          prelude: '''
    final probe = _probe;
    if (probe.unsafeFlag) {
      return;
    }
''',
        ),
        (
          name: 'index operator read',
          extraMembers: '''
  final _probe = _IndexProbe();
''',
          extraDeclarations: '''
class _IndexProbe {
  bool operator [](int index) {
    print('side effect');
    return false;
  }
}
''',
          prelude: '''
    if (_probe[0]) {
      return;
    }
''',
        ),
      ];

  for (final scenario in scenarios) {
    test('rejects root pre-guard bypass: ${scenario.name}', () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        _writeNeutralCapabilityOwners(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          sceneControllerFixture(
            extraMembers: scenario.extraMembers,
            extraDeclarations: scenario.extraDeclarations,
            methods: _canonicalControllerMethods(
              handlePointerSignature: '()',
              handlePointerBody:
                  '''
${scenario.prelude}
    _ensurePublicSideEffectAllowed('handlePointer');
''',
            ),
          ),
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'public SceneController entrypoints must guard '
                'resolver purity with _ensurePublicSideEffectAllowed',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });
  }

  test(
    'rejects public interactive method when graph interaction happens before guard',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        _writeNeutralCapabilityOwners(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          sceneControllerFixture(
            methods: _canonicalControllerMethods(
              handlePointerSignature: '()',
              handlePointerBody: '''
    sceneControllerGraphActions(_graph);
    _ensurePublicSideEffectAllowed('handlePointer');
''',
            ),
          ),
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'public SceneController entrypoints must guard '
                'resolver purity with _ensurePublicSideEffectAllowed',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects root entrypoint when guard is returned instead of invoked as a statement',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        _writeNeutralCapabilityOwners(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          sceneControllerFixture(
            methods: _canonicalControllerMethods(
              handlePointerSignature: '()',
              handlePointerBody: '''
    return _ensurePublicSideEffectAllowed('handlePointer');
''',
            ),
          ),
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'public SceneController entrypoints must guard '
                'resolver purity with _ensurePublicSideEffectAllowed',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );
}

void _registerResolvedCapabilityGuardRegressionTests() {
  final scenarios = <({String name, String relativePath, String content, String detail})>[
    (
      name: 'interaction owner fake _access getter',
      relativePath: 'lib/src/interactive/scene_controller_interaction.dart',
      content: '''
class SceneControllerInteractionOwner {
  _FakeAccess get _access => _FakeAccess();

  void handlePointer() {
    _access.runtime.ensurePublicSideEffectAllowed('handlePointer');
  }
}

class _FakeAccess {
  _FakeRuntime get runtime => _FakeRuntime();
}

class _FakeRuntime {
  void ensurePublicSideEffectAllowed(String operation) {}
}
''',
      detail:
          'public SceneControllerInteractionOwner entrypoints must guard '
          'resolver purity with _access.runtime.ensurePublicSideEffectAllowed',
    ),
    (
      name: 'interaction owner fake _access field',
      relativePath: 'lib/src/interactive/scene_controller_interaction.dart',
      content: '''
class SceneControllerInteractionOwner {
  final _access = _FakeAccess();

  void handlePointer() {
    _access.runtime.ensurePublicSideEffectAllowed('handlePointer');
  }
}

class _FakeAccess {
  final runtime = _FakeRuntime();
}

class _FakeRuntime {
  void ensurePublicSideEffectAllowed(String operation) {}
}
''',
      detail:
          'public SceneControllerInteractionOwner entrypoints must guard '
          'resolver purity with _access.runtime.ensurePublicSideEffectAllowed',
    ),
    (
      name: 'interaction owner local alias',
      relativePath: 'lib/src/interactive/scene_controller_interaction.dart',
      content: '''
class SceneControllerInteractionOwner {
  final _access = _Access();

  void handlePointer() {
    final access = _access;
    access.runtime.ensurePublicSideEffectAllowed('handlePointer');
  }
}

class _Access {
  final runtime = _RuntimeAccess();
}

class _RuntimeAccess {
  void ensurePublicSideEffectAllowed(String operation) {}
}
''',
      detail:
          'public SceneControllerInteractionOwner entrypoints must guard '
          'resolver purity with _access.runtime.ensurePublicSideEffectAllowed',
    ),
    (
      name: 'interaction owner pre-guard getter read',
      relativePath: 'lib/src/interactive/scene_controller_interaction.dart',
      content: '''
class SceneControllerInteractionOwner {
  final _access = _Access();
  final _probe = _Probe();

  void handlePointer() {
    if (_probe.unsafeFlag) {
      return;
    }
    _access.runtime.ensurePublicSideEffectAllowed('handlePointer');
  }
}

class _Access {
  final runtime = _RuntimeAccess();
}

class _RuntimeAccess {
  void ensurePublicSideEffectAllowed(String operation) {}
}

class _Probe {
  bool get unsafeFlag {
    print('side effect');
    return false;
  }
}
''',
      detail:
          'public SceneControllerInteractionOwner entrypoints must guard '
          'resolver purity with _access.runtime.ensurePublicSideEffectAllowed',
    ),
    (
      name: 'interaction owner pre-guard index read',
      relativePath: 'lib/src/interactive/scene_controller_interaction.dart',
      content: '''
class SceneControllerInteractionOwner {
  final _access = _Access();
  final _probe = _IndexProbe();

  void handlePointer() {
    if (_probe[0]) {
      return;
    }
    _access.runtime.ensurePublicSideEffectAllowed('handlePointer');
  }
}

class _Access {
  final runtime = _RuntimeAccess();
}

class _RuntimeAccess {
  void ensurePublicSideEffectAllowed(String operation) {}
}

class _IndexProbe {
  bool operator [](int index) {
    print('side effect');
    return false;
  }
}
''',
      detail:
          'public SceneControllerInteractionOwner entrypoints must guard '
          'resolver purity with _access.runtime.ensurePublicSideEffectAllowed',
    ),
    (
      name: 'selection owner fake _runtime getter',
      relativePath: 'lib/src/interactive/scene_controller_selection.dart',
      content: '''
class SceneControllerSelectionOwner {
  _FakeRuntime get _runtime => _FakeRuntime();

  void setSelection(Object nodeIds) {
    _runtime.ensurePublicSideEffectAllowed('setSelection');
  }
}

class _FakeRuntime {
  void ensurePublicSideEffectAllowed(String operation) {}
}
''',
      detail:
          'public SceneControllerSelectionOwner entrypoints must guard '
          'resolver purity with _runtime.ensurePublicSideEffectAllowed',
    ),
    (
      name: 'selection owner fake _runtime field',
      relativePath: 'lib/src/interactive/scene_controller_selection.dart',
      content: '''
class SceneControllerSelectionOwner {
  final _runtime = _FakeRuntime();

  void setSelection(Object nodeIds) {
    _runtime.ensurePublicSideEffectAllowed('setSelection');
  }
}

class _FakeRuntime {
  void ensurePublicSideEffectAllowed(String operation) {}
}
''',
      detail:
          'public SceneControllerSelectionOwner entrypoints must guard '
          'resolver purity with _runtime.ensurePublicSideEffectAllowed',
    ),
    (
      name: 'selection owner local alias',
      relativePath: 'lib/src/interactive/scene_controller_selection.dart',
      content: '''
class SceneControllerSelectionOwner {
  final _runtime = _Runtime();

  void setSelection(Object nodeIds) {
    final runtime = _runtime;
    runtime.ensurePublicSideEffectAllowed('setSelection');
  }
}

class _Runtime {
  void ensurePublicSideEffectAllowed(String operation) {}
}
''',
      detail:
          'public SceneControllerSelectionOwner entrypoints must guard '
          'resolver purity with _runtime.ensurePublicSideEffectAllowed',
    ),
    (
      name: 'selection owner pre-guard getter read',
      relativePath: 'lib/src/interactive/scene_controller_selection.dart',
      content: '''
class SceneControllerSelectionOwner {
  final _runtime = _Runtime();
  final _probe = _Probe();

  void setSelection(Object nodeIds) {
    if (_probe.unsafeFlag) {
      return;
    }
    _runtime.ensurePublicSideEffectAllowed('setSelection');
  }
}

class _Runtime {
  void ensurePublicSideEffectAllowed(String operation) {}
}

class _Probe {
  bool get unsafeFlag {
    print('side effect');
    return false;
  }
}
''',
      detail:
          'public SceneControllerSelectionOwner entrypoints must guard '
          'resolver purity with _runtime.ensurePublicSideEffectAllowed',
    ),
    (
      name: 'selection owner interpolation getter read',
      relativePath: 'lib/src/interactive/scene_controller_selection.dart',
      content: '''
class SceneControllerSelectionOwner {
  final _runtime = _Runtime();

  String get label {
    print('side effect');
    return 'unsafe';
  }

  void setSelection(Object nodeIds) {
    final message = '\$label';
    if (message.isEmpty) {
      return;
    }
    _runtime.ensurePublicSideEffectAllowed('setSelection');
  }
}

class _Runtime {
  void ensurePublicSideEffectAllowed(String operation) {}
}
''',
      detail:
          'public SceneControllerSelectionOwner entrypoints must guard '
          'resolver purity with _runtime.ensurePublicSideEffectAllowed',
    ),
    (
      name: 'scene owner local alias',
      relativePath: 'lib/src/interactive/scene_controller_scene.dart',
      content: '''
abstract interface class SceneControllerScene {
  void write(Object fn);
}

class SceneControllerSceneOwner implements SceneControllerScene {
  final void Function(String operation, {bool allowAfterDispose})
  ensurePublicSideEffectAllowed = _ensure;

  @override
  void write(Object fn) {
    final guard = ensurePublicSideEffectAllowed;
    guard('write');
  }
}

void _ensure(
  String operation, {
  bool allowAfterDispose = false,
}) {}
''',
      detail:
          'public SceneControllerSceneOwner entrypoints must guard '
          'resolver purity with ensurePublicSideEffectAllowed',
    ),
    (
      name: 'scene owner pre-guard getter read',
      relativePath: 'lib/src/interactive/scene_controller_scene.dart',
      content: '''
abstract interface class SceneControllerScene {
  void write(Object fn);
}

class SceneControllerSceneOwner implements SceneControllerScene {
  final void Function(String operation, {bool allowAfterDispose})
  ensurePublicSideEffectAllowed = _ensure;

  bool get hasPendingWork {
    print('side effect');
    return false;
  }

  @override
  void write(Object fn) {
    if (hasPendingWork) {
      return;
    }
    ensurePublicSideEffectAllowed('write');
  }
}

void _ensure(
  String operation, {
  bool allowAfterDispose = false,
}) {}
''',
      detail:
          'public SceneControllerSceneOwner entrypoints must guard '
          'resolver purity with ensurePublicSideEffectAllowed',
    ),
  ];

  for (final scenario in scenarios) {
    test('rejects capability guard bypass: ${scenario.name}', () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        _writeNeutralCapabilityOwners(
          sandbox,
          exceptRelativePath: scenario.relativePath,
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _canonicalCapabilityControllerFixture(),
        );
        writeSandboxFile(sandbox, scenario.relativePath, scenario.content);

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(category: 'interactive API', detail: scenario.detail),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });
  }

  test(
    'rejects scene owner delegate call before resolver purity guard',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        _writeNeutralCapabilityOwners(
          sandbox,
          exceptRelativePath: 'lib/src/interactive/scene_controller_scene.dart',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _canonicalCapabilityControllerFixture(),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller_scene.dart',
          '''
abstract interface class SceneControllerScene {
  void write(Object fn);
}

class SceneControllerSceneOwner implements SceneControllerScene {
  final void Function(String operation, {bool allowAfterDispose})
  ensurePublicSideEffectAllowed = _ensure;
  final _Mutations _mutations = _Mutations();

  @override
  void write(Object fn) {
    _mutations.write(fn);
    ensurePublicSideEffectAllowed('write');
  }
}

class _Mutations {
  void write(Object fn) {}
}

void _ensure(
  String operation, {
  bool allowAfterDispose = false,
}) {}
''',
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'public SceneControllerSceneOwner entrypoints must guard '
                'resolver purity with ensurePublicSideEffectAllowed',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects capability entrypoint when guard is returned instead of invoked as a statement',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        _writeNeutralCapabilityOwners(
          sandbox,
          exceptRelativePath:
              'lib/src/interactive/scene_controller_interaction.dart',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _canonicalCapabilityControllerFixture(),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller_interaction.dart',
          '''
import 'internal/scene_controller_interaction_runtime.dart';

class SceneControllerInteractionOwner {
  final _access = _Access();

  void handlePointer() {
    return _access.runtime.ensurePublicSideEffectAllowed('handlePointer');
  }
}

class _Access {
  final runtime = SceneControllerInteractionRuntime();
}
''',
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'public SceneControllerInteractionOwner entrypoints must guard '
                'resolver purity with _access.runtime.ensurePublicSideEffectAllowed',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );
}

void _registerResolvedEntrypointAcceptanceTests() {
  test(
    'accepts harmless local scaffolding before SceneController purity guard',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        _writeNeutralCapabilityOwners(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          sceneControllerFixture(
            methods: _canonicalControllerMethods(
              handlePointerSignature: '(int value)',
              handlePointerBody: '''
    final shouldReturn = value < 0;
    if (shouldReturn) {
      return;
    }
    _ensurePublicSideEffectAllowed('handlePointer');
''',
            ),
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
    'accepts nullable scalar pre-guard checks in root entrypoints',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        _writeNeutralCapabilityOwners(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          sceneControllerFixture(
            methods: _canonicalControllerMethods(
              handlePointerSignature: '(int? timestampMs)',
              handlePointerBody: '''
    if (timestampMs == null) {
      return;
    }
    _ensurePublicSideEffectAllowed('handlePointer');
''',
            ),
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
    'accepts num-typed pre-guard comparisons in capability entrypoints',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        _writeNeutralCapabilityOwners(
          sandbox,
          exceptRelativePath:
              'lib/src/interactive/scene_controller_selection.dart',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _canonicalCapabilityControllerFixture(),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller_selection.dart',
          '''
import 'internal/scene_controller_interaction_runtime.dart';

class SceneControllerSelectionOwner {
  const SceneControllerSelectionOwner(this._runtime);

  final SceneControllerInteractionRuntime _runtime;

  void setSelection(num value) {
    if (value < 0) {
      return;
    }
    _runtime.ensurePublicSideEffectAllowed('setSelection');
  }
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

  test('accepts scene owner explicit getter guard source', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      _writeNeutralCapabilityOwners(
        sandbox,
        exceptRelativePath: 'lib/src/interactive/scene_controller_scene.dart',
      );
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        _canonicalCapabilityControllerFixture(),
      );
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller_scene.dart',
        '''
abstract interface class SceneControllerScene {
  void write(Object fn);
}

class SceneControllerSceneOwner implements SceneControllerScene {
  void Function(String operation, {bool allowAfterDispose})
  get ensurePublicSideEffectAllowed => _ensure;

  @override
  void write(Object fn) {
    ensurePublicSideEffectAllowed('write');
  }
}

void _ensure(
  String operation, {
  bool allowAfterDispose = false,
}) {}
''',
      );

      final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
      expect(result.exitCode, 0, reason: result.stderr.toString());
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test(
    'accepts scene owner purity guard after harmless local scaffolding',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        _writeNeutralCapabilityOwners(
          sandbox,
          exceptRelativePath: 'lib/src/interactive/scene_controller_scene.dart',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _canonicalCapabilityControllerFixture(),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller_scene.dart',
          '''
abstract interface class SceneControllerScene {
  void write(Object fn);

  void clearScene();
}

class SceneControllerSceneOwner implements SceneControllerScene {
  final void Function(String operation, {bool allowAfterDispose})
  ensurePublicSideEffectAllowed = _ensure;
  final _Mutations _mutations = _Mutations();

  @override
  void write(Object fn) {
    final shouldReturn = fn is Never;
    if (shouldReturn) {
      return;
    }
    ensurePublicSideEffectAllowed('write');
    _mutations.write(fn);
  }

  @override
  void clearScene() {
    ensurePublicSideEffectAllowed('clearScene');
    _mutations.clearScene();
  }
}

class _Mutations {
  void write(Object fn) {}

  void clearScene() {}
}

void _ensure(
  String operation, {
  bool allowAfterDispose = false,
}) {}
''',
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );
}
