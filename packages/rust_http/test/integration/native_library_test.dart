import 'package:rust_http/src/ffi/native_library.dart';
import 'package:test/test.dart';

void main() {
  test('the bundled native library loads and has the expected ABI', () {
    expect(nativeLibrary.status, isA<NativeLibraryLoaded>());
  });
}
