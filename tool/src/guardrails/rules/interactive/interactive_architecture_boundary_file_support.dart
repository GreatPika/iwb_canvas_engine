part of 'mutation_boundary_rules.dart';

ParsedUnitResult _parseArchitectureUnit(GuardrailContext context, File file) {
  return parseUnitOrFail(
    context: context,
    absPath: file.absolute.path,
    filePathForDiag: _repoRelPath(context, file),
    onFailure: _onInteractiveParseFailure,
  );
}

String _repoRelPath(GuardrailContext context, File file) {
  return toRepoRelPosixPath(
    absPosixPath: toPosixPath(file.absolute.path),
    rootAbsPosixPath: context.rootAbsPosixPath,
  );
}

File _interactiveArchitectureFile(
  GuardrailContext context,
  String relativePath,
) {
  if (relativePath.startsWith('../')) {
    return libSrcFile(context, relativePath: relativePath.substring(3));
  }
  return _interactiveSupportFile(context, relativePath);
}

File _interactiveSupportFile(GuardrailContext context, String relativePath) {
  return libSrcFile(context, relativePath: 'interactive/$relativePath');
}
