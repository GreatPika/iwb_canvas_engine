import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../frame/frame_paint_output.dart';
import 'main_painter.dart';
import 'overlay_painter.dart';

final class LayerPaintHost extends StatelessWidget {
  const LayerPaintHost({
    required this.paintSize,
    required this.mainOutputListenable,
    required this.overlayOutputListenable,
  }) : super(key: const ValueKey<String>('iwb_canvas_surface.paint_host'));

  final Size paintSize;
  final ValueListenable<MainFramePaintOutput?> mainOutputListenable;
  final ValueListenable<OverlayFramePaintOutput?> overlayOutputListenable;

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: paintSize,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            key: const ValueKey<String>(
              'iwb_canvas_surface.main_repaint_boundary',
            ),
            child: CustomPaint(
              key: const ValueKey<String>('iwb_canvas_surface.main_paint_host'),
              painter: MainFramePainter(outputListenable: mainOutputListenable),
            ),
          ),
          RepaintBoundary(
            key: const ValueKey<String>(
              'iwb_canvas_surface.overlay_repaint_boundary',
            ),
            child: CustomPaint(
              key: const ValueKey<String>(
                'iwb_canvas_surface.overlay_paint_host',
              ),
              painter: OverlayFramePainter(
                outputListenable: overlayOutputListenable,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
