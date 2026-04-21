import 'dart:io';

import '../../../layer_guardrails.dart';
import '../../support/guardrail_path_utils.dart';

List<LibSrcLayoutViolation> collectEntrypointLayoutRuleViolations({
  required Directory srcRoot,
  required String rootAbsPosixPath,
}) {
  return collectTopLevelLibSrcLayoutViolations(
    srcRoot: srcRoot,
    rootAbsPosixPath: rootAbsPosixPath,
    toPosixPath: toPosixPath,
    toRepoRelPosixPath: toRepoRelPosixPath,
  );
}
