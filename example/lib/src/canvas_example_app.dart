import 'package:flutter/material.dart';

import 'canvas_example_screen.dart';

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
