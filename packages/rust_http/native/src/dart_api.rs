//! Access to the Dart VM through the dynamically linked Dart API.
//!
//! Dart hands us `NativeApi.initializeApiDLData`, a table of VM functions.
//! We only need `Dart_PostCObject`, so we look it up directly instead of
//! compiling `dart_api_dl.c`.

use std::ffi::{CStr, c_char, c_int, c_void};
use std::sync::OnceLock;

/// Major version of the Dart API DL table this crate understands.
const API_DL_MAJOR_VERSION: c_int = 2;

/// `Dart_CObject_kTypedData`.
const COBJECT_TYPED_DATA: i32 = 7;

/// `Dart_TypedData_kUint8`.
const TYPED_DATA_UINT8: i32 = 2;

#[repr(C)]
struct ApiEntry {
    name: *const c_char,
    function: *const c_void,
}

#[repr(C)]
struct ApiTable {
    major: c_int,
    minor: c_int,
    functions: *const ApiEntry,
}

/// `Dart_CObject` holding a `kTypedData` value (64-bit layout).
#[repr(C)]
struct TypedDataCObject {
    ty: i32,
    _type_padding: i32,
    typed_data_type: i32,
    _typed_data_padding: i32,
    length: isize,
    values: *const u8,
    _rest: [u64; 2],
}

type PostCObjectFn = unsafe extern "C" fn(i64, *mut TypedDataCObject) -> bool;

static POST_C_OBJECT: OnceLock<PostCObjectFn> = OnceLock::new();

/// Why [`initialize`] failed.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum InitError {
    /// The table pointer was null.
    NullTable,
    /// The table has a major version this crate does not understand.
    UnsupportedVersion,
    /// The table has no `Dart_PostCObject` entry.
    MissingPostCObject,
}

impl InitError {
    /// The status code reported over the C ABI.
    #[must_use]
    pub fn code(self) -> i32 {
        match self {
            Self::NullTable => -1,
            Self::UnsupportedVersion => -2,
            Self::MissingPostCObject => -3,
        }
    }
}

/// Reads `Dart_PostCObject` from the Dart API DL table.
///
/// Calling it again after a success is harmless.
///
/// # Errors
/// Returns an [`InitError`] when the table is null, has an unsupported
/// version, or lacks `Dart_PostCObject`.
///
/// # Safety
/// `table` must be null or the value of `NativeApi.initializeApiDLData`.
pub unsafe fn initialize(table: *mut c_void) -> Result<(), InitError> {
    if table.is_null() {
        return Err(InitError::NullTable);
    }
    // SAFETY: the caller guarantees `table` points to the Dart API DL table.
    let api = unsafe { &*table.cast::<ApiTable>() };
    if api.major != API_DL_MAJOR_VERSION {
        return Err(InitError::UnsupportedVersion);
    }
    let mut entry = api.functions;
    loop {
        // SAFETY: the table is a null-terminated array of entries.
        let current = unsafe { &*entry };
        if current.name.is_null() {
            return Err(InitError::MissingPostCObject);
        }
        // SAFETY: entry names are valid NUL-terminated C strings.
        let name = unsafe { CStr::from_ptr(current.name) };
        if name.to_bytes() == b"Dart_PostCObject" {
            // SAFETY: the VM documents this entry as `Dart_PostCObject`.
            let function: PostCObjectFn = unsafe { std::mem::transmute(current.function) };
            let _ = POST_C_OBJECT.set(function);
            return Ok(());
        }
        // SAFETY: the entry is not the terminator, so the next one exists.
        entry = unsafe { entry.add(1) };
    }
}

/// Whether [`initialize`] succeeded.
#[must_use]
pub fn is_initialized() -> bool {
    POST_C_OBJECT.get().is_some()
}

/// Posts `data` to the Dart port `port` as a `Uint8List`. Dart copies it.
///
/// Returns `false` when the API is not initialized or the port is closed,
/// for example because its isolate is gone.
#[must_use]
pub fn post_bytes(port: i64, data: &[u8]) -> bool {
    let Some(post_c_object) = POST_C_OBJECT.get() else {
        return false;
    };
    let mut object = TypedDataCObject {
        ty: COBJECT_TYPED_DATA,
        _type_padding: 0,
        typed_data_type: TYPED_DATA_UINT8,
        _typed_data_padding: 0,
        length: isize::try_from(data.len()).unwrap_or(isize::MAX),
        values: data.as_ptr(),
        _rest: [0; 2],
    };
    // SAFETY: `post_c_object` is `Dart_PostCObject`, and `object` outlives the call.
    unsafe { post_c_object(port, &raw mut object) }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn null_table_is_refused() {
        // SAFETY: null is an allowed argument.
        let result = unsafe { initialize(std::ptr::null_mut()) };
        assert_eq!(result, Err(InitError::NullTable));
    }

    #[test]
    fn post_without_initialize_fails_softly() {
        assert!(!post_bytes(1, b"x"));
    }
}
