//! One client connection: its buffers, the answers it waits for, and the
//! parse of its requests.
//!
//! Answers go out in request order, also when Dart answers out of order:
//! each request gets a [`PendingAnswer`] slot, and only the front slot
//! writes to the socket buffer.

use std::collections::VecDeque;
use std::io::{ErrorKind, Read, Write};
use std::time::Instant;

use mio::net::TcpStream;

use crate::http::body::{BodyProgress, BodyReader};
use crate::http::head::{HeadParse, RequestInfo, parse_request};
use crate::http::render::{AnswerFraming, render_answer};
use crate::limits::{
    BIG_WRITE_BUFFER, CLOSE_WAIT, KEEP_WRITE_BUFFER, LINGER, Limits, MAX_HEAD, MAX_INFLIGHT,
    MAX_PENDING, READ_ROOM, SEND_WAIT,
};
use crate::protocol::request_record::{Peer, RecordHead};
use crate::protocol::{kinds::InboundKind, outbox::Outbox};
use crate::websocket::WebSocketState;

/// How a streamed body is framed and ends.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum StreamTail {
    /// In chunks, then the last chunk.
    Chunked,
    /// The connection closes after it.
    Close,
    /// Dart declared `content-length`: this many bytes are still due.
    Remaining(u64),
}

/// A request that waits for its answer.
#[derive(Debug, Default)]
pub struct PendingAnswer {
    /// Sequence number of the request on this server.
    pub sequence: u32,
    /// Answer bytes that came before the answers in front of this one.
    pub out: Vec<u8>,
    /// The answer is complete; the slot goes once `out` is written.
    pub done: bool,
    /// An answer came (maybe not complete: a stream or a gzip job).
    pub answered: bool,
    /// What the answer needs to know about the request.
    pub request: RequestInfo,
    /// Dart accepted the upgrade: the connection is a WebSocket after it.
    pub upgrade: bool,
    /// A streamed body: its id and how it ends.
    pub stream: Option<(u64, StreamTail)>,
    /// Stream body bytes in `out`, reported to Dart once written.
    pub unsent: u64,
}

impl PendingAnswer {
    /// The framing for this slot's answer.
    #[must_use]
    pub fn framing(&self) -> AnswerFraming {
        AnswerFraming {
            http10: self.request.http10,
            is_head: self.request.is_head,
            close: self.request.close,
            lines_say_close: false,
        }
    }
}

/// What a connection's timer fires for.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Due {
    /// The lingering close is over.
    Linger,
    /// The body timeout: answer 408.
    Body,
    /// No request head in the idle time.
    Head,
    /// A closing WebSocket got no close frame back.
    WebSocketClose,
    /// Send a heartbeat or close if the last one went unanswered.
    WebSocketPing,
    /// A write made no progress: the client does not read.
    Send,
}

/// One client connection.
pub struct Connection {
    /// The socket.
    pub socket: TcpStream,
    /// The remote address.
    pub peer: Peer,
    /// Read bytes; `read_pos..read_len` is not parsed yet. Empty while no
    /// bytes wait: a read then uses the loop's shared buffer.
    pub read_buf: Vec<u8>,
    /// Start of unparsed bytes.
    pub read_pos: usize,
    /// End of read bytes.
    pub read_len: usize,
    /// Bytes to write; `write_pos..` is not written yet.
    pub write_buf: Vec<u8>,
    /// Start of unwritten bytes.
    pub write_pos: usize,
    /// Bytes written to the socket so far.
    pub written: u64,
    /// Stream bytes to report once `written` reaches the first value:
    /// (end, stream id, bytes).
    pub stream_marks: VecDeque<(u64, u64, u64)>,
    /// Requests waiting for answers, in order.
    pub slots: VecDeque<PendingAnswer>,
    /// A body being read.
    pub body: Option<Box<BodyReader>>,
    /// Request id when Dart has the head of the current body.
    pub streaming_body: Option<u64>,
    /// The WebSocket after an accepted upgrade.
    pub websocket: Option<Box<WebSocketState>>,
    /// In the loop's ready queue.
    pub queued: bool,
    /// In the loop's touched list.
    pub touched: bool,
    /// Parse no more requests (a close, an error or a shutdown).
    pub closing: bool,
    /// An upgrade request waits for its answer: parse no more for now.
    pub upgrading: bool,
    /// Reading stopped until answers go out or Dart catches up.
    pub paused: bool,
    /// The `101` went out: switch to the WebSocket.
    pub switch_to_websocket: bool,
    /// Close once the write buffer is written.
    pub shut: bool,
    /// The client closed its side.
    pub eof: bool,
    /// The poll saw the client close: a short read must go on to the 0.
    pub hangup: bool,
    /// Lingering close: when it started and the bytes dropped.
    pub linger: Option<(Instant, usize)>,
    /// When the last request came or answer went out: the idle time
    /// counts from here.
    pub idle_since: Instant,
    /// The time of the timer entry this connection relies on.
    pub timer: Option<Instant>,
    /// When pending writes last made progress.
    pub stuck_since: Option<Instant>,
}

/// Where parsing a connection's requests stopped.
#[derive(Debug, PartialEq, Eq)]
pub struct NeedsRoom(pub usize);

/// Ids and time for parsing.
pub struct ParseContext<'a> {
    /// The connection's index in the loop.
    pub index: usize,
    /// Dart's buffer.
    pub out: &'a mut [u8],
    /// Body chunks and completion records.
    pub outbox: &'a mut Outbox,
    /// Bytes used in `out`.
    pub used: &'a mut usize,
    /// The server's request sequence counter.
    pub sequence: &'a mut u32,
    /// The limits.
    pub limits: &'a Limits,
    /// The current date line.
    pub date_line: &'a [u8],
    /// The loop's clock.
    pub now: Instant,
}

/// The id of request `sequence` on connection `index`. The sequence is per
/// server, so a late answer for a closed connection never reaches a new
/// connection in the same slot.
#[must_use]
pub fn request_id(index: usize, sequence: u32) -> u64 {
    ((index as u64) << 32) | u64::from(sequence)
}

impl Connection {
    /// A fresh connection accepted at `now`.
    #[must_use]
    pub fn new(socket: TcpStream, peer: Peer, now: Instant) -> Self {
        Self {
            socket,
            peer,
            read_buf: Vec::new(),
            read_pos: 0,
            read_len: 0,
            write_buf: Vec::new(),
            write_pos: 0,
            written: 0,
            stream_marks: VecDeque::new(),
            slots: VecDeque::new(),
            body: None,
            streaming_body: None,
            websocket: None,
            queued: false,
            touched: false,
            closing: false,
            upgrading: false,
            paused: false,
            switch_to_websocket: false,
            shut: false,
            eof: false,
            hangup: false,
            linger: None,
            idle_since: now,
            timer: None,
            stuck_since: None,
        }
    }

    /// Bytes waiting to be written.
    #[must_use]
    pub fn pending(&self) -> usize {
        self.write_buf.len() - self.write_pos
    }

    /// Whether the connection is a live WebSocket.
    #[must_use]
    pub fn is_live_websocket(&self) -> bool {
        self.websocket.as_ref().is_some_and(|ws| ws.live)
    }

    /// Whether it may read and parse more requests now.
    #[must_use]
    pub fn can_parse(&self) -> bool {
        self.slots.len() < MAX_INFLIGHT && !self.upgrading && self.pending() < MAX_PENDING
    }

    /// Reads what the socket has. False on a socket error.
    pub fn read(&mut self) -> bool {
        loop {
            if self.read_pos == self.read_len {
                self.read_pos = 0;
                self.read_len = 0;
                if self.read_buf.len() > 4 * READ_ROOM {
                    self.read_buf = vec![0; READ_ROOM];
                }
            }
            if self.read_buf.len() - self.read_len < READ_ROOM {
                if self.read_pos > 0 {
                    self.read_buf.copy_within(self.read_pos..self.read_len, 0);
                    self.read_len -= self.read_pos;
                    self.read_pos = 0;
                }
                if self.read_buf.len() - self.read_len < READ_ROOM {
                    if self.read_len > MAX_HEAD + READ_ROOM {
                        // Many pipelined requests: parse first, read later.
                        self.paused = true;
                        return true;
                    }
                    let size = (self.read_buf.len() * 2).max(self.read_len + READ_ROOM);
                    self.read_buf.resize(size, 0);
                }
            }
            match (&self.socket).read(&mut self.read_buf[self.read_len..]) {
                Ok(0) => {
                    self.eof = true;
                    return true;
                }
                Ok(read) => {
                    self.read_len += read;
                    // A short read emptied the socket; new bytes give a new
                    // edge. After a hangup, read on to the 0.
                    if self.read_len < self.read_buf.len() && !self.hangup {
                        return true;
                    }
                }
                Err(e) if e.kind() == ErrorKind::WouldBlock => return true,
                Err(e) if e.kind() == ErrorKind::Interrupted => {}
                Err(_) => return false,
            }
        }
    }

    /// Before a read: when no bytes wait, borrow the loop's `scratch`
    /// buffer, so an idle keep-alive connection holds no read buffer.
    /// Returns whether it was borrowed.
    pub fn borrow_scratch(&mut self, scratch: &mut Vec<u8>) -> bool {
        if self.read_pos < self.read_len {
            return false;
        }
        self.read_pos = 0;
        self.read_len = 0;
        self.read_buf = std::mem::take(scratch);
        true
    }

    /// After a parse: gives `scratch` back. Only unparsed bytes (part of a
    /// request) are copied to a buffer of the connection's own.
    pub fn return_scratch(&mut self, scratch: &mut Vec<u8>, borrowed: bool) {
        if self.read_pos == self.read_len {
            self.read_pos = 0;
            self.read_len = 0;
            let buffer = std::mem::take(&mut self.read_buf);
            if borrowed {
                *scratch = buffer;
            }
        } else if borrowed {
            let buffer = std::mem::take(&mut self.read_buf);
            self.read_buf = buffer[self.read_pos..self.read_len].to_vec();
            self.read_len -= self.read_pos;
            self.read_pos = 0;
            *scratch = buffer;
        }
    }

    /// Writes the write buffer. False on a socket error.
    pub fn flush(&mut self) -> bool {
        while self.write_pos < self.write_buf.len() {
            match (&self.socket).write(&self.write_buf[self.write_pos..]) {
                Ok(0) => return false,
                Ok(written) => {
                    self.write_pos += written;
                    self.written += written as u64;
                }
                Err(e) if e.kind() == ErrorKind::WouldBlock => break,
                Err(e) if e.kind() == ErrorKind::Interrupted => {}
                Err(_) => return false,
            }
        }
        if self.write_pos == self.write_buf.len() {
            self.write_pos = 0;
            if self.write_buf.capacity() > KEEP_WRITE_BUFFER {
                self.write_buf = Vec::new();
            } else {
                self.write_buf.clear();
            }
        } else if self.write_pos > BIG_WRITE_BUFFER && self.write_pos * 2 > self.write_buf.len() {
            self.write_buf.drain(..self.write_pos);
            self.write_pos = 0;
        }
        true
    }

    /// Whether the connection can be closed now.
    #[must_use]
    pub fn is_finished(&self) -> bool {
        self.pending() == 0
            && !self.is_live_websocket()
            && self.eof
            && self.slots.is_empty()
            && self.body.is_none()
            && !self.queued
    }

    /// Adds answer bytes for slot `index`; `stream_bytes` of them are
    /// streamed body bytes, reported to Dart once written.
    pub fn put(&mut self, index: usize, data: &[u8], stream_bytes: u64) {
        if index == 0 {
            self.write_buf.extend_from_slice(data);
            self.mark_stream_bytes(stream_bytes);
        } else {
            let slot = &mut self.slots[index];
            slot.out.extend_from_slice(data);
            slot.unsent += stream_bytes;
        }
    }

    /// The last `count` bytes of the write buffer are stream bytes of the
    /// front slot.
    fn mark_stream_bytes(&mut self, count: u64) {
        if count > 0
            && let Some((stream, _)) = self.slots.front().and_then(|slot| slot.stream)
        {
            let end = self.written + self.pending() as u64;
            self.stream_marks.push_back((end, stream, count));
        }
    }

    /// Moves the answers that are next in order to the write buffer.
    pub fn advance_slots(&mut self) {
        while let Some(front) = self.slots.front_mut() {
            if !front.out.is_empty() {
                let out = std::mem::take(&mut front.out);
                let unsent = std::mem::take(&mut front.unsent);
                if self.pending() == 0 {
                    self.write_buf = out;
                    self.write_pos = 0;
                } else {
                    self.write_buf.extend_from_slice(&out);
                }
                self.mark_stream_bytes(unsent);
            }
            if !self.slots.front().is_some_and(|slot| slot.done) {
                break;
            }
            let Some(slot) = self.slots.pop_front() else {
                break;
            };
            if slot.request.close {
                self.shut = true;
                break;
            }
            if slot.upgrade {
                self.switch_to_websocket = true;
                break;
            }
        }
        if self.slots.is_empty() {
            self.upgrading = false;
            if self.closing && self.body.is_none() && self.websocket.is_none() {
                self.shut = true;
            }
        }
    }

    /// Answers a bad request from Rust and closes after it.
    pub fn reject(&mut self, status: u16, date_line: &[u8]) {
        self.body = None;
        let mut out = Vec::new();
        let framing = AnswerFraming {
            close: true,
            ..AnswerFraming::default()
        };
        render_answer(&mut out, status, b"", b"", date_line, framing);
        self.slots.push_back(PendingAnswer {
            out,
            done: true,
            answered: true,
            request: RequestInfo {
                close: true,
                ..RequestInfo::default()
            },
            ..PendingAnswer::default()
        });
        self.closing = true;
        self.advance_slots();
    }

    /// Parses the complete requests of the read buffer into Dart's buffer.
    ///
    /// # Errors
    /// [`NeedsRoom`] when the next record needs more room than is left.
    pub fn parse(&mut self, cx: &mut ParseContext<'_>) -> Result<(), NeedsRoom> {
        loop {
            if self.body.is_some() {
                if self.continue_body(cx)? {
                    continue;
                }
                break;
            }
            if self.closing || self.read_pos >= self.read_len {
                break;
            }
            if !self.can_parse() {
                self.paused = true;
                break;
            }
            let id = request_id(cx.index, *cx.sequence);
            let parsed = parse_request(
                &self.read_buf[self.read_pos..self.read_len],
                id,
                &self.peer,
                cx.out,
                *cx.used,
                cx.limits,
                cx.now,
            );
            match parsed {
                HeadParse::Incomplete => break,
                HeadParse::Reject(status) => self.reject(status, cx.date_line),
                HeadParse::NoRoom(size) => return Err(NeedsRoom(size)),
                HeadParse::Complete { used, info } => {
                    self.read_pos += used;
                    *cx.used += RecordHead::read(&cx.out[*cx.used..]).record_len();
                    self.closing = info.close;
                    self.upgrading = info.websocket_key.is_some();
                    self.push_slot(info, cx);
                }
                HeadParse::BodyFollows {
                    used,
                    mut body,
                    send_continue,
                } => {
                    self.read_pos += used;
                    let first = self.slots.is_empty();
                    if cx.limits.stream_request_bodies {
                        *cx.used += RecordHead::read(&cx.out[*cx.used..]).record_len();
                        self.streaming_body = Some(id);
                        body.set_streaming();
                        let info = body.request_info();
                        self.closing = info.close;
                        self.push_slot(info, cx);
                    }
                    self.body = Some(body);
                    if send_continue && first {
                        // Only with no earlier answer due, so it never lands
                        // inside one; else the client sends after its wait.
                        self.write_buf
                            .extend_from_slice(b"HTTP/1.1 100 Continue\r\n\r\n");
                    }
                }
            }
        }
        if self.eof
            && !self.closing
            && self.body.is_none()
            && self.read_pos < self.read_len
            && self.slots.is_empty()
        {
            // The client closed in the middle of a request.
            self.read_pos = self.read_len;
        }
        Ok(())
    }

    /// Feeds the body being read. Returns whether parsing goes on.
    fn continue_body(&mut self, cx: &mut ParseContext<'_>) -> Result<bool, NeedsRoom> {
        let Some(body) = self.body.as_mut() else {
            return Ok(false);
        };
        let before = self.read_pos;
        let progress = body.feed(&self.read_buf[..self.read_len], &mut self.read_pos);
        if let Some(id) = self.streaming_body {
            let bytes = body.take_chunk();
            if !bytes.is_empty() {
                cx.outbox.push(id, InboundKind::RequestBody, 0, &bytes);
            }
            match progress {
                BodyProgress::More if !self.eof => {
                    if self.read_pos > before {
                        body.touch(cx.now);
                    }
                    return Ok(false);
                }
                BodyProgress::More => self.end_streaming_body(cx.outbox, 400),
                BodyProgress::Reject(status) => self.end_streaming_body(cx.outbox, status),
                BodyProgress::Whole => {
                    self.end_streaming_body(cx.outbox, 0);
                    return Ok(true);
                }
            }
            return Ok(false);
        }
        match progress {
            BodyProgress::More => {
                if self.read_pos > before {
                    body.touch(cx.now);
                }
                Ok(false)
            }
            BodyProgress::Reject(status) => {
                self.reject(status, cx.date_line);
                Ok(false)
            }
            BodyProgress::Whole => {
                let Some(body) = self.body.take() else {
                    return Ok(false);
                };
                let id = request_id(cx.index, *cx.sequence);
                match body.into_record(id, &mut cx.out[*cx.used..]) {
                    Ok((written, info)) => {
                        *cx.used += written;
                        self.closing |= info.close;
                        self.push_slot(info, cx);
                        Ok(true)
                    }
                    Err((body, size)) => {
                        self.body = Some(body);
                        Err(NeedsRoom(size))
                    }
                }
            }
        }
    }

    /// Ends the current streamed request body, retaining its response slot.
    pub fn end_streaming_body(&mut self, outbox: &mut Outbox, status: u16) {
        if let Some(id) = self.streaming_body.take() {
            self.body = None;
            self.closing |= status != 0;
            outbox.push(id, InboundKind::RequestBodyEnd, status, b"");
            if self.closing && self.slots.is_empty() {
                self.shut = true;
            }
        }
    }

    fn push_slot(&mut self, request: RequestInfo, cx: &mut ParseContext<'_>) {
        self.slots.push_back(PendingAnswer {
            sequence: *cx.sequence,
            request,
            ..PendingAnswer::default()
        });
        *cx.sequence = cx.sequence.wrapping_add(1);
        self.idle_since = cx.now;
    }

    /// The next due time of this connection, and what is due then.
    #[must_use]
    pub fn due(&self, limits: &Limits) -> Option<(Instant, Due)> {
        if let Some((since, _)) = self.linger {
            return Some((since + LINGER, Due::Linger));
        }
        if let Some(since) = self.websocket.as_ref().and_then(|ws| ws.closing_since) {
            return Some((since + CLOSE_WAIT, Due::WebSocketClose));
        }
        if let Some(body) = &self.body
            && !body.is_whole()
        {
            return Some((body.last_progress() + limits.body_timeout, Due::Body));
        }
        if let Some(since) = self.stuck_since {
            return Some((since + SEND_WAIT, Due::Send));
        }
        if let Some(at) = self.websocket.as_ref().and_then(|ws| ws.ping_due) {
            return Some((at, Due::WebSocketPing));
        }
        if self.websocket.is_some() || self.body.is_some() {
            return None;
        }
        if self.slots.is_empty() && self.pending() == 0 {
            return Some((self.idle_since + limits.idle_timeout, Due::Head));
        }
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn request_ids_pack_index_and_sequence() {
        assert_eq!(request_id(3, 7), (3 << 32) | 7);
    }
}
