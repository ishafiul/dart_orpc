//! The C ABI that Dart calls through `dart:ffi`.
//!
//! Every exported symbol is prefixed with `rust_http_`. Functions here only
//! translate arguments and results; the logic lives in safe modules.

use std::ffi::c_void;

use crate::{ABI_VERSION, dart_api};

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
}
