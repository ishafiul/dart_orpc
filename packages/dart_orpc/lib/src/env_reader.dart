import 'dart:io';

import 'package:dart_orpc_logger/dart_orpc_logger.dart';
import 'package:dotenv/dotenv.dart';

const _log = Logger('dart_orpc.env');
const _fileLoaded = 'env.file_loaded';
const _fileMissing = 'env.file_missing';
const _fileAttribute = 'env.file';

/// Reads configuration from the process environment and an optional `.env`
/// file, whose values take precedence.
final class EnvReader {
  EnvReader._(this._read);

  /// Reads the process environment plus [path] when it exists. A missing file
  /// is normal, such as in production, and is logged at info level.
  factory EnvReader.load({String path = '.env'}) {
    final variables = DotEnv(includePlatformEnvironment: true, quiet: true);
    if (File(path).existsSync()) {
      variables.load([path]);
      _log.debug(_fileLoaded, attributes: {_fileAttribute: path});
    } else {
      _log.info(_fileMissing, attributes: {_fileAttribute: path});
    }
    return EnvReader._((name) => variables[name]);
  }

  factory EnvReader.fromMap(Map<String, String> variables) {
    return EnvReader._((name) => variables[name]);
  }

  final String? Function(String name) _read;

  String requiredString(String name) {
    final value = _read(name)?.trim();
    if (value == null || value.isEmpty) {
      throw StateError('$name is required.');
    }
    return value;
  }

  String required(String name) => requiredString(name);

  String string(String name, {required String fallback}) {
    final value = _read(name)?.trim();
    return value == null || value.isEmpty ? fallback : value;
  }

  /// An absolute `http` or `https` URI, or null when [name] is unset.
  Uri? optionalUri(String name) {
    final raw = _read(name)?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        !uri.isAbsolute ||
        !(uri.isScheme('http') || uri.isScheme('https'))) {
      throw StateError('$name must be an absolute http or https URI.');
    }
    return uri;
  }

  int positiveInt(String name, {required int fallback}) {
    final raw = _read(name)?.trim();
    if (raw == null || raw.isEmpty) {
      return fallback;
    }
    final value = int.tryParse(raw);
    if (value == null || value <= 0) {
      throw StateError('$name must be a positive integer.');
    }
    return value;
  }

  Duration duration(String name, {required Duration fallback}) {
    return Duration(seconds: positiveInt(name, fallback: fallback.inSeconds));
  }

  int port(String name, {required int fallback}) {
    final value = positiveInt(name, fallback: fallback);
    if (value > 65535) {
      throw StateError('$name must be between 1 and 65535.');
    }
    return value;
  }
}
