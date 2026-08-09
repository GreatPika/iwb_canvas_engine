import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/resolver_mutation_guard.dart';
import 'package:iwb_canvas_engine/src/resources/resource_resolver_adapter.dart';

final class RecordingResourceResolver implements CanvasResourceResolver {
  RecordingResourceResolver(this._resolve);

  final ui.Image? Function(CanvasImageResource resource) _resolve;
  final List<CanvasImageResource> resources = [];

  int get callCount => resources.length;

  @override
  ui.Image? resolveImage(CanvasImageResource resource) {
    resources.add(resource);

    return _resolve(resource);
  }
}

final class CountingResolverMutationGuard implements ResolverMutationGuard {
  int callbackCount = 0;

  @override
  T runResolverCallback<T>(T Function() callback) {
    callbackCount += 1;

    return callback();
  }

  @override
  void ensureRuntimeMutationAllowed() => _allowRuntimeMutation();
}

int _allowRuntimeMutation() => 0;

// The request fixture builder mirrors the public descriptor payload so tests can
// vary one field without hiding the app-key resolver contract behind presets.
// ignore: number-of-parameters
ResourceAssetResolveRequest descriptorRequest({
  required String id,
  String appKey = 'asset-a',
  String? mimeType = 'image/png',
  String? contentHash = 'sha256:resource',
  int? byteLength = 2048,
  int resourceRevision = 0,
  ui.Rect placeholderBounds = const ui.Rect.fromLTWH(1, 2, 3, 4),
  CanvasMetadata? metadata,
}) {
  return ResourceAssetResolveRequest.descriptor(
    resource: CanvasImageResource(
      id: CanvasResourceId(id),
      source: CanvasResourceSource.appKey(appKey),
      mimeType: mimeType,
      contentHash: contentHash,
      byteLength: byteLength,
      metadata: metadata ?? CanvasMetadata.fromMap({'role': id}),
    ),
    resourceRevision: resourceRevision,
    placeholderBounds: placeholderBounds,
  );
}

ResourceAssetResolveRequest missingRequest({
  required String id,
  int resourceRevision = 0,
  ui.Rect placeholderBounds = const ui.Rect.fromLTWH(5, 6, 7, 8),
}) {
  return ResourceAssetResolveRequest.missingDescriptor(
    resourceId: CanvasResourceId(id),
    resourceRevision: resourceRevision,
    placeholderBounds: placeholderBounds,
  );
}

ui.Image resolvedImage(ResourceAssetResolveResult result) {
  final resolved = result as ResolvedResourceAsset;
  final asset = resolved.asset;
  if (asset is! ImageResourceAsset) {
    throw StateError('Expected the current image resource asset.');
  }

  return asset.image;
}

Future<ui.Image> createResourceTestImage([int color = 0xff00aa00]) {
  return createSizedResourceTestImage(color: color);
}

Future<ui.Image> createSizedResourceTestImage({
  int color = 0xff00aa00,
  int width = 1,
  int height = 1,
}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = ui.Color(color),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();

  return image;
}
