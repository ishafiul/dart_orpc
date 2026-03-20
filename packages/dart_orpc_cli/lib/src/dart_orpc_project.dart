import 'dart:io';

import 'package:yaml/yaml.dart';

import 'path_utils.dart';

final class DartOrpcProject {
  DartOrpcProject({
    required this.projectDirectory,
    required this.entrypoint,
    required this.entrypointFile,
    required this.projectPubspec,
    required this.pubspec,
    this.pubspecLoadError,
  });

  final Directory projectDirectory;
  final String entrypoint;
  final File entrypointFile;
  final File projectPubspec;
  final YamlMap? pubspec;
  final Object? pubspecLoadError;

  static Future<DartOrpcProject> discover({
    required Directory currentDirectory,
    required String projectPath,
    required String entrypoint,
  }) async {
    final projectDirectory = resolveDirectory(currentDirectory, projectPath);
    final entrypointFile = resolveFile(projectDirectory, entrypoint);
    final projectPubspec = File.fromUri(
      projectDirectory.uri.resolve('pubspec.yaml'),
    );

    YamlMap? pubspec;
    Object? pubspecLoadError;

    if (await projectPubspec.exists()) {
      try {
        final contents = await projectPubspec.readAsString();
        final loaded = loadYaml(contents);
        pubspec = loaded is YamlMap ? loaded : null;
      } catch (error) {
        pubspecLoadError = error;
      }
    }

    return DartOrpcProject(
      projectDirectory: projectDirectory,
      entrypoint: entrypoint,
      entrypointFile: entrypointFile,
      projectPubspec: projectPubspec,
      pubspec: pubspec,
      pubspecLoadError: pubspecLoadError,
    );
  }

  Future<String?> validateForServe() async {
    if (!await projectDirectory.exists()) {
      return 'Project directory not found: ${projectDirectory.path}';
    }

    if (!await projectPubspec.exists()) {
      return 'pubspec.yaml not found in ${projectDirectory.path}.';
    }

    if (pubspecLoadError != null) {
      return 'Failed to parse ${projectPubspec.path}: $pubspecLoadError';
    }

    if (!isDartOrpcProject) {
      return 'Directory ${projectDirectory.path} is not a valid dart_orpc app. '
          'Expected a runtime dependency on dart_orpc or another dart_orpc_* package in pubspec.yaml.';
    }

    if (!await entrypointFile.exists()) {
      return 'Entrypoint file not found: ${entrypointFile.path}';
    }

    return null;
  }

  Future<String?> validateForWatch() async {
    final serveValidationError = await validateForServe();
    if (serveValidationError != null) {
      return serveValidationError;
    }

    if (!hasBuildRunner || !hasGeneratorDependency) {
      return 'Directory ${projectDirectory.path} is not watch-ready for dart_orpc. '
          'Expected build_runner and dart_orpc_generator in dependencies or dev_dependencies.';
    }

    return null;
  }

  bool get isDartOrpcProject {
    return _sectionKeys('dependencies').any(_isFrameworkRuntimePackage);
  }

  bool get hasBuildRunner {
    return _allDependencyKeys.contains('build_runner');
  }

  bool get hasGeneratorDependency {
    return _allDependencyKeys.contains('dart_orpc_generator');
  }

  Iterable<String> get _allDependencyKeys sync* {
    yield* _sectionKeys('dependencies');
    yield* _sectionKeys('dev_dependencies');
  }

  Iterable<String> _sectionKeys(String sectionName) sync* {
    final section = pubspec?[sectionName];
    if (section is YamlMap) {
      for (final key in section.keys) {
        if (key is String) {
          yield key;
        }
      }
    }
  }

  bool _isFrameworkRuntimePackage(String packageName) {
    return packageName == 'dart_orpc' || packageName == 'dart_orpc_http';
  }
}
