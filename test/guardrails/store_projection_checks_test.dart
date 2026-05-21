@Timeout(Duration(minutes: 2))
library;

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:test/test.dart';

import '../../tool/guardrails/src/store_projection_checks.dart';
import '../support/guardrail_fixture_scan.dart';

void main() {
  _testLiveStateFields();
  _testTopLevelLiveStateFields();
  _testProjectionConstruction();
  _testProjectionInvocations();
  _testRuntimeFacadeProjectionInvocations();
  _testProjectionReadPathAllowances();
  _testFutureHotPathProjectionOwners();
  _testProjectionReturns();
}

void _testLiveStateFields() {
  test('live document state check rejects nullable and generic fields', () {
    return expectLater(
      _expectLiveStateViolations(
        {
          'lib/src/runtime/bad_nullable_document.dart': '''
import 'package:iwb_canvas_engine/src/api/canvas_document.dart';

class Bad {
  CanvasDocument? document;
}
''',
          'lib/src/store/bad_document_list.dart': '''
import 'package:iwb_canvas_engine/src/api/canvas_document.dart';

class Bad {
  List<CanvasDocument> documents = const [];
}
''',
        },
        containsAll([
          'lib/src/runtime/bad_nullable_document.dart',
          'lib/src/store/bad_document_list.dart',
        ]),
      ),
      completes,
    );
  });
}

void _testTopLevelLiveStateFields() {
  test('live document state check rejects top-level document state', () {
    return expectLater(
      _expectLiveStateViolations({
        'lib/src/runtime/bad_top_level_document.dart': '''
import 'package:iwb_canvas_engine/src/api/canvas_document.dart';

CanvasDocument? cachedDocument;
''',
      }, contains('lib/src/runtime/bad_top_level_document.dart')),
      completes,
    );
  });
}

void _testProjectionConstruction() {
  test('projection read-path check rejects direct document construction', () {
    return expectLater(
      _expectProjectionViolations({
        'lib/src/runtime/bad_projection_constructor.dart': '''
import 'package:iwb_canvas_engine/src/api/canvas_document.dart';

CanvasDocument buildProjection() {
  return CanvasDocument();
}
''',
      }, contains('lib/src/runtime/bad_projection_constructor.dart')),
      completes,
    );
  });
}

void _testProjectionInvocations() {
  test('projection read-path check rejects non-read document invocations', () {
    return expectLater(
      _expectSingleProjectionViolation(
        {
          'lib/src/store/bad_projection_invocation.dart': '''
import 'package:iwb_canvas_engine/src/store/committed_document.dart';
import 'package:iwb_canvas_engine/src/store/document_projection_cache.dart';

CommittedDocument? admittedDocument;

void hotPathProjection(DocumentProjectionCache cache) {
  cache.projectionFor(admittedDocument!);
}
''',
        },
        path: 'lib/src/store/bad_projection_invocation.dart',
        message: 'public document projection invocation is read-path-only',
      ),
      completes,
    );
  });
}

void _testRuntimeFacadeProjectionInvocations() {
  test('projection read-path check rejects runtime facade bypasses', () {
    return expectLater(
      _expectProjectionViolations({
        'lib/src/api/canvas_runtime_bad_projection.dart': '''
import 'package:iwb_canvas_engine/src/api/canvas_document.dart';

class BadRuntimeFacade {
  CanvasDocument? document;

  CanvasDocument readDocument() {
    return document!;
  }

  CanvasDocument hotPathProjection() {
    return readDocument();
  }
}
''',
      }, contains('lib/src/api/canvas_runtime_bad_projection.dart')),
      completes,
    );
  });

  test(
    'projection read-path check rejects similarly prefixed facade helpers',
    () {
      return expectLater(
        _expectProjectionViolations({
          'lib/src/api/canvas_runtime_debug.dart': '''
import 'package:iwb_canvas_engine/src/api/canvas_document.dart';

class BadRuntimeDebug {
  CanvasDocument? document;

  CanvasDocument readDocument() {
    return document!;
  }

  CanvasDocument hotPathProjection() {
    return readDocument();
  }
}
''',
        }, contains('lib/src/api/canvas_runtime_debug.dart')),
        completes,
      );
    },
  );
}

void _testProjectionReadPathAllowances() {
  test('projection read-path allowance is owner-scoped', () {
    final unit = parseString(
      content: '''
class RuntimeRoot {
  Object readDocument() {
    final retained = () {
      return cache.projectionFor(document);
    };

    return cache.projectionFor(document);
  }
}
''',
    ).unit;
    final visitor = _ProjectionForInvocationVisitor();
    unit.accept(visitor);
    final invocations = visitor.invocations;

    expect(invocations, hasLength(2));
    expect(
      isProjectionReadPathAllowedForGuardrailTest(
        'lib/src/runtime/runtime_root.dart',
        invocations.first,
      ),
      isFalse,
    );
    expect(
      isProjectionReadPathAllowedForGuardrailTest(
        'lib/src/runtime/runtime_root.dart',
        invocations.last,
      ),
      isTrue,
    );

    final wrongOwner = parseString(
      content: '''
class RuntimeRootDebug {
  Object readDocument() {
    return cache.projectionFor(document);
  }
}
''',
    ).unit;
    final wrongOwnerVisitor = _ProjectionForInvocationVisitor();
    wrongOwner.accept(wrongOwnerVisitor);

    expect(
      isProjectionReadPathAllowedForGuardrailTest(
        'lib/src/runtime/runtime_root.dart',
        wrongOwnerVisitor.invocations.single,
      ),
      isFalse,
    );
  });
}

final class _ProjectionForInvocationVisitor extends RecursiveAstVisitor<void> {
  final List<MethodInvocation> invocations = [];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'projectionFor') {
      invocations.add(node);
    }
    super.visitMethodInvocation(node);
  }
}

void _testFutureHotPathProjectionOwners() {
  test('projection read-path check rejects frame hot-path projection', () {
    return expectLater(
      _expectProjectionViolations({
        'lib/src/frame/bad_frame_projection.dart': '''
import 'package:iwb_canvas_engine/src/api/canvas_document.dart';

CanvasDocument buildPaintPlanProjection() {
  return CanvasDocument();
}
''',
      }, contains('lib/src/frame/bad_frame_projection.dart')),
      completes,
    );
  });
}

void _testProjectionReturns() {
  test('projection read-path check rejects non-read document returns', () {
    return expectLater(
      _expectProjectionViolations({
        'lib/src/store/bad_projection_return.dart': '''
import 'package:iwb_canvas_engine/src/api/canvas_document.dart';

CanvasDocument leakProjection(CanvasDocument document) {
  return document;
}
''',
      }, contains('lib/src/store/bad_projection_return.dart')),
      completes,
    );
  });
}

Future<void> _expectLiveStateViolations(
  Map<String, String> files,
  Matcher pathsMatcher,
) {
  return withGuardrailFixtureScan(files, (scan) async {
    final violations = await checkNoPublicDocumentLiveState(
      sources: scan.sources,
      analysisIncludedPaths: scan.analysisIncludedPaths,
    );

    expect(violations.map((violation) => violation.path), pathsMatcher);
  });
}

Future<void> _expectProjectionViolations(
  Map<String, String> files,
  Matcher pathsMatcher,
) {
  return withGuardrailFixtureScan(files, (scan) async {
    final violations = await checkProjectionOnlyExplicitReadPaths(
      sources: scan.sources,
      analysisIncludedPaths: scan.analysisIncludedPaths,
    );

    expect(violations.map((violation) => violation.path), pathsMatcher);
  });
}

Future<void> _expectSingleProjectionViolation(
  Map<String, String> files, {
  required String path,
  required String message,
}) {
  return withGuardrailFixtureScan(files, (scan) async {
    final violations = await checkProjectionOnlyExplicitReadPaths(
      sources: scan.sources,
      analysisIncludedPaths: scan.analysisIncludedPaths,
    );
    final matching = violations.where((violation) => violation.path == path);

    expect(matching, hasLength(1));
    expect(matching.single.message, message);
  });
}
