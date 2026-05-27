import 'package:flutter/foundation.dart';

@immutable
/// Public API v1 declaration for [CanvasFieldUpdate].
sealed class CanvasFieldUpdate<T> {
  const CanvasFieldUpdate();
  const factory CanvasFieldUpdate.absent() = CanvasFieldAbsent<T>;
}

@immutable
/// Public API v1 declaration for [CanvasFieldAbsent].
final class CanvasFieldAbsent<T> extends CanvasFieldUpdate<T> {
  const CanvasFieldAbsent();

  @override
  bool operator ==(Object other) {
    return other is CanvasFieldAbsent<T>;
  }

  @override
  int get hashCode => T.hashCode;
}

@immutable
/// Public API v1 declaration for [CanvasFieldSet].
final class CanvasFieldSet<T extends Object> extends CanvasFieldUpdate<T> {
  const CanvasFieldSet(this.value);
  final T value;

  @override
  bool operator ==(Object other) {
    return other is CanvasFieldSet<T> && other.value == value;
  }

  @override
  int get hashCode => Object.hash(T, value);
}

@immutable
/// Public API v1 declaration for [CanvasFieldClear].
final class CanvasFieldClear<T extends Object> extends CanvasFieldUpdate<T?> {
  const CanvasFieldClear();

  @override
  bool operator ==(Object other) {
    return other is CanvasFieldClear<T>;
  }

  @override
  int get hashCode => T.hashCode;
}
