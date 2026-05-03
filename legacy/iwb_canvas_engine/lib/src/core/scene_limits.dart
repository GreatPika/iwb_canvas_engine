/// Global numeric/scheme limits enforced by scene import/build pipeline.
library;

export '../contract/scene_contract_limits.dart'
    show
        kMaxFontFamilyLength,
        kMaxImageIdLength,
        kMaxContentLayersPerScene,
        kMaxLayerIdLength,
        kMaxNodesPerScene,
        kMaxPaletteItems,
        kMaxNodeIdLength,
        kMaxRawSceneJsonLength,
        kMaxStrokePointsPerNode,
        kMinGridCellSize,
        kMaxSvgPathDataLength,
        kMaxTextLength,
        sceneCoordMax,
        sceneCoordMin,
        sceneSizeMax;

const double sceneScaleMin = 1e-4;
const double sceneScaleMax = 1e4;

const double sceneThicknessMax = 1e5;
const double sceneHitPaddingMax = 1e5;

// Guardrail invariants:
// - trimTo must be >= 2 (endpoint-preserving resample requires two points)
// - trimTo must be < softLimit (hysteresis avoids resampling on every point)
const int kInteractiveStrokePointsSoftLimit = 22000;
const int kInteractiveStrokePointsTrimTo = 18000;
const int kInteractiveEraserPointsSoftLimit = 8000;
const int kInteractiveEraserPointsTrimTo = 4000;

const Set<int> sceneSchemaVersionsRead = {7};
const int sceneSchemaVersionWrite = 7;
