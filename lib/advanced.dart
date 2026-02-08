/// Advanced public API exports for `iwb_canvas_engine`.
///
/// This entrypoint exposes the full API surface, including low-level building
/// blocks (custom painting, hit-testing, pointer tracking).
///
/// Prefer `package:iwb_canvas_engine/basic.dart` unless you need low-level APIs.
library;

// Re-export the "happy path" API as a base.
//
// Keeping `advanced.dart` as a strict superset of `basic.dart` avoids ambiguous
// re-exports in dartdoc.
export 'basic.dart';

// Additional low-level building blocks.
export 'src/core/hit_test.dart' hide nodeHitTestCandidateBoundsWorld;

export 'src/input/pointer_input.dart' hide PointerInputSettings;

export 'src/render/scene_painter.dart' hide ImageResolver;

export 'src/serialization/scene_codec.dart'
    hide
        SceneJsonFormatException,
        decodeSceneFromJson,
        encodeSceneToJson,
        schemaVersionWrite,
        schemaVersionsRead;
