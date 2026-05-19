sealed class CanvasFieldUpdate<T> {
  const CanvasFieldUpdate();
  const factory CanvasFieldUpdate.absent() = CanvasFieldAbsent<T>;
}

final class CanvasFieldAbsent<T> extends CanvasFieldUpdate<T> {
  const CanvasFieldAbsent();
}

final class CanvasFieldSet<T extends Object> extends CanvasFieldUpdate<T> {
  const CanvasFieldSet(this.value);
  final T value;
}

final class CanvasFieldClear<T extends Object> extends CanvasFieldUpdate<T?> {
  const CanvasFieldClear();
}
