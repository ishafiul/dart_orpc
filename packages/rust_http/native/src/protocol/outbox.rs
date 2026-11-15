//! Messages for Dart that are not requests: WebSocket messages and stream
//! progress. They are queued as request records and copied to Dart at the
//! end of the next `rust_http_run` call.

use crate::limits::EXTERNAL_MIN;
use crate::native_memory::ExternalBody;

use super::kinds::{InboundKind, request_flags};
use super::request_record::{HEAD_LEN, RecordHead, free_external_body};

/// Queued records for Dart.
#[derive(Default)]
pub struct Outbox {
    bytes: Vec<u8>,
    /// Client WebSocket bytes given to Dart and not acknowledged yet.
    unacked_websocket_bytes: usize,
}

impl Outbox {
    /// Queues a record of `kind` for `id`. `code` goes in the port field.
    pub fn push(&mut self, id: u64, kind: InboundKind, code: u16, data: &[u8]) {
        if matches!(
            kind,
            InboundKind::WebSocketText | InboundKind::WebSocketBinary
        ) {
            self.unacked_websocket_bytes += data.len();
        }
        let external = data.len() >= EXTERNAL_MIN;
        let reference;
        let body: &[u8] = if external {
            reference = ExternalBody::leak(data.to_vec());
            &reference
        } else {
            data
        };
        let mut flags = kind.flags();
        if external {
            flags |= request_flags::EXTERNAL_BODY;
        }
        let head = RecordHead {
            id,
            flags,
            body_len: u32::try_from(body.len()).unwrap_or(u32::MAX),
            port: code,
            ..RecordHead::default()
        };
        let at = self.bytes.len();
        self.bytes.resize(at + HEAD_LEN, 0);
        head.write(&mut self.bytes[at..]);
        self.bytes.extend_from_slice(body);
    }

    /// Whether nothing is queued.
    #[must_use]
    pub fn is_empty(&self) -> bool {
        self.bytes.is_empty()
    }

    /// Client WebSocket bytes Dart has not acknowledged.
    #[must_use]
    pub fn unacked_websocket_bytes(&self) -> usize {
        self.unacked_websocket_bytes
    }

    /// Dart handled `bytes` of client messages.
    pub fn acknowledge(&mut self, bytes: usize) {
        self.unacked_websocket_bytes = self.unacked_websocket_bytes.saturating_sub(bytes);
    }

    /// Length of the first queued record, if any.
    #[must_use]
    pub fn first_len(&self) -> Option<usize> {
        (self.bytes.len() >= HEAD_LEN).then(|| RecordHead::read(&self.bytes).record_len())
    }

    /// Moves the whole records that fit into `out`. Returns the bytes moved.
    pub fn drain_into(&mut self, out: &mut [u8]) -> usize {
        let mut take = 0;
        while take + HEAD_LEN <= self.bytes.len() {
            let len = RecordHead::read(&self.bytes[take..]).record_len();
            if take + len > out.len() {
                break;
            }
            take += len;
        }
        out[..take].copy_from_slice(&self.bytes[..take]);
        self.bytes.drain(..take);
        take
    }
}

impl Drop for Outbox {
    fn drop(&mut self) {
        let mut at = 0;
        while at + HEAD_LEN <= self.bytes.len() {
            free_external_body(&self.bytes[at..]);
            at += RecordHead::read(&self.bytes[at..]).record_len();
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn counts_unacknowledged_message_bytes_only() {
        let mut outbox = Outbox::default();
        outbox.push(1, InboundKind::WebSocketText, 0, b"abc");
        outbox.push(1, InboundKind::WebSocketClosed, 1000, b"bye");
        assert_eq!(outbox.unacked_websocket_bytes(), 3);
        outbox.acknowledge(10);
        assert_eq!(outbox.unacked_websocket_bytes(), 0);
    }

    #[test]
    fn drains_only_whole_records() {
        let mut outbox = Outbox::default();
        outbox.push(1, InboundKind::StreamGone, 0, b"");
        outbox.push(2, InboundKind::StreamSent, 0, &5u64.to_le_bytes());
        let mut out = vec![0; HEAD_LEN + 4];
        assert_eq!(outbox.drain_into(&mut out), HEAD_LEN);
        assert_eq!(outbox.first_len(), Some(HEAD_LEN + 8));
        let mut out = vec![0; 128];
        assert_eq!(outbox.drain_into(&mut out), HEAD_LEN + 8);
        assert!(outbox.is_empty());
    }

    #[test]
    fn frees_external_bodies_that_never_reached_dart() {
        let mut outbox = Outbox::default();
        outbox.push(1, InboundKind::WebSocketBinary, 0, &vec![0; EXTERNAL_MIN]);
        drop(outbox); // must not leak; run under miri or a leak checker
    }
}
