import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

import '../../../data/services/sample_image_asset_service.dart';
import '../view_models/canvas_example_view_model.dart';
import 'canvas_controls_dock.dart';
import 'canvas_scene_surface.dart';
import 'canvas_text_edit_overlay.dart';
import 'canvas_text_options_panel.dart';

class CanvasExampleScreen extends StatefulWidget {
  const CanvasExampleScreen({
    super.key,
    this.controller,
    this.sampleImageAssetService,
  });

  final SceneController? controller;
  final SampleImageAssetService? sampleImageAssetService;

  @override
  State<CanvasExampleScreen> createState() => _CanvasExampleScreenState();
}

class _CanvasExampleScreenState extends State<CanvasExampleScreen> {
  late CanvasExampleViewModel _viewModel;
  TextEditingController? _textEditController;
  FocusNode? _textEditFocusNode;
  NodeId? _syncedEditingNodeId;

  @override
  void initState() {
    super.initState();
    _viewModel = _createViewModel();
    _viewModel.addListener(_syncInlineTextEditor);
    _syncInlineTextEditor();
  }

  @override
  void didUpdateWidget(covariant CanvasExampleScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller &&
        oldWidget.sampleImageAssetService == widget.sampleImageAssetService) {
      return;
    }

    _viewModel.removeListener(_syncInlineTextEditor);
    _viewModel.dispose();
    _disposeTextEditState();

    _viewModel = _createViewModel();
    _viewModel.addListener(_syncInlineTextEditor);
    _syncInlineTextEditor();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_syncInlineTextEditor);
    _disposeTextEditState();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _viewModel,
          builder: (context, _) {
            final selectedTextNodes = _viewModel.selectedTextNodes;
            final editingNode = _viewModel.editingTextNode;
            final textEditController = _textEditController;
            final textEditFocusNode = _textEditFocusNode;

            return Stack(
              children: [
                Positioned.fill(
                  child: CanvasSceneSurface(
                    controller: _viewModel.controller,
                    imageResolver: _viewModel.imageResolver,
                    cameraOffset: _viewModel.cameraOffset,
                    pendingLineStart: _viewModel.pendingLineStart,
                    pendingLineColor: _viewModel.pendingLineColor,
                    pendingLineThickness: _viewModel.pendingLineThickness,
                  ),
                ),
                Positioned(
                  top: 20,
                  left: 20,
                  child: CanvasCameraIndicator(cameraX: _viewModel.cameraX),
                ),
                Positioned(
                  top: 20,
                  right: 20,
                  child: CanvasCameraPanControls(onPan: _viewModel.panCameraBy),
                ),
                if (selectedTextNodes.isNotEmpty)
                  Positioned(
                    bottom: 120,
                    left: 20,
                    right: 20,
                    child: CanvasTextOptionsPanel(
                      node: selectedTextNodes.first,
                      paletteColors: _viewModel.penColors,
                      lineHeightMinMultiplier:
                          CanvasExampleViewModel.lineHeightMinMultiplier,
                      lineHeightMaxMultiplier:
                          CanvasExampleViewModel.lineHeightMaxMultiplier,
                      lineHeightMultiplier: _viewModel
                          .lineHeightMultiplierForNode(selectedTextNodes.first),
                      onToggleBold: _viewModel.toggleSelectedTextBold,
                      onToggleItalic: _viewModel.toggleSelectedTextItalic,
                      onToggleUnderline: _viewModel.toggleSelectedTextUnderline,
                      onAlignChanged: _viewModel.setSelectedTextAlign,
                      onFontSizeChanged: _viewModel.setSelectedTextFontSize,
                      onLineHeightMultiplierChanged:
                          _viewModel.setSelectedTextLineHeightMultiplier,
                      onColorChanged: _viewModel.setSelectedTextColor,
                    ),
                  ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: CanvasControlsDock(
                    isDrawMode: _viewModel.isDrawMode,
                    hasSelection: _viewModel.hasSelection,
                    currentMode: _viewModel.mode,
                    currentDrawTool: _viewModel.drawTool,
                    penColors: _viewModel.penColors,
                    selectedDrawColor: _viewModel.drawColor,
                    isGridEnabled: _viewModel.isGridEnabled,
                    gridCellSize: _viewModel.gridCellSize,
                    gridSizes: _viewModel.gridSizes,
                    backgroundColors: _viewModel.backgroundColors,
                    selectedBackgroundColor: _viewModel.backgroundColor,
                    onModeChanged: _handleModeChanged,
                    onDrawToolChanged: _viewModel.setDrawTool,
                    onDrawColorChanged: _viewModel.setDrawColor,
                    onRotateLeft: () {
                      _viewModel.rotateSelection(clockwise: false);
                    },
                    onRotateRight: () {
                      _viewModel.rotateSelection(clockwise: true);
                    },
                    onFlipVertical: _viewModel.flipSelectionVertical,
                    onFlipHorizontal: _viewModel.flipSelectionHorizontal,
                    onDeleteSelection: _viewModel.deleteSelection,
                    onAddSample: _viewModel.addSampleObjects,
                    onGridEnabledChanged: _viewModel.setGridEnabled,
                    onGridCellSizeChanged: _viewModel.setGridSize,
                    onBackgroundColorChanged: _viewModel.setBackgroundColor,
                    onExportJson: () {
                      unawaited(_showExportDialog());
                    },
                    onImportJson: () {
                      unawaited(_showImportDialog());
                    },
                    onClearCanvas: _viewModel.clearCanvas,
                  ),
                ),
                if (editingNode != null &&
                    textEditController != null &&
                    textEditFocusNode != null)
                  Positioned.fill(
                    child: CanvasTextEditOverlay(
                      node: editingNode,
                      cameraOffset: _viewModel.cameraOffset,
                      textController: textEditController,
                      focusNode: textEditFocusNode,
                      onDismiss: _commitInlineTextEdit,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  CanvasExampleViewModel _createViewModel() {
    return CanvasExampleViewModel(
      controller: widget.controller,
      sampleImageAssetService: widget.sampleImageAssetService,
    );
  }

  void _syncInlineTextEditor() {
    final editingNode = _viewModel.editingTextNode;
    if (editingNode == null) {
      _disposeTextEditState();
      return;
    }

    if (_syncedEditingNodeId == editingNode.id &&
        _textEditController != null &&
        _textEditFocusNode != null) {
      return;
    }

    _disposeTextEditState();
    _syncedEditingNodeId = editingNode.id;
    _textEditController = TextEditingController(text: editingNode.text);
    _textEditFocusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _syncedEditingNodeId != editingNode.id) {
        return;
      }
      _textEditFocusNode?.requestFocus();
    });
  }

  void _disposeTextEditState() {
    _syncedEditingNodeId = null;
    _textEditController?.dispose();
    _textEditFocusNode?.dispose();
    _textEditController = null;
    _textEditFocusNode = null;
  }

  void _commitInlineTextEdit() {
    _viewModel.finishInlineTextEdit(
      save: true,
      text: _textEditController?.text,
    );
  }

  void _handleModeChanged(CanvasMode mode) {
    _viewModel.setMode(
      mode,
      activeInlineText: _textEditController?.text,
      saveInlineText: true,
    );
  }

  Future<void> _showExportDialog() async {
    final json = _viewModel.exportSceneJson();
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scene JSON'),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: TextEditingController(text: json),
            maxLines: 8,
            readOnly: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: json));
              Navigator.pop(context);
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showImportDialog() async {
    final textController = TextEditingController(
      text: _viewModel.lastExportedJson ?? '',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Scene'),
        content: TextField(controller: textController, maxLines: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, textController.text),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    textController.dispose();

    if (!mounted || result == null || result.isEmpty) {
      return;
    }

    final error = _viewModel.importSceneJson(result);
    if (error == null || !mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }
}
