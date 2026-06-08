/// Graph-checkable marker for release benchmark readiness tooling.
///
/// This declaration intentionally lives under `tool/bench` so architecture
/// graph closure can prove release measurement readiness without adding public
/// API or runtime production behavior.
final class ReleaseReadiness {
  const ReleaseReadiness._();
}
