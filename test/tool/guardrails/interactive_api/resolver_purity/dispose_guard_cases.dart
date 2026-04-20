part of '../../guardrails_interactive_api_tool_test.dart';

void _registerInteractiveDisposeGuardTests() {
  test(
    'rejects dispose without allowAfterDispose true in purity guard',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          sceneControllerFixture(
            methods: '''
  void dispose() {
    _ensurePublicSideEffectAllowed('dispose');
  }
''',
          ),
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'dispose() must guard resolver purity with '
                'allowAfterDispose: true',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );
}
