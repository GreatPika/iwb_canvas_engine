import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

const performanceHostSurfaceKey = ValueKey<String>('perf.host.surface');
const performanceHostTextOverlayKey = ValueKey<String>(
  'perf.host.text_overlay',
);
const performanceHostResourceAppKey = 'perf-host-image';

final class PerformanceHostController extends ChangeNotifier {
  PerformanceHostController({
    CanvasRuntime? runtime,
    PerformanceHostResourceResolver? resourceResolver,
  }) : _runtime =
           runtime ?? CanvasRuntime(config: _acceptDeletionRuntimeConfig()),
       resourceResolver = resourceResolver ?? PerformanceHostResourceResolver();

  CanvasRuntime _runtime;
  final PerformanceHostResourceResolver resourceResolver;

  CanvasRuntime get runtime => _runtime;

  void loadSmokeDocument() {
    runtime.edits.edit((edit) {
      edit.replaceDraftDocument(createPerformanceHostSmokeDocument());
    });
  }

  void swapRuntime(CanvasRuntime replacement) {
    final previous = _runtime;
    _runtime = replacement;
    notifyListeners();
    previous.dispose();
  }

  @override
  void dispose() {
    _runtime.dispose();
    super.dispose();
  }
}

final class PerformanceHost extends StatelessWidget {
  const PerformanceHost({required this.controller, super.key});

  final PerformanceHostController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox.expand(
            child: Stack(
              children: [
                CanvasSurface(
                  key: performanceHostSurfaceKey,
                  runtime: controller.runtime,
                  resourceResolver: controller.resourceResolver,
                ),
                CanvasTextEditingOverlay(
                  key: performanceHostTextOverlayKey,
                  runtime: controller.runtime,
                  autofocus: false,
                  commitOnFocusLoss: false,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

final class PerformanceHostResourceResolver implements CanvasResourceResolver {
  final List<String> resolvedAppKeys = <String>[];

  @override
  ui.Image? resolveImage(CanvasImageResource resource) {
    final source = resource.source;
    if (source is CanvasAppKeyResourceSource) {
      resolvedAppKeys.add(source.key);
    }

    return null;
  }

  @override
  CanvasPreparedVector? resolveVector(CanvasVectorResource resource) => null;
}

CanvasDocument createPerformanceHostSmokeDocument() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('perf-image-resource'),
        source: CanvasResourceSource.appKey(performanceHostResourceAppKey),
        mimeType: 'image/png',
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('perf-layer'),
        elements: [
          CanvasImageElement(
            id: CanvasElementId('perf-image'),
            resourceId: CanvasResourceId('perf-image-resource'),
            size: const Size(24, 16),
            naturalSize: const Size(24, 16),
          ),
          CanvasRectElement(
            id: CanvasElementId('perf-command-target'),
            transform: CanvasTransform.translation(const Offset(40, 0)),
            size: const Size(18, 18),
            fillColor: const Color(0xFF1565C0),
          ),
          CanvasTextElement(
            id: CanvasElementId('perf-text'),
            transform: CanvasTransform.translation(const Offset(0, 32)),
            text: 'perf',
            color: const Color(0xFF111111),
            textDirection: TextDirection.ltr,
            fontSize: 18,
            maxWidth: 120,
          ),
        ],
      ),
    ],
  );
}

bool removePerformanceCommandTarget(
  CanvasRuntime runtime, {
  int timestampMs = 1,
}) {
  return runtime.commands.removeElement(
    CanvasElementId('perf-command-target'),
    timestampMs: timestampMs,
  );
}

void switchPerformanceMarkerTool(CanvasRuntime runtime) {
  runtime.tools
    ..setMode(CanvasInteractionMode.draw)
    ..setDrawTool(CanvasDrawTool.marker);
}

CanvasTextEditSession? startPerformanceTextEditingFromContextAction(
  CanvasRuntime runtime,
  CanvasContextActionRequested request,
) {
  return runtime.textEditing.startFromContextAction(request);
}

CanvasDeletionDecision _acceptDeletionCommit(CanvasDeletionCommitRequest _) =>
    CanvasDeletionDecision.accept;

CanvasRuntimeConfig _acceptDeletionRuntimeConfig() =>
    const CanvasRuntimeConfig(deletionCommitResolver: _acceptDeletionCommit);
