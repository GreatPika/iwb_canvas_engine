import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:vector_graphics/vector_graphics.dart' as vg;

import '../contracts/public/canvas_contract_limits.dart';
import '../contracts/public/canvas_errors.dart';
import '../contracts/public/canvas_prepared_vector.dart';
import '../contracts/public/canvas_value_validators.dart';

export '../contracts/public/canvas_prepared_vector.dart'
    show CanvasPreparedVector;

/// Prepares caller-provided raster-free vector bytes for application ownership.
Future<CanvasPreparedVector> prepareVector(
  ByteData bytes, {
  BuildContext? context,
}) async {
  if (bytes.lengthInBytes > canvasMaxVectorByteLength) {
    throw CanvasDataException(
      code: CanvasDataErrorCode.fieldMaxLength,
      message: 'vector.bytes exceeds the maximum length.',
      path: 'vector.bytes',
      details: {
        'maxLength': canvasMaxVectorByteLength,
        'actualLength': bytes.lengthInBytes,
      },
    );
  }

  final snapshot = _copyExactView(bytes);
  final selected = vg.vg.loadPicture(_VectorBytesLoader(snapshot), context);
  late vg.PictureInfo pictureInfo;
  try {
    pictureInfo = await selected;
  } on Object {
    _throwInvalidVectorData();
  }

  try {
    validateSize(pictureInfo.size, path: 'vector.intrinsicSize');
  } on Object {
    pictureInfo.picture.dispose();
    rethrow;
  }
  return createCanvasPreparedVector(
    picture: pictureInfo.picture,
    intrinsicSize: pictureInfo.size,
  );
}

Never _throwInvalidVectorData() {
  throw CanvasDataException(
    code: CanvasDataErrorCode.invalidVectorData,
    message: 'vector.bytes could not be prepared.',
    path: 'vector.bytes',
  );
}

ByteData _copyExactView(ByteData bytes) {
  final view = bytes.buffer.asUint8List(
    bytes.offsetInBytes,
    bytes.lengthInBytes,
  );
  return ByteData.sublistView(Uint8List.fromList(view));
}

final class _VectorBytesLoader extends vg.BytesLoader {
  const _VectorBytesLoader(this._bytes);

  final ByteData _bytes;

  @override
  Future<ByteData> loadBytes(BuildContext? context) {
    return Future<ByteData>.value(_bytes);
  }

  @override
  String toString() => 'CanvasPreparedVector bytes';
}
