//! Native HTTP/1.1 core of the `rust_http` Dart package.
//!
//! Rust owns the sockets and parses HTTP. All application code stays in
//! Dart, which drives this crate through the C ABI in [`ffi`].
//!
//! Only [`ffi`] and [`dart_api`] contain `unsafe` code.

pub mod dart_api;
pub mod ffi;

/// Version of the C ABI and of the record layout shared with Dart.
///
/// Bump it whenever an exported function or a record layout changes. Dart
/// refuses to load a library whose version differs from its own
/// `abiVersion`.
pub const ABI_VERSION: i32 = 1;
