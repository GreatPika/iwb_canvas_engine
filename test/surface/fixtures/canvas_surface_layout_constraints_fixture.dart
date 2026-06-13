import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

import '../../support/runtime_with_document.dart';

void main() {
  testWidgets('bounded CanvasSurface keeps paint host size', (tester) async {
    await _pumpBoundedSurface(tester);
    expect(tester.takeException(), isNull);
    expect(_paintHosts(), findsOneWidget);
    expect(
      tester.widget<CustomPaint>(_paintHosts()).size,
      const Size(100, 100),
    );
  });

  testWidgets('vertically unbounded CanvasSurface reports FlutterError', (
    tester,
  ) async {
    final error = await _takeVerticallyUnboundedSurfaceException(tester);
    expect(error, isA<FlutterError>());
    _expectBoundedLayoutError(error);
  });

  testWidgets('horizontally unbounded CanvasSurface reports FlutterError', (
    tester,
  ) async {
    final error = await _takeHorizontallyUnboundedSurfaceException(tester);
    expect(error, isA<FlutterError>());
    _expectBoundedLayoutError(error);
  });

  test('bounded layout rejection stays on the ordinary execution path', () {
    final paintSizeFor = _paintSizeForSource();

    expect(_ordinaryPathRequiredTokens(paintSizeFor), isEmpty);
    expect(_debugOnlyPathTokens(paintSizeFor), isEmpty);
    expect(_silentFallbackTokens(paintSizeFor), isEmpty);
  });
}

Future<void> _pumpBoundedSurface(WidgetTester tester) async {
  final runtime = runtimeWithDocument(CanvasDocument());
  addTearDown(runtime.dispose);

  await tester.pumpWidget(
    _DirectionalHost(
      child: Center(
        child: SizedBox(
          width: 100,
          height: 100,
          child: CanvasSurface(runtime: runtime, interactive: false),
        ),
      ),
    ),
  );
}

Future<Object?> _takeVerticallyUnboundedSurfaceException(
  WidgetTester tester,
) async {
  final runtime = runtimeWithDocument(CanvasDocument());
  addTearDown(runtime.dispose);

  await tester.pumpWidget(
    _DirectionalHost(
      child: ListView(
        children: [CanvasSurface(runtime: runtime, interactive: false)],
      ),
    ),
  );

  return tester.takeException();
}

Future<Object?> _takeHorizontallyUnboundedSurfaceException(
  WidgetTester tester,
) async {
  final runtime = runtimeWithDocument(CanvasDocument());
  addTearDown(runtime.dispose);

  await tester.pumpWidget(
    _DirectionalHost(
      child: SizedBox(
        height: 100,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: CanvasSurface(runtime: runtime, interactive: false),
        ),
      ),
    ),
  );

  return tester.takeException();
}

final class _DirectionalHost extends StatelessWidget {
  const _DirectionalHost({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Directionality(textDirection: TextDirection.ltr, child: child);
  }
}

Finder _paintHosts() {
  return find.byKey(const ValueKey<String>('iwb_canvas_surface.paint_host'));
}

void _expectBoundedLayoutError(Object? error) {
  expect(error, isA<FlutterError>());
  expect(
    error?.toString(),
    contains('CanvasSurface requires bounded width and height'),
  );
}

String _paintSizeForSource() {
  final source = File(
    'lib/src/surface/canvas_surface_widget.dart',
  ).readAsStringSync();

  return _functionSource(source, 'Size _paintSizeFor');
}

List<String> _ordinaryPathRequiredTokens(String source) {
  return [
    'throw FlutterError',
    'CanvasSurface requires bounded width and height',
    'return constraints.biggest;',
  ].where((token) => !source.contains(token)).toList();
}

List<String> _debugOnlyPathTokens(String source) {
  return [
    'assert',
    'kDebugMode',
    'kReleaseMode',
    'kProfileMode',
    '!kProfileMode',
    '!kReleaseMode',
  ].where(source.contains).toList();
}

List<String> _silentFallbackTokens(String source) {
  return [
    '? constraints.maxWidth : 0.0',
    '? constraints.maxHeight : 0.0',
  ].where(source.contains).toList();
}

String _functionSource(String source, String signature) {
  final start = source.indexOf(signature);
  expect(start, isNot(-1));

  final firstBrace = source.indexOf('{', start);
  expect(firstBrace, isNot(-1));

  var depth = 0;
  for (var index = firstBrace; index < source.length; index += 1) {
    final character = source[index];
    if (character == '{') {
      depth += 1;
    } else if (character == '}') {
      depth -= 1;
      if (depth == 0) {
        return source.characters.getRange(start, index + 1).toString();
      }
    }
  }

  throw StateError('Function $signature was not closed.');
}
