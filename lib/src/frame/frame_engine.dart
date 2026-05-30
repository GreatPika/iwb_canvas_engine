import '../contracts/internal/frame_facts_port.dart';
import '../contracts/internal/selection_facts_port.dart';
import '../geometry/spatial_kernel.dart';
import 'captured_frame.dart';
import 'frame_capture_service.dart';

final class FrameEngine {
  FrameEngine({
    required FrameFactsPort frameFacts,
    required SelectionFactsPort selectionFacts,
    required SpatialKernel spatialKernel,
  }) : _capture = FrameCaptureService(
         frameFacts: frameFacts,
         selectionFacts: selectionFacts,
         queryPaint: spatialKernel.queryPaint,
       );

  final FrameCaptureService _capture;

  CapturedMainFrame captureMainFrame(FrameCaptureInputs inputs) {
    return _capture.captureMainFrame(inputs);
  }

  CapturedOverlayFrame captureOverlayFrame(FrameCaptureInputs inputs) {
    return _capture.captureOverlayFrame(inputs);
  }
}
