final class GuardrailViolation {
  const GuardrailViolation({
    required this.guardrailId,
    required this.path,
    required this.message,
  });

  final String guardrailId;
  final String path;
  final String message;

  @override
  String toString() => '$guardrailId: $path: $message';
}
