import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

import '../../support/vector_preparation_fixture.dart';
import '../../support/accept_deletion_commit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The executable fixture owns its direct public-state, pixel, and lifecycle
  // assertions; the route wrapper has no independent assertion to add.
  // ignore: missing-test-assertion
  testWidgets(
    'external application publishes only current preparation and releases surfaces before disposal',
    (tester) async {
      await _expectExternalApplicationFreshnessAndRelease(tester);
    },
  );
}

// This external consumer owns context freshness and wrapper disposal. It feeds
// the real public resolver into two CanvasSurface instances rather than
// mirroring a session or output cache under test ownership.
// Its ordered publication, release, and disposal timeline is the behavior
// under test; splitting it would conceal the release-before-dispose boundary.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
Future<void> _expectExternalApplicationFreshnessAndRelease(
  WidgetTester tester,
) async {
  final preparedPictures = <ui.Picture>[];
  final disposedPictures = <ui.Picture>[];
  final trackedPreparedPictures = <ui.Picture>{};
  final previousOnCreate = ui.Picture.onCreate;
  final previousOnDispose = ui.Picture.onDispose;
  ui.Picture.onCreate = preparedPictures.add;
  ui.Picture.onDispose = (picture) {
    if (trackedPreparedPictures.contains(picture)) {
      disposedPictures.add(picture);
    }
  };
  addTearDown(() {
    ui.Picture.onCreate = previousOnCreate;
    ui.Picture.onDispose = previousOnDispose;
  });

  final preparations = await _prepareContextualVectors(tester);
  final initial = preparations.initial;
  final stale = preparations.stale;
  final current = preparations.current;
  expect(preparations.ltr, isNot(preparations.rtl));
  expect(preparations.ltr.locale, const Locale('en'));
  expect(preparations.ltr.textDirection, TextDirection.ltr);
  expect(preparations.rtl.locale, const Locale('ar'));
  expect(preparations.rtl.textDirection, TextDirection.rtl);
  if (preparedPictures.length < 3) {
    fail('Expected preparation to create three observable Pictures.');
  }
  final initialPicture = preparedPictures[0];
  final stalePicture = preparedPictures[1];
  final currentPicture = preparedPictures[2];
  trackedPreparedPictures.addAll([
    initialPicture,
    stalePicture,
    currentPicture,
  ]);
  final firstAlias = _PublicationAlias(
    runtime: _runtimeForVector('vector-left'),
    resourceId: CanvasResourceId('vector-left'),
  );
  final secondAlias = _PublicationAlias(
    runtime: _runtimeForVector('vector-right'),
    resourceId: CanvasResourceId('vector-right'),
  );
  addTearDown(firstAlias.runtime.dispose);
  addTearDown(secondAlias.runtime.dispose);
  final application = _ExternalVectorPublicationController(
    aliases: [firstAlias, secondAlias],
  );
  application.publishInitial(initial, context: preparations.ltr);
  final disposedAtResourcePublication = <bool>[];
  final stopObservingInitialPublication = [
    _observeResourcePublication(
      firstAlias.runtime,
      initialPicture,
      disposedPictures,
      disposedAtResourcePublication,
    ),
    _observeResourcePublication(
      secondAlias.runtime,
      initialPicture,
      disposedPictures,
      disposedAtResourcePublication,
    ),
  ];

  await tester.pumpWidget(
    _ExternalConsumerSurfaceHost(
      firstAlias: firstAlias,
      secondAlias: secondAlias,
      resolver: application,
    ),
  );
  await tester.pump();
  expect(
    application.resolveVector(_vectorResource('vector-left')),
    same(initial),
  );
  expect(
    application.resolveVector(_vectorResource('vector-right')),
    same(initial),
  );
  expect(await _paintPixel(tester, _firstSurfaceKey), const Color(0xFF336699));
  expect(await _paintPixel(tester, _secondSurfaceKey), const Color(0xFF336699));

  await _completeResourceRepaint(
    tester,
    firstAlias.runtime,
    () => application.releaseAlias(firstAlias),
  );
  expect(application.resolveVector(_vectorResource('vector-left')), isNull);
  expect(
    application.resolveVector(_vectorResource('vector-right')),
    same(initial),
  );
  expect(await _paintPixel(tester, _firstSurfaceKey), const Color(0xFF000000));
  expect(await _paintPixel(tester, _secondSurfaceKey), const Color(0xFF336699));
  expect(disposedPictures, isEmpty);

  final currentCompletion = Completer<CanvasPreparedVector>();
  final staleCompletion = Completer<CanvasPreparedVector>();
  application.activateContext(preparations.rtl);
  final currentFuture = application.acceptPreparation(
    currentCompletion.future,
    context: preparations.rtl,
  );
  final staleFuture = application.acceptPreparation(
    staleCompletion.future,
    context: preparations.ltr,
  );

  await _completeResourceRepaints(tester, [
    firstAlias.runtime,
    secondAlias.runtime,
  ], () => currentCompletion.complete(current));
  await currentFuture;

  expect(
    application.resolveVector(_vectorResource('vector-right')),
    same(current),
  );
  expect(disposedAtResourcePublication, everyElement(isFalse));
  expect(disposedPictures, [initialPicture]);
  for (final stop in stopObservingInitialPublication) {
    stop();
  }
  expect(await _paintPixel(tester, _firstSurfaceKey), const Color(0xFF000000));
  expect(await _paintPixel(tester, _secondSurfaceKey), const Color(0xFF336699));

  staleCompletion.complete(stale);
  await staleFuture;

  expect(
    application.resolveVector(_vectorResource('vector-right')),
    same(current),
  );
  expect(disposedPictures, [initialPicture, stalePicture]);
  expect(await _paintPixel(tester, _secondSurfaceKey), const Color(0xFF336699));

  await _completeResourceRepaints(tester, [
    firstAlias.runtime,
    secondAlias.runtime,
  ], application.disposeCurrentPublication);
  expect(disposedAtResourcePublication, everyElement(isFalse));
  expect(disposedPictures, [initialPicture, stalePicture, currentPicture]);
  expect(await _paintPixel(tester, _firstSurfaceKey), const Color(0xFF000000));
  expect(await _paintPixel(tester, _secondSurfaceKey), const Color(0xFF000000));
}

Future<void> _completeResourceRepaint(
  WidgetTester tester,
  CanvasRuntime runtime,
  VoidCallback action,
) {
  return _completeResourceRepaints(tester, [runtime], action);
}

Future<void> _completeResourceRepaints(
  WidgetTester tester,
  Iterable<CanvasRuntime> runtimes,
  VoidCallback action,
) async {
  final completions = [
    for (final runtime in runtimes) _nextResourceVisualPublication(runtime),
  ];
  action();
  await Future.wait(completions);
  await tester.pump();
}

Future<void> _nextResourceVisualPublication(CanvasRuntime runtime) {
  final completion = Completer<void>();
  final before = runtime.state.value.revisions.resourceVisual;
  late VoidCallback listener;
  listener = () {
    if (runtime.state.value.revisions.resourceVisual == before) {
      return;
    }
    runtime.state.removeListener(listener);
    completion.complete();
  };
  runtime.state.addListener(listener);

  return completion.future;
}

VoidCallback _observeResourcePublication(
  CanvasRuntime runtime,
  ui.Picture initialPicture,
  List<ui.Picture> disposedPictures,
  List<bool> observations,
) {
  var resourceRevision = runtime.state.value.revisions.resourceVisual;
  late VoidCallback listener;
  listener = () {
    final nextRevision = runtime.state.value.revisions.resourceVisual;
    if (nextRevision == resourceRevision) {
      return;
    }
    resourceRevision = nextRevision;
    observations.add(disposedPictures.contains(initialPicture));
  };
  runtime.state.addListener(listener);

  return () => runtime.state.removeListener(listener);
}

Future<_ContextualPreparations> _prepareContextualVectors(
  WidgetTester tester,
) async {
  late BuildContext ltrBuildContext;
  await tester.pumpWidget(
    _PreparationContextHost(
      locale: const Locale('en'),
      textDirection: TextDirection.ltr,
      onContext: (context) => ltrBuildContext = context,
    ),
  );
  final ltr = _effectiveContextFor(ltrBuildContext);
  final initial = prepareVector(basicVectorBytes(), context: ltrBuildContext);
  final stale = prepareVector(basicVectorBytes(), context: ltrBuildContext);

  late BuildContext rtlBuildContext;
  await tester.pumpWidget(
    _PreparationContextHost(
      locale: const Locale('ar'),
      textDirection: TextDirection.rtl,
      onContext: (context) => rtlBuildContext = context,
    ),
  );
  final rtl = _effectiveContextFor(rtlBuildContext);
  final current = prepareVector(basicVectorBytes(), context: rtlBuildContext);
  await tester.pumpWidget(const SizedBox.shrink());

  return _ContextualPreparations(
    ltr: ltr,
    rtl: rtl,
    initial: await initial,
    stale: await stale,
    current: await current,
  );
}

_EffectiveVectorContext _effectiveContextFor(BuildContext context) {
  return _EffectiveVectorContext(
    Localizations.localeOf(context),
    Directionality.of(context),
  );
}

@immutable
final class _ContextualPreparations {
  const _ContextualPreparations({
    required this.ltr,
    required this.rtl,
    required this.initial,
    required this.stale,
    required this.current,
  });

  final _EffectiveVectorContext ltr;
  final _EffectiveVectorContext rtl;
  final CanvasPreparedVector initial;
  final CanvasPreparedVector stale;
  final CanvasPreparedVector current;
}

final class _PreparationContextHost extends StatelessWidget {
  const _PreparationContextHost({
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

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

final class _ExternalVectorPublicationController
    implements CanvasResourceResolver {
  _ExternalVectorPublicationController({
    required Iterable<_PublicationAlias> aliases,
  }) : _activeAliases = {...aliases},
       _runtimes = {for (final alias in aliases) alias.runtime};

  final Set<_PublicationAlias> _activeAliases;
  final Set<CanvasRuntime> _runtimes;
  final Map<_PublicationIdentity, CanvasPreparedVector> _published = {};
  final Map<_EffectiveVectorContext, int> _latestRequestByContext = {};
  late _EffectiveVectorContext _effectiveContext;
  CanvasPreparedVector? _current;

  void publishInitial(
    CanvasPreparedVector prepared, {
    required _EffectiveVectorContext context,
  }) {
    _effectiveContext = context;
    _current = prepared;
    for (final alias in _activeAliases) {
      _published[_PublicationIdentity(alias.resourceId, context)] = prepared;
    }
  }

  void activateContext(_EffectiveVectorContext context) {
    _effectiveContext = context;
    _releasePublishedSurfaceBorrows();
  }

  Future<void> acceptPreparation(
    Future<CanvasPreparedVector> preparation, {
    required _EffectiveVectorContext context,
  }) async {
    final request = (_latestRequestByContext[context] ?? 0) + 1;
    _latestRequestByContext[context] = request;
    final prepared = await preparation;
    if (request != _latestRequestByContext[context] ||
        context != _effectiveContext) {
      prepared.dispose();

      return;
    }

    final previous = _current;
    _current = prepared;
    _published.removeWhere((_, value) => identical(value, previous));
    for (final alias in _activeAliases) {
      _published[_PublicationIdentity(alias.resourceId, context)] = prepared;
    }
    _releasePublishedSurfaceBorrows();
    previous?.dispose();
  }

  void releaseAlias(_PublicationAlias alias) {
    if (!_activeAliases.remove(alias)) {
      return;
    }
    _published.removeWhere(
      (identity, _) => identity.resourceId == alias.resourceId,
    );
    alias.runtime.resources.markResourceDirty(alias.resourceId);
  }

  void disposeCurrentPublication() {
    final current = _current;
    if (current == null) {
      return;
    }
    _published.clear();
    _activeAliases.clear();
    _releasePublishedSurfaceBorrows();
    _current = null;
    current.dispose();
  }

  void _releasePublishedSurfaceBorrows() {
    for (final runtime in _runtimes) {
      runtime.resources.markAllResourcesDirty();
    }
  }

  @override
  ui.Image? resolveImage(CanvasImageResource resource) => null;

  @override
  CanvasPreparedVector? resolveVector(CanvasVectorResource resource) {
    return _published[_PublicationIdentity(resource.id, _effectiveContext)];
  }
}

@immutable
final class _EffectiveVectorContext {
  const _EffectiveVectorContext(this.locale, this.textDirection);

  final Locale locale;
  final TextDirection textDirection;

  @override
  bool operator ==(Object other) {
    return other is _EffectiveVectorContext &&
        other.locale == locale &&
        other.textDirection == textDirection;
  }

  @override
  int get hashCode => Object.hash(locale, textDirection);
}

@immutable
final class _PublicationIdentity {
  const _PublicationIdentity(this.resourceId, this.context);

  final CanvasResourceId resourceId;
  final _EffectiveVectorContext context;

  @override
  bool operator ==(Object other) {
    return other is _PublicationIdentity &&
        other.resourceId == resourceId &&
        other.context == context;
  }

  @override
  int get hashCode => Object.hash(resourceId, context);
}

@immutable
final class _PublicationAlias {
  const _PublicationAlias({required this.runtime, required this.resourceId});

  final CanvasRuntime runtime;
  final CanvasResourceId resourceId;
}

const _firstSurfaceKey = ValueKey<String>('external-vector-first-surface');
const _secondSurfaceKey = ValueKey<String>('external-vector-second-surface');

final class _ExternalConsumerSurfaceHost extends StatelessWidget {
  const _ExternalConsumerSurfaceHost({
    required this.firstAlias,
    required this.secondAlias,
    required this.resolver,
  });

  final _PublicationAlias firstAlias;
  final _PublicationAlias secondAlias;
  final CanvasResourceResolver resolver;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        children: [
          _ExternalConsumerSurface(
            alias: firstAlias,
            boundaryKey: _firstSurfaceKey,
            resolver: resolver,
          ),
          _ExternalConsumerSurface(
            alias: secondAlias,
            boundaryKey: _secondSurfaceKey,
            resolver: resolver,
          ),
        ],
      ),
    );
  }
}

final class _ExternalConsumerSurface extends StatelessWidget {
  const _ExternalConsumerSurface({
    required this.alias,
    required this.boundaryKey,
    required this.resolver,
  });

  final _PublicationAlias alias;
  final Key boundaryKey;
  final CanvasResourceResolver resolver;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: boundaryKey,
      child: SizedBox(
        width: 32,
        height: 32,
        child: CanvasSurface(
          runtime: alias.runtime,
          resourceResolver: resolver,
          interactive: false,
        ),
      ),
    );
  }
}

CanvasRuntime _runtimeForVector(String resourceId) {
  final runtime = CanvasRuntime(config: _acceptDeletionRuntimeConfig());
  runtime.edits.loadDocumentFromJson(
    encodeCanvasDocumentToJson(
      CanvasDocument(
        background: const CanvasBackground(
          color: Color(0x00000000),
          grid: CanvasGrid.disabled,
        ),
        resources: [_vectorResource(resourceId)],
        layers: [
          CanvasLayer(
            id: CanvasLayerId('layer-$resourceId'),
            elements: [
              CanvasVectorElement(
                id: CanvasElementId('element-$resourceId'),
                resourceId: CanvasResourceId(resourceId),
                size: const Size(20, 20),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  return runtime;
}

CanvasVectorResource _vectorResource(String id) {
  return CanvasVectorResource(
    id: CanvasResourceId(id),
    source: CanvasResourceSource.appKey(id),
  );
}

Future<Color> _paintPixel(WidgetTester tester, Key key) async {
  final color = await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(key),
    );
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    if (bytes == null) {
      throw StateError('External consumer surface produced no pixel bytes.');
    }

    final offset = (5 * 32 + 5) * 4;

    return Color.fromARGB(
      bytes.getUint8(offset + 3),
      bytes.getUint8(offset),
      bytes.getUint8(offset + 1),
      bytes.getUint8(offset + 2),
    );
  });
  if (color == null) {
    throw StateError('External consumer pixel capture did not complete.');
  }

  return color;
}

CanvasRuntimeConfig _acceptDeletionRuntimeConfig() =>
    const CanvasRuntimeConfig(deletionCommitResolver: acceptDeletionCommit);
