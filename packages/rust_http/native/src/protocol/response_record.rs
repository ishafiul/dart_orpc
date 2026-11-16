//! Records from Dart to Rust.
//!
//! Layout (20 byte head): `u64` id, `u16` status, `u16` kind (low byte: an
//! [`OutboundKind`], high byte: [`super::kinds::answer_flags`]), `u32`
//! header lines length, `u32` body length. Then the header lines
//! (`name: value\r\n` each) and the body.

use super::kinds::{OutboundKind, answer_flags};
use super::{read_u16, read_u32, read_u64};

/// Size of a record head.
pub const HEAD_LEN: usize = 20;

/// One record from Dart.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ResponseRecord<'a> {
    /// Request, stream or WebSocket id; for an ack, the acked byte count.
    pub id: u64,
    /// HTTP status, close code or stream end status.
    pub status: u16,
    /// What the record carries.
    pub kind: OutboundKind,
    /// The high byte of the kind field.
    pub flags: u16,
    /// Header lines, each `name: value\r\n`.
    pub lines: &'a [u8],
    /// The body.
    pub body: &'a [u8],
}

impl ResponseRecord<'_> {
    /// Rust must gzip the body.
    #[must_use]
    pub fn gzip(&self) -> bool {
        self.flags & answer_flags::GZIP != 0
    }

    /// The header lines contain `connection: close`.
    #[must_use]
    pub fn says_close(&self) -> bool {
        self.flags & answer_flags::CONNECTION_CLOSE != 0
    }

    /// The leading `u64` of the body, used by accepts and stream starts.
    #[must_use]
    pub fn body_word(&self, index: usize) -> Option<u64> {
        let at = index * 8;
        (self.body.len() >= at + 8).then(|| read_u64(self.body, at))
    }
}

/// Iterates the records of one buffer from Dart.
///
/// A truncated record ends the iteration; Dart always writes whole
/// records, so this only guards against a broken buffer. Records with an
/// unknown kind are skipped.
pub struct ResponseRecords<'a> {
    bytes: &'a [u8],
    at: usize,
}

impl<'a> ResponseRecords<'a> {
    /// Iterates `bytes`.
    #[must_use]
    pub fn new(bytes: &'a [u8]) -> Self {
        Self { bytes, at: 0 }
    }
}

impl<'a> Iterator for ResponseRecords<'a> {
    type Item = ResponseRecord<'a>;

    fn next(&mut self) -> Option<Self::Item> {
        loop {
            let bytes = self.bytes;
            let at = self.at;
            if at + HEAD_LEN > bytes.len() {
                return None;
            }
            let kind_field = read_u16(bytes, at + 10);
            let lines_len = read_u32(bytes, at + 12) as usize;
            let body_len = read_u32(bytes, at + 16) as usize;
            let lines_at = at + HEAD_LEN;
            let body_at = lines_at.checked_add(lines_len)?;
            let end = body_at.checked_add(body_len)?;
            if end > bytes.len() {
                self.at = bytes.len();
                return None;
            }
            self.at = end;
            let Some(kind) = OutboundKind::from_wire(kind_field) else {
                continue;
            };
            return Some(ResponseRecord {
                id: read_u64(bytes, at),
                status: read_u16(bytes, at + 8),
                kind,
                flags: kind_field & 0xff00,
                lines: &bytes[lines_at..body_at],
                body: &bytes[body_at..end],
            });
        }
    }
}

/// Appends a record to `out`, the way Dart writes one. For tests.
pub fn encode(out: &mut Vec<u8>, id: u64, status: u16, kind: u16, lines: &[u8], body: &[u8]) {
    out.extend_from_slice(&id.to_le_bytes());
    out.extend_from_slice(&status.to_le_bytes());
    out.extend_from_slice(&kind.to_le_bytes());
    out.extend_from_slice(&u32::try_from(lines.len()).unwrap_or(u32::MAX).to_le_bytes());
    out.extend_from_slice(&u32::try_from(body.len()).unwrap_or(u32::MAX).to_le_bytes());
    out.extend_from_slice(lines);
    out.extend_from_slice(body);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reads_records_in_order() {
        let mut out = Vec::new();
        encode(&mut out, 1, 200, answer_flags::GZIP, b"a: b\r\n", b"body");
        encode(&mut out, 9, 0, 7, b"", b"part");
        let records: Vec<_> = ResponseRecords::new(&out).collect();
        assert_eq!(records.len(), 2);
        assert_eq!(records[0].kind, OutboundKind::Answer);
        assert!(records[0].gzip());
        assert_eq!(records[0].lines, b"a: b\r\n");
        assert_eq!(records[1].kind, OutboundKind::StreamPart);
        assert_eq!(records[1].body, b"part");
    }

    #[test]
    fn a_truncated_record_ends_the_iteration() {
        let mut out = Vec::new();
        encode(&mut out, 1, 200, 0, b"", b"body");
        out.truncate(out.len() - 1);
        assert_eq!(ResponseRecords::new(&out).count(), 0);
    }

    #[test]
    fn an_unknown_kind_is_skipped() {
        let mut out = Vec::new();
        encode(&mut out, 1, 0, 0x42, b"", b"");
        encode(&mut out, 2, 200, 0, b"", b"");
        let ids: Vec<_> = ResponseRecords::new(&out).map(|r| r.id).collect();
        assert_eq!(ids, [2]);
    }

    #[test]
    fn body_words_read_ids() {
        let body = [7u64.to_le_bytes(), 9u64.to_le_bytes()].concat();
        let mut out = Vec::new();
        encode(&mut out, 1, 101, 1, b"", &body);
        let record = ResponseRecords::new(&out).next().unwrap();
        assert_eq!(record.body_word(0), Some(7));
        assert_eq!(record.body_word(1), Some(9));
        assert_eq!(record.body_word(2), None);
    }
}
