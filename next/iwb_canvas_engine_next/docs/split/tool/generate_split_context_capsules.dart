import 'dart:io';

import 'split_context_capsules.dart';

void main(List<String> args) {
  final checkOnly = args.contains('--check');
  final result = syncSplitContextCapsules(checkOnly: checkOnly);

  if (result.errors.isNotEmpty) {
    stderr.writeln(
      checkOnly
          ? 'Split context capsule check failed:'
          : 'Split context capsule generation failed:',
    );
    for (final error in result.errors) {
      stderr.writeln('- $error');
    }
    exitCode = 1;
    return;
  }

  if (checkOnly) {
    stdout.writeln('Split context capsule check passed.');
    return;
  }

  if (result.changedFiles.isEmpty) {
    stdout.writeln('Split context capsules already up to date.');
    return;
  }

  stdout.writeln('Split context capsules generated:');
  for (final file in result.changedFiles) {
    stdout.writeln('- $file');
  }
}
