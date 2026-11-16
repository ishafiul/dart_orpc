//! Native HTTP/1.1 core of the `rust_http` Dart package.
//!
//! Rust owns the sockets and parses HTTP. All application code stays in
//! Dart, which drives this crate through the C ABI in [`ffi`].
//!
//! Only [`ffi`], [`dart_api`], [`native_memory`] and the poll call in
//! [`server`] contain `unsafe` code.

pub mod compress;
pub mod connection;
pub mod dart_api;
pub mod event_loop;
pub mod ffi;
pub mod http;
pub mod limits;
pub mod listener;
pub mod native_memory;
pub mod protocol;
pub mod server;
pub mod websocket;

/// Version of the C ABI and of the record layout shared with Dart.
///
/// Bump it whenever an exported function or a record layout changes. Dart
/// refuses to load a library whose version differs from its own
/// `abiVersion`.
pub const ABI_VERSION: i32 = 3;
