//! The binary records exchanged with Dart in one `rust_http_run` call.
//!
//! All integers are little endian. Dart mirrors this module in
//! `lib/src/protocol/`; a layout change must bump [`crate::ABI_VERSION`].
//!
//! - Rust to Dart: [`request_record`] records — HTTP requests, WebSocket
//!   messages and stream progress — written into a buffer Dart owns.
//! - Dart to Rust: [`response_record`] records — answers, streamed body
//!   parts and WebSocket messages.

pub mod kinds;
pub mod outbox;
pub mod request_record;
pub mod response_record;

/// Reads a little-endian `u16` at `at`.
#[must_use]
pub fn read_u16(bytes: &[u8], at: usize) -> u16 {
    u16::from_le_bytes([bytes[at], bytes[at + 1]])
}

/// Reads a little-endian `u32` at `at`.
#[must_use]
pub fn read_u32(bytes: &[u8], at: usize) -> u32 {
    u32::from_le_bytes([bytes[at], bytes[at + 1], bytes[at + 2], bytes[at + 3]])
}

/// Reads a little-endian `u64` at `at`.
#[must_use]
pub fn read_u64(bytes: &[u8], at: usize) -> u64 {
    let mut word = [0; 8];
    word.copy_from_slice(&bytes[at..at + 8]);
    u64::from_le_bytes(word)
}
