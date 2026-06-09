import 'dart:ui';

Future<int> alphaAt(
  void Function(Canvas canvas) paint, {
  required int x,
  required int y,
}) async {
  final recorder = PictureRecorder();
  paint(Canvas(recorder));
  final image = await recorder.endRecording().toImage(64, 32);
  final bytes = await image.toByteData(format: ImageByteFormat.rawRgba);
  if (bytes == null) {
    throw StateError('surface painter clipping test produced no pixel data');
  }

  return bytes.buffer.asUint8List()[(y * 64 + x) * 4 + 3];
}
