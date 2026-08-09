import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_prepared_vector.dart';

import '../support/vector_preparation_fixture.dart';
import 'fixtures/vm_retention_observer.dart';

// Flutter's test runner supplies this mutually exclusive VM-service intent.
const _vmServiceDisabledArgument = '--disable-vm-service';

// Keeping the related lifecycle scenarios together makes their shared
// invocation, settlement, and unmount ordering explicit; splitting them only
// for metrics would make that ownership harder to follow.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void main() {
  testWidgets(
    'preparation renders direction-sensitive output after context unmount',
    (tester) async {
      final englishLtr = await _prepareAfterContextUnmount(
        tester,
        locale: const Locale('en'),
        textDirection: TextDirection.ltr,
      );
      final englishRtl = await _prepareAfterContextUnmount(
        tester,
        locale: const Locale('en'),
        textDirection: TextDirection.rtl,
      );
      addTearDown(englishLtr.dispose);
      addTearDown(englishRtl.dispose);

      final englishLtrPixels = await tester.runAsync(
        () => _pixelsFor(englishLtr),
      );
      final englishRtlPixels = await tester.runAsync(
        () => _pixelsFor(englishRtl),
      );

      expect(englishLtrPixels, isNot(equals(englishRtlPixels)));
    },
  );

  testWidgets(
    'preparation registers its invocation locale dependency before settlement',
    (tester) async {
      final probeKey = GlobalKey<_LocaleDependencyProbeState>();
      await _pumpLocaleDependencyProbe(
        tester,
        key: probeKey,
        locale: const Locale('en'),
      );
      final probe = probeKey.currentState;
      if (probe == null) {
        throw StateError('The locale dependency probe was not mounted.');
      }
      final preparation = probe.preparation;
      expect(probe.dependencyChanges, 1);

      await _pumpLocaleDependencyProbe(
        tester,
        key: probeKey,
        locale: const Locale('ar'),
      );

      expect(probe.dependencyChanges, 2);
      final prepared = await preparation;
      addTearDown(prepared.dispose);
    },
  );

  testWidgets('settled preparation releases the invocation context '
      '(requires flutter test --enable-vmservice '
      'test/api/vector_preparation_context_test.dart)', (tester) async {
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
    expect(
      observation.inboundTraversalComplete,
      isTrue,
      reason: observation.inboundTraversalLimitReasons.join(', '),
    );
    expect(observation.inboundTraversalLimitReasons, isEmpty);
    expect(
      _hasEngineOrUpstreamOwner(observation.inboundOwnershipSources),
      isFalse,
    );
    expect(
      _hasOnlyExplicitTestOrServiceOwnership(
        observation.inboundOwnershipSources,
      ),
      isTrue,
    );
  }, skip: Platform.executableArguments.contains(_vmServiceDisabledArgument));
}

Future<CanvasPreparedVector> _prepareAfterContextUnmount(
  WidgetTester tester, {
  required Locale locale,
  required TextDirection textDirection,
}) async {
  late BuildContext invocationContext;
  await tester.pumpWidget(
    _ContextRoot(
      locale: locale,
      textDirection: textDirection,
      onContext: (context) => invocationContext = context,
    ),
  );
  final preparation = prepareVector(
    contextSensitiveVectorBytes(),
    context: invocationContext,
  );
  await tester.pumpWidget(const SizedBox());
  expect(invocationContext.mounted, isFalse);
  return preparation;
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

Future<void> _pumpLocaleDependencyProbe(
  WidgetTester tester, {
  required GlobalKey<_LocaleDependencyProbeState> key,
  required Locale locale,
}) {
  return tester.pumpWidget(
    _ContextRoot(
      locale: locale,
      textDirection: TextDirection.ltr,
      child: _LocaleDependencyProbe(key: key),
    ),
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
    this.onContext,
    this.child = const SizedBox(),
  });

  final Locale locale;
  final TextDirection textDirection;
  final ValueChanged<BuildContext>? onContext;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Localizations(
      locale: locale,
      delegates: const [DefaultWidgetsLocalizations.delegate],
      child: Directionality(
        textDirection: textDirection,
        child: Builder(
          builder: (context) {
            onContext?.call(context);
            return child;
          },
        ),
      ),
    );
  }
}

final class _LocaleDependencyProbe extends StatefulWidget {
  const _LocaleDependencyProbe({super.key});

  @override
  State<_LocaleDependencyProbe> createState() => _LocaleDependencyProbeState();
}

final class _LocaleDependencyProbeState extends State<_LocaleDependencyProbe> {
  late final Future<CanvasPreparedVector> preparation;
  int dependencyChanges = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    dependencyChanges += 1;
    if (dependencyChanges == 1) {
      preparation = prepareVector(
        contextSensitiveVectorBytes(),
        context: context,
      );
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
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

bool _hasEngineOrUpstreamOwner(Iterable<VmRetentionSource> sources) {
  return sources.any(
    (source) =>
        source.libraryUri.startsWith('package:iwb_canvas_engine/src/api/') ||
        source.libraryUri.startsWith('package:vector_graphics/'),
  );
}

bool _hasOnlyExplicitTestOrServiceOwnership(
  Iterable<VmRetentionSource> sources,
) {
  return sources.every(_isExplicitTestOrServiceOwnership);
}

bool _isExplicitTestOrServiceOwnership(VmRetentionSource source) {
  final libraryUri = source.libraryUri;
  return libraryUri.startsWith('dart:developer') ||
      libraryUri.startsWith('package:vm_service/') ||
      libraryUri.startsWith('package:flutter_test/') ||
      libraryUri.startsWith('package:test_api/') ||
      libraryUri.contains('/test/api/') ||
      (libraryUri.startsWith('package:flutter/src/widgets/') &&
          source.className.endsWith('Element'));
}
