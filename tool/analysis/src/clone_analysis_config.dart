enum CloneAnalysisOutputFormat { text, json }

enum CloneAnalysisReportMode { pairs, clusters }

class CloneAnalysisConfig {
  static const Object noChange = Object();

  CloneAnalysisConfig({
    required this.rootPath,
    required this.minTokens,
    required this.kGramSize,
    required this.windowSize,
    required this.minSharedFingerprints,
    required this.minOverlap,
    required this.maxBucketSize,
    required this.excludeMain,
    required this.topResults,
    required this.outputFormat,
    required this.reportMode,
  });

  factory CloneAnalysisConfig.defaults() {
    return CloneAnalysisConfig(
      rootPath: '.',
      minTokens: 40,
      kGramSize: 25,
      windowSize: 4,
      minSharedFingerprints: 3,
      minOverlap: 0.35,
      maxBucketSize: 20,
      excludeMain: false,
      topResults: null,
      outputFormat: CloneAnalysisOutputFormat.text,
      reportMode: CloneAnalysisReportMode.pairs,
    );
  }

  final String rootPath;
  final int minTokens;
  final int kGramSize;
  final int windowSize;
  final int minSharedFingerprints;
  final double minOverlap;
  final int maxBucketSize;
  final bool excludeMain;
  final int? topResults;
  final CloneAnalysisOutputFormat outputFormat;
  final CloneAnalysisReportMode reportMode;

  CloneAnalysisConfig copyWith({
    String? rootPath,
    int? minTokens,
    int? kGramSize,
    int? windowSize,
    int? minSharedFingerprints,
    double? minOverlap,
    int? maxBucketSize,
    bool? excludeMain,
    Object? topResults = noChange,
    CloneAnalysisOutputFormat? outputFormat,
    CloneAnalysisReportMode? reportMode,
  }) {
    return CloneAnalysisConfig(
      rootPath: _resolveString(rootPath, this.rootPath),
      minTokens: _resolveInt(minTokens, this.minTokens),
      kGramSize: _resolveInt(kGramSize, this.kGramSize),
      windowSize: _resolveInt(windowSize, this.windowSize),
      minSharedFingerprints: _resolveInt(
        minSharedFingerprints,
        this.minSharedFingerprints,
      ),
      minOverlap: _resolveDouble(minOverlap, this.minOverlap),
      maxBucketSize: _resolveInt(maxBucketSize, this.maxBucketSize),
      excludeMain: _resolveBool(excludeMain, this.excludeMain),
      topResults: _resolveTopResults(topResults, this.topResults),
      outputFormat: outputFormat ?? this.outputFormat,
      reportMode: reportMode ?? this.reportMode,
    );
  }

  String? validate() {
    return _firstValidationError(<String?>[
      _validateRequiredPath(rootPath),
      _validatePositiveInt('minTokens', minTokens),
      _validatePositiveInt('kGramSize', kGramSize),
      _validatePositiveInt('windowSize', windowSize),
      _validatePositiveInt('minSharedFingerprints', minSharedFingerprints),
      _validateUnitRange('minOverlap', minOverlap),
      _validatePositiveInt('maxBucketSize', maxBucketSize),
      _validateOptionalPositiveInt('topResults', topResults),
    ]);
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'rootPath': rootPath,
      'minTokens': minTokens,
      'kGramSize': kGramSize,
      'windowSize': windowSize,
      'minSharedFingerprints': minSharedFingerprints,
      'minOverlap': minOverlap,
      'maxBucketSize': maxBucketSize,
      'excludeMain': excludeMain,
      'topResults': topResults,
      'outputFormat': outputFormat.name,
      'reportMode': reportMode.name,
    };
  }
}

int? _resolveTopResults(Object? topResults, int? fallback) {
  if (identical(topResults, CloneAnalysisConfig.noChange)) {
    return fallback;
  }
  return topResults as int?;
}

String _resolveString(String? value, String fallback) {
  return value ?? fallback;
}

int _resolveInt(int? value, int fallback) {
  return value ?? fallback;
}

double _resolveDouble(double? value, double fallback) {
  return value ?? fallback;
}

bool _resolveBool(bool? value, bool fallback) {
  return value ?? fallback;
}

String? _firstValidationError(List<String?> candidates) {
  for (final candidate in candidates) {
    if (candidate != null) {
      return candidate;
    }
  }
  return null;
}

String? _validateRequiredPath(String value) {
  if (value.isEmpty) {
    return 'rootPath must not be empty.';
  }
  return null;
}

String? _validatePositiveInt(String name, int value) {
  if (value <= 0) {
    return '$name must be > 0.';
  }
  return null;
}

String? _validateOptionalPositiveInt(String name, int? value) {
  if (value == null) {
    return null;
  }
  return _validatePositiveInt(name, value);
}

String? _validateUnitRange(String name, double value) {
  if (value < 0 || value > 1) {
    return '$name must be in the range 0..1.';
  }
  return null;
}

class CloneAnalysisParseResult {
  CloneAnalysisParseResult._({
    this.config,
    this.errorMessage,
    this.showHelp = false,
  });

  factory CloneAnalysisParseResult.help() {
    return CloneAnalysisParseResult._(showHelp: true);
  }

  factory CloneAnalysisParseResult.error(String errorMessage) {
    return CloneAnalysisParseResult._(errorMessage: errorMessage);
  }

  factory CloneAnalysisParseResult.success(CloneAnalysisConfig config) {
    return CloneAnalysisParseResult._(config: config);
  }

  final CloneAnalysisConfig? config;
  final String? errorMessage;
  final bool showHelp;
}
