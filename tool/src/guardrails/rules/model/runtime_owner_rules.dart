final class RuntimeOwnerRuleScope {
  const RuntimeOwnerRuleScope({
    required this.runtimeOwnerFiles,
    required this.runtimeOwnerMutableFields,
  });

  final Set<String> runtimeOwnerFiles;
  final Set<String> runtimeOwnerMutableFields;
}
