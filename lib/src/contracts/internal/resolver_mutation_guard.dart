final class ResolverCallbackRejection extends StateError {
  ResolverCallbackRejection(super.message);
}

abstract interface class ResolverMutationGuard {
  T runResolverCallback<T>(T Function() callback);
  void ensureRuntimeMutationAllowed();
}
