abstract interface class ResolverMutationGuard {
  T runResolverCallback<T>(T Function() callback);
  void ensureRuntimeMutationAllowed();
}
