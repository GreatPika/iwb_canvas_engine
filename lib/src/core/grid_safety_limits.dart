/// Safety limits for background grid rendering.
///
/// These limits prevent pathological grid settings from producing excessive
/// paint workload and frame stalls.
library;

/// Minimum allowed grid cell size in scene/world units when the grid is on.
const double kMinGridCellSize = 1.0;

/// Maximum number of grid lines per axis that may be painted in one frame.
///
/// When raw grid density exceeds this limit, rendering must degrade by
/// increasing line stride (draw every Nth line) instead of fully skipping grid.
const int kMaxGridLinesPerAxis = 200;
