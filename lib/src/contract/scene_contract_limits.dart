/// Contract-safe limits shared by public boundary validators.
library;

const int kMaxSvgPathDataLength = 200000;
const int kMaxLayerIdLength = 256;
const int kMaxNodeIdLength = 256;
const int kMaxImageIdLength = 1024;
const int kMaxFontFamilyLength = 256;
const int kMaxTextLength = 100000;
const int kMaxStrokePointsPerNode = 20000;
const int kMaxPaletteItems = 1024;
const int kMaxRawSceneJsonLength = 32 * 1024 * 1024;
const int kMaxContentLayersPerScene = 4096;
const int kMaxNodesPerScene = 200000;
const double sceneCoordMin = -1e7;
const double sceneCoordMax = 1e7;
const double sceneSizeMax = 1e7;
const double kMinGridCellSize = 1.0;

List<int> sceneContractLimitValues() {
  return const <int>[
    kMaxSvgPathDataLength,
    kMaxLayerIdLength,
    kMaxNodeIdLength,
    kMaxImageIdLength,
    kMaxFontFamilyLength,
    kMaxTextLength,
    kMaxStrokePointsPerNode,
    kMaxPaletteItems,
    kMaxRawSceneJsonLength,
    kMaxContentLayersPerScene,
    kMaxNodesPerScene,
  ];
}

List<double> sceneContractDoubleLimitValues() {
  return const <double>[
    sceneCoordMin,
    sceneCoordMax,
    sceneSizeMax,
    kMinGridCellSize,
  ];
}
