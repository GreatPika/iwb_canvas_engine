import 'package:flutter/material.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

import 'canvas_controls_dock.dart';
import 'canvas_example_view_model.dart';
import 'canvas_pending_line_overlay.dart';

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
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(title: const Text('IWB Canvas Engine')),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _viewModel,
          builder: (context, _) => _CanvasExampleContent(viewModel: _viewModel),
        ),
      ),
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
    if (mounted) {
      setState(() {});
    }
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
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _surfaceStack(),
          ),
        ),
        Positioned(
          top: 20,
          left: 20,
          child: CanvasCameraIndicator(cameraOffset: viewModel.cameraOffset),
        ),
        Positioned(
          top: 20,
          right: 20,
          child: CanvasCameraPanControls(
            onPan: viewModel.panCameraBy,
            onReset: viewModel.resetCamera,
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 20,
          child: CanvasControlsDock(viewModel: viewModel),
        ),
      ],
    );
  }

  Widget _surfaceStack() {
    return Stack(
      children: [
        CanvasSurface(
          runtime: viewModel.runtime,
          resourceResolver: viewModel.resourceResolver,
          selectionStyle: CanvasSelectionStyle(
            color: const Color(0xFFFFFF00),
            strokeWidth: 4,
          ),
        ),
        CanvasPendingLineOverlay(
          preview: viewModel.preview,
          cameraOffset: viewModel.cameraOffset,
        ),
      ],
    );
  }
}
