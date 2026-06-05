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
ResourceImageResolveRequest descriptorRequest({
  required String id,
  String appKey = 'asset-a',
  String? mimeType = 'image/png',
  String? contentHash = 'sha256:resource',
  int? byteLength = 2048,
  int resourceRevision = 0,
  ui.Rect placeholderBounds = const ui.Rect.fromLTWH(1, 2, 3, 4),
  CanvasMetadata? metadata,
}) {
  return ResourceImageResolveRequest.descriptor(
    resourceId: CanvasResourceId(id),
    appKey: appKey,
    mimeType: mimeType,
    contentHash: contentHash,
    byteLength: byteLength,
    metadata: metadata ?? CanvasMetadata.fromMap({'role': id}),
    resourceRevision: resourceRevision,
    placeholderBounds: placeholderBounds,
  );
}

ResourceImageResolveRequest missingRequest({
  required String id,
  int resourceRevision = 0,
  ui.Rect placeholderBounds = const ui.Rect.fromLTWH(5, 6, 7, 8),
}) {
  return ResourceImageResolveRequest.missingDescriptor(
    resourceId: CanvasResourceId(id),
    resourceRevision: resourceRevision,
    placeholderBounds: placeholderBounds,
  );
}

ui.Image resolvedImage(ResourceImageResolveResult result) {
  final resolved = result as ResolvedResourceImage;

  return resolved.image;
}

Future<ui.Image> createResourceTestImage([int color = 0xff00aa00]) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, 1, 1),
    ui.Paint()..color = ui.Color(color),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(1, 1);
  picture.dispose();

  return image;
}
