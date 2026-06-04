import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine_example/src/canvas_example_screen.dart';
import 'package:iwb_canvas_engine_example/src/canvas_example_view_model.dart';
import 'package:iwb_canvas_engine_example/src/sample_image_asset_service.dart';
import 'package:iwb_canvas_engine_example/src/sample_image_resolver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  _registerAddSampleSuccessTest();
  _registerAddSampleRepeatTest();
  _registerAddSampleIdCollisionTest();
  _registerAddSampleFailureTest();
  _registerResolverAndDisposalTest();
  _registerSurfaceReceivesResolverTest();
  _registerSurfaceRenderingResolverTest();
  _registerFailureSnackbarTest();
}

void _registerAddSampleSuccessTest() {
  test(
    'Add Sample inserts rect, text, resource, and image via public DTOs',
    () async {
      final viewModel = CanvasExampleViewModel(
        sampleImageAssetService: _fileBackedService(),
      );
      addTearDown(viewModel.dispose);

      await viewModel.addSampleObjects();

      final document = viewModel.document;
      expect(document.resources.map((resource) => resource.id), [
        SampleImageResolver.sampleCatResourceId,
      ]);
      _expectSampleRect(
        _elements(document).whereType<CanvasRectElement>().single,
      );
      _expectSampleText(
        _elements(document).whereType<CanvasTextElement>().single,
      );
      _expectSampleImage(
        _elements(document).whereType<CanvasImageElement>().single,
      );
    },
  );
}

void _registerAddSampleRepeatTest() {
  test(
    'repeated Add Sample uses unique element ids and visible offsets',
    () async {
      final viewModel = CanvasExampleViewModel(
        sampleImageAssetService: _fileBackedService(),
      );
      addTearDown(viewModel.dispose);

      await viewModel.addSampleObjects();
      await viewModel.addSampleObjects();

      final elements = _elements(viewModel.document);
      expect(elements.map((element) => element.id.value).toSet(), hasLength(6));
      expect(
        elements.map((element) => element.transform.translation).toSet(),
        hasLength(6),
      );
      expect(viewModel.runtimeState.summary.resourceCount, 1);
    },
  );
}

void _registerAddSampleIdCollisionTest() {
  test(
    'Add Sample skips ids that already exist in the current document',
    () async {
      final viewModel = CanvasExampleViewModel(
        sampleImageAssetService: _fileBackedService(),
      );
      addTearDown(viewModel.dispose);
      viewModel.runtime.edits.edit((edit) {
        edit.addElement(
          CanvasRectElement(
            id: CanvasElementId('sample-0'),
            size: const Size(1, 1),
          ),
          layerId: CanvasLayerId('layer-auto-0'),
        );
      });

      await viewModel.addSampleObjects();

      final elementIds = _elements(
        viewModel.document,
      ).map((element) => element.id.value);
      expect(elementIds.toSet(), hasLength(4));
      expect(
        elementIds,
        containsAll(['sample-0', 'sample-1', 'sample-2', 'sample-3']),
      );
      expect(viewModel.sampleImageError, isNull);
    },
  );
}

void _registerAddSampleFailureTest() {
  test(
    'cat load failure leaves document unchanged and records bounded error',
    () async {
      final viewModel = CanvasExampleViewModel(
        sampleImageAssetService: _failingService(),
      );
      addTearDown(viewModel.dispose);
      final before = viewModel.runtimeState.summary;

      await viewModel.addSampleObjects();

      expect(viewModel.runtimeState.summary, before);
      expect(viewModel.document.resources, isEmpty);
      expect(viewModel.sampleImageError, 'Unable to load sample cat image.');
      expect(viewModel.sampleImageErrorRevision, 1);
    },
  );
}

void _registerResolverAndDisposalTest() {
  test(
    'app resolver returns cat image and view model disposes app-owned image',
    () async {
      final viewModel = CanvasExampleViewModel(
        sampleImageAssetService: _fileBackedService(),
      );
      final resolver = viewModel.resourceResolver;

      await viewModel.addSampleObjects();
      expect(viewModel.resourceResolver, same(resolver));
      final resource =
          viewModel.document.resources.single as CanvasImageResource;
      final image = resolver.resolveImage(resource);

      if (image == null) {
        fail('Expected the app resolver to return the sample cat image.');
      }
      expect(image.debugDisposed, isFalse);

      viewModel.dispose();
      expect(image.debugDisposed, isTrue);
    },
  );
}

void _registerSurfaceReceivesResolverTest() {
  testWidgets('screen passes app resolver to CanvasSurface', (tester) async {
    final viewModel = CanvasExampleViewModel();
    addTearDown(viewModel.dispose);
    await tester.pumpWidget(
      MaterialApp(home: CanvasExampleScreen(viewModel: viewModel)),
    );
    await tester.pump();

    final surface = tester.widget<CanvasSurface>(find.byType(CanvasSurface));
    expect(surface.resourceResolver, isNotNull);
  });
}

void _registerSurfaceRenderingResolverTest() {
  testWidgets('CanvasSurface asks resolver for the sample-cat descriptor', (
    tester,
  ) async {
    final runtime = CanvasRuntime(initialDocument: _sampleImageDocument());
    final resolver = _RecordingResourceResolver();
    addTearDown(runtime.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 100,
          height: 100,
          child: CanvasSurface(
            runtime: runtime,
            resourceResolver: resolver,
            interactive: false,
          ),
        ),
      ),
    );

    expect(resolver.requestedIds, [SampleImageResolver.sampleCatResourceId]);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

void _registerFailureSnackbarTest() {
  testWidgets('screen projects Add Sample failure as snackbar', (tester) async {
    final viewModel = CanvasExampleViewModel(
      sampleImageAssetService: _failingService(),
    );
    addTearDown(viewModel.dispose);
    await tester.pumpWidget(
      MaterialApp(home: CanvasExampleScreen(viewModel: viewModel)),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('sample.add')));
    await tester.pumpAndSettle();

    expect(find.text('Unable to load sample cat image.'), findsOneWidget);
    expect(viewModel.runtimeState.summary.elementCount, 0);

    ScaffoldMessenger.of(
      tester.element(find.byType(CanvasExampleScreen)),
    ).clearSnackBars();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sample.add')));
    await tester.pumpAndSettle();

    expect(find.text('Unable to load sample cat image.'), findsOneWidget);
    expect(viewModel.sampleImageErrorRevision, 2);
  });
}

SampleImageAssetService _fileBackedService() {
  return SampleImageAssetService(
    assetLoader: (_) => _byteDataForFile(File('image/cat.png')),
  );
}

SampleImageAssetService _failingService() {
  return SampleImageAssetService(
    assetLoader: (_) => throw StateError('decode failed'),
  );
}

Future<ByteData> _byteDataForFile(File file) async {
  final bytes = await file.readAsBytes();
  final data = Uint8List.fromList(bytes);

  return ByteData.sublistView(data);
}

List<CanvasElement> _elements(CanvasDocument document) {
  return [for (final layer in document.layers) ...layer.elements];
}

void _expectSampleRect(CanvasRectElement rect) {
  expect(rect.size, const Size(140, 90));
  expect(rect.fillColor, const Color(0xFF2196F3).withValues(alpha: 0.2));
  expect(rect.strokeColor, const Color(0xFF2196F3));
  expect(rect.strokeWidth, 2);
}

void _expectSampleText(CanvasTextElement text) {
  expect(text.text, 'New Note');
  expect(text.fontSize, 20);
  expect(text.color, const Color(0xDD000000));
}

void _expectSampleImage(CanvasImageElement image) {
  expect(image.resourceId, SampleImageResolver.sampleCatResourceId);
  expect(image.size, const Size(120, 180));
}

CanvasDocument _sampleImageDocument() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: SampleImageResolver.sampleCatResourceId,
        source: CanvasResourceSource.appKey('sample-cat'),
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-auto-0'),
        elements: [
          CanvasImageElement(
            id: CanvasElementId('sample-image'),
            resourceId: SampleImageResolver.sampleCatResourceId,
            size: const Size(20, 20),
          ),
        ],
      ),
    ],
  );
}

final class _RecordingResourceResolver implements CanvasResourceResolver {
  final requestedIds = <CanvasResourceId>[];

  @override
  Null resolveImage(CanvasImageResource resource) {
    requestedIds.add(resource.id);

    return null;
  }
}
