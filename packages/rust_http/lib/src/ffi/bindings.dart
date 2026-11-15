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

/// `rust_http_bind` in `native/src/ffi.rs`.
@Native<
  Int64 Function(
    Int32,
    Int64,
    Int64,
    Int64,
    Int64,
    Int32,
    Uint64,
    Uint64,
    Int64,
    Int64,
    Int32,
  )
>(symbol: 'rust_http_bind')
external int rustHttpBind(
  int port,
  int sendPort,
  int maxBody,
  int maxMultipart,
  int bodyTimeoutMs,
  int family,
  int addressHigh,
  int addressLow,
  int maxConnections,
  int idleTimeoutMs,
  int flags,
);

/// `rust_http_bound_port` in `native/src/ffi.rs`.
@Native<Int32 Function(Int64)>(symbol: 'rust_http_bound_port', isLeaf: true)
external int rustHttpBoundPort(int handle);

/// `rust_http_run` in `native/src/ffi.rs`. Not a leaf call: it may wait
/// on the sockets.
@Native<
  Int64 Function(Int64, Pointer<Uint8>, Int64, Pointer<Uint8>, Int64, Int64)
>(symbol: 'rust_http_run')
external int rustHttpRun(
  int handle,
  Pointer<Uint8> answers,
  int answersLength,
  Pointer<Uint8> inbox,
  int inboxLength,
  int budgetUs,
);

/// `rust_http_shutdown` in `native/src/ffi.rs`.
@Native<Void Function(Int64)>(symbol: 'rust_http_shutdown')
external void rustHttpShutdown(int handle);

/// `rust_http_unbind` in `native/src/ffi.rs`.
@Native<Void Function(Int64)>(symbol: 'rust_http_unbind')
external void rustHttpUnbind(int handle);

/// `rust_http_alloc` in `native/src/ffi.rs`.
@Native<Pointer<Uint8> Function(Int64)>(symbol: 'rust_http_alloc', isLeaf: true)
external Pointer<Uint8> rustHttpAlloc(int size);

/// `rust_http_free` in `native/src/ffi.rs`.
@Native<Void Function(Pointer<Uint8>, Int64)>(
  symbol: 'rust_http_free',
  isLeaf: true,
)
external void rustHttpFree(Pointer<Uint8> pointer, int size);

/// `rust_http_free_body` in `native/src/ffi.rs`, the finalizer of an
/// external body.
@Native<Void Function(Pointer<Void>)>(
  symbol: 'rust_http_free_body',
  isLeaf: true,
)
external void rustHttpFreeBody(Pointer<Void> token);
