final class GuardrailRuleMetadata {
  const GuardrailRuleMetadata({
    required this.id,
    required this.invariantIds,
    required this.area,
    required this.description,
    this.readsStateArtifacts = const <String>[],
    this.writesStateArtifacts = const <String>[],
  });

  final String id;
  final List<String> invariantIds;
  final String area;
  final String description;
  final List<String> readsStateArtifacts;
  final List<String> writesStateArtifacts;
}
