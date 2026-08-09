import 'dart:typed_data';

import 'package:flutter/widgets.dart' show BuildContext;
import 'package:vector_graphics/vector_graphics.dart'
    as vg
    show BytesLoader, PictureInfo, vg;

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
}) => Future<CanvasPreparedVector>.sync(
  () => _prepareAdmittedVector(_admitVectorInput(bytes), context: context),
);

_AdmittedVectorInput _admitVectorInput(ByteData bytes) {
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

  return _AdmittedVectorInput._(bytes);
}

Future<CanvasPreparedVector> _prepareAdmittedVector(
  _AdmittedVectorInput input, {
  required BuildContext? context,
}) async {
  final selected = vg.vg.loadPicture(
    _VectorBytesLoader(input.copyExactSnapshot()),
    context,
  );
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

final class _AdmittedVectorInput {
  const _AdmittedVectorInput._(this._bytes);

  final ByteData _bytes;

  ByteData copyExactSnapshot() {
    final view = _bytes.buffer.asUint8List(
      _bytes.offsetInBytes,
      _bytes.lengthInBytes,
    );
    return ByteData.sublistView(Uint8List.fromList(view));
  }
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
