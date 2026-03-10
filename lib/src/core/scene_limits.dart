/// Global numeric/scheme limits enforced by scene import/build pipeline.
library;

export '../contract/scene_contract_limits.dart'
    show
        kMaxFontFamilyLength,
        kMaxImageIdLength,
        kMaxLayerIdLength,
        kMaxNodeIdLength,
        kMaxRawSceneJsonLength,
        kMaxSvgPathDataLength,
        kMaxTextLength;

const double sceneCoordMin = -1e7;
const double sceneCoordMax = 1e7;

const double sceneScaleMin = 1e-4;
const double sceneScaleMax = 1e4;

const double sceneSizeMax = 1e7;
const double sceneThicknessMax = 1e5;
const double sceneHitPaddingMax = 1e5;

const int kMaxContentLayersPerScene = 4096;
const int kMaxNodesPerScene = 200000;
const int kMaxStrokePointsPerNode = 20000;
const int kMaxPaletteItems = 1024;
// Guardrail invariants:
// - trimTo must be >= 2 (endpoint-preserving resample requires two points)
// - trimTo must be < softLimit (hysteresis avoids resampling on every point)
const int kInteractiveStrokePointsSoftLimit = 22000;
const int kInteractiveStrokePointsTrimTo = 18000;
const int kInteractiveEraserPointsSoftLimit = 8000;
const int kInteractiveEraserPointsTrimTo = 4000;

const Set<int> sceneSchemaVersionsRead = {5};
const int sceneSchemaVersionWrite = 5;
