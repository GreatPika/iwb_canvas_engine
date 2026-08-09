import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_prepared_vector.dart';

import 'fixtures/vector_preparation_fixture.dart';
import 'fixtures/vm_retention_observer.dart';

// Flutter's test runner supplies this mutually exclusive VM-service intent.
const _vmServiceDisabledArgument = '--disable-vm-service';

void main() {
  testWidgets(
    'preparation captures invocation locale and direction before context unmount',
    (tester) async {
      late BuildContext ltrContext;
      await tester.pumpWidget(
        _ContextRoot(
          locale: const Locale('en'),
          textDirection: TextDirection.ltr,
          onContext: (context) => ltrContext = context,
        ),
      );

      final ltrPreparation = prepareVector(
        contextSensitiveVectorBytes(),
        context: ltrContext,
      );
      await tester.pumpWidget(const SizedBox());
      expect(ltrContext.mounted, isFalse);
      late BuildContext rtlContext;
      await tester.pumpWidget(
        _ContextRoot(
          locale: const Locale('ar'),
          textDirection: TextDirection.rtl,
          onContext: (context) => rtlContext = context,
        ),
      );

      final rtlPreparation = prepareVector(
        contextSensitiveVectorBytes(),
        context: rtlContext,
      );
      final ltrPrepared = await ltrPreparation;
      final rtlPrepared = await rtlPreparation;
      addTearDown(ltrPrepared.dispose);
      addTearDown(rtlPrepared.dispose);

      final ltrPixels = await tester.runAsync(() => _pixelsFor(ltrPrepared));
      final rtlPixels = await tester.runAsync(() => _pixelsFor(rtlPrepared));

      expect(ltrPixels, isNot(equals(rtlPixels)));
    },
  );

  testWidgets('settled preparation releases the invocation context '
      '(requires flutter test --enable-vmservice '
      'test/preparation/vector_preparation_context_test.dart)', (tester) async {
    final observer = await tester.runAsync(VmRetentionObserver.connect);
    if (observer == null) {
      throw StateError('The VM retention observer did not connect.');
    }
    addTearDown(observer.dispose);
    final settled = await _prepareAndReleaseInvocationContext(tester, observer);
    await tester.pumpWidget(
      _ContextRoot(
        locale: const Locale('ar'),
        textDirection: TextDirection.rtl,
        onContext: (context) => expect(context.mounted, isTrue),
      ),
    );
    addTearDown(settled.prepared.dispose);
    await tester.pump();

    final observation = await tester.runAsync(() async {
      await observer.collectGarbage();
      return observer.observeReleasedObjectId(
        settled.invocationContextId,
        isTerminalOwnershipRoot: _isExplicitTestOrServiceOwnership,
      );
    });
    if (observation == null) {
      throw StateError('The VM retention observer did not return a path.');
    }

    expect(observation.targetId, settled.invocationContextId);
    expect(_hasEngineOrUpstreamOwner(observation), isFalse);
    expect(
      observation.inboundTraversalComplete,
      isTrue,
      reason: observation.inboundTraversalLimitReasons.join(', '),
    );
    expect(_hasOnlyExplicitTestOrServiceOwnership(observation), isTrue);
  }, skip: Platform.executableArguments.contains(_vmServiceDisabledArgument));
}

Future<_SettledInvocationPreparation> _prepareAndReleaseInvocationContext(
  WidgetTester tester,
  VmRetentionObserver observer,
) async {
  BuildContext? invocationContext;
  await tester.pumpWidget(
    _ContextRoot(
      locale: const Locale('en'),
      textDirection: TextDirection.ltr,
      onContext: (context) => invocationContext = context,
    ),
  );
  final contextId = switch (invocationContext) {
    final BuildContext context => observer.objectId(context),
    null => throw StateError('The invocation context was not captured.'),
  };
  final preparation = prepareVector(
    contextSensitiveVectorBytes(),
    context: invocationContext,
  );
  await tester.pumpWidget(const SizedBox());
  expect(invocationContext?.mounted, isFalse);
  invocationContext = null;
  return _SettledInvocationPreparation(
    invocationContextId: contextId,
    prepared: await preparation,
  );
}

final class _SettledInvocationPreparation {
  const _SettledInvocationPreparation({
    required this.invocationContextId,
    required this.prepared,
  });

  final String invocationContextId;
  final CanvasPreparedVector prepared;
}

final class _ContextRoot extends StatelessWidget {
  const _ContextRoot({
    required this.locale,
    required this.textDirection,
    required this.onContext,
  });

  final Locale locale;
  final TextDirection textDirection;
  final ValueChanged<BuildContext> onContext;

  @override
  Widget build(BuildContext context) {
    return Localizations(
      locale: locale,
      delegates: const [DefaultWidgetsLocalizations.delegate],
      child: Directionality(
        textDirection: textDirection,
        child: Builder(
          builder: (context) {
            onContext(context);
            return const SizedBox();
          },
        ),
      ),
    );
  }
}

Future<Uint8List> _pixelsFor(CanvasPreparedVector prepared) async {
  final image = liveCanvasPreparedVectorPicture(prepared).toImageSync(40, 20);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) {
      throw StateError('Vector picture did not produce pixel data.');
    }
    return Uint8List.fromList(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  } finally {
    image.dispose();
  }
}

bool _hasEngineOrUpstreamOwner(VmRetentionObservation observation) {
  return observation.ownershipSources.any(
    (source) =>
        source.libraryUri.startsWith('package:iwb_canvas_engine/src/api/') ||
        source.libraryUri.startsWith('package:vector_graphics/'),
  );
}

bool _hasOnlyExplicitTestOrServiceOwnership(
  VmRetentionObservation observation,
) {
  return observation.ownershipSources.every(_isExplicitTestOrServiceOwnership);
}

bool _isExplicitTestOrServiceOwnership(VmRetentionSource source) {
  final libraryUri = source.libraryUri;
  return libraryUri.isEmpty ||
      libraryUri.startsWith('dart:developer') ||
      libraryUri.startsWith('package:vm_service/') ||
      libraryUri.startsWith('package:flutter_test/') ||
      libraryUri.startsWith('package:test_api/') ||
      libraryUri.contains('/test/preparation/') ||
      (libraryUri.startsWith('package:flutter/src/widgets/') &&
          source.className.endsWith('Element'));
}
