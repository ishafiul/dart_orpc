//! WebSocket state of one connection, on top of the sync `tungstenite`
//! state machine over the non-blocking socket.

use std::collections::VecDeque;
use std::io::{ErrorKind, Read, Write};
use std::time::{Duration, Instant};

use tungstenite::protocol::frame::coding::CloseCode;
use tungstenite::protocol::{CloseFrame, Role, WebSocketContext};
use tungstenite::{Message, Utf8Bytes};

use crate::limits::WS_MIN_QUEUE;
use crate::stream::Stream;

/// The WebSocket of an upgraded connection.
pub struct WebSocketState {
    /// The protocol state machine.
    pub context: WebSocketContext,
    /// The id Dart picked.
    pub id: u64,
    /// Max message and frame size.
    pub max_message: usize,
    /// Messages from Dart that tungstenite does not have yet.
    pub queue: VecDeque<Message>,
    /// Bytes in [`Self::queue`].
    pub queued_bytes: usize,
    /// Most bytes [`Self::queue`] may hold before the socket closes with
    /// 1008: the client reads too slowly.
    pub queue_cap: usize,
    /// The `101` is written and frames flow.
    pub live: bool,
    /// The close code and reason for Dart, once known.
    pub close_status: Option<(u16, Vec<u8>)>,
    /// Dart got its one closed record.
    pub told_dart: bool,
    /// When our close frame went out.
    pub closing_since: Option<Instant>,
    /// Frames are not read: Dart or the client is behind.
    pub paused: bool,
    /// Heartbeat interval, when enabled.
    pub ping_interval: Option<Duration>,
    /// Next ping or pong deadline.
    pub ping_due: Option<Instant>,
    /// A ping is outstanding.
    pub awaiting_pong: bool,
}

impl WebSocketState {
    /// A WebSocket that goes live after the `101` is written.
    #[must_use]
    pub fn new(id: u64, max_message: usize) -> Self {
        Self {
            context: WebSocketContext::new(Role::Server, None),
            id,
            max_message,
            queue: VecDeque::new(),
            queued_bytes: 0,
            queue_cap: max_message.saturating_mul(4).max(WS_MIN_QUEUE),
            live: false,
            close_status: None,
            told_dart: false,
            closing_since: None,
            paused: false,
            ping_interval: None,
            ping_due: None,
            awaiting_pong: false,
        }
    }
}

/// Reads from the socket and writes to the connection's write buffer, so
/// tungstenite never waits on a write: the event loop writes the buffer.
pub struct SocketIo<'a> {
    /// The socket.
    pub socket: &'a Stream,
    /// The write buffer.
    pub out: &'a mut Vec<u8>,
    /// Bytes it may still read in this turn.
    pub read_budget: usize,
}

impl Read for SocketIo<'_> {
    fn read(&mut self, buf: &mut [u8]) -> std::io::Result<usize> {
        if self.read_budget == 0 {
            // The share of this turn is used up; the caller queues again.
            return Err(ErrorKind::WouldBlock.into());
        }
        let max = buf.len().min(self.read_budget);
        let mut socket = self.socket;
        let read = socket.read(&mut buf[..max])?;
        self.read_budget -= read;
        Ok(read)
    }
}

impl Write for SocketIo<'_> {
    fn write(&mut self, buf: &[u8]) -> std::io::Result<usize> {
        self.out.extend_from_slice(buf);
        Ok(buf.len())
    }

    fn flush(&mut self) -> std::io::Result<()> {
        Ok(())
    }
}

/// The code and reason of a close frame. No frame is 1005 (no status),
/// like dart:io.
#[must_use]
pub fn close_parts(frame: Option<CloseFrame>) -> (u16, Vec<u8>) {
    frame.map_or((1005, Vec::new()), |frame| {
        (u16::from(frame.code), frame.reason.as_bytes().to_vec())
    })
}

/// A close frame with `code` and no reason.
#[must_use]
pub fn close_frame(code: CloseCode) -> Option<CloseFrame> {
    Some(CloseFrame {
        code,
        reason: Utf8Bytes::from_static(""),
    })
}

/// The close code reported when the TCP connection ended without a close
/// frame.
pub const ABNORMAL_CLOSURE: u16 = 1006;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn no_close_frame_reports_1005() {
        assert_eq!(close_parts(None), (1005, Vec::new()));
        assert_eq!(close_parts(close_frame(CloseCode::Away)).0, 1001);
    }

    #[test]
    fn the_queue_cap_is_at_least_the_minimum() {
        assert_eq!(WebSocketState::new(1, 8).queue_cap, WS_MIN_QUEUE);
        assert_eq!(WebSocketState::new(1, 1 << 20).queue_cap, 4 << 20);
    }
}
