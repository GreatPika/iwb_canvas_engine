# Good and Bad Tests

The resource-resolution tests exercise the existing
`CanvasResourceResolver` boundary. Supply an app resolver and observe the
result returned by `SurfaceResourceSession`; do not invent a plugin boundary.
Use the established resource-test support for `RecordingResourceResolver`,
`CountingResolverMutationGuard`, and `descriptorRequest`.

## Good Tests

**Behavior-focused**: observe the result the session returns when the app
resolver fails, not its internal callback sequence.

```dart
// GOOD: an app resolver failure becomes the documented placeholder result.
test('returns an exception placeholder when the app resolver throws', () {
  final resolver = RecordingResourceResolver((_) {
    throw StateError('app resource resolver failed');
  });
  final session = SurfaceResourceSession(
    resolver: resolver,
    mutationGuard: CountingResolverMutationGuard(),
  );
  final request = descriptorRequest(id: 'broken-resource');

  final result = session.resolveResource(request);

  expect(result, isA<ResolverExceptionResourceAssetPlaceholder>());
  expect(result.placeholderBounds, request.placeholderBounds);
});
```

Characteristics:

- Tests behavior callers of the resource-resolution owner care about.
- Uses the existing resolver boundary and resource-test support.
- Survives an internal refactor of callback handling.
- Describes the visible result, not how it is implemented.
- Has one logical outcome.

## Bad Tests

**Implementation-detail tests**: coupled to the current callback sequence
rather than the result the caller receives.

```dart
// BAD: proves only that the current implementation invokes the resolver once.
test('calls the image resolver once', () {
  final resolver = RecordingResourceResolver((_) => null);
  final session = SurfaceResourceSession(
    resolver: resolver,
    mutationGuard: CountingResolverMutationGuard(),
  );

  session.resolveResource(descriptorRequest(id: 'missing-image'));

  expect(resolver.callCount, 1);
});
```

The test may remain green even if the returned placeholder, its bounds, or
exception handling is wrong. A captured argument or call count can support a
behavior assertion, but it must not be the only observed outcome.

Red flags:

- Mocking an internal collaborator.
- Testing a private method.
- Asserting only call counts or order.
- A test that breaks when a refactor preserves behavior.
- A test name that describes how rather than what.
- Reading cache or resolver state instead of the returned result.

**Tautological tests**: their expected value comes from the result under test,
so they pass by construction.

```dart
// BAD: the expectation cannot distinguish a correct result from an incorrect one.
test('reports a resolver failure', () {
  final result = session.resolveResource(request);

  expect(result, same(result));
});

// GOOD: the expected result is an independent contract value.
test('reports a resolver failure', () {
  final result = session.resolveResource(request);

  expect(result, isA<ResolverExceptionResourceAssetPlaceholder>());
});
```
