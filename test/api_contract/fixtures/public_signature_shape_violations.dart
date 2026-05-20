import 'dart:async';

class GenericClassViolation<T extends FutureOr<int>> {}

typedef GenericAliasViolation<T extends Future<int>?> = T Function();

class SignatureShapeViolations {
  FutureOr<int> futureOrReturn() => 1;

  Future<int>? nullableFutureReturn() => null;

  List<int>? nullableListReturn() => null;

  // This negative fixture intentionally exposes dynamic so the public signature
  // guardrail proves it rejects the forbidden shape.
  // ignore: avoid-dynamic
  dynamic dynamicReturn() => null;
}
