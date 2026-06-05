import 'package:flutter/material.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

import 'canvas_controls_dock.dart';
import 'canvas_example_view_model.dart';
import 'canvas_pending_line_overlay.dart';
import 'canvas_text_options_panel.dart';

final class CanvasExampleScreen extends StatefulWidget {
  const CanvasExampleScreen({this.viewModel, super.key});

  final CanvasExampleViewModel? viewModel;

  @override
  State<CanvasExampleScreen> createState() => _CanvasExampleScreenState();
}

// The state owns view-model lifecycle and snackbar projection at the Flutter
// boundary; splitting that lifecycle would make mounted/dispose ordering opaque.
// ignore: coupling-between-object-classes
final class _CanvasExampleScreenState extends State<CanvasExampleScreen> {
  late CanvasExampleViewModel _viewModel;
  late bool _ownsViewModel;
  int _lastShownSampleImageErrorRevision = 0;
  int _lastShownJsonImportErrorRevision = 0;

  @override
  void initState() {
    super.initState();
    _installViewModel(widget.viewModel);
  }

  @override
  void didUpdateWidget(covariant CanvasExampleScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewModel == widget.viewModel) {
      return;
    }
    _removeViewModel();
    _installViewModel(widget.viewModel);
  }

  @override
  void dispose() {
    _removeViewModel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(child: _CanvasExampleContent(viewModel: _viewModel)),
    );
  }

  void _installViewModel(CanvasExampleViewModel? viewModel) {
    _ownsViewModel = viewModel == null;
    _viewModel = viewModel ?? CanvasExampleViewModel();
    _viewModel.addListener(_handleViewModelChanged);
  }

  void _removeViewModel() {
    _viewModel.removeListener(_handleViewModelChanged);
    if (_ownsViewModel) {
      _viewModel.dispose();
    }
  }

  void _handleViewModelChanged() {
    _showSampleImageErrorIfNeeded();
    _showJsonImportErrorIfNeeded();
  }

  void _showSampleImageErrorIfNeeded() {
    final error = _viewModel.sampleImageError;
    final revision = _viewModel.sampleImageErrorRevision;
    if (!mounted ||
        error == null ||
        revision == _lastShownSampleImageErrorRevision) {
      return;
    }
    _lastShownSampleImageErrorRevision = revision;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  void _showJsonImportErrorIfNeeded() {
    final error = _viewModel.jsonImportError;
    final revision = _viewModel.jsonImportErrorRevision;
    if (!mounted ||
        error == null ||
        revision == _lastShownJsonImportErrorRevision) {
      return;
    }
    _lastShownJsonImportErrorRevision = revision;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }
}

// This widget is the screen composition root for surface, overlay, camera, and
// dock; keeping the composition together makes z-order and hit testing clearer.
// ignore: coupling-between-object-classes
final class _CanvasExampleContent extends StatelessWidget {
  const _CanvasExampleContent({required this.viewModel});

  final CanvasExampleViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: CanvasSurface(
            runtime: viewModel.runtime,
            resourceResolver: viewModel.resourceResolver,
            selectionStyle: CanvasSelectionStyle(
              color: const Color(0xFF1565C0),
              strokeWidth: 2,
              haloWidth: 0,
            ),
          ),
        ),
        AnimatedBuilder(
          animation: viewModel,
          builder: (context, _) {
            return _CanvasExampleReactiveLayer(viewModel: viewModel);
          },
        ),
      ],
    );
  }
}

// The reactive layer owns the moving screen chrome above the stable surface so
// runtime ticks rebuild controls and overlays without recreating CanvasSurface.
// ignore: coupling-between-object-classes
final class _CanvasExampleReactiveLayer extends StatelessWidget {
  const _CanvasExampleReactiveLayer({required this.viewModel});

  final CanvasExampleViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _SurfaceOverlays(viewModel: viewModel),
        _CameraIndicatorOverlay(viewModel: viewModel),
        _CameraPanControlsOverlay(viewModel: viewModel),
        _ControlsDockOverlay(viewModel: viewModel),
      ],
    );
  }
}

final class _SurfaceOverlays extends StatelessWidget {
  const _SurfaceOverlays({required this.viewModel});

  final CanvasExampleViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          CanvasPendingLineOverlay(
            preview: viewModel.preview,
            cameraOffset: viewModel.cameraOffset,
          ),
          CanvasTextEditingOverlay(
            runtime: viewModel.runtime,
            inlineEditOnDoubleTap: true,
          ),
        ],
      ),
    );
  }
}

final class _CameraIndicatorOverlay extends StatelessWidget {
  const _CameraIndicatorOverlay({required this.viewModel});

  final CanvasExampleViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 20,
      left: 20,
      child: CanvasCameraIndicator(cameraX: viewModel.cameraOffset.dx),
    );
  }
}

final class _CameraPanControlsOverlay extends StatelessWidget {
  const _CameraPanControlsOverlay({required this.viewModel});

  final CanvasExampleViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 20,
      right: 20,
      child: CanvasCameraPanControls(onPan: viewModel.panCameraBy),
    );
  }
}

final class _ControlsDockOverlay extends StatelessWidget {
  const _ControlsDockOverlay({required this.viewModel});

  final CanvasExampleViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          if (viewModel.selectedTextElement case final text?)
            Positioned(
              left: 20,
              right: 20,
              bottom: 120,
              child: CanvasTextOptionsPanel(
                element: text,
                paletteColors: viewModel.penColors,
                lineHeightMinMultiplier:
                    CanvasExampleViewModel.lineHeightMinMultiplier,
                lineHeightMaxMultiplier:
                    CanvasExampleViewModel.lineHeightMaxMultiplier,
                lineHeightMultiplier: viewModel.lineHeightMultiplierForText(
                  text,
                ),
                onToggleBold: viewModel.toggleSelectedTextBold,
                onToggleItalic: viewModel.toggleSelectedTextItalic,
                onToggleUnderline: viewModel.toggleSelectedTextUnderline,
                onAlignChanged: viewModel.setSelectedTextAlign,
                onFontSizeChanged: viewModel.setSelectedTextFontSize,
                onLineHeightMultiplierChanged:
                    viewModel.setSelectedTextLineHeightMultiplier,
                onColorChanged: viewModel.setSelectedTextColor,
              ),
            ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: CanvasControlsDock(viewModel: viewModel),
          ),
        ],
      ),
    );
  }
}
