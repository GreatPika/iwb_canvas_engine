class GuardrailViolation {
  GuardrailViolation({
    required this.filePath,
    required this.line,
    required this.message,
  });

  final String filePath;
  final int line;
  final String message;

  @override
  String toString() => '$filePath:$line: $message';
}

class GuardrailToolFailure implements Exception {
  const GuardrailToolFailure(this.violation);

  final GuardrailViolation violation;
}

bool isPublicName(String name) => !name.startsWith('_');
