/// Safety limits for background grid rendering.
///
/// These limits prevent pathological grid settings from producing excessive
/// paint workload and frame stalls.
library;

export '../contract/scene_contract_limits.dart' show kMinGridCellSize;

/// Maximum number of grid lines per axis that may be painted in one frame.
///
/// When raw grid density exceeds this limit, rendering must degrade by
/// increasing line stride (draw every Nth line) instead of fully skipping grid.
const int kMaxGridLinesPerAxis = 200;
