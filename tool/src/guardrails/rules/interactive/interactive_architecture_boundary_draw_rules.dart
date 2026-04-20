part of 'mutation_boundary_rules.dart';

Future<GuardrailViolation?> _checkInteractiveRuntimeBoundary(
  GuardrailContext context,
) async {
  final file = _interactiveArchitectureFile(
    context,
    'internal/interactive_runtime.dart',
  );
  final filePath = _repoRelPath(context, file);
  final parsed = _parseArchitectureUnit(context, file);
  final runtimeClass = _findClassDeclaration(parsed.unit, 'InteractiveRuntime');
  if (runtimeClass == null ||
      _classOwnsMethodDeclaration(runtimeClass, 'handlePointer') ||
      _classOwnsMethodDeclaration(runtimeClass, 'handleDoubleTap') ||
      _classHasFieldNamed(runtimeClass, '_timestampCursorMs') ||
      _classHasFieldNamed(runtimeClass, '_actionCounter') ||
      _classHasFieldNamed(runtimeClass, '_actions') ||
      _unitContainsIdentifier(parsed.unit, 'StreamController') ||
      _classOwnsMethodDeclaration(runtimeClass, '_eraserHitsLine')) {
    return GuardrailViolation(
      filePath: filePath,
      line: 1,
      message:
          'interactive API violation: InteractiveRuntime must keep event '
          'timeline and draw-local geometry outside the boundary runtime.',
    );
  }
  return null;
}

GuardrailViolation? _checkEventDispatcherBoundary(GuardrailContext context) {
  final file = _interactiveArchitectureFile(
    context,
    'internal/interactive_event_dispatcher.dart',
  );
  final filePath = _repoRelPath(context, file);
  final parsed = _parseArchitectureUnit(context, file);
  final dispatcherClass = _findClassDeclaration(
    parsed.unit,
    'InteractiveEventDispatcher',
  );
  if (dispatcherClass == null ||
      !_classHasFieldNamed(dispatcherClass, '_actions') ||
      !_classHasFieldNamed(dispatcherClass, '_editTextRequests') ||
      !_classOwnsMethodDeclaration(dispatcherClass, 'resolveTimestampMs') ||
      !_classOwnsMethodDeclaration(dispatcherClass, 'emitAction') ||
      !_classOwnsMethodDeclaration(dispatcherClass, 'emitEditTextRequested') ||
      _unitContainsIdentifier(parsed.unit, 'InteractiveDrawCoordinator') ||
      _unitContainsIdentifier(parsed.unit, 'SceneControllerMutationBoundary')) {
    return GuardrailViolation(
      filePath: filePath,
      line: 1,
      message:
          'interactive API violation: InteractiveEventDispatcher must remain '
          'the event timeline owner.',
    );
  }
  return null;
}

GuardrailViolation? _checkDrawCoordinatorBoundary(GuardrailContext context) {
  final coordinatorFile = _interactiveArchitectureFile(
    context,
    'internal/interactive_draw_coordinator.dart',
  );
  final coordinatorParsed = _parseArchitectureUnit(context, coordinatorFile);
  if (!_hasImport(coordinatorParsed, 'interactive_draw_eraser_engine.dart') ||
      !_hasImport(coordinatorParsed, 'interactive_draw_line_engine.dart') ||
      !_hasImport(coordinatorParsed, 'interactive_draw_stroke_engine.dart') ||
      !_hasImport(coordinatorParsed, 'interactive_draw_terminal_router.dart') ||
      !_unitContainsIdentifier(
        coordinatorParsed.unit,
        'InteractiveDrawEraserEngine',
      ) ||
      !_unitContainsIdentifier(
        coordinatorParsed.unit,
        'InteractiveDrawLineEngine',
      ) ||
      !_unitContainsIdentifier(
        coordinatorParsed.unit,
        'InteractiveDrawStrokeEngine',
      ) ||
      _classOwnsMethod(
        coordinatorParsed,
        'InteractiveDrawCoordinator',
        '_eraserHitsLine',
      ) ||
      _classOwnsMethod(
        coordinatorParsed,
        'InteractiveDrawCoordinator',
        '_hitsLine',
      ) ||
      _classOwnsMethod(
        coordinatorParsed,
        'InteractiveDrawCoordinator',
        '_hitsStroke',
      )) {
    return GuardrailViolation(
      filePath: _repoRelPath(context, coordinatorFile),
      line: 1,
      message:
          'interactive API violation: InteractiveDrawCoordinator must remain '
          'a draw-family orchestrator and not re-own eraser geometry.',
    );
  }
  return null;
}

GuardrailViolation? _checkDrawEraserEngineBoundary(GuardrailContext context) {
  final eraserFile = _interactiveArchitectureFile(
    context,
    'internal/interactive_draw_eraser_engine.dart',
  );
  final eraserParsed = _parseArchitectureUnit(context, eraserFile);
  if (!_hasImport(eraserParsed, 'interactive_draw_eraser_exact_hit.dart') ||
      !_unitContainsIdentifier(
        eraserParsed.unit,
        'InteractiveDrawEraserExactHit',
      ) ||
      !_unitContainsIdentifier(
        eraserParsed.unit,
        'InteractiveDrawEraserTargets',
      ) ||
      _classOwnsMethod(
        eraserParsed,
        'InteractiveDrawEraserEngine',
        '_eraserHitsLine',
      ) ||
      _classOwnsMethod(
        eraserParsed,
        'InteractiveDrawEraserEngine',
        '_hitsLine',
      ) ||
      _classOwnsMethod(
        eraserParsed,
        'InteractiveDrawEraserEngine',
        '_hitsStroke',
      ) ||
      _classOwnsMethod(
        eraserParsed,
        'InteractiveDrawEraserEngine',
        '_projectEraserToLocal',
      )) {
    return GuardrailViolation(
      filePath: _repoRelPath(context, eraserFile),
      line: 1,
      message:
          'interactive API violation: InteractiveDrawEraserEngine must '
          'delegate exact-hit geometry to eraser-local owners.',
    );
  }
  return null;
}

GuardrailViolation? _checkDrawExactHitBoundary(GuardrailContext context) {
  final file = _interactiveArchitectureFile(
    context,
    'internal/interactive_draw_eraser_exact_hit.dart',
  );
  final filePath = _repoRelPath(context, file);
  final parsed = _parseArchitectureUnit(context, file);
  if (!_hasImport(parsed, 'interactive_draw_eraser_line_hit.dart') ||
      !_hasImport(parsed, 'interactive_draw_eraser_stroke_hit.dart') ||
      !_hasImport(parsed, 'interactive_draw_eraser_projection.dart') ||
      !_classOwnsMethod(parsed, 'InteractiveDrawEraserExactHit', 'hitsNode') ||
      !_unitContainsIdentifier(parsed.unit, 'InteractiveDrawEraserLineHit') ||
      !_unitContainsIdentifier(parsed.unit, 'InteractiveDrawEraserStrokeHit') ||
      _unitContainsIdentifier(parsed.unit, 'queryHitTestCandidates') ||
      _unitContainsIdentifier(parsed.unit, 'commitEraseNodes')) {
    return GuardrailViolation(
      filePath: filePath,
      line: 1,
      message:
          'interactive API violation: InteractiveDrawEraserExactHit must '
          'remain the exact-hit owner over line/stroke delegates.',
    );
  }
  return null;
}

GuardrailViolation? _checkDrawLineHitBoundary(GuardrailContext context) {
  final file = _interactiveArchitectureFile(
    context,
    'internal/interactive_draw_eraser_line_hit.dart',
  );
  final filePath = _repoRelPath(context, file);
  final parsed = _parseArchitectureUnit(context, file);
  if (!_classOwnsMethod(
        parsed,
        'InteractiveDrawEraserLineHit',
        'hitsProjectedLine',
      ) ||
      _unitContainsIdentifier(parsed.unit, 'StrokeNodeSnapshot') ||
      _unitContainsIdentifier(parsed.unit, 'InteractiveDrawEraserStrokeHit')) {
    return GuardrailViolation(
      filePath: filePath,
      line: 1,
      message:
          'interactive API violation: InteractiveDrawEraserLineHit must '
          'remain the projected-line exact-hit owner.',
    );
  }
  return null;
}

GuardrailViolation? _checkDrawStrokeHitBoundary(GuardrailContext context) {
  final file = _interactiveArchitectureFile(
    context,
    'internal/interactive_draw_eraser_stroke_hit.dart',
  );
  final filePath = _repoRelPath(context, file);
  final parsed = _parseArchitectureUnit(context, file);
  if (!_classOwnsMethod(
        parsed,
        'InteractiveDrawEraserStrokeHit',
        'hitsProjectedStroke',
      ) ||
      _unitContainsIdentifier(parsed.unit, 'LineNodeSnapshot') ||
      _unitContainsIdentifier(parsed.unit, 'InteractiveDrawEraserLineHit')) {
    return GuardrailViolation(
      filePath: filePath,
      line: 1,
      message:
          'interactive API violation: InteractiveDrawEraserStrokeHit must '
          'remain the projected-stroke exact-hit owner.',
    );
  }
  return null;
}

GuardrailViolation? _checkDrawProjectionBoundary(GuardrailContext context) {
  final file = _interactiveArchitectureFile(
    context,
    'internal/interactive_draw_eraser_projection.dart',
  );
  final filePath = _repoRelPath(context, file);
  final parsed = _parseArchitectureUnit(context, file);
  if (!_hasTopLevelOwner(parsed, 'InteractiveDrawProjectedEraser') ||
      _unitContainsIdentifier(parsed.unit, 'hitsProjectedLine') ||
      _unitContainsIdentifier(parsed.unit, 'hitsProjectedStroke')) {
    return GuardrailViolation(
      filePath: filePath,
      line: 1,
      message:
          'interactive API violation: InteractiveDrawProjectedEraser must '
          'remain the shared projection contract.',
    );
  }
  return null;
}

GuardrailViolation? _checkDrawStyleBoundary(GuardrailContext context) {
  final file = _interactiveArchitectureFile(
    context,
    'internal/interactive_draw_style.dart',
  );
  final filePath = _repoRelPath(context, file);
  final parsed = _parseArchitectureUnit(context, file);
  if (!_hasTopLevelOwner(parsed, 'InteractiveDrawStyle') ||
      _unitContainsIdentifier(parsed.unit, 'InteractiveDrawCoordinator') ||
      _unitContainsIdentifier(parsed.unit, 'SceneControllerMutationBoundary')) {
    return GuardrailViolation(
      filePath: filePath,
      line: 1,
      message:
          'interactive API violation: InteractiveDrawStyle must remain a '
          'data-only draw contract.',
    );
  }
  return null;
}
