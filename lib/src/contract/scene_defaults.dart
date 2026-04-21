import 'dart:ui';

/// Shared palette/grid defaults used across public snapshots and core scene.
class SceneDefaults {
  static const double gridCellSize = 10;

  static const List<Color> penColors = <Color>[
    Color(0xFF000000),
    Color(0xFFE53935),
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFFB8C00),
    Color(0xFF8E24AA),
  ];

  static const Color backgroundColor = Color(0xFFFFFFFF);
  static const List<Color> backgroundColors = <Color>[
    backgroundColor,
    Color(0xFFFFF9C4),
    Color(0xFFBBDEFB),
    Color(0xFFC8E6C9),
  ];

  static const List<double> gridSizes = <double>[gridCellSize, 20, 40, 80];
  static const Color gridColor = Color(0x1F000000);
}
