/// Finds and loads the native library when no build hook bundled it.
///
/// `dart compile aot-snapshot` and `dart compile exe` do not run build
/// hooks, so the compiled program has no code asset for `bindings.dart`.
/// The VM then resolves `@Native` functions by looking them up in the whole
/// process. Loading the library globally before that lookup makes it
/// succeed, so such programs run when the library file ships beside them.
library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

/// The environment variable that names the library file to load.
const rustHttpLibEnvironmentKey = 'RUST_HTTP_LIB';

/// The library file name on [operatingSystem] (a [Platform.operatingSystem]
/// value), or null where loading it globally is not supported.
String? fallbackLibraryFileName(String operatingSystem) =>
    switch (operatingSystem) {
      'macos' => 'librust_http.dylib',
      'linux' || 'android' => 'librust_http.so',
      _ => null,
    };

/// The paths to try, in order.
///
/// 1. [environment]'s `RUST_HTTP_LIB`, when set.
/// 2. `lib/` beside [script], then `../lib/` (the `dart build cli` bundle
///    layout).
/// 3. The same two beside [executable].
///
/// Empty where [fallbackLibraryFileName] is null.
List<String> fallbackLibraryCandidates({
  required Map<String, String> environment,
  required Uri script,
  required String executable,
  required String operatingSystem,
}) {
  final fileName = fallbackLibraryFileName(operatingSystem);
  if (fileName == null) return const [];
  final explicit = environment[rustHttpLibEnvironmentKey];
  final candidates = <String>[
    if (explicit != null && explicit.isNotEmpty) explicit,
  ];
  // Only macOS and Linux get here, so paths are POSIX whatever the host.
  final directories = <Uri>[
    if (script.isScheme('file')) script.resolve('.'),
    Uri.file(executable, windows: false).resolve('.'),
  ];
  for (final directory in directories) {
    for (final relative in ['lib/', '../lib/']) {
      final path = directory
          .resolve('$relative$fileName')
          .toFilePath(windows: false);
      if (!candidates.contains(path)) candidates.add(path);
    }
  }
  return candidates;
}

/// The candidates for the running process that exist on disk, except that
/// an explicit `RUST_HTTP_LIB` is always kept so a wrong path is reported.
///
/// Where a candidate is missing, its directory may hold the library under a
/// target-prefixed name such as `linux-x64-librust_http.so`, which is how
/// `dart build cli` bundles a prebuilt download.
List<String> existingFallbackLibraries() {
  final environment = Platform.environment;
  final explicit = environment[rustHttpLibEnvironmentKey];
  final fileName = fallbackLibraryFileName(Platform.operatingSystem);
  final found = <String>[];
  for (final path in fallbackLibraryCandidates(
    environment: environment,
    script: Platform.script,
    executable: Platform.resolvedExecutable,
    operatingSystem: Platform.operatingSystem,
  )) {
    if (path == explicit || File(path).existsSync()) {
      found.add(path);
      continue;
    }
    final directory = File(path).parent;
    if (fileName == null || !directory.existsSync()) continue;
    found.addAll(
      prefixedLibraryFiles(
        directory.listSync().whereType<File>().map((f) => f.path),
        fileName,
      ).where((p) => !found.contains(p)),
    );
  }
  return found;
}

/// The [paths] whose file name is `<target>-<fileName>`, sorted.
List<String> prefixedLibraryFiles(Iterable<String> paths, String fileName) {
  final suffix = '-$fileName';
  return [
    for (final path in paths)
      if (Uri.file(path).pathSegments.last.endsWith(suffix)) path,
  ]..sort();
}

typedef _DlopenNative = Pointer<Void> Function(Pointer<Uint8>, Int32);
typedef _Dlopen = Pointer<Void> Function(Pointer<Uint8>, int);
typedef _DlerrorNative = Pointer<Uint8> Function();
typedef _MallocNative = Pointer<Uint8> Function(IntPtr);
typedef _Malloc = Pointer<Uint8> Function(int);
typedef _FreeNative = Void Function(Pointer<Uint8>);
typedef _Free = void Function(Pointer<Uint8>);

/// Loads [path] with `dlopen(RTLD_NOW | RTLD_GLOBAL)`, so its symbols take
/// part in process-wide lookups. Returns null on success, otherwise why it
/// failed.
String? loadLibraryGlobally(String path) {
  final global = switch (Platform.operatingSystem) {
    'macos' => 0x8,
    'linux' || 'android' => 0x100,
    _ => null,
  };
  if (global == null) {
    return 'loading a library globally is not supported on '
        '${Platform.operatingSystem}';
  }
  const now = 0x2;
  final process = DynamicLibrary.process();
  final dlopen = process.lookupFunction<_DlopenNative, _Dlopen>('dlopen');
  final dlerror = process.lookupFunction<_DlerrorNative, _DlerrorNative>(
    'dlerror',
  );
  final malloc = process.lookupFunction<_MallocNative, _Malloc>('malloc');
  final free = process.lookupFunction<_FreeNative, _Free>('free');

  final bytes = utf8.encode(path);
  final cPath = malloc(bytes.length + 1);
  if (cPath.address == 0) return 'out of memory';
  try {
    cPath.asTypedList(bytes.length + 1)
      ..setAll(0, bytes)
      ..[bytes.length] = 0;
    if (dlopen(cPath, now | global).address != 0) return null;
    final error = dlerror();
    return error.address == 0 ? 'dlopen failed' : _readCString(error);
  } finally {
    free(cPath);
  }
}

String _readCString(Pointer<Uint8> pointer) {
  var length = 0;
  while ((pointer + length).value != 0) {
    length++;
  }
  return utf8.decode(pointer.asTypedList(length), allowMalformed: true);
}
