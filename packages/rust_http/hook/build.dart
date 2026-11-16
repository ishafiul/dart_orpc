// Bundles the rust_http native library as a code asset.
//
// The library comes from the first source that has one; see
// NativeLibraryResolver.standard. When none does, no asset is added and
// RustHttpServer reports why at runtime; the build itself never fails
// because of this package.
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:rust_http/src/native_build/native_build_context.dart';
import 'package:rust_http/src/native_build/native_library_resolver.dart';

Future<void> main(List<String> arguments) async {
  await build(arguments, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    final code = input.config.code;
    final os = code.targetOS;
    final architecture = code.targetArchitecture;
    final context = NativeBuildContext(
      packageRoot: input.packageRoot,
      libraryFileName: os.dylibFileName('rust_http'),
      targetName: '${os.name}-${architecture.name}',
      isHostTarget: os == OS.current && architecture == Architecture.current,
      sharedOutputDirectory: input.outputDirectoryShared,
      userLibraryPath: input.userDefines['lib_path'] as String?,
      usePrebuilt: input.userDefines['prebuilt'] != false,
    );
    final library = await NativeLibraryResolver.standard().resolve(context);
    if (library == null) {
      stderr.writeln(
        'rust_http: no native library for ${os.name}-${architecture.name}. '
        'No prebuilt library matched and cargo is not available; install '
        'Rust (https://rustup.rs) to build it from source.',
      );
      return;
    }
    output.dependencies.addAll(library.dependencies);
    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: 'src/ffi/bindings.dart',
        linkMode: DynamicLoadingBundled(),
        file: library.file,
      ),
    );
  });
}
