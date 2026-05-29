final class SpatialBudgetCounters {
  int _queryTileBudgetExceededCount = 0;
  int _fallbackCandidateBudgetExceededCount = 0;
  int _invalidIndexProbeCount = 0;

  int get queryTileBudgetExceededCount => _queryTileBudgetExceededCount;
  int get fallbackCandidateBudgetExceededCount =>
      _fallbackCandidateBudgetExceededCount;
  int get invalidIndexProbeCount => _invalidIndexProbeCount;

  void recordQueryTileBudgetExceeded() {
    _queryTileBudgetExceededCount += 1;
  }

  void recordFallbackCandidateBudgetExceeded() {
    _fallbackCandidateBudgetExceededCount += 1;
  }

  void recordInvalidIndexProbe() {
    _invalidIndexProbeCount += 1;
  }
}
