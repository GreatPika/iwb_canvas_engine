import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

Future<CanvasPreparedVector> prepareCallerOwnedVector(
  ByteData bytes, {
  BuildContext? context,
}) async {
  final prepare = prepareVector;
  final prepared = await prepare(bytes, context: context);
  final intrinsicSize = prepared.intrinsicSize;
  Object.hash(intrinsicSize.width, intrinsicSize.height);
  prepared.dispose();
  prepared.dispose();
  return prepared;
}
