//! Record kinds and flags shared with Dart (`lib/src/protocol/kinds.dart`).

/// Flag bits of a request record (Rust to Dart).
pub mod request_flags {
    /// The request is HTTP/1.0.
    pub const HTTP10: u32 = 1;
    /// The request is a valid WebSocket upgrade request.
    pub const WEBSOCKET_UPGRADE: u32 = 1 << 1;
    /// The body lives in native memory; see
    /// [`crate::protocol::request_record::ExternalBody`].
    pub const EXTERNAL_BODY: u32 = 1 << 2;
    /// Shift of the [`super::InboundKind`] in the flags.
    pub const KIND_SHIFT: u32 = 8;
}

/// What a record from Rust to Dart carries (flags bits 8 to 15).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u32)]
pub enum InboundKind {
    /// An HTTP request.
    Request = 0,
    /// A text WebSocket message. The id is the WebSocket id.
    WebSocketText = 1,
    /// A binary WebSocket message.
    WebSocketBinary = 2,
    /// The WebSocket closed. The port field holds the close code and the
    /// body the reason. Sent exactly once per WebSocket.
    WebSocketClosed = 3,
    /// Bytes of a streamed body reached the socket. The id is the stream
    /// id and the body a `u64` byte count.
    StreamSent = 4,
    /// The client of a streamed body is gone; Dart stops sending.
    StreamGone = 5,
}

impl InboundKind {
    /// The flag bits that encode this kind.
    #[must_use]
    pub const fn flags(self) -> u32 {
        (self as u32) << request_flags::KIND_SHIFT
    }
}

/// What a record from Dart to Rust carries (low byte of its kind field).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum OutboundKind {
    /// A whole HTTP answer.
    Answer,
    /// Accept a WebSocket upgrade. Body: `u64` ws id, `u64` max message.
    WebSocketAccept,
    /// A text message for a WebSocket.
    WebSocketText,
    /// A binary message for a WebSocket.
    WebSocketBinary,
    /// Close a WebSocket. Status: the code (0 for none). Body: the reason.
    WebSocketClose,
    /// Dart handled this many client message bytes (in the id field).
    WebSocketAck,
    /// Start a streamed answer. Body: `u64` stream id, then the first part.
    StreamStart,
    /// One part of a streamed body. The id is the stream id.
    StreamPart,
    /// The end of a streamed body. Status 0: complete; else the connection
    /// is cut so the client sees a short body.
    StreamEnd,
    /// The ping interval in milliseconds as a u64. Zero disables it.
    WebSocketPingInterval,
}

impl OutboundKind {
    /// Decodes the low byte of a kind field.
    #[must_use]
    pub const fn from_wire(kind: u16) -> Option<Self> {
        Some(match kind & 0xff {
            0 => Self::Answer,
            1 => Self::WebSocketAccept,
            2 => Self::WebSocketText,
            3 => Self::WebSocketBinary,
            4 => Self::WebSocketClose,
            5 => Self::WebSocketAck,
            6 => Self::StreamStart,
            7 => Self::StreamPart,
            8 => Self::StreamEnd,
            9 => Self::WebSocketPingInterval,
            _ => return None,
        })
    }

    /// Whether this record answers a request, which Dart counts as open
    /// until then.
    #[must_use]
    pub const fn answers_request(self) -> bool {
        matches!(
            self,
            Self::Answer | Self::WebSocketAccept | Self::StreamStart
        )
    }
}

/// Flag bits in the high byte of an outbound kind field.
pub mod answer_flags {
    /// Rust gzips the body on a helper thread. Dart set `content-encoding`.
    pub const GZIP: u16 = 0x100;
    /// Dart's header lines already contain `connection: close`.
    pub const CONNECTION_CLOSE: u16 = 0x200;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn outbound_kinds_round_trip_through_the_low_byte() {
        for wire in 0..=9u16 {
            let kind = OutboundKind::from_wire(wire | answer_flags::GZIP);
            assert!(kind.is_some(), "kind {wire}");
        }
        assert_eq!(OutboundKind::from_wire(10), None);
    }

    #[test]
    fn inbound_kind_sits_in_bits_8_to_15() {
        assert_eq!(InboundKind::StreamGone.flags(), 5 << 8);
    }
}
