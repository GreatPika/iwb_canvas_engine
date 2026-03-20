import 'dart:ui';

import '../ids.dart';
import '../owned_collections.dart';
import '../patch_field.dart';
import '../path_fill_rule.dart';
import '../transform2d.dart';
import '../validated/finite_offset_value.dart';
import '../validated/font_family_value.dart';
import '../validated/image_id_value.dart';
import '../validated/instance_revision_value.dart';
import '../validated/node_id_value.dart';
import '../validated/non_negative_finite_double_value.dart';
import '../validated/opacity_value.dart';
import '../validated/positive_finite_double_value.dart';
import '../validated/svg_path_data_value.dart';
import '../validated/text_content_value.dart';
import '../validated/validated_value_support.dart';

part 'node_boundary_schema_patch.part.dart';
part 'node_boundary_schema_spec.part.dart';
part 'node_boundary_schema_snapshot.part.dart';
part 'node_boundary_schema_primitives.part.dart';

typedef NodePatchCommonSchemaFields = ({
  PatchField<Transform2D> transform,
  PatchField<double> opacity,
  PatchField<double> hitPadding,
  PatchField<bool> isVisible,
  PatchField<bool> isSelectable,
  PatchField<bool> isLocked,
  PatchField<bool> isDeletable,
  PatchField<bool> isTransformable,
});

typedef NodeSpecCommonSchemaFields = ({
  NodeId? id,
  Transform2D transform,
  double opacity,
  double hitPadding,
  bool isVisible,
  bool isSelectable,
  bool isLocked,
  bool isDeletable,
  bool isTransformable,
});

typedef NodeSnapshotCommonSchemaFields = ({
  NodeId id,
  int instanceRevision,
  Transform2D transform,
  double opacity,
  double hitPadding,
  bool isVisible,
  bool isSelectable,
  bool isLocked,
  bool isDeletable,
  bool isTransformable,
});

typedef ImageNodePatchSchemaFields = ({
  PatchField<String> imageId,
  PatchField<Size> size,
  PatchField<Size?> naturalSize,
});

typedef TextNodePatchSchemaFields = ({
  PatchField<String> text,
  PatchField<double> fontSize,
  PatchField<Color> color,
  PatchField<TextAlign> align,
  PatchField<bool> isBold,
  PatchField<bool> isItalic,
  PatchField<bool> isUnderline,
  PatchField<String?> fontFamily,
  PatchField<double?> maxWidth,
  PatchField<double?> lineHeight,
});

typedef StrokeNodePatchSchemaFields = ({
  PatchField<List<Offset>> points,
  PatchField<double> thickness,
  PatchField<Color> color,
});

typedef LineNodePatchSchemaFields = ({
  PatchField<Offset> start,
  PatchField<Offset> end,
  PatchField<double> thickness,
  PatchField<Color> color,
});

typedef RectNodePatchSchemaFields = ({
  PatchField<Size> size,
  PatchField<Color?> fillColor,
  PatchField<Color?> strokeColor,
  PatchField<double> strokeWidth,
});

typedef PathNodePatchSchemaFields = ({
  PatchField<String> svgPathData,
  PatchField<Color?> fillColor,
  PatchField<Color?> strokeColor,
  PatchField<double> strokeWidth,
  PatchField<PathFillRule> fillRule,
});

typedef ImageNodeSchemaFields = ({
  String imageId,
  Size size,
  Size? naturalSize,
});

typedef TextNodeSpecSchemaFields = ({
  String text,
  double fontSize,
  Color color,
  TextAlign align,
  bool isBold,
  bool isItalic,
  bool isUnderline,
  String? fontFamily,
  double? maxWidth,
  double? lineHeight,
});

typedef TextNodeSnapshotSchemaFields = ({
  String text,
  Size size,
  double fontSize,
  Color color,
  TextAlign align,
  bool isBold,
  bool isItalic,
  bool isUnderline,
  String? fontFamily,
  double? maxWidth,
  double? lineHeight,
});

typedef StrokeNodeSpecSchemaInput = ({
  List<Offset> points,
  double thickness,
  Color color,
});

typedef StrokeNodeSpecSchemaFields = ({
  OwnedList<Offset> points,
  double thickness,
  Color color,
});

typedef StrokeNodeSnapshotSchemaInput = ({
  List<Offset> points,
  int pointsRevision,
  double thickness,
  Color color,
});

typedef StrokeNodeSnapshotSchemaFields = ({
  OwnedList<Offset> points,
  int pointsRevision,
  double thickness,
  Color color,
});

typedef LineNodeSchemaFields = ({
  Offset start,
  Offset end,
  double thickness,
  Color color,
});

typedef RectNodeSchemaFields = ({
  Size size,
  Color? fillColor,
  Color? strokeColor,
  double strokeWidth,
});

typedef PathNodeSchemaFields = ({
  String svgPathData,
  Color? fillColor,
  Color? strokeColor,
  double strokeWidth,
  PathFillRule fillRule,
});

abstract final class NodeBoundarySchema {
  static NodeId validateRequiredNodeId(NodeId id) {
    return NodeIdValue.of(id, name: 'id').value;
  }

  static NodePatchCommonSchemaFields validatePatchCommon(
    NodePatchCommonSchemaFields fields,
  ) => _validatePatchCommon(fields);

  static NodePatchCommonSchemaFields patchCommonFromValidated(
    NodePatchCommonSchemaFields fields,
  ) => _patchCommonFromValidated(fields);

  static ImageNodePatchSchemaFields validateImagePatch(
    ImageNodePatchSchemaFields fields,
  ) => _validateImagePatch(fields);

  static ImageNodePatchSchemaFields imagePatchFromValidated(
    ImageNodePatchSchemaFields fields,
  ) => fields;

  static TextNodePatchSchemaFields validateTextPatch(
    TextNodePatchSchemaFields fields,
  ) => _validateTextPatch(fields);

  static TextNodePatchSchemaFields textPatchFromValidated(
    TextNodePatchSchemaFields fields,
  ) => fields;

  static StrokeNodePatchSchemaFields validateStrokePatch(
    StrokeNodePatchSchemaFields fields,
  ) => _validateStrokePatch(fields);

  static StrokeNodePatchSchemaFields strokePatchFromValidated(
    StrokeNodePatchSchemaFields fields,
  ) => _strokePatchFromValidated(fields);

  static LineNodePatchSchemaFields validateLinePatch(
    LineNodePatchSchemaFields fields,
  ) => _validateLinePatch(fields);

  static LineNodePatchSchemaFields linePatchFromValidated(
    LineNodePatchSchemaFields fields,
  ) => fields;

  static RectNodePatchSchemaFields validateRectPatch(
    RectNodePatchSchemaFields fields,
  ) => _validateRectPatch(fields);

  static RectNodePatchSchemaFields rectPatchFromValidated(
    RectNodePatchSchemaFields fields,
  ) => fields;

  static PathNodePatchSchemaFields validatePathPatch(
    PathNodePatchSchemaFields fields,
  ) => _validatePathPatch(fields);

  static PathNodePatchSchemaFields pathPatchFromValidated(
    PathNodePatchSchemaFields fields,
  ) => fields;

  static NodeSpecCommonSchemaFields validateSpecCommon(
    NodeSpecCommonSchemaFields fields,
  ) => _validateSpecCommon(fields);

  static NodeSpecCommonSchemaFields specCommonFromValidated(
    NodeSpecCommonSchemaFields fields,
  ) => fields;

  static ImageNodeSchemaFields validateImageFields(
    ImageNodeSchemaFields fields,
  ) => _validateImageFields(fields);

  static ImageNodeSchemaFields imageFieldsFromValidated(
    ImageNodeSchemaFields fields,
  ) => fields;

  static TextNodeSpecSchemaFields validateTextSpecFields(
    TextNodeSpecSchemaFields fields,
  ) => _validateTextSpecFields(fields);

  static TextNodeSpecSchemaFields textSpecFieldsFromValidated(
    TextNodeSpecSchemaFields fields,
  ) => fields;

  static StrokeNodeSpecSchemaFields validateStrokeSpecFields(
    StrokeNodeSpecSchemaInput fields,
  ) => _validateStrokeSpecFields(fields);

  static StrokeNodeSpecSchemaFields strokeSpecFieldsFromValidated(
    StrokeNodeSpecSchemaInput fields,
  ) => _strokeSpecFieldsFromValidated(fields);

  static LineNodeSchemaFields validateLineFields(LineNodeSchemaFields fields) =>
      _validateLineFields(fields);

  static LineNodeSchemaFields lineFieldsFromValidated(
    LineNodeSchemaFields fields,
  ) => fields;

  static RectNodeSchemaFields validateRectFields(RectNodeSchemaFields fields) =>
      _validateRectFields(fields);

  static RectNodeSchemaFields rectFieldsFromValidated(
    RectNodeSchemaFields fields,
  ) => fields;

  static PathNodeSchemaFields validatePathFields(PathNodeSchemaFields fields) =>
      _validatePathFields(fields);

  static PathNodeSchemaFields pathFieldsFromValidated(
    PathNodeSchemaFields fields,
  ) => fields;

  static NodeSnapshotCommonSchemaFields validateSnapshotCommon(
    NodeSnapshotCommonSchemaFields fields,
  ) => _validateSnapshotCommon(fields);

  static NodeSnapshotCommonSchemaFields snapshotCommonFromValidated(
    NodeSnapshotCommonSchemaFields fields,
  ) => fields;

  static TextNodeSnapshotSchemaFields validateTextSnapshotFields(
    TextNodeSnapshotSchemaFields fields,
  ) => _validateTextSnapshotFields(fields);

  static TextNodeSnapshotSchemaFields textSnapshotFieldsFromValidated(
    TextNodeSnapshotSchemaFields fields,
  ) => fields;

  static StrokeNodeSnapshotSchemaFields validateStrokeSnapshotFields(
    StrokeNodeSnapshotSchemaInput fields,
  ) => _validateStrokeSnapshotFields(fields);

  static StrokeNodeSnapshotSchemaFields strokeSnapshotFieldsFromValidated(
    StrokeNodeSnapshotSchemaInput fields,
  ) => _strokeSnapshotFieldsFromValidated(fields);
}
