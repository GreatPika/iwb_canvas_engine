import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

// This guardrail uses analyzer resolution directly so relative imports,
// re-exports, and helper type references cannot bypass the dependency boundary
// by changing spelling.
// ignore_for_file: number-of-external-imports

void main() {
  test('typed edit effects avoid concrete downstream owner dependencies', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/edit/fixtures/typed_effects_no_frame_dependency_fixture.dart',
      ),
      completes,
    );
  });

  test(
    'edit-owned typed effects do not resolve concrete downstream owners',
    () async {
      expect(await _concreteDownstreamViolations(), isEmpty);
    },
  );
}

Future<List<String>> _concreteDownstreamViolations() async {
  final collection = AnalysisContextCollection(
    includedPaths: ['${Directory.current.path}/lib'],
  );
  final violations = <String>[];

  try {
    for (final file in _editSourceFiles()) {
      final context = collection.contextFor(file.absolute.path);
      final result = await context.currentSession.getResolvedUnit(
        file.absolute.path,
      );
      if (result is! ResolvedUnitResult) {
        violations.add('Could not resolve ${file.path}.');
        continue;
      }

      final visitor = _ConcreteDownstreamReferenceVisitor(file.path);
      result.unit.accept(visitor);
      violations.addAll(visitor.violations);
    }
  } finally {
    await collection.dispose();
  }

  return violations;
}

Iterable<File> _editSourceFiles() {
  return Directory(
    'lib/src/edit',
  ).listSync().whereType<File>().where((file) => file.path.endsWith('.dart'));
}

// The visitor keeps import and resolved symbol checks together because both
// spellings represent the same forbidden dependency boundary.
// ignore: coupling-between-object-classes
final class _ConcreteDownstreamReferenceVisitor
    extends RecursiveAstVisitor<void> {
  _ConcreteDownstreamReferenceVisitor(this.path);

  final String path;
  final Set<String> violations = {};
  final Set<DartType> _visitedTypes = {};

  @override
  void visitImportDirective(ImportDirective node) {
    final rawUri = node.uri.stringValue;
    final resolvedUri = node.libraryImport?.importedLibrary?.uri.toString();
    if (_isForbiddenImport(rawUri) || _isForbiddenImport(resolvedUri)) {
      violations.add('$path imports ${rawUri ?? resolvedUri}');
    }
    super.visitImportDirective(node);
  }

  @override
  void visitNamedType(NamedType node) {
    _recordElement(node.name.lexeme, node.element);
    _collectType(node.type);
    super.visitNamedType(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    _recordElement(node.name, node.element);
    super.visitSimpleIdentifier(node);
  }

  void _recordElement(String name, Element? element) {
    final libraryUri = element?.library?.uri.toString();
    if (_isForbiddenLibraryUri(libraryUri) || _isForbiddenOwnerName(name)) {
      violations.add('$path references $name from $libraryUri');
    }
  }

  // Analyzer type traversal needs to cover every resolved DartType shape in
  // one pass so generic/function/record references cannot hide forbidden
  // downstream owners behind helper APIs.
  // ignore: cyclomatic-complexity
  void _collectType(DartType? type) {
    if (type == null || !_visitedTypes.add(type)) {
      return;
    }
    _recordElement(type.getDisplayString(), type.element);

    switch (type) {
      case InterfaceType():
        for (final argument in type.typeArguments) {
          _collectType(argument);
        }
      case FunctionType():
        _collectType(type.returnType);
        for (final argument in type.normalParameterTypes) {
          _collectType(argument);
        }
        for (final argument in type.optionalParameterTypes) {
          _collectType(argument);
        }
        for (final argument in type.namedParameterTypes.values) {
          _collectType(argument);
        }
      case RecordType():
        for (final field in type.positionalFields) {
          _collectType(field.type);
        }
        for (final field in type.namedFields) {
          _collectType(field.type);
        }
      case TypeParameterType():
        _collectType(type.bound);
      default:
        break;
    }
  }
}

bool _isForbiddenImport(String? uri) {
  return _isForbiddenLibraryUri(uri) ||
      _forbiddenRelativeImports.any(
        (prefix) => uri?.startsWith(prefix) ?? false,
      );
}

bool _isForbiddenLibraryUri(String? uri) {
  return uri != null &&
      (_forbiddenLibraryFragments.any(uri.contains) ||
          uri.startsWith('package:flutter/'));
}

bool _isForbiddenOwnerName(String name) {
  return _forbiddenOwnerNames.contains(name);
}

const _forbiddenRelativeImports = {
  '../frame/',
  '../spatial/',
  '../resources/',
  '../interaction/',
  '../surface/',
};

const _forbiddenLibraryFragments = {
  '/src/frame/',
  '/src/spatial/',
  '/src/resources/',
  '/src/interaction/',
  '/src/surface/',
};

const _forbiddenOwnerNames = {
  'FrameEngine',
  'SpatialKernel',
  'ResourceKernel',
  'SurfaceResourceSession',
};
