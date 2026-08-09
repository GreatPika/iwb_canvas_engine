import 'dart:convert';
import 'dart:typed_data';

const basicVectorBase64 =
    'Yi2IAAEpAAAgQQAAoEEcmWYz/wMAAP//GwAAAAUAAAAAAQEBAwgAAAAAAAAAAAAAAAAAAAAAIEEAAAAAAAAgQQAAoEEAAAAAAACgQTAeAAAAAP//';

const contextSensitiveVectorBase64 =
    'Yi2IAAEpAAAgQgAAoEEcAAAA/wMAAP//MgAAAAAAQAAAcEEAAMB/AADAfwEALQAAAAAAAAAAYEEDAAAAAAD/AAADAGFiYzAzAAAsAAAAAP////8=';

const invalidIntrinsicVectorBase64 =
    'Yi2IAAEpAAAAAAAAoEEcmWYz/wMAAP//GwAAAAUAAAAAAQEBAwgAAAAAAAAAAAAAAAAAAAAAIEEAAAAAAAAgQQAAoEEAAAAAAACgQTAeAAAAAP//';

ByteData basicVectorBytes() => _bytes(basicVectorBase64);

ByteData contextSensitiveVectorBytes() => _bytes(contextSensitiveVectorBase64);

ByteData invalidIntrinsicVectorBytes() => _bytes(invalidIntrinsicVectorBase64);

ByteData assertionOnlyMalformedVectorBytes() {
  final bytes = Uint8List.fromList(
    _bytes(contextSensitiveVectorBase64).buffer.asUint8List(),
  );
  bytes.fillRange(0x4b, 0x4f, 0xff);
  return ByteData.sublistView(bytes);
}

ByteData _bytes(String source) =>
    ByteData.sublistView(Uint8List.fromList(base64Decode(source)));
