import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

import '../support/vector_preparation_fixture.dart';

void main() {
  testWidgets('preparation uses caller bytes without asset or network lookup', (
    tester,
  ) async {
    final assets = _DenyAssetBundle();
    late BuildContext context;
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: assets,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (buildContext) {
              context = buildContext;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    final prepared = await HttpOverrides.runZoned(
      () => IOOverrides.runZoned(
        () => prepareVector(basicVectorBytes(), context: context),
        createFile: (_) =>
            throw StateError('Vector preparation must not read files.'),
      ),
      createHttpClient: (_) => throw StateError(
        'Vector preparation must not create an HTTP client.',
      ),
    );
    addTearDown(prepared.dispose);

    expect(prepared.intrinsicSize, const Size(10, 20));
    expect(assets.requestedKeys, isEmpty);
  });
}

final class _DenyAssetBundle extends CachingAssetBundle {
  final requestedKeys = <String>[];

  @override
  Future<ByteData> load(String key) {
    requestedKeys.add(key);
    throw StateError('Vector preparation must not load assets.');
  }
}
