/// Raw `dart:ffi` declarations of the Rust library's C ABI.
///
/// The build hook bundles the library as the code asset of this file, so
/// every `@Native` here resolves against it. Nothing else belongs here:
/// wrappers and logic live in other files.
library;

import 'dart:ffi';

/// `rust_http_abi_version` in `native/src/ffi.rs`.
@Native<Int32 Function()>(symbol: 'rust_http_abi_version', isLeaf: true)
external int rustHttpAbiVersion();

/// `rust_http_init` in `native/src/ffi.rs`.
@Native<Int32 Function(Pointer<Void>)>(symbol: 'rust_http_init')
external int rustHttpInit(Pointer<Void> apiDlData);
