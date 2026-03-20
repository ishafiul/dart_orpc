import 'dart:io';

String normalizePath(String path) {
  return path.replaceAll('\\', '/');
}

String normalizeDirectoryPath(String path) {
  final normalizedPath = normalizePath(path);
  if (normalizedPath == '/') {
    return normalizedPath;
  }

  return normalizedPath.endsWith('/')
      ? normalizedPath.substring(0, normalizedPath.length - 1)
      : normalizedPath;
}

Directory resolveDirectory(Directory currentDirectory, String path) {
  final directory = Directory(path);
  if (directory.isAbsolute) {
    return directory.absolute;
  }

  return Directory.fromUri(currentDirectory.uri.resolve(path));
}

File resolveFile(Directory baseDirectory, String path) {
  final file = File(path);
  if (file.isAbsolute) {
    return file.absolute;
  }

  return File.fromUri(baseDirectory.uri.resolve(path));
}
