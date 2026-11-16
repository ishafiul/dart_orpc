//! Memory handed across the FFI boundary.
//!
//! Together with [`crate::ffi`] and [`crate::dart_api`] this is the only
//! module with `unsafe` code.

/// A body moved to Dart without a copy.
///
/// Dart wraps `address..address + length` as a typed list whose finalizer
/// calls `rust_http_free_body(token)`, which runs [`ExternalBody::free`].
pub struct ExternalBody;

/// Encoded size of an external body reference: address, token, length.
pub const EXTERNAL_BODY_LEN: usize = 24;

impl ExternalBody {
    /// Leaks `data` and returns its reference for a record body.
    #[must_use]
    pub fn leak(data: Vec<u8>) -> [u8; EXTERNAL_BODY_LEN] {
        let length = data.len() as u64;
        let boxed = Box::new(data);
        let address = boxed.as_ptr() as u64;
        let token = Box::into_raw(boxed) as u64;
        let mut out = [0; EXTERNAL_BODY_LEN];
        out[..8].copy_from_slice(&address.to_le_bytes());
        out[8..16].copy_from_slice(&token.to_le_bytes());
        out[16..].copy_from_slice(&length.to_le_bytes());
        out
    }

    /// Frees a body leaked by [`ExternalBody::leak`].
    ///
    /// # Safety
    /// `token` must come from one `leak` call and be freed only once.
    pub unsafe fn free(token: u64) {
        // SAFETY: the caller guarantees `token` is an unfreed leaked box.
        drop(unsafe { Box::from_raw(token as *mut Vec<u8>) });
    }

    /// Copies the bytes behind an encoded reference and frees them. For
    /// tests that play the Dart side.
    ///
    /// # Safety
    /// `reference` must come from `leak` and not be freed yet.
    #[must_use]
    pub unsafe fn take(reference: &[u8]) -> Vec<u8> {
        let word = |at: usize| crate::protocol::read_u64(reference, at);
        let (address, token, length) = (word(0), word(8), word(16));
        // SAFETY: `leak` produced these values from a live `Vec<u8>`.
        let bytes = unsafe {
            std::slice::from_raw_parts(address as *const u8, usize::try_from(length).unwrap_or(0))
        }
        .to_vec();
        // SAFETY: forwarded from the caller.
        unsafe { Self::free(token) };
        bytes
    }
}

/// A zeroed buffer for Dart, which cannot pass Dart heap memory to a
/// non-leaf FFI call.
#[must_use]
pub fn alloc_buffer(size: usize) -> *mut u8 {
    let buffer: Box<[u8]> = vec![0; size.max(1)].into_boxed_slice();
    Box::into_raw(buffer).cast::<u8>()
}

/// Frees a buffer from [`alloc_buffer`].
///
/// # Safety
/// `pointer` and `size` must come from one `alloc_buffer` call.
pub unsafe fn free_buffer(pointer: *mut u8, size: usize) {
    let slice = std::ptr::slice_from_raw_parts_mut(pointer, size.max(1));
    // SAFETY: the caller guarantees this is a live `alloc_buffer` buffer.
    drop(unsafe { Box::from_raw(slice) });
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_leaked_body_comes_back_whole() {
        let reference = ExternalBody::leak(b"hello".to_vec());
        // SAFETY: fresh from `leak`.
        let bytes = unsafe { ExternalBody::take(&reference) };
        assert_eq!(bytes, b"hello");
    }

    #[test]
    fn buffers_are_zeroed_and_freed() {
        let pointer = alloc_buffer(16);
        // SAFETY: 16 bytes were just allocated.
        let slice = unsafe { std::slice::from_raw_parts(pointer, 16) };
        assert!(slice.iter().all(|&b| b == 0));
        // SAFETY: from `alloc_buffer(16)`.
        unsafe { free_buffer(pointer, 16) };
    }
}
