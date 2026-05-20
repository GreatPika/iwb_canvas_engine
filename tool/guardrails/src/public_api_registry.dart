import 'dart:io';

import 'package:yaml/yaml.dart';

import 'repository_paths.dart';

Set<String> readPublicApiRegistry() {
  final file = File('$repositoryRoot/docs/_registry/public_api_v1.yaml');
  final parsed = loadYaml(file.readAsStringSync()) as YamlMap;
  final exports = parsed['public_exports'] as YamlList;

  return exports.cast<String>().toSet();
}
