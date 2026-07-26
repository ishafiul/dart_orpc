import 'package:dotenv/dotenv.dart';

final class EnvReader {
  EnvReader._(this._read);

  factory EnvReader.load({String path = '.env'}) {
    final variables = DotEnv(includePlatformEnvironment: true)..load([path]);
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
