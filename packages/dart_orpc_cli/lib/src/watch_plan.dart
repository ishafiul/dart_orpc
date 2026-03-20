import 'dart:io';

import 'dart_orpc_project.dart';
import 'path_utils.dart';

final class WatchPlan {
  WatchPlan({
    required this.project,
    this.workspaceRoot,
    this.workspacePubspec,
    this.packagesDirectory,
  });

  final DartOrpcProject project;
  final Directory? workspaceRoot;
  final File? workspacePubspec;
  final Directory? packagesDirectory;

  Directory get projectDirectory => project.projectDirectory;

  String get entrypoint => project.entrypoint;

  File get projectPubspec => project.projectPubspec;

  static Future<WatchPlan> discover({required DartOrpcProject project}) async {
    final workspaceRoot = await findWorkspaceRoot(project.projectDirectory);
    final workspacePubspec = workspaceRoot == null
        ? null
        : File.fromUri(workspaceRoot.uri.resolve('pubspec.yaml'));
    final packagesDirectory = workspaceRoot == null
        ? null
        : Directory.fromUri(workspaceRoot.uri.resolve('packages/'));

    return WatchPlan(
      project: project,
      workspaceRoot: workspaceRoot,
      workspacePubspec: workspacePubspec,
      packagesDirectory: packagesDirectory,
    );
  }

  static Future<Directory?> findWorkspaceRoot(Directory startDirectory) async {
    var current = startDirectory.absolute;

    while (true) {
      final pubspec = File.fromUri(current.uri.resolve('pubspec.yaml'));
      if (await pubspec.exists()) {
        final contents = await pubspec.readAsString();
        if (_workspaceFieldPattern.hasMatch(contents)) {
          return current;
        }
      }

      final parent = current.parent;
      if (normalizeDirectoryPath(parent.path) ==
          normalizeDirectoryPath(current.path)) {
        return null;
      }

      current = parent;
    }
  }

  static final RegExp _workspaceFieldPattern = RegExp(
    r'^workspace\s*:',
    multiLine: true,
  );

  Iterable<Directory> get directoriesToWatch sync* {
    yield projectDirectory;

    final packagesDirectory = this.packagesDirectory;
    if (packagesDirectory != null) {
      yield packagesDirectory;
    }
  }

  Iterable<File> get filesToWatch sync* {
    final workspacePubspec = this.workspacePubspec;
    if (workspacePubspec != null &&
        normalizePath(workspacePubspec.path) !=
            normalizePath(projectPubspec.path)) {
      yield workspacePubspec;
    }
  }

  bool requiresPubGet(String path) {
    final normalizedPath = normalizePath(path);
    return normalizedPath.endsWith('/pubspec.yaml');
  }

  bool isRelevantPath(String path) {
    final normalizedPath = normalizePath(path);

    if (normalizedPath.contains('/.dart_tool/') ||
        normalizedPath.contains('/.git/') ||
        normalizedPath.contains('/build/')) {
      return false;
    }

    if (_isGeneratedOutput(normalizedPath)) {
      return false;
    }

    if (_isUnder(
      normalizedPath,
      '${normalizeDirectoryPath(projectDirectory.path)}/',
    )) {
      return _matchesProjectSource(normalizedPath);
    }

    final packagesDirectory = this.packagesDirectory;
    if (packagesDirectory != null &&
        _isUnder(
          normalizedPath,
          '${normalizeDirectoryPath(packagesDirectory.path)}/',
        )) {
      return _matchesPackageSource(normalizedPath);
    }

    final workspacePubspec = this.workspacePubspec;
    return workspacePubspec != null &&
        normalizedPath == normalizePath(workspacePubspec.path);
  }

  String describeWatchedRoots() {
    final roots = <String>[
      _relativePath(projectDirectory.path),
      if (packagesDirectory != null) _relativePath(packagesDirectory!.path),
    ];
    return roots.join(' and ');
  }

  String describeEvent(int type, String path) {
    final relativePath = _relativePath(path);

    switch (type) {
      case FileSystemEvent.create:
        return 'created $relativePath';
      case FileSystemEvent.delete:
        return 'deleted $relativePath';
      case FileSystemEvent.modify:
        return 'modified $relativePath';
      case FileSystemEvent.move:
        return 'moved $relativePath';
    }

    return 'updated $relativePath';
  }

  String _relativePath(String path) {
    final workspaceRoot = this.workspaceRoot;
    if (workspaceRoot == null) {
      return normalizeDirectoryPath(path);
    }

    final normalizedRoot = normalizeDirectoryPath(workspaceRoot.path);
    final normalizedPath = normalizeDirectoryPath(path);
    if (_isUnder(normalizedPath, '$normalizedRoot/')) {
      return normalizedPath.substring(normalizedRoot.length + 1);
    }

    return normalizedPath;
  }

  bool _matchesProjectSource(String path) {
    final projectRoot = '${normalizeDirectoryPath(projectDirectory.path)}/';
    return _isUnder(path, '${projectRoot}lib/') ||
        _isUnder(path, '${projectRoot}bin/') ||
        path == normalizePath(projectPubspec.path) ||
        path ==
            normalizePath(
              File.fromUri(projectDirectory.uri.resolve('build.yaml')).path,
            );
  }

  bool _matchesPackageSource(String path) {
    return path.contains('/lib/') ||
        path.endsWith('/pubspec.yaml') ||
        path.endsWith('/build.yaml');
  }

  bool _isGeneratedOutput(String path) {
    return path.endsWith('.g.dart') ||
        path.endsWith('.freezed.dart') ||
        path.endsWith('.dart_orpc.g.part');
  }

  static bool _isUnder(String path, String directoryPath) {
    return path.startsWith(directoryPath);
  }
}
