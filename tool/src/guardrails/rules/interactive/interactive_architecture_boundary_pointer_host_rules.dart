part of 'mutation_boundary_rules.dart';

Future<GuardrailViolation?> _checkPointerHostBoundary(
  GuardrailContext context,
) async {
  final file = _interactiveArchitectureFile(
    context,
    '../view/scene_view_interactive_pointer_host.dart',
  );
  final filePath = _repoRelPath(context, file);
  final resolved = await _resolveInteractiveUnitOrFail(
    context: context,
    file: file,
    filePath: filePath,
  );
  final runtimeClass = _findClassByName(
    resolved.unit.declarations,
    '_SceneViewInteractivePointerRuntime',
  );
  final replaceMethod = runtimeClass == null
      ? null
      : _findMethodByName(runtimeClass.members, 'replacePointerSession');
  final disposeMethod = runtimeClass == null
      ? null
      : _findMethodByName(runtimeClass.members, 'dispose');
  if (runtimeClass == null ||
      replaceMethod == null ||
      disposeMethod == null ||
      !_methodHasParameterType(
        replaceMethod,
        parameterName: 'next',
        typeName: 'SceneViewPointerSession',
      ) ||
      !_methodInvokesOwnedMethod(
        replaceMethod,
        context: context,
        filePath: null,
        ownerName: 'SceneViewPointerSession',
        methodName: 'detach',
      ) ||
      !_methodInvokesOwnedMethod(
        replaceMethod,
        context: context,
        filePath: null,
        ownerName: 'SceneViewPointerSession',
        methodName: 'dispose',
      ) ||
      !_methodInvokesOwnedMethod(
        replaceMethod,
        context: context,
        filePath: null,
        ownerName: 'SceneViewPointerRouter',
        methodName: 'reset',
      ) ||
      !_methodContainsOrderedStatementsWithForbiddenOutsideSequence(
        replaceMethod,
        orderedMatchers: <bool Function(Statement)>[
          (statement) => _statementInvokesOwnedMethod(
            statement,
            context: context,
            filePath: null,
            ownerName: 'SceneViewPointerSession',
            methodName: 'detach',
            targetSegments: <String>['current'],
          ),
          (statement) => _statementInvokesOwnedMethod(
            statement,
            context: context,
            filePath: null,
            ownerName: 'SceneViewPointerSession',
            methodName: 'dispose',
            targetSegments: <String>['current'],
          ),
          (statement) => _statementInvokesOwnedMethod(
            statement,
            context: context,
            filePath: null,
            ownerName: 'SceneViewPointerRouter',
            methodName: 'reset',
          ),
          (statement) => _statementAssignsFieldFromQualifiedName(
            statement,
            fieldName: '_pointerSession',
            rhsSegments: <String>['next'],
          ),
        ],
        forbiddenBeforeCompletion: <bool Function(Statement)>[
          (statement) => _statementAssignsFieldNamed(
            statement,
            fieldName: '_pointerSession',
          ),
        ],
        forbiddenAfterCompletion: <bool Function(Statement)>[
          (statement) => _statementAssignsFieldNamed(
            statement,
            fieldName: '_pointerSession',
          ),
        ],
      ) ||
      !_methodInvokesOwnedMethod(
        disposeMethod,
        context: context,
        filePath: null,
        ownerName: 'SceneViewPointerSession',
        methodName: 'detach',
      ) ||
      !_methodInvokesOwnedMethod(
        disposeMethod,
        context: context,
        filePath: null,
        ownerName: 'SceneViewPointerSession',
        methodName: 'dispose',
      ) ||
      !_methodContainsOrderedStatements(
        disposeMethod,
        <bool Function(Statement)>[
          (statement) => _statementInvokesOwnedMethod(
            statement,
            context: context,
            filePath: null,
            ownerName: 'SceneViewPointerSession',
            methodName: 'detach',
            targetSegments: <String>['_pointerSession'],
          ),
          (statement) => _statementInvokesOwnedMethod(
            statement,
            context: context,
            filePath: null,
            ownerName: 'SceneViewPointerSession',
            methodName: 'dispose',
            targetSegments: <String>['_pointerSession'],
          ),
        ],
      ) ||
      _unitContainsIdentifier(resolved.unit, 'SceneController') ||
      _unitContainsIdentifier(resolved.unit, 'createPointerSemanticsBridge') ||
      _unitContainsIdentifier(resolved.unit, 'PointerInputTracker') ||
      _unitContainsIdentifier(resolved.unit, '_PendingTapFlushScheduler') ||
      _unitContainsIdentifier(resolved.unit, '_pendingPointerSettings') ||
      _unitContainsIdentifier(
        resolved.unit,
        '_SceneViewPointerSessionFactory',
      )) {
    return GuardrailViolation(
      filePath: filePath,
      line: 1,
      message:
          'interactive API violation: SceneViewInteractivePointerHost must '
          'remain a raw routing/lifecycle shell over pointer sessions.',
    );
  }
  return null;
}
