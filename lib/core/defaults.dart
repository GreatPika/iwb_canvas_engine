import 'dart:ui';

/// Default values used by the engine for palettes and tool settings.
class SceneDefaults {
  static const List<Color> penColors = <Color>[
    Color(0xFF000000),
    Color(0xFFE53935),
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFFB8C00),
    Color(0xFF8E24AA),
  ];

  static const List<Color> backgroundColors = <Color>[
    Color(0xFFFFFFFF),
    Color(0xFFFFF9C4),
    Color(0xFFBBDEFB),
    Color(0xFFC8E6C9),
  ];

  static const List<double> gridSizes = <double>[10, 20, 40, 80];

  static const double penThickness = 3;
  static const double highlighterThickness = 12;
  static const double highlighterOpacity = 0.4;
  static const double eraserThickness = 20;

  static const Color gridColor = Color(0x1F000000);
}
