import 'package:flutter/material.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

import 'canvas_example_defaults.dart';

final class CanvasExampleApp extends StatelessWidget {
  const CanvasExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'IWB Canvas Engine Example',
      home: CanvasExampleScreen(),
    );
  }
}

final class CanvasExampleScreen extends StatefulWidget {
  const CanvasExampleScreen({super.key});

  @override
  State<CanvasExampleScreen> createState() => _CanvasExampleScreenState();
}

final class _CanvasExampleScreenState extends State<CanvasExampleScreen> {
  late final CanvasRuntime _runtime = createCanvasExampleRuntime();

  @override
  void dispose() {
    _runtime.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CanvasExampleSurfaceHost(runtime: _runtime);
  }
}

final class CanvasExampleSurfaceHost extends StatelessWidget {
  const CanvasExampleSurfaceHost({required this.runtime, super.key});

  final CanvasRuntime runtime;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('IWB Canvas Engine')),
      body: SafeArea(
        child: ColoredBox(
          color: const Color(0xFFF5F6F8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: CanvasSurface(runtime: runtime),
          ),
        ),
      ),
    );
  }
}
