// This surface lifecycle fixture spans widget mounting, runtime attachment, and
// resource session seams; keeping the imports together makes session ownership
// and rollback behavior visible in one test owner.
// ignore_for_file: number-of-imports

import 'dart:io';
import "../../support/runtime_root_with_committed_document_seed.dart";

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

import 'package:iwb_canvas_engine/src/api/canvas_runtime_frame_bridge.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/surface_resource_session_lifecycle.dart';
import 'package:iwb_canvas_engine/src/resources/resource_resolver_adapter.dart';
import 'package:iwb_canvas_engine/src/resources/surface_resource_session.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

import '../../resources/fixtures/surface_resource_session_test_support.dart';

typedef _RejectedAttachScenario = ({
  CanvasRuntime runtime,
  RecordingResourceResolver acceptedResolver,
  RecordingResourceResolver rejectedResolver,
  SurfaceResourceSession firstSession,
});

void main() {
  testWidgets(
    'accepted and rejected attach keep session side effects ordered',
    (tester) async {
      await _expectAcceptedAndRejectedAttach(tester);
      expect(_paintHosts(), findsOneWidget);
    },
  );

  testWidgets(
    'resolver replacement reuses the active session with fresh cache',
    (tester) async {
      await _expectResolverReplacementReusesSession(tester);
      expect(_paintHosts(), findsOneWidget);
    },
  );

  testWidgets('detach, runtime swap, and runtime dispose drop sessions', (
    tester,
  ) async {
    await _expectSurfaceDetachPathsDropSessions(tester);
    expect(tester.takeException(), isNull);
  });

  test('runtime token guards active session installation and dirty order', () {
    expect(_runtimeTokenGuardedSessionInstall(), isTrue);
    expect(_dirtyInvalidatesInstalledSessionBeforePublish(), isTrue);
  });

  test(
    'surface session lifecycle seam stays narrow and constructor-infallible',
    () {
      expect(_lifecycleSeamShapeIsNarrow(), isTrue);
      expect(_sessionConstructorHasNoFallibleCollaborators(), isTrue);
      expect(_surfaceInstallRollbackIsGuarded(), isTrue);
    },
  );
}

Future<void> _expectAcceptedAndRejectedAttach(WidgetTester tester) async {
  final runtime = runtimeWithDocument(_documentWithResource());
  final acceptedResolver = RecordingResourceResolver((_) => null);
  final rejectedResolver = RecordingResourceResolver((_) => null);
  addTearDown(runtime.dispose);

  await _mountAcceptedSurface(tester, runtime, acceptedResolver);
  final firstSession = _activeSession(runtime);
  expect(firstSession, isA<SurfaceResourceSession>());
  expect(acceptedResolver.callCount, 0);

  await _expectSecondAttachRejected(tester, (
    runtime: runtime,
    acceptedResolver: acceptedResolver,
    rejectedResolver: rejectedResolver,
    firstSession: firstSession,
  ));
}

Future<void> _mountAcceptedSurface(
  WidgetTester tester,
  CanvasRuntime runtime,
  RecordingResourceResolver acceptedResolver,
) async {
  await tester.pumpWidget(
    _Host(
      child: _SameRuntimeSlots(
        runtime: runtime,
        firstResolver: acceptedResolver,
        secondSlot: const SizedBox.shrink(),
      ),
    ),
  );
}

Future<void> _expectSecondAttachRejected(
  WidgetTester tester,
  _RejectedAttachScenario scenario,
) async {
  await tester.pumpWidget(
    _Host(
      child: _SameRuntimeSlots(
        runtime: scenario.runtime,
        firstResolver: scenario.acceptedResolver,
        secondSlot: CanvasSurface(
          key: const ValueKey<String>('surface-b'),
          runtime: scenario.runtime,
          resourceResolver: scenario.rejectedResolver,
          interactive: false,
        ),
      ),
    ),
  );

  final error = tester.takeException();
  expect(error, isStateError);
  expect(
    (error as StateError).message,
    'CanvasRuntime already has an active CanvasSurface.',
  );
  expect(_activeSession(scenario.runtime), same(scenario.firstSession));
  expect(_paintHosts(), findsOneWidget);
  expect(scenario.rejectedResolver.callCount, 0);
}

Future<void> _expectResolverReplacementReusesSession(
  WidgetTester tester,
) async {
  final firstImage = await createResourceTestImage(0xff00aa00);
  final secondImage = await createResourceTestImage(0xff0000aa);
  final runtime = runtimeWithDocument(_documentWithResource());
  final firstResolver = RecordingResourceResolver((_) => firstImage);
  final secondResolver = RecordingResourceResolver((_) => secondImage);
  addTearDown(runtime.dispose);

  final request = descriptorRequest(id: 'resource-a');
  final session = await _mountSurfaceWithResolver(
    tester,
    runtime: runtime,
    resolver: firstResolver,
  );
  _expectSessionResolvesImage(session, request, firstImage);
  expect(firstResolver.callCount, 1);

  await _replaceSurfaceResolver(
    tester,
    runtime: runtime,
    resolver: secondResolver,
  );
  expect(_activeSession(runtime), same(session));
  _expectSessionResolvesImage(session, request, secondImage);
  expect(firstResolver.callCount, 1);
  expect(secondResolver.callCount, 1);
  expect(firstImage.debugDisposed, isFalse);
  expect(secondImage.debugDisposed, isFalse);
  firstImage.dispose();
  secondImage.dispose();
}

Future<SurfaceResourceSession> _mountSurfaceWithResolver(
  WidgetTester tester, {
  required CanvasRuntime runtime,
  required CanvasResourceResolver resolver,
}) async {
  await tester.pumpWidget(
    _Host(
      child: CanvasSurface(
        runtime: runtime,
        resourceResolver: resolver,
        interactive: false,
      ),
    ),
  );

  return _activeSession(runtime);
}

Future<void> _replaceSurfaceResolver(
  WidgetTester tester, {
  required CanvasRuntime runtime,
  required CanvasResourceResolver resolver,
}) async {
  await tester.pumpWidget(
    _Host(
      child: CanvasSurface(
        runtime: runtime,
        resourceResolver: resolver,
        interactive: false,
      ),
    ),
  );
}

Future<void> _expectSurfaceDetachPathsDropSessions(WidgetTester tester) async {
  await _expectRuntimeSwapDropsOldSession(tester);
  await _expectRuntimeDisposeDropsSessionBeforeWidgetDetach(tester);
}

Future<void> _expectRuntimeSwapDropsOldSession(WidgetTester tester) async {
  final oldImage = await createResourceTestImage(0xff00aa00);
  final oldRuntime = runtimeWithDocument(_documentWithResource());
  final newRuntime = runtimeWithDocument(_documentWithResource('resource-b'));
  final oldResolver = RecordingResourceResolver((_) => oldImage);
  addTearDown(oldRuntime.dispose);
  addTearDown(newRuntime.dispose);

  final oldSession = await _mountSurfaceWithResolver(
    tester,
    runtime: oldRuntime,
    resolver: oldResolver,
  );
  _expectSessionResolvesImage(
    oldSession,
    descriptorRequest(id: 'resource-a'),
    oldImage,
  );

  await tester.pumpWidget(
    _Host(child: CanvasSurface(runtime: newRuntime, interactive: false)),
  );

  expect(_rootFor(oldRuntime).activeSurfaceResourceSessionForTesting, isNull);
  expect(_activeSession(newRuntime), isA<SurfaceResourceSession>());
  expect(
    oldSession.resolveResource(descriptorRequest(id: 'resource-a')),
    isA<NoResolverResourceAssetPlaceholder>(),
  );
  expect(oldImage.debugDisposed, isFalse);
  oldImage.dispose();
}

Future<void> _expectRuntimeDisposeDropsSessionBeforeWidgetDetach(
  WidgetTester tester,
) async {
  final image = await createResourceTestImage(0xff0000aa);
  final runtime = runtimeWithDocument(_documentWithResource());
  final resolver = RecordingResourceResolver((_) => image);

  await tester.pumpWidget(
    _Host(
      child: CanvasSurface(
        runtime: runtime,
        resourceResolver: resolver,
        interactive: false,
      ),
    ),
  );
  final session = _activeSession(runtime);
  final root = _rootFor(runtime);
  expect(
    identical(
      resolvedImage(
        session.resolveResource(descriptorRequest(id: 'resource-a')),
      ),
      image,
    ),
    isTrue,
  );

  runtime.dispose();
  expect(root.activeSurfaceResourceSessionForTesting, isNull);
  expect(
    session.resolveResource(descriptorRequest(id: 'resource-a')),
    isA<NoResolverResourceAssetPlaceholder>(),
  );
  await _expectDisposedRuntimeRebuildDetachesSurface(
    tester,
    runtime: runtime,
    resolver: resolver,
  );
  await tester.pumpWidget(const SizedBox.shrink());
  expect(image.debugDisposed, isFalse);
  image.dispose();
}

Future<void> _expectDisposedRuntimeRebuildDetachesSurface(
  WidgetTester tester, {
  required CanvasRuntime runtime,
  required CanvasResourceResolver resolver,
}) async {
  await tester.pumpWidget(
    _Host(
      child: CanvasSurface(
        runtime: runtime,
        resourceResolver: resolver,
        interactive: false,
      ),
    ),
  );
  expect(tester.takeException(), isNull);
  expect(_paintHosts(), findsNothing);
}

bool _runtimeTokenGuardedSessionInstall() {
  final root = runtimeRootWithCommittedDocumentSeed(
    _documentWithResource(),
    config: const CanvasRuntimeConfig(),
  );
  final activeToken = Object();
  final staleToken = Object();
  final activeSession = _RecordingLifecycleSession();
  final staleSession = _RecordingLifecycleSession();

  root.attachSurface(activeToken);
  root.installSurfaceResourceSession(activeToken, activeSession);
  expect(root.activeSurfaceResourceSessionForTesting, same(activeSession));
  expect(
    () => root.installSurfaceResourceSession(staleToken, staleSession),
    throwsStateError,
  );
  expect(root.activeSurfaceResourceSessionForTesting, same(activeSession));
  expect(staleSession.dropCount, 0);
  expect(root.detachSurface(staleToken), isFalse);
  expect(activeSession.dropCount, 0);
  expect(root.detachSurface(activeToken), isTrue);
  expect(root.activeSurfaceResourceSessionForTesting, isNull);
  expect(activeSession.dropCount, 1);
  root.dispose();

  return true;
}

bool _dirtyInvalidatesInstalledSessionBeforePublish() {
  _expectTargetDirtyInvalidatesBeforePublish();
  _expectMarkAllInvalidatesBeforePublish();
  _expectDetachedAndStaleSessionsAreIgnoredByDirty();

  return true;
}

void _expectTargetDirtyInvalidatesBeforePublish() {
  final root = runtimeRootWithCommittedDocumentSeed(
    _documentWithResource(),
    config: const CanvasRuntimeConfig(),
  );
  final token = Object();
  final session = _RecordingLifecycleSession();
  root.attachSurface(token);
  root.installSurfaceResourceSession(token, session);
  root.state.addListener(() {
    expect(session.releasedIds, [CanvasResourceId('resource-a')]);
  });

  root.resources.markResourceDirty(CanvasResourceId('resource-a'));

  expect(root.state.value.revisions.resourceVisual, 1);
  expect(session.releasedIds, [CanvasResourceId('resource-a')]);
  expect(session.releaseAllCount, 0);
  root.dispose();
}

void _expectMarkAllInvalidatesBeforePublish() {
  final root = runtimeRootWithCommittedDocumentSeed(
    _documentWithResource(),
    config: const CanvasRuntimeConfig(),
  );
  final token = Object();
  final session = _RecordingLifecycleSession();
  root.attachSurface(token);
  root.installSurfaceResourceSession(token, session);
  root.state.addListener(() {
    expect(session.releaseAllCount, 1);
  });

  root.resources.markAllResourcesDirty();

  expect(root.state.value.revisions.resourceVisual, 1);
  expect(session.releasedIds, isEmpty);
  expect(session.releaseAllCount, 1);
  root.dispose();
}

void _expectDetachedAndStaleSessionsAreIgnoredByDirty() {
  final root = runtimeRootWithCommittedDocumentSeed(
    _documentWithResource(),
    config: const CanvasRuntimeConfig(),
  );
  final activeToken = Object();
  final staleToken = Object();
  final activeSession = _RecordingLifecycleSession();
  final staleSession = _RecordingLifecycleSession();
  root.attachSurface(activeToken);
  root.installSurfaceResourceSession(activeToken, activeSession);
  expect(
    () => root.installSurfaceResourceSession(staleToken, staleSession),
    throwsStateError,
  );
  expect(root.detachSurface(activeToken), isTrue);

  root.resources.markResourceDirty(CanvasResourceId('resource-a'));
  root.resources.markAllResourcesDirty();

  expect(activeSession.releasedIds, isEmpty);
  expect(activeSession.releaseAllCount, 0);
  expect(activeSession.dropCount, 1);
  expect(staleSession.releasedIds, isEmpty);
  expect(staleSession.releaseAllCount, 0);
  expect(staleSession.dropCount, 0);
  expect(root.state.value.revisions.resourceVisual, 2);
  root.dispose();
}

bool _lifecycleSeamShapeIsNarrow() {
  final lifecycleSource = File(
    'lib/src/contracts/internal/surface_resource_session_lifecycle.dart',
  ).readAsStringSync();
  expect(lifecycleSource, contains('implements ResourceSessionReleaseSink'));
  expect(lifecycleSource, contains('void resetForDocumentReplacement();'));
  expect(lifecycleSource, contains('void drop();'));
  expect(lifecycleSource, isNot(contains('resolveImage')));
  expect(lifecycleSource, isNot(contains('replaceResolver')));
  expect(lifecycleSource, isNot(contains('CanvasResourceResolver')));

  final bridgeSource = File(
    'lib/src/api/canvas_runtime_surface_bridge.dart',
  ).readAsStringSync();
  expect(bridgeSource, isNot(contains('surface_resource_session.dart')));
  expect(bridgeSource, isNot(contains('= SurfaceResourceSession')));

  return true;
}

bool _sessionConstructorHasNoFallibleCollaborators() {
  final source = File(
    'lib/src/resources/surface_resource_session.dart',
  ).readAsStringSync();
  final constructorStart = source.indexOf('SurfaceResourceSession({');
  final constructorEnd = source.indexOf('final ResolverMutationGuard');
  final constructorSource = _codeUnitSlice(
    source,
    constructorStart,
    constructorEnd,
  );

  expect(constructorSource, isNot(contains('resolveImage')));
  expect(constructorSource, isNot(contains('runResolverCallback')));
  expect(constructorSource, isNot(contains('throw ')));
  expect(constructorSource, isNot(contains('Future')));
  expect(constructorSource, isNot(contains('File(')));

  return true;
}

bool _surfaceInstallRollbackIsGuarded() {
  final source = File(
    'lib/src/surface/canvas_surface_widget.dart',
  ).readAsStringSync();
  final attachStart = source.indexOf(
    'void _attachSurface(CanvasRuntime runtime)',
  );
  final detachStart = source.indexOf('void _detachSurface()');
  final attachSource = _codeUnitSlice(source, attachStart, detachStart);
  final attachIndex = attachSource.indexOf(
    'port.attachSurface(_surfaceToken);',
  );
  final constructIndex = attachSource.indexOf(
    'session = SurfaceResourceSession(',
  );
  final installIndex = attachSource.indexOf(
    'port.installSurfaceResourceSession(_surfaceToken, session);',
  );
  final storeIndex = attachSource.indexOf('_activeSession = session;');
  final dropIndex = attachSource.indexOf('session?.drop();');
  final detachIndex = attachSource.indexOf(
    'port.detachSurface(_surfaceToken);',
  );
  final rethrowIndex = attachSource.indexOf('rethrow;');

  expect(attachIndex, greaterThanOrEqualTo(0));
  expect(constructIndex, greaterThan(attachIndex));
  expect(installIndex, greaterThan(constructIndex));
  expect(storeIndex, greaterThan(installIndex));
  expect(dropIndex, greaterThan(installIndex));
  expect(detachIndex, greaterThan(dropIndex));
  expect(rethrowIndex, greaterThan(detachIndex));

  return true;
}

String _codeUnitSlice(String source, int start, int end) {
  // Source marker indexes are String code-unit offsets; substring keeps the
  // checked source region aligned with those marker positions.
  // ignore: avoid-substring
  return source.substring(start, end);
}

SurfaceResourceSession _activeSession(CanvasRuntime runtime) {
  final session = _rootFor(runtime).activeSurfaceResourceSessionForTesting;
  if (session is SurfaceResourceSession) {
    return session;
  }

  throw StateError('CanvasRuntime has no active SurfaceResourceSession.');
}

RuntimeRoot _rootFor(CanvasRuntime runtime) {
  final root = canvasRuntimeFrameRootForSurface(runtime);
  if (root != null) {
    return root;
  }

  throw StateError('CanvasRuntime frame root is not attached.');
}

Finder _paintHosts() {
  return find.byKey(const ValueKey<String>('iwb_canvas_surface.paint_host'));
}

final class _Host extends StatelessWidget {
  const _Host({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(width: 160, height: 120, child: child),
    );
  }
}

final class _SameRuntimeSlots extends StatelessWidget {
  const _SameRuntimeSlots({
    required this.runtime,
    required this.firstResolver,
    required this.secondSlot,
  });

  final CanvasRuntime runtime;
  final CanvasResourceResolver firstResolver;
  final Widget secondSlot;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: CanvasSurface(
            key: const ValueKey<String>('surface-a'),
            runtime: runtime,
            resourceResolver: firstResolver,
            interactive: false,
          ),
        ),
        Expanded(child: secondSlot),
      ],
    );
  }
}

CanvasDocument _documentWithResource([String resourceId = 'resource-a']) {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId(resourceId),
        source: CanvasResourceSource.appKey('surface-image-$resourceId'),
        mimeType: 'image/png',
        byteLength: 24,
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasRectElement(
            id: CanvasElementId('rect-a'),
            size: const Size(8, 8),
          ),
        ],
      ),
    ],
  );
}

void _expectSessionResolvesImage(
  SurfaceResourceSession session,
  ResourceAssetResolveRequest request,
  Object image,
) {
  expect(
    identical(resolvedImage(session.resolveResource(request)), image),
    isTrue,
  );
}

final class _RecordingLifecycleSession
    implements SurfaceResourceSessionLifecycle {
  final List<CanvasResourceId> releasedIds = [];
  int releaseAllCount = 0;
  int replacementResetCount = 0;
  int dropCount = 0;

  @override
  void releaseResource(CanvasResourceId id) {
    releasedIds.add(id);
  }

  @override
  void releaseAllResources() {
    releaseAllCount += 1;
  }

  @override
  void resetForDocumentReplacement() {
    replacementResetCount += 1;
  }

  @override
  void drop() {
    dropCount += 1;
  }
}

CanvasRuntime runtimeWithDocument(CanvasDocument document) {
  final runtime = CanvasRuntime();
  runtime.edits.loadDocumentFromJson(encodeCanvasDocumentToJson(document));

  return runtime;
}
