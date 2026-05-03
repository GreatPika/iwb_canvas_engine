import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _ArchitectureAnalysis analysis;
  const retiredInteractionAccessReader =
      'readInteractionAccessFor'
      'Test';
  const retiredInteractionAccessHelper =
      'sceneControllerInternalInteractionAccessFor'
      'Test';
  const retiredDebugMoveSession =
      'debugMove'
      'Session';
  const retiredInteractionContext =
      'SceneControllerInteraction'
      'Context';

  setUpAll(() {
    analysis = _ArchitectureAnalysis(repoRootPath: Directory.current.path);
  });

  // INV:INV-ENG-INTERACTIVE-ARCHITECTURE-BOUNDARY
  // INV:INV-ENG-VIEW-RENDER-READ-STATE-BOUNDARY
  // INV:INV-ENG-VIEW-POINTER-SEMANTICS-BOUNDARY
  // INV:INV-ENG-COMMITTED-SELECTION-REVISION-ALIGNMENT
  test('SceneController architecture boundary remains structurally split', () {
    analysis.expectMissingFile(
      'lib/src/interactive/internal/scene_controller_interaction_access.dart',
    );
    analysis.expectMissingFile(
      'lib/src/interactive/internal/scene_controller_facade_assembly.dart',
    );
    analysis.expectMissingFile(
      'lib/src/interactive/internal/scene_controller_pointer_semantics.dart',
    );
    analysis.expectMissingFile(
      'lib/src/interactive/scene_view_pointer_semantics.dart',
    );

    final facade = analysis.parsed('lib/src/interactive/scene_controller.dart');
    final graph = analysis.parsed(
      'lib/src/interactive/internal/scene_controller_graph.dart',
    );
    final interactionOwner = analysis.parsed(
      'lib/src/interactive/scene_controller_interaction.dart',
    );
    final internalAccess = analysis.parsed(
      'lib/src/interactive/internal/scene_controller_internal_access.dart',
    );
    final runtimeContract = analysis.parsed(
      'lib/src/contract/scene_view_runtime.dart',
    );
    final interactionRuntime = analysis.parsed(
      'lib/src/interactive/internal/scene_controller_interaction_runtime.dart',
    );
    final sceneViewRuntime = analysis.parsed(
      'lib/src/interactive/internal/scene_controller_scene_view_runtime.dart',
    );
    final pointerSession = analysis.parsed(
      'lib/src/interactive/internal/scene_controller_pointer_session.dart',
    );
    final sceneViewInteractive = analysis.parsed(
      'lib/src/view/scene_view_interactive.dart',
    );
    final runtimeHost = analysis.parsed(
      'lib/src/view/scene_view_runtime_host.dart',
    );
    final renderSurface = analysis.parsed(
      'lib/src/view/scene_view_render_surface.dart',
    );
    final overlayPainter = analysis.parsed(
      'lib/src/view/scene_view_interactive_overlay_painter.dart',
    );

    final sceneController = analysis.findClass(facade, 'SceneController');
    final interactionOwnerClass = analysis.findClass(
      interactionOwner,
      'SceneControllerInteractionOwner',
    );
    final sceneControllerBridge = analysis.findTopLevelFunction(
      facade,
      'sceneControllerViewRuntimeOf',
    );
    final graphFactory = analysis.findTopLevelFunction(
      graph,
      'createSceneControllerGraph',
    );
    final graphAssembly = analysis.findTopLevelFunction(
      graph,
      '_assembleSceneControllerGraph',
    );
    final graphHandle = analysis.findClass(graph, 'SceneControllerGraphHandle');
    final sceneViewRuntimeClass = analysis.findClass(
      sceneViewRuntime,
      'SceneControllerSceneViewRuntime',
    );
    final mainSceneRenderReadClass = analysis.findClass(
      sceneViewRuntime,
      'SceneControllerSceneViewMainSceneRenderRead',
    );
    final overlayPreviewReadClass = analysis.findClass(
      sceneViewRuntime,
      'SceneControllerSceneViewOverlayPreviewRead',
    );
    final pointerSessionClass = analysis.findClass(
      pointerSession,
      'SceneControllerPointerSession',
    );
    final sceneViewInteractiveClass = analysis.findClass(
      sceneViewInteractive,
      'SceneViewInteractive',
    );
    final runtimeHostClass = analysis.findClass(
      runtimeHost,
      'SceneViewRuntimeHost',
    );
    final runtimeHostState = analysis.findClass(
      runtimeHost,
      '_SceneViewRuntimeHostState',
    );
    final renderSurfaceClass = analysis.findClass(
      renderSurface,
      'SceneViewRenderSurface',
    );

    expect(
      analysis.hasImport(facade, 'internal/scene_controller_graph.dart'),
      isTrue,
    );
    expect(
      analysis.hasImport(
        interactionOwner,
        'internal/scene_controller_interaction_access.dart',
      ),
      isFalse,
    );
    expect(
      analysis.hasImport(facade, '../contract/scene_view_runtime.dart'),
      isTrue,
    );
    expect(
      analysis.hasImport(facade, '../controller/scene_store_controller.dart'),
      isFalse,
    );
    expect(
      analysis.hasImport(
        facade,
        'internal/scene_controller_internal_access.dart',
      ),
      isFalse,
    );
    expect(
      analysis.hasImport(
        facade,
        'internal/scene_controller_pointer_session.dart',
      ),
      isFalse,
    );
    expect(
      analysis.implementsInterface(
        sceneController,
        'SceneViewMainSceneRenderRead',
      ),
      isFalse,
    );
    expect(
      analysis.implementsInterface(
        sceneController,
        'SceneViewOverlayPreviewRead',
      ),
      isFalse,
    );
    expect(
      analysis.hasUnnamedFactoryInvocation(
        facade.unit,
        'createSceneControllerGraph',
      ),
      isTrue,
    );
    expect(
      analysis.containsIdentifier(facade.unit, 'sceneControllerGraphActions'),
      isFalse,
    );
    expect(
      analysis.containsIdentifier(
        facade.unit,
        'sceneControllerGraphEditTextRequests',
      ),
      isFalse,
    );
    expect(
      analysis.containsIdentifier(
        facade.unit,
        'sceneControllerGraphPreviewDeltaResolver',
      ),
      isFalse,
    );
    expect(
      analysis.containsIdentifier(
        facade.unit,
        'sceneControllerGraphEnsurePublicSideEffectAllowed',
      ),
      isFalse,
    );
    expect(
      analysis.containsIdentifier(
        facade.unit,
        'sceneControllerGraphIsDisposed',
      ),
      isFalse,
    );
    expect(
      analysis.containsIdentifier(facade.unit, 'SceneStoreController'),
      isFalse,
    );
    expect(
      analysis.containsIdentifier(facade.unit, '_storeController'),
      isFalse,
    );
    expect(
      analysis.hasUnnamedFactoryInvocation(
        facade.unit,
        'registerSceneControllerInternalAccess',
      ),
      isFalse,
    );
    expect(
      analysis.namedTypeOf(sceneControllerBridge.returnType),
      'SceneViewRuntime',
    );

    final runtimeInterface = analysis.findClass(
      runtimeContract,
      'SceneViewRuntime',
    );
    final pointerSessionInterface = analysis.findClass(
      runtimeContract,
      'SceneViewPointerSession',
    );
    expect(
      analysis.namedTypeOf(
        analysis
            .findMethod(runtimeInterface, 'createPointerSession')
            .returnType,
      ),
      'SceneViewPointerSession',
    );
    expect(runtimeInterface.abstractKeyword, isNotNull);
    expect(pointerSessionInterface.abstractKeyword, isNotNull);

    expect(
      analysis.containsInvocation(
        graphFactory,
        'registerSceneControllerInternalAccess',
      ),
      isTrue,
    );
    expect(
      analysis.containsInvocation(
        graphFactory,
        '_assembleSceneControllerGraph',
      ),
      isTrue,
    );
    expect(
      analysis.variableInitializerConstructorType(
        graphAssembly,
        'storeController',
      ),
      'SceneStoreController',
    );
    expect(
      analysis.variableInitializerConstructorType(
        graphAssembly,
        'sceneViewRuntime',
      ),
      'SceneControllerSceneViewRuntime',
    );
    expect(
      analysis.variableInitializerConstructorType(graphAssembly, 'interaction'),
      'SceneControllerInteractionOwner',
    );
    expect(
      analysis.containsConstructorInvocation(
        graphAssembly,
        'SceneControllerGraphHandle',
      ),
      isTrue,
    );
    expect(
      analysis.classFieldType(graphHandle, 'interaction'),
      'SceneControllerInteraction',
    );
    expect(
      analysis.classFieldType(graphHandle, 'selection'),
      'SceneControllerSelection',
    );
    expect(
      analysis.classFieldType(graphHandle, 'scene'),
      'SceneControllerScene',
    );
    expect(
      analysis.classFieldType(graphHandle, 'sceneViewRuntime'),
      'SceneViewRuntime',
    );
    expect(
      analysis.classFieldType(graphHandle, '_storeController'),
      'SceneStoreController',
    );
    expect(
      analysis.hasTopLevelFunction(graph, 'sceneControllerGraphActions'),
      isFalse,
    );
    expect(
      analysis.hasTopLevelFunction(
        graph,
        'sceneControllerGraphEditTextRequests',
      ),
      isFalse,
    );
    expect(
      analysis.hasTopLevelFunction(
        graph,
        'sceneControllerGraphPreviewDeltaResolver',
      ),
      isFalse,
    );
    expect(
      analysis.hasTopLevelFunction(
        graph,
        'sceneControllerGraphEnsurePublicSideEffectAllowed',
      ),
      isFalse,
    );
    expect(
      analysis.hasTopLevelFunction(graph, 'sceneControllerGraphIsDisposed'),
      isFalse,
    );
    expect(
      analysis.hasTopLevelFunction(graph, 'disposeSceneControllerGraph'),
      isFalse,
    );
    expect(
      analysis.hasTopLevelFunction(
        graph,
        'detachSceneControllerGraphInternalAccess',
      ),
      isFalse,
    );
    expect(
      analysis.containsMethodInvocation(
        graphAssembly,
        target: 'interactionRuntime',
        methodName: 'captureFramePreview',
      ),
      isFalse,
    );
    expect(
      analysis.containsMethodInvocation(
        graphAssembly,
        target: 'interactionRuntime',
        methodName: 'previewDeltaForNode',
      ),
      isFalse,
    );
    expect(
      analysis.containsIdentifier(graph.unit, retiredInteractionAccessReader),
      isFalse,
    );
    expect(
      analysis.containsIdentifier(
        internalAccess.unit,
        retiredInteractionAccessHelper,
      ),
      isFalse,
    );
    expect(
      analysis.containsIdentifier(
        internalAccess.unit,
        retiredInteractionAccessReader,
      ),
      isFalse,
    );
    expect(
      analysis.containsIdentifier(graph.unit, retiredInteractionContext),
      isFalse,
    );
    expect(
      analysis.containsIdentifier(
        interactionRuntime.unit,
        retiredDebugMoveSession,
      ),
      isFalse,
    );
    expect(
      analysis.classFieldType(interactionOwnerClass, '_ownerListenable'),
      'Listenable',
    );
    expect(
      analysis.classFieldType(interactionOwnerClass, '_config'),
      'SceneControllerInteractionConfig',
    );
    expect(
      analysis.classFieldType(interactionOwnerClass, '_runtime'),
      'SceneControllerInteractionRuntime',
    );
    expect(
      analysis.namedFormalParameterType(
        analysis.findConstructor(interactionOwnerClass),
        'ownerListenable',
      ),
      'Listenable',
    );
    expect(
      analysis.namedFormalParameterType(
        analysis.findConstructor(interactionOwnerClass),
        'config',
      ),
      'SceneControllerInteractionConfig',
    );
    expect(
      analysis.namedFormalParameterType(
        analysis.findConstructor(interactionOwnerClass),
        'runtime',
      ),
      'SceneControllerInteractionRuntime',
    );

    expect(
      analysis.implementsInterface(sceneViewRuntimeClass, 'SceneViewRuntime'),
      isTrue,
    );
    expect(mainSceneRenderReadClass.name.lexeme, isNotEmpty);
    expect(overlayPreviewReadClass.name.lexeme, isNotEmpty);
    expect(
      analysis.implementsInterface(
        pointerSessionClass,
        'SceneViewPointerSession',
      ),
      isTrue,
    );
    expect(
      analysis.variableInitializerConstructorType(
        analysis.findMethod(sceneViewRuntimeClass, 'createPointerSession'),
        'session',
      ),
      'SceneControllerPointerSession',
    );
    expect(
      analysis.namedFormalParameterType(
        analysis.findConstructor(sceneViewRuntimeClass),
        'movePreviewRead',
      ),
      'InteractiveMovePreviewRead Function()',
    );
    expect(
      analysis.containsMethodInvocation(
        analysis.findMethod(sceneViewRuntimeClass, 'createPointerSession'),
        target: '_interactionRuntime',
        methodName: 'registerPointerSession',
      ),
      isTrue,
    );
    expect(
      analysis.namedTypeOf(
        analysis
            .findGetter(sceneViewRuntimeClass, 'mainSceneRenderRead')
            .returnType,
      ),
      'SceneViewMainSceneRenderRead',
    );
    expect(
      analysis.namedTypeOf(
        analysis
            .findGetter(sceneViewRuntimeClass, 'overlayPreviewRead')
            .returnType,
      ),
      'SceneViewOverlayPreviewRead',
    );

    expect(
      analysis.hasImport(
        sceneViewInteractive,
        '../interactive/scene_controller.dart',
      ),
      isTrue,
    );
    expect(
      analysis.namedConstructorArgumentInvocationTarget(
        analysis.findSingleConstructorInvocation(
          analysis.findMethod(sceneViewInteractiveClass, 'build'),
          'SceneViewRuntimeHost',
        ),
        'runtime',
      ),
      'sceneControllerViewRuntimeOf',
    );
    expect(
      analysis.namedConstructorArgumentSingleIdentifier(
        analysis.findSingleConstructorInvocation(
          analysis.findMethod(sceneViewInteractiveClass, 'build'),
          'SceneViewRuntimeHost',
        ),
        'runtime',
      ),
      'controller',
    );
    expect(
      analysis.variableInitializerPropertyChain(
        analysis.findMethod(runtimeHostState, 'build'),
        'mainSceneRenderRead',
      ),
      '_activeRuntime.mainSceneRenderRead',
    );
    expect(
      analysis.variableInitializerPropertyChain(
        analysis.findMethod(runtimeHostState, 'build'),
        'overlayPreviewRead',
      ),
      '_activeRuntime.overlayPreviewRead',
    );

    expect(
      analysis.hasImport(runtimeHost, '../interactive/scene_controller.dart'),
      isFalse,
    );
    expect(
      analysis.classFieldType(runtimeHostClass, 'runtime'),
      'SceneViewRuntime',
    );
    expect(
      analysis.namedTypeOf(
        analysis
            .findMethod(runtimeHostState, '_createReplacementPointerSession')
            .returnType,
      ),
      'SceneViewPointerSession',
    );
    analysis.expectRuntimeHostSwapOrder(
      analysis.findMethod(runtimeHostState, 'didUpdateWidget'),
    );
    expect(
      analysis.namedConstructorArgumentIdentifier(
        analysis.findSingleConstructorInvocation(
          analysis.findMethod(runtimeHostState, 'build'),
          'SceneViewInteractiveOverlayPainter',
        ),
        'overlayPreviewRead',
      ),
      'overlayPreviewRead',
    );
    expect(
      analysis.namedConstructorArgumentIdentifier(
        analysis.findSingleConstructorInvocation(
          analysis.findMethod(runtimeHostState, 'build'),
          'SceneViewRenderSurface',
        ),
        'mainSceneRenderRead',
      ),
      'mainSceneRenderRead',
    );

    expect(
      analysis.hasImport(renderSurface, '../interactive/scene_controller.dart'),
      isFalse,
    );
    expect(
      analysis.namedFormalParameterType(
        analysis.findConstructor(renderSurfaceClass),
        'mainSceneRenderRead',
      ),
      'SceneViewMainSceneRenderRead',
    );
    expect(
      analysis.hasImport(
        overlayPainter,
        '../interactive/scene_controller.dart',
      ),
      isFalse,
    );
    expect(
      analysis.classFieldType(
        analysis.findClass(
          overlayPainter,
          'SceneViewInteractiveOverlayPainter',
        ),
        'overlayPreviewRead',
      ),
      'SceneViewOverlayPreviewRead',
    );
    expect(
      analysis.containsConstructorInvocation(
        renderSurface.unit,
        'SceneViewInteractiveOverlayPainter',
      ),
      isFalse,
    );
  });
}

final class _ArchitectureAnalysis {
  _ArchitectureAnalysis({required this.repoRootPath});

  final String repoRootPath;
  final Map<String, ParseStringResult> _parsedCache =
      <String, ParseStringResult>{};

  ParseStringResult parsed(String relativePath) {
    return _parsedCache.putIfAbsent(relativePath, () {
      final absolutePath = _absolutePath(relativePath);
      return parseString(
        path: absolutePath,
        content: File(absolutePath).readAsStringSync(),
        throwIfDiagnostics: true,
      );
    });
  }

  void expectMissingFile(String relativePath) {
    expect(
      File(_absolutePath(relativePath)).existsSync(),
      isFalse,
      reason: '$relativePath must stay deleted.',
    );
  }

  ClassDeclaration findClass(ParseStringResult parsed, String className) {
    for (final declaration
        in parsed.unit.declarations.whereType<ClassDeclaration>()) {
      if (declaration.name.lexeme == className) {
        return declaration;
      }
    }
    throw StateError('Class not found: $className');
  }

  FunctionDeclaration findTopLevelFunction(
    ParseStringResult parsed,
    String functionName,
  ) {
    for (final declaration
        in parsed.unit.declarations.whereType<FunctionDeclaration>()) {
      if (declaration.name.lexeme == functionName) {
        return declaration;
      }
    }
    throw StateError('Top-level function not found: $functionName');
  }

  bool hasTopLevelFunction(ParseStringResult parsed, String functionName) {
    return parsed.unit.declarations.whereType<FunctionDeclaration>().any(
      (declaration) => declaration.name.lexeme == functionName,
    );
  }

  MethodDeclaration findMethod(
    ClassDeclaration declaration,
    String methodName,
  ) {
    for (final method in declaration.members.whereType<MethodDeclaration>()) {
      if (method.name.lexeme == methodName) {
        return method;
      }
    }
    throw StateError(
      'Method not found in ${declaration.name.lexeme}: $methodName',
    );
  }

  MethodDeclaration findGetter(
    ClassDeclaration declaration,
    String getterName,
  ) {
    for (final method in declaration.members.whereType<MethodDeclaration>()) {
      if (method.isGetter && method.name.lexeme == getterName) {
        return method;
      }
    }
    throw StateError(
      'Getter not found in ${declaration.name.lexeme}: $getterName',
    );
  }

  ConstructorDeclaration findConstructor(ClassDeclaration declaration) {
    final constructors = declaration.members
        .whereType<ConstructorDeclaration>();
    if (constructors.length != 1) {
      throw StateError(
        'Expected exactly one constructor in ${declaration.name.lexeme}, found ${constructors.length}.',
      );
    }
    return constructors.single;
  }

  String? classFieldType(ClassDeclaration declaration, String fieldName) {
    for (final field in declaration.members.whereType<FieldDeclaration>()) {
      for (final variable in field.fields.variables) {
        if (variable.name.lexeme == fieldName) {
          return namedTypeOf(field.fields.type);
        }
      }
    }
    throw StateError(
      'Field not found in ${declaration.name.lexeme}: $fieldName',
    );
  }

  bool hasImport(ParseStringResult parsed, String suffix) {
    for (final directive
        in parsed.unit.directives.whereType<ImportDirective>()) {
      final uri = directive.uri.stringValue;
      if (uri == suffix) {
        return true;
      }
    }
    return false;
  }

  bool implementsInterface(ClassDeclaration declaration, String interfaceName) {
    final clause = declaration.implementsClause;
    if (clause == null) {
      return false;
    }
    return clause.interfaces.any((type) => namedTypeOf(type) == interfaceName);
  }

  bool hasUnnamedFactoryInvocation(AstNode node, String functionName) {
    final collector = _InvocationCollector();
    node.accept(collector);
    return collector.methodInvocations.any(
          (invocation) =>
              invocation.target == null &&
              invocation.methodName.name == functionName,
        ) ||
        collector.functionInvocations.any(
          (invocation) => _expressionName(invocation.function) == functionName,
        );
  }

  bool containsInvocation(AstNode node, String functionName) {
    return hasUnnamedFactoryInvocation(node, functionName);
  }

  bool containsConstructorInvocation(AstNode node, String className) {
    final collector = _InvocationCollector();
    node.accept(collector);
    return collector.instanceCreations.any(
          (creation) => _createdTypeName(creation) == className,
        ) ||
        collector.methodInvocations.any(
          (invocation) =>
              invocation.target == null &&
              invocation.methodName.name == className,
        ) ||
        collector.functionInvocations.any(
          (invocation) => _expressionName(invocation.function) == className,
        );
  }

  bool containsIdentifier(AstNode node, String identifier) {
    final collector = _IdentifierCollector();
    node.accept(collector);
    return collector.identifiers.contains(identifier);
  }

  bool containsMethodInvocation(
    AstNode node, {
    required String target,
    required String methodName,
  }) {
    final collector = _InvocationCollector();
    node.accept(collector);
    return collector.methodInvocations.any(
      (invocation) =>
          expressionChain(invocation.target) == target &&
          invocation.methodName.name == methodName,
    );
  }

  bool containsAssignment(
    AstNode node, {
    required String leftHandSide,
    required String rightHandSide,
  }) {
    final collector = _AssignmentCollector();
    node.accept(collector);
    return collector.assignments.any(
      (expression) =>
          expression.operator.lexeme == '=' &&
          expressionChain(expression.leftHandSide) == leftHandSide &&
          expressionChain(expression.rightHandSide) == rightHandSide,
    );
  }

  void expectRuntimeHostSwapOrder(MethodDeclaration method) {
    final statements = blockStatements(method.body);
    final guardIndex = statements.indexWhere(
      (statement) => isEqualityGuardReturn(
        statement,
        leftOperand: '_activeRuntime',
        rightOperand: 'widget.runtime',
      ),
    );
    if (guardIndex < 0) {
      throw StateError(
        'Runtime equality guard not found in ${method.name.lexeme}.',
      );
    }
    for (final statement in statements.take(guardIndex)) {
      expect(
        containsInvocation(statement, '_createReplacementPointerSession'),
        isFalse,
      );
      expect(
        containsMethodInvocation(
          statement,
          target: '_pointerHost',
          methodName: 'replacePointerSession',
        ),
        isFalse,
      );
      expect(
        containsAssignment(
          statement,
          leftHandSide: '_activeRuntime',
          rightHandSide: 'widget.runtime',
        ),
        isFalse,
      );
    }

    final nextPointerSessionIndex = _indexWhereAfter(
      statements,
      start: guardIndex + 1,
      predicate: (statement) =>
          localVariableInitializerSingleArgumentChain(
                statement,
                variableName: 'nextPointerSession',
              ) ==
              'widget.runtime' &&
          localVariableInitializerInvocationTarget(
                statement,
                variableName: 'nextPointerSession',
              ) ==
              '_createReplacementPointerSession',
    );
    final replacePointerSessionIndex = _indexWhereAfter(
      statements,
      start: nextPointerSessionIndex + 1,
      predicate: (statement) => statementInvokesMethod(
        statement,
        target: '_pointerHost',
        methodName: 'replacePointerSession',
        singleArgument: 'nextPointerSession',
      ),
    );
    final runtimeAssignmentIndex = _indexWhereAfter(
      statements,
      start: replacePointerSessionIndex + 1,
      predicate: (statement) => isAssignmentStatement(
        statement,
        leftHandSide: '_activeRuntime',
        rightHandSide: 'widget.runtime',
      ),
    );

    expect(nextPointerSessionIndex > guardIndex, isTrue);
    expect(replacePointerSessionIndex > nextPointerSessionIndex, isTrue);
    expect(runtimeAssignmentIndex > replacePointerSessionIndex, isTrue);
  }

  int _indexWhereAfter(
    List<Statement> statements, {
    required int start,
    required bool Function(Statement statement) predicate,
  }) {
    for (var index = start; index < statements.length; index += 1) {
      final statement = statements[index];
      try {
        if (predicate(statement)) {
          return index;
        }
      } on StateError {
        continue;
      }
    }
    throw StateError(
      'Expected statement pattern not found after index $start.',
    );
  }

  Expression findSingleConstructorInvocation(AstNode node, String className) {
    final collector = _InvocationCollector();
    node.accept(collector);
    final matches = <Expression>[
      ...collector.instanceCreations.where(
        (creation) => _createdTypeName(creation) == className,
      ),
      ...collector.methodInvocations.where(
        (invocation) =>
            invocation.target == null &&
            invocation.methodName.name == className,
      ),
      ...collector.functionInvocations.where(
        (invocation) => _expressionName(invocation.function) == className,
      ),
    ];
    if (matches.length != 1) {
      throw StateError(
        'Expected exactly one $className invocation, found ${matches.length}.',
      );
    }
    return matches.single;
  }

  Expression namedConstructorArgument(
    Expression creation,
    String argumentName,
  ) {
    final arguments = switch (creation) {
      InstanceCreationExpression(:final argumentList) => argumentList.arguments,
      MethodInvocation(:final argumentList) => argumentList.arguments,
      FunctionExpressionInvocation(:final argumentList) =>
        argumentList.arguments,
      _ => throw StateError(
        'Expected constructor-like invocation, found: $creation',
      ),
    };
    for (final argument in arguments.whereType<NamedExpression>()) {
      if (argument.name.label.name == argumentName) {
        return argument.expression;
      }
    }
    throw StateError('Named argument not found: $argumentName');
  }

  bool invokesTopLevelFunction(Expression expression, String functionName) {
    if (expression is MethodInvocation) {
      return expression.target == null &&
          expression.methodName.name == functionName;
    }
    if (expression is FunctionExpressionInvocation) {
      return _expressionName(expression.function) == functionName;
    }
    return false;
  }

  String singleIdentifierArgument(Expression expression) {
    final arguments = switch (expression) {
      MethodInvocation(:final argumentList) => argumentList.arguments,
      FunctionExpressionInvocation(:final argumentList) =>
        argumentList.arguments,
      _ => throw StateError(
        'Expression is not a callable invocation: $expression',
      ),
    };
    if (arguments.length != 1 || arguments.single is! SimpleIdentifier) {
      throw StateError('Expected a single identifier argument: $expression');
    }
    return (arguments.single as SimpleIdentifier).name;
  }

  String namedConstructorArgumentIdentifier(
    Expression creation,
    String argumentName,
  ) {
    final argument = namedConstructorArgument(creation, argumentName);
    return switch (argument) {
      SimpleIdentifier(:final name) => name,
      _ => throw StateError(
        'Expected $argumentName to be a simple identifier: $argument',
      ),
    };
  }

  String namedConstructorArgumentInvocationTarget(
    Expression creation,
    String argumentName,
  ) {
    final argument = namedConstructorArgument(creation, argumentName);
    if (!invokesTopLevelFunction(argument, _expressionName(argument) ?? '')) {
      final invocationName = switch (argument) {
        MethodInvocation(:final methodName) => methodName.name,
        FunctionExpressionInvocation(:final function) => _expressionName(
          function,
        ),
        _ => null,
      };
      if (invocationName != null) {
        return invocationName;
      }
    }
    return switch (argument) {
      MethodInvocation(:final methodName) => methodName.name,
      FunctionExpressionInvocation(:final function) =>
        _expressionName(function) ??
            (throw StateError('Invocation target not found: $argument')),
      _ => throw StateError(
        'Expected $argumentName to be an invocation: $argument',
      ),
    };
  }

  String namedConstructorArgumentSingleIdentifier(
    Expression creation,
    String argumentName,
  ) {
    return singleIdentifierArgument(
      namedConstructorArgument(creation, argumentName),
    );
  }

  String? namedFormalParameterType(
    ConstructorDeclaration constructor,
    String parameterName,
  ) {
    for (final parameter in constructor.parameters.parameters) {
      if (parameter.name?.lexeme != parameterName) {
        continue;
      }
      return switch (parameter) {
        SimpleFormalParameter(:final type) => namedTypeOf(type),
        DefaultFormalParameter(:final parameter) =>
          namedFormalParameterTypeFromNode(parameter),
        FieldFormalParameter(:final type) => namedTypeOf(type),
        SuperFormalParameter(:final type) => namedTypeOf(type),
        _ => null,
      };
    }
    throw StateError('Constructor parameter not found: $parameterName');
  }

  String? namedTypeOf(TypeAnnotation? type) {
    return type?.toSource();
  }

  List<Statement> blockStatements(FunctionBody body) {
    if (body is! BlockFunctionBody) {
      throw StateError('Expected block function body, found: $body');
    }
    return body.block.statements;
  }

  String variableInitializerConstructorType(AstNode node, String variableName) {
    final initializer = variableInitializer(node, variableName);
    return constructorLikeName(initializer) ??
        (throw StateError(
          'Expected $variableName to be initialized with a constructor-like invocation: $initializer',
        ));
  }

  String variableInitializerPropertyChain(AstNode node, String variableName) {
    return expressionChain(variableInitializer(node, variableName)) ??
        (throw StateError('Property chain not found for $variableName'));
  }

  String returnedExpressionConstructorType(AstNode node) {
    final expression = singleReturnedExpression(node);
    return constructorLikeName(expression) ??
        (throw StateError(
          'Expected a returned constructor-like invocation: $expression',
        ));
  }

  Expression variableInitializer(AstNode node, String variableName) {
    for (final statement in _variableDeclarationStatements(node)) {
      for (final variable in statement.variables) {
        if (variable.name.lexeme == variableName) {
          return variable.initializer ??
              (throw StateError('Initializer not found for $variableName'));
        }
      }
    }
    throw StateError('Variable not found: $variableName');
  }

  String returnedRecordFieldConstructorType(AstNode node, String fieldName) {
    final expression = returnedRecordFieldExpression(node, fieldName);
    return constructorLikeName(expression) ??
        (throw StateError(
          'Expected return field $fieldName to be a constructor-like invocation: $expression',
        ));
  }

  String? returnedRecordFieldIdentifier(AstNode node, String fieldName) {
    final expression = returnedRecordFieldExpression(node, fieldName);
    return switch (expression) {
      SimpleIdentifier(:final name) => name,
      _ => null,
    };
  }

  Expression returnedRecordFieldExpression(AstNode node, String fieldName) {
    final expression = singleReturnedExpression(node);
    if (expression is! RecordLiteral) {
      throw StateError('Expected a returned record literal: $expression');
    }
    for (final field in expression.fields) {
      if (field is NamedExpression && field.name.label.name == fieldName) {
        return field.expression;
      }
    }
    throw StateError('Returned record field not found: $fieldName');
  }

  Expression singleReturnedExpression(AstNode node) {
    final returnStatements = <ReturnStatement>[];
    node.visitChildren(_ReturnCollector(returnStatements));
    if (returnStatements.length != 1) {
      throw StateError(
        'Expected exactly one return statement, found ${returnStatements.length}.',
      );
    }
    return returnStatements.single.expression ??
        (throw StateError('Expected return expression in $node.'));
  }

  bool isEqualityGuardReturn(
    Statement statement, {
    required String leftOperand,
    required String rightOperand,
  }) {
    if (statement is! IfStatement) {
      return false;
    }
    final condition = statement.expression;
    if (condition is! BinaryExpression ||
        condition.operator.lexeme != '==' ||
        expressionChain(condition.leftOperand) != leftOperand ||
        expressionChain(condition.rightOperand) != rightOperand) {
      return false;
    }
    return switch (statement.thenStatement) {
      Block(:final statements) =>
        statements.length == 1 && statements.single is ReturnStatement,
      ReturnStatement() => true,
      _ => false,
    };
  }

  String localVariableInitializerIdentifier(
    Statement statement, {
    required String variableName,
  }) {
    if (statement is! VariableDeclarationStatement) {
      throw StateError('Expected variable declaration statement: $statement');
    }
    for (final variable in statement.variables.variables) {
      if (variable.name.lexeme != variableName) {
        continue;
      }
      return expressionChain(variable.initializer) ??
          (throw StateError('Initializer chain not found for $variableName'));
    }
    throw StateError('Variable not found: $variableName');
  }

  String localVariableInitializerSingleArgumentChain(
    Statement statement, {
    required String variableName,
  }) {
    if (statement is! VariableDeclarationStatement) {
      throw StateError('Expected variable declaration statement: $statement');
    }
    for (final variable in statement.variables.variables) {
      if (variable.name.lexeme != variableName) {
        continue;
      }
      final initializer = variable.initializer;
      final arguments = switch (initializer) {
        MethodInvocation(:final argumentList) => argumentList.arguments,
        FunctionExpressionInvocation(:final argumentList) =>
          argumentList.arguments,
        _ => throw StateError(
          'Expected invocation initializer for $variableName: $initializer',
        ),
      };
      if (arguments.length != 1) {
        throw StateError(
          'Expected a single argument in initializer for $variableName: $initializer',
        );
      }
      return expressionChain(arguments.single) ??
          (throw StateError('Argument chain not found for $variableName'));
    }
    throw StateError('Variable not found: $variableName');
  }

  String localVariableInitializerInvocationTarget(
    Statement statement, {
    required String variableName,
  }) {
    if (statement is! VariableDeclarationStatement) {
      throw StateError('Expected variable declaration statement: $statement');
    }
    for (final variable in statement.variables.variables) {
      if (variable.name.lexeme != variableName) {
        continue;
      }
      final initializer = variable.initializer;
      return switch (initializer) {
        MethodInvocation(:final methodName) => methodName.name,
        FunctionExpressionInvocation(:final function) =>
          _expressionName(function) ??
              (throw StateError('Invocation target not found: $initializer')),
        _ => throw StateError(
          'Expected invocation initializer for $variableName: $initializer',
        ),
      };
    }
    throw StateError('Variable not found: $variableName');
  }

  bool statementInvokesMethod(
    Statement statement, {
    required String target,
    required String methodName,
    required String singleArgument,
  }) {
    if (statement is! ExpressionStatement) {
      return false;
    }
    final expression = statement.expression;
    if (expression is! MethodInvocation ||
        expression.methodName.name != methodName ||
        expressionChain(expression.target) != target) {
      return false;
    }
    if (expression.argumentList.arguments.length != 1) {
      return false;
    }
    return expressionChain(expression.argumentList.arguments.single) ==
        singleArgument;
  }

  bool isAssignmentStatement(
    Statement statement, {
    required String leftHandSide,
    required String rightHandSide,
  }) {
    if (statement is! ExpressionStatement) {
      return false;
    }
    final expression = statement.expression;
    if (expression is! AssignmentExpression ||
        expression.operator.lexeme != '=') {
      return false;
    }
    return expressionChain(expression.leftHandSide) == leftHandSide &&
        expressionChain(expression.rightHandSide) == rightHandSide;
  }

  String _absolutePath(String relativePath) => '$repoRootPath/$relativePath';

  String? namedFormalParameterTypeFromNode(FormalParameter parameter) {
    return switch (parameter) {
      SimpleFormalParameter(:final type) => namedTypeOf(type),
      FieldFormalParameter(:final type) => namedTypeOf(type),
      SuperFormalParameter(:final type) => namedTypeOf(type),
      _ => null,
    };
  }

  String? _createdTypeName(InstanceCreationExpression creation) {
    return namedTypeOf(creation.constructorName.type);
  }

  String? constructorLikeName(Expression expression) {
    if (expression is InstanceCreationExpression) {
      return _createdTypeName(expression);
    }
    if (expression is MethodInvocation && expression.target == null) {
      return expression.methodName.name;
    }
    if (expression is FunctionExpressionInvocation) {
      return _expressionName(expression.function);
    }
    return null;
  }

  String? _expressionName(Expression expression) {
    if (expression is SimpleIdentifier) {
      return expression.name;
    }
    if (expression is PrefixedIdentifier) {
      return expression.identifier.name;
    }
    return null;
  }

  Iterable<VariableDeclarationList> _variableDeclarationStatements(
    AstNode node,
  ) {
    final collector = _VariableDeclarationCollector();
    node.accept(collector);
    return collector.declarations;
  }

  String? expressionChain(Expression? expression) {
    if (expression is SimpleIdentifier) {
      return expression.name;
    }
    if (expression is PrefixedIdentifier) {
      return '${expression.prefix.name}.${expression.identifier.name}';
    }
    if (expression is PropertyAccess) {
      final target = expressionChain(expression.target);
      if (target == null) {
        return null;
      }
      return '$target.${expression.propertyName.name}';
    }
    return null;
  }
}

final class _InvocationCollector extends RecursiveAstVisitor<void> {
  final List<InstanceCreationExpression> instanceCreations =
      <InstanceCreationExpression>[];
  final List<MethodInvocation> methodInvocations = <MethodInvocation>[];
  final List<FunctionExpressionInvocation> functionInvocations =
      <FunctionExpressionInvocation>[];

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    functionInvocations.add(node);
    super.visitFunctionExpressionInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    instanceCreations.add(node);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    methodInvocations.add(node);
    super.visitMethodInvocation(node);
  }
}

final class _IdentifierCollector extends RecursiveAstVisitor<void> {
  final Set<String> identifiers = <String>{};

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    identifiers.add(node.name);
    super.visitSimpleIdentifier(node);
  }
}

final class _AssignmentCollector extends RecursiveAstVisitor<void> {
  final List<AssignmentExpression> assignments = <AssignmentExpression>[];

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    assignments.add(node);
    super.visitAssignmentExpression(node);
  }
}

final class _ReturnCollector extends RecursiveAstVisitor<void> {
  _ReturnCollector(this.returns);

  final List<ReturnStatement> returns;

  @override
  void visitReturnStatement(ReturnStatement node) {
    returns.add(node);
    super.visitReturnStatement(node);
  }
}

final class _VariableDeclarationCollector extends RecursiveAstVisitor<void> {
  final List<VariableDeclarationList> declarations =
      <VariableDeclarationList>[];

  @override
  void visitVariableDeclarationList(VariableDeclarationList node) {
    declarations.add(node);
    super.visitVariableDeclarationList(node);
  }
}
