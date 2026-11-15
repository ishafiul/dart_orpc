//! Records from Rust to Dart.
//!
//! Layout (44 byte head): `u64` id, `u32` flags (see
//! [`super::kinds::request_flags`]), `u16` method length, `u16` target
//! length, `u32` headers length, `u32` body length, `u16` remote port
//! (or WebSocket close code), `u16` reserved, 16 bytes remote IP (IPv6,
//! IPv4 mapped). Then method, target, headers, body.
//!
//! Each header is `u16` name length, `u16` value length, the lowercase
//! name, the value. The lengths let Dart find one header without decoding
//! the others.

use crate::native_memory::{EXTERNAL_BODY_LEN, ExternalBody};

use super::kinds::request_flags;
use super::{read_u16, read_u32, read_u64};

/// Size of a record head.
pub const HEAD_LEN: usize = 44;

/// Remote address of a request: 16 IP bytes (IPv4 mapped) and a port.
pub type Peer = [u8; 18];

/// The fixed part of a request record.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub struct RecordHead {
    /// Request, WebSocket or stream id.
    pub id: u64,
    /// See [`request_flags`].
    pub flags: u32,
    /// Bytes of the method.
    pub method_len: u16,
    /// Bytes of the target.
    pub target_len: u16,
    /// Bytes of the header block.
    pub headers_len: u32,
    /// Bytes of the body (24 for an external body).
    pub body_len: u32,
    /// Remote port, or the close code of a closed WebSocket.
    pub port: u16,
    /// Remote IP, IPv4 mapped to IPv6.
    pub ip: [u8; 16],
}

impl RecordHead {
    /// A head for a request from `peer`.
    #[must_use]
    pub fn request(
        flags: u32,
        method_len: usize,
        target_len: usize,
        headers_len: usize,
        peer: &Peer,
    ) -> Self {
        let mut ip = [0; 16];
        ip.copy_from_slice(&peer[..16]);
        Self {
            id: 0,
            flags,
            method_len: to_u16(method_len),
            target_len: to_u16(target_len),
            headers_len: to_u32(headers_len),
            body_len: 0,
            port: u16::from_le_bytes([peer[16], peer[17]]),
            ip,
        }
    }

    /// Writes the head into `out[..HEAD_LEN]`.
    pub fn write(&self, out: &mut [u8]) {
        out[0..8].copy_from_slice(&self.id.to_le_bytes());
        out[8..12].copy_from_slice(&self.flags.to_le_bytes());
        out[12..14].copy_from_slice(&self.method_len.to_le_bytes());
        out[14..16].copy_from_slice(&self.target_len.to_le_bytes());
        out[16..20].copy_from_slice(&self.headers_len.to_le_bytes());
        out[20..24].copy_from_slice(&self.body_len.to_le_bytes());
        out[24..26].copy_from_slice(&self.port.to_le_bytes());
        out[26..28].copy_from_slice(&[0, 0]);
        out[28..44].copy_from_slice(&self.ip);
    }

    /// Reads a head from `bytes[..HEAD_LEN]`.
    #[must_use]
    pub fn read(bytes: &[u8]) -> Self {
        let mut ip = [0; 16];
        ip.copy_from_slice(&bytes[28..44]);
        Self {
            id: read_u64(bytes, 0),
            flags: read_u32(bytes, 8),
            method_len: read_u16(bytes, 12),
            target_len: read_u16(bytes, 14),
            headers_len: read_u32(bytes, 16),
            body_len: read_u32(bytes, 20),
            port: read_u16(bytes, 24),
            ip,
        }
    }

    /// Offset of the body from the start of the record.
    #[must_use]
    pub fn body_offset(&self) -> usize {
        HEAD_LEN
            + usize::from(self.method_len)
            + usize::from(self.target_len)
            + self.headers_len as usize
    }

    /// Length of the whole record.
    #[must_use]
    pub fn record_len(&self) -> usize {
        self.body_offset() + self.body_len as usize
    }

    /// Whether the body is an [`ExternalBody`] reference.
    #[must_use]
    pub fn has_external_body(&self) -> bool {
        self.flags & request_flags::EXTERNAL_BODY != 0
    }
}

/// Encoded size of a header block entry.
#[must_use]
pub fn header_entry_len(name: &str, value: &[u8]) -> usize {
    4 + name.len() + value.len()
}

/// Writes method, target and the header block into `out`. Header names
/// are lowercased. Returns the bytes written.
pub fn write_names(
    out: &mut [u8],
    method: &[u8],
    target: &[u8],
    headers: &[httparse::Header<'_>],
) -> usize {
    let mut at = 0;
    out[at..at + method.len()].copy_from_slice(method);
    at += method.len();
    out[at..at + target.len()].copy_from_slice(target);
    at += target.len();
    for header in headers {
        let (name, value) = (header.name.as_bytes(), header.value);
        out[at..at + 2].copy_from_slice(&to_u16(name.len()).to_le_bytes());
        out[at + 2..at + 4].copy_from_slice(&to_u16(value.len()).to_le_bytes());
        at += 4;
        for (dst, src) in out[at..at + name.len()].iter_mut().zip(name) {
            *dst = src.to_ascii_lowercase();
        }
        at += name.len();
        out[at..at + value.len()].copy_from_slice(value);
        at += value.len();
    }
    at
}

/// Sets the id and body of a record whose head and names are already in
/// `out[..body_at]`, and writes `body` after them. A body of
/// `external_min` bytes or more is moved as an [`ExternalBody`]. Returns
/// the record length, or `Err(needed)` when `out` is too small.
///
/// # Errors
/// `Err(size)` when the record needs `size` bytes, more than `out` has.
pub fn finish_with_body(
    head_and_names: &[u8],
    id: u64,
    body: Vec<u8>,
    external_min: usize,
    out: &mut [u8],
) -> Result<usize, usize> {
    let external = body.len() >= external_min;
    let body_len = if external {
        EXTERNAL_BODY_LEN
    } else {
        body.len()
    };
    let size = head_and_names.len() + body_len;
    if out.len() < size {
        return Err(size);
    }
    let names = head_and_names.len();
    out[..names].copy_from_slice(head_and_names);
    let mut head = RecordHead::read(out);
    head.id = id;
    head.body_len = to_u32(body_len);
    if external {
        head.flags |= request_flags::EXTERNAL_BODY;
        out[names..size].copy_from_slice(&ExternalBody::leak(body));
    } else {
        out[names..size].copy_from_slice(&body);
    }
    head.write(out);
    Ok(size)
}

/// Frees the external body of an encoded record that never reached Dart.
pub fn free_external_body(record: &[u8]) {
    let head = RecordHead::read(record);
    if head.has_external_body() {
        let token = read_u64(record, head.body_offset() + 8);
        // SAFETY: records only carry tokens from `ExternalBody::leak`, and
        // a record that never reached Dart has not been freed.
        unsafe { ExternalBody::free(token) };
    }
}

/// Lengths fit the wire fields: the head limit keeps method, target and
/// header lengths far below `u16::MAX`, and bodies below `u32::MAX`.
fn to_u16(value: usize) -> u16 {
    u16::try_from(value).unwrap_or(u16::MAX)
}

fn to_u32(value: usize) -> u32 {
    u32::try_from(value).unwrap_or(u32::MAX)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn peer() -> Peer {
        let mut peer = [0; 18];
        peer[15] = 1;
        peer[16..].copy_from_slice(&8080u16.to_le_bytes());
        peer
    }

    #[test]
    fn head_round_trips() {
        let mut head = RecordHead::request(request_flags::HTTP10, 3, 5, 12, &peer());
        head.id = 7;
        head.body_len = 9;
        let mut bytes = [0; HEAD_LEN];
        head.write(&mut bytes);
        assert_eq!(RecordHead::read(&bytes), head);
        assert_eq!(head.port, 8080);
        assert_eq!(head.record_len(), HEAD_LEN + 3 + 5 + 12 + 9);
    }

    #[test]
    fn names_lowercase_header_names_and_keep_values() {
        let headers = [httparse::Header {
            name: "X-Test",
            value: b"Yes",
        }];
        let mut out = [0; 64];
        let written = write_names(&mut out, b"GET", b"/", &headers);
        assert_eq!(&out[..4], b"GET/");
        assert_eq!(&out[4..8], &[6, 0, 3, 0]);
        assert_eq!(&out[8..written], b"x-testYes");
        assert_eq!(written, 4 + header_entry_len("X-Test", b"Yes"));
    }

    #[test]
    fn a_small_body_is_copied_and_a_big_one_moved() {
        let mut prefix = vec![0; HEAD_LEN];
        RecordHead::request(0, 0, 0, 0, &peer()).write(&mut prefix);
        let mut out = vec![0; 256];

        let len = finish_with_body(&prefix, 1, b"hi".to_vec(), 4, &mut out).unwrap();
        let head = RecordHead::read(&out);
        assert_eq!((head.id, head.body_len, len), (1, 2, HEAD_LEN + 2));
        assert_eq!(&out[HEAD_LEN..len], b"hi");

        let len = finish_with_body(&prefix, 2, b"large".to_vec(), 4, &mut out).unwrap();
        let head = RecordHead::read(&out);
        assert!(head.has_external_body());
        // SAFETY: just leaked by `finish_with_body`.
        let body = unsafe { ExternalBody::take(&out[HEAD_LEN..len]) };
        assert_eq!(body, b"large");
    }

    #[test]
    fn a_record_that_does_not_fit_reports_its_size() {
        let prefix = vec![0; HEAD_LEN];
        let mut out = vec![0; 10];
        assert_eq!(
            finish_with_body(&prefix, 1, b"abc".to_vec(), 1024, &mut out),
            Err(HEAD_LEN + 3)
        );
    }
}
