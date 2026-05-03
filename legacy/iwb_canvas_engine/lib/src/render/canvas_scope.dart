import 'dart:typed_data';
import 'dart:ui';

typedef CanvasScopeCallback = void Function();

void withSave(Canvas canvas, CanvasScopeCallback draw) {
  canvas.save();
  try {
    draw();
  } finally {
    canvas.restore();
  }
}

void withTranslate(Canvas canvas, Offset offset, CanvasScopeCallback draw) {
  if (offset == Offset.zero) {
    draw();
    return;
  }

  withSave(canvas, () {
    canvas.translate(offset.dx, offset.dy);
    draw();
  });
}

void withTransform(
  Canvas canvas,
  Float64List transform,
  CanvasScopeCallback draw,
) {
  withSave(canvas, () {
    canvas.transform(transform);
    draw();
  });
}
