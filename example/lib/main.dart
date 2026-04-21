import 'package:flutter/material.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

import 'data/services/sample_image_asset_service.dart';
import 'ui/canvas_example/widgets/canvas_example_screen.dart';

void main() {
  runApp(const CanvasExampleApp());
}

class CanvasExampleApp extends StatelessWidget {
  const CanvasExampleApp({
    super.key,
    this.controller,
    this.sampleImageAssetService,
  });

  final SceneController? controller;
  final SampleImageAssetService? sampleImageAssetService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'IWB Canvas Engine',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1565C0),
        brightness: Brightness.light,
      ),
      home: CanvasExampleScreen(
        controller: controller,
        sampleImageAssetService: sampleImageAssetService,
      ),
    );
  }
}
