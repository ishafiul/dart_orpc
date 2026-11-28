//! The C ABI that Dart calls through `dart:ffi`.
//!
//! Every exported symbol is prefixed with `rust_http_`. Functions here only
//! translate arguments and results; the logic lives in safe modules.
//!
//! A server handle is an `Arc<Server>` turned into a raw pointer by
//! [`rust_http_bind`] and released by [`rust_http_unbind`].

use std::ffi::c_void;
use std::sync::Arc;
use std::time::Duration;

use crate::connection::NeedsRoom;
use crate::limits::Limits;
use crate::listener::ListenAddress;
use crate::native_memory::{ExternalBody, alloc_buffer, free_buffer};
use crate::server::{BindError, Server};
use crate::{ABI_VERSION, dart_api};

/// `rust_http_bind` result: `rust_http_init` was not called.
const BIND_NOT_INITIALIZED: i64 = -1;
/// `rust_http_bind` result: no poller or helper thread.
const BIND_NO_RESOURCES: i64 = -2;
/// `rust_http_bind_unix` result: Unix domain sockets are not supported on
/// this OS.
#[cfg(not(unix))]
const BIND_UNSUPPORTED: i64 = -3;
/// `rust_http_bind` result base: `-(1000 + errno)` for an OS bind error.
const BIND_OS_ERROR_BASE: i64 = 1000;

/// The ABI version of this library. Dart checks it before anything else.
#[unsafe(no_mangle)]
pub extern "C" fn rust_http_abi_version() -> i32 {
    ABI_VERSION
}

/// Connects this library to the Dart VM. Returns 0 on success, or a
/// negative [`dart_api::InitError`] code.
///
/// # Safety
/// `api_dl_data` must be `NativeApi.initializeApiDLData`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn rust_http_init(api_dl_data: *mut c_void) -> i32 {
    // SAFETY: forwarded from the caller.
    match unsafe { dart_api::initialize(api_dl_data) } {
        Ok(()) => 0,
        Err(error) => error.code(),
    }
}

/// Binds a server and starts its idle helper, which posts to `send_port`.
///
/// `family` (0 all interfaces, 4 IPv4, 6 IPv6), `address_high` and
/// `address_low` encode the host. Flag bit 0 enables sharing and bit 1
/// enables streaming request bodies. Returns a handle (> 0), -1 when not
/// initialized, -2 without resources, or `-(1000 + errno)` when the bind
/// fails.
#[unsafe(no_mangle)]
#[allow(clippy::too_many_arguments)]
pub extern "C" fn rust_http_bind(
    port: i32,
    send_port: i64,
    max_body: i64,
    max_multipart: i64,
    body_timeout_ms: i64,
    family: i32,
    address_high: u64,
    address_low: u64,
    max_connections: i64,
    idle_timeout_ms: i64,
    flags: i32,
) -> i64 {
    if !dart_api::is_initialized() {
        return BIND_NOT_INITIALIZED;
    }
    let address = ListenAddress::from_dart(
        family,
        address_high,
        address_low,
        u16::try_from(port).unwrap_or(0),
    );
    let mut limits = Limits::from_dart(
        max_body,
        max_multipart,
        body_timeout_ms,
        max_connections,
        idle_timeout_ms,
    );
    limits.stream_request_bodies = flags & 2 != 0;
    bind_result(Server::bind(address, flags & 1 != 0, limits, send_port))
}

/// Binds a server on the Unix domain socket at the `path_len` bytes of
/// `path`, like [`rust_http_bind`] otherwise. The socket file must not
/// exist; the last unbind of the path removes it. Returns what
/// [`rust_http_bind`] returns, or -3 where Unix domain sockets are not
/// supported.
///
/// # Safety
/// `path` must point to `path_len` readable bytes.
#[unsafe(no_mangle)]
#[allow(clippy::too_many_arguments)]
pub unsafe extern "C" fn rust_http_bind_unix(
    path: *const u8,
    path_len: i64,
    send_port: i64,
    max_body: i64,
    max_multipart: i64,
    body_timeout_ms: i64,
    max_connections: i64,
    idle_timeout_ms: i64,
    flags: i32,
) -> i64 {
    if !dart_api::is_initialized() {
        return BIND_NOT_INITIALIZED;
    }
    #[cfg(unix)]
    {
        use std::os::unix::ffi::OsStrExt;

        let path: &[u8] = match usize::try_from(path_len) {
            // SAFETY: the caller guarantees `path_len` readable bytes.
            Ok(len) if len > 0 && !path.is_null() => unsafe {
                std::slice::from_raw_parts(path, len)
            },
            _ => &[],
        };
        if path.is_empty() || path.contains(&0) {
            return -(BIND_OS_ERROR_BASE + i64::from(libc::EINVAL));
        }
        let path = std::path::Path::new(std::ffi::OsStr::from_bytes(path));
        let mut limits = Limits::from_dart(
            max_body,
            max_multipart,
            body_timeout_ms,
            max_connections,
            idle_timeout_ms,
        );
        limits.stream_request_bodies = flags & 2 != 0;
        bind_result(Server::bind_unix(path, flags & 1 != 0, limits, send_port))
    }
    #[cfg(not(unix))]
    {
        let _ = (
            path,
            path_len,
            send_port,
            max_body,
            max_multipart,
            body_timeout_ms,
            max_connections,
            idle_timeout_ms,
            flags,
        );
        BIND_UNSUPPORTED
    }
}

/// A bind's result as `rust_http_bind` returns it.
fn bind_result(result: Result<Arc<Server>, BindError>) -> i64 {
    match result {
        Ok(server) => Arc::into_raw(server) as i64,
        Err(BindError::Os(error)) => {
            -(BIND_OS_ERROR_BASE + i64::from(error.raw_os_error().unwrap_or(0)))
        }
        Err(BindError::Resources) => BIND_NO_RESOURCES,
    }
}

/// Borrows the server behind `handle`.
///
/// # Safety
/// `handle` must come from `rust_http_bind` and not be unbound.
unsafe fn server<'a>(handle: i64) -> &'a Server {
    // SAFETY: the caller guarantees `handle` is a live `Arc<Server>`.
    unsafe { &*(handle as *const Server) }
}

/// The bound port of a server (useful for port 0).
///
/// # Safety
/// `handle` must come from `rust_http_bind` and not be unbound.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn rust_http_bound_port(handle: i64) -> i32 {
    // SAFETY: forwarded from the caller.
    i32::from(unsafe { server(handle) }.port())
}

/// Writes the records in `answers`, then reads new requests into `inbox`,
/// waiting up to `budget_us` when there are none. Returns the bytes
/// written to `inbox`; 0 when nothing came (the idle helper then posts
/// `[1]` when something does); or `-size` when one record needs an inbox
/// of at least `size` bytes.
///
/// # Safety
/// `handle` must be live; `answers` must point to `answers_len` readable
/// bytes and `inbox` to `inbox_len` writable bytes. One call per handle at
/// a time.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn rust_http_run(
    handle: i64,
    answers: *const u8,
    answers_len: i64,
    inbox: *mut u8,
    inbox_len: i64,
    budget_us: i64,
) -> i64 {
    // SAFETY: forwarded from the caller.
    let server = unsafe { server(handle) };
    let answers: &[u8] = match usize::try_from(answers_len) {
        // SAFETY: the caller guarantees `answers_len` readable bytes.
        Ok(len) if len > 0 => unsafe { std::slice::from_raw_parts(answers, len) },
        _ => &[],
    };
    let inbox_len = usize::try_from(inbox_len).unwrap_or(0);
    // SAFETY: the caller guarantees `inbox_len` writable bytes.
    let inbox = unsafe { std::slice::from_raw_parts_mut(inbox, inbox_len) };
    let budget = Duration::from_micros(u64::try_from(budget_us).unwrap_or(0));
    match server.run(answers, inbox, budget) {
        Ok(written) => i64::try_from(written).unwrap_or(i64::MAX),
        Err(NeedsRoom(size)) => -i64::try_from(size).unwrap_or(i64::MAX),
    }
}

/// Starts a graceful shutdown. Dart gets `[2]` once every connection has
/// closed; then call `rust_http_unbind`.
///
/// # Safety
/// `handle` must come from `rust_http_bind` and not be unbound.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn rust_http_shutdown(handle: i64) {
    // SAFETY: forwarded from the caller.
    unsafe { server(handle) }.shutdown();
}

/// Stops a server, closes its sockets and frees the handle.
///
/// # Safety
/// `handle` must come from `rust_http_bind`. It is invalid afterwards.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn rust_http_unbind(handle: i64) {
    // SAFETY: the caller guarantees `handle` is a live `Arc<Server>` that
    // is released only here.
    let server = unsafe { Arc::from_raw(handle as *const Server) };
    server.stop();
}

/// Native memory for Dart's record buffers.
#[unsafe(no_mangle)]
pub extern "C" fn rust_http_alloc(size: i64) -> *mut c_void {
    alloc_buffer(usize::try_from(size).unwrap_or(0)).cast()
}

/// Frees memory from `rust_http_alloc`.
///
/// # Safety
/// `pointer` and `size` must come from one `rust_http_alloc` call.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn rust_http_free(pointer: *mut c_void, size: i64) {
    // SAFETY: forwarded from the caller.
    unsafe { free_buffer(pointer.cast(), usize::try_from(size).unwrap_or(0)) };
}

/// The finalizer of an external body: frees it.
///
/// # Safety
/// `token` must be the token of an external body, freed only once.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn rust_http_free_body(token: *mut c_void) {
    // SAFETY: forwarded from the caller.
    unsafe { ExternalBody::free(token as u64) };
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reports_the_abi_version() {
        assert_eq!(rust_http_abi_version(), ABI_VERSION);
    }

    #[test]
    fn init_with_null_reports_its_code() {
        // SAFETY: null is an allowed argument.
        let code = unsafe { rust_http_init(std::ptr::null_mut()) };
        assert_eq!(code, dart_api::InitError::NullTable.code());
    }

    #[test]
    fn bind_before_init_is_refused() {
        assert_eq!(
            rust_http_bind(0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0),
            BIND_NOT_INITIALIZED
        );
    }
}
