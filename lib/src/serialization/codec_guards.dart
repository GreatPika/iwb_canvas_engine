part of 'scene_codec.dart';

T _guardDecode<T>(String rawJson, T Function(Map<String, Object?> raw) decode) {
  _guardRawJsonLength(rawJson);
  try {
    final raw = jsonDecode(rawJson);
    if (raw is! Map) {
      throw SceneDataException.invalidJsonRoot(source: raw);
    }
    return decode(Map<String, Object?>.from(raw));
  } on SceneDataException {
    rethrow;
  } on FormatException catch (error) {
    throw SceneDataException.invalidJsonPayload(source: error);
  } catch (error) {
    throw SceneDataException.invalidJsonPayload(source: error);
  }
}

T _guardEncode<T>(T Function() encode) {
  try {
    return encode();
  } on SceneDataException {
    rethrow;
  } on FormatException catch (error) {
    throw SceneDataException.invalidJsonPayload(source: error);
  } catch (error) {
    throw SceneDataException.invalidJsonPayload(source: error);
  }
}

void _guardRawJsonLength(String rawJson) {
  if (rawJson.length <= kMaxRawSceneJsonLength) {
    return;
  }
  throw SceneDataException.jsonPayloadTooLarge(
    maxLength: kMaxRawSceneJsonLength,
    source: <String, Object?>{'length': rawJson.length},
  );
}
