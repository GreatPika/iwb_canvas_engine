TBacking
resolveBoundaryBacking<TPublic extends Object, TBacking extends Object>({
  required TPublic value,
  required Expando<TBacking> cache,
  required TBacking? Function(TPublic value) readCarrier,
  required TBacking Function(TPublic value) rebuild,
}) {
  final carrier = readCarrier(value);
  if (carrier != null) {
    return carrier;
  }
  final cached = cache[value];
  if (cached != null) {
    return cached;
  }
  final backing = rebuild(value);
  cache[value] = backing;
  return backing;
}

final class BoundaryBackingResolver<
  TPublic extends Object,
  TBacking extends Object
> {
  const BoundaryBackingResolver({
    required this.cache,
    required this.readCarrier,
    required this.rebuild,
  });

  final Expando<TBacking> cache;
  final TBacking? Function(TPublic value) readCarrier;
  final TBacking Function(TPublic value) rebuild;

  TBacking resolve(TPublic value) {
    return resolveBoundaryBacking(
      value: value,
      cache: cache,
      readCarrier: readCarrier,
      rebuild: rebuild,
    );
  }
}

TBacking? readBoundaryBackingCarrier<
  TPublic extends Object,
  TBacking extends Object
>(TPublic value, TBacking Function(TPublic value) readCarrier) {
  try {
    return readCarrier(value);
  } on TypeError {
    return null;
  }
}

void requireExactBoundaryRuntimeType<TPublic extends Object>({
  required TPublic value,
  required Type exactType,
  required String typeName,
}) {
  if (value.runtimeType == exactType) {
    return;
  }
  throw StateError('Unsupported $typeName subtype: ${value.runtimeType}');
}
