//! The server loop. It runs on the thread of the Dart isolate.
//!
//! Dart calls `rust_http_run` (a non-leaf FFI call) in a loop. One call:
//! 1. writes the answers Dart gives (response records),
//! 2. runs the timers that are due (408, lingering close, WebSocket waits),
//! 3. accepts, reads and parses new requests into Dart's buffer, plus the
//!    WebSocket and stream messages for Dart.
//!
//! Per connection:
//! - Answers go out in request order. At most [`MAX_INFLIGHT`] requests
//!   wait for answers and at most [`MAX_PENDING`] answer bytes wait to be
//!   written; then Rust stops reading that connection.
//! - Each connection gets one turn per call; a WebSocket reads at most
//!   [`WS_READ`] bytes per turn, so one busy client cannot hold the
//!   isolate.
//! - When Rust closes a connection after an answer, it shuts its own side,
//!   then drops what the client still sends for up to [`LINGER`]
//!   ("lingering close"), so the client does not lose the last answer to
//!   a reset.
//!
//! [`MAX_INFLIGHT`]: crate::limits::MAX_INFLIGHT
//! [`MAX_PENDING`]: crate::limits::MAX_PENDING
//! [`LINGER`]: crate::limits::LINGER

use std::cmp::Reverse;
use std::collections::{BinaryHeap, HashMap, VecDeque};
use std::io::{ErrorKind, Read};
use std::net::Shutdown;
use std::sync::Arc;
use std::time::{Duration, Instant};

use bytes::Bytes;
use mio::net::TcpListener;
use mio::{Events, Interest, Poll, Token, Waker};
use slab::Slab;
use tungstenite::protocol::frame::coding::CloseCode;
use tungstenite::protocol::{CloseFrame, Role, WebSocketConfig, WebSocketContext};
use tungstenite::{Error as WsError, Message, Utf8Bytes};

use crate::compress::{CompressJob, Compressor};
use crate::connection::{Connection, Due, NeedsRoom, ParseContext, StreamTail};
use crate::http::parse_length;
use crate::http::render::{
    AnswerFraming, BodyLength, DateLine, LAST_CHUNK, render_answer, render_head, render_part,
};
use crate::limits::{
    ACCEPT_RETRY, LINGER_MAX, Limits, READ_ROOM, WS_HOLD, WS_OUT_MAX, WS_READ, WS_UNACKED,
};
use crate::listener::{self, ListenAddress, ListenerSource, peer_bytes};
use crate::protocol::kinds::{InboundKind, OutboundKind};
use crate::protocol::outbox::Outbox;
use crate::protocol::response_record::{ResponseRecord, ResponseRecords};
use crate::websocket::{ABNORMAL_CLOSURE, SocketIo, WebSocketState, close_frame, close_parts};

/// Poll token of the listening socket.
const LISTENER: Token = Token(0);
/// Poll token of the waker.
const WAKER: Token = Token(usize::MAX);

/// All socket state of one server. Only the owner of its mutex touches it.
pub struct EventLoop {
    poll: Poll,
    events: Events,
    listener: Option<Acceptor>,
    address: ListenAddress,
    released: bool,
    connections: Slab<Connection>,
    /// Connections that may have bytes to read or requests to parse.
    ready: VecDeque<usize>,
    /// The listener may have connections to accept.
    accept_pending: bool,
    /// The listener is not registered: accepts are tried on every turn.
    poll_accepts: bool,
    /// Accept again at this time (after an error or at the limit).
    accept_retry_at: Option<Instant>,
    sequence: u32,
    limits: Limits,
    date: DateLine,
    now: Instant,
    /// One live entry per connection, see [`Connection::timer`].
    timers: BinaryHeap<Reverse<(Instant, usize)>>,
    outbox: Outbox,
    /// Open streamed bodies: stream id to (connection, request sequence).
    streams: HashMap<u64, (usize, u32)>,
    /// WebSocket id to connection.
    websockets: HashMap<u64, usize>,
    /// WebSockets that stopped reading until Dart acknowledges.
    paused_websockets: Vec<usize>,
    draining: bool,
    drained_reported: bool,
    /// The server stops: no lingering close.
    stopped: bool,
    waker: Arc<Waker>,
    compressor: Compressor,
    /// The read buffer lent to each connection in turn.
    scratch: Vec<u8>,
    dead: Vec<usize>,
    touched: Vec<usize>,
}

impl EventLoop {
    /// A loop over a bound listener.
    ///
    /// An owned socket is watched by this loop's poller. A socket shared
    /// with other loops ([`ListenerSource::Shared`], Windows) is not: the
    /// loop tries a non-blocking accept on every turn instead, and the idle
    /// helper does the same every [`SHARED_ACCEPT_POLL`].
    ///
    /// # Errors
    /// When the poller or its waker cannot be created.
    pub fn new(
        source: ListenerSource,
        address: ListenAddress,
        limits: Limits,
    ) -> std::io::Result<Self> {
        let poll = Poll::new()?;
        let waker = Arc::new(Waker::new(poll.registry(), WAKER)?);
        let listener = Acceptor::new(source, &poll)?;
        let poll_accepts = listener.is_polled();
        Ok(Self {
            poll,
            events: Events::with_capacity(1024),
            listener: Some(listener),
            address,
            released: false,
            connections: Slab::with_capacity(1024),
            ready: VecDeque::new(),
            accept_pending: true,
            poll_accepts,
            accept_retry_at: None,
            sequence: 0,
            limits,
            date: DateLine::default(),
            now: Instant::now(),
            timers: BinaryHeap::new(),
            outbox: Outbox::default(),
            streams: HashMap::new(),
            websockets: HashMap::new(),
            paused_websockets: Vec::new(),
            draining: false,
            drained_reported: false,
            stopped: false,
            compressor: Compressor::new(waker.clone()),
            waker,
            scratch: Vec::new(),
            dead: Vec::new(),
            touched: Vec::new(),
        })
    }

    /// The waker of the poller.
    #[must_use]
    pub fn waker(&self) -> Arc<Waker> {
        self.waker.clone()
    }

    /// The bound port.
    #[must_use]
    pub fn port(&self) -> u16 {
        self.address.port
    }

    /// The poll file descriptor, watched by the idle helper.
    #[cfg(unix)]
    #[must_use]
    pub fn poll_fd(&self) -> i32 {
        use std::os::fd::AsRawFd;
        self.poll.as_raw_fd()
    }

    /// Refreshes the clock and the date line.
    pub fn update_clock(&mut self) {
        self.now = Instant::now();
        self.date.update();
    }

    /// One turn for Dart: writes `answers`, then fills `inbox`. Waits up to
    /// `budget` for requests when none came.
    ///
    /// # Errors
    /// [`NeedsRoom`] when one record is bigger than all of `inbox`.
    pub fn run(
        &mut self,
        answers: &[u8],
        inbox: &mut [u8],
        budget: Duration,
    ) -> Result<usize, NeedsRoom> {
        self.update_clock();
        if self.poll_accepts {
            self.accept_pending = true;
        }
        self.take_compressed();
        if !answers.is_empty() {
            self.respond(answers);
        }
        self.run_timers();
        self.wait(Some(Duration::ZERO));
        let mut got = self.fill(inbox);
        if matches!(got, Ok(0)) && !budget.is_zero() {
            let mut wait = if self.ready.is_empty() {
                budget
            } else {
                Duration::ZERO
            };
            if let Some(at) = self.next_timer() {
                wait = wait.min(at.saturating_duration_since(self.now));
            }
            self.wait(Some(wait));
            self.update_clock();
            self.run_timers();
            got = self.fill(inbox);
        }
        got
    }

    /// Whether accepts are polled; see [`EventLoop::new`].
    #[must_use]
    pub fn polls_accepts(&self) -> bool {
        self.poll_accepts
    }

    /// Accepts waiting connections now when accepts are polled. Returns
    /// whether Dart has work afterwards.
    pub fn accept_polled(&mut self) -> bool {
        if self.poll_accepts && self.listener.is_some() {
            self.accept_all();
        }
        self.has_work()
    }

    /// Whether Dart has something to do.
    #[must_use]
    pub fn has_work(&self) -> bool {
        !self.ready.is_empty()
            || self.accept_pending
            || !self.outbox.is_empty()
            // A finished gzip job wakes the poller, and on Windows the idle
            // helper consumes that wake-up: the job itself must count.
            || self.compressor.has_done()
    }

    /// The time of the next timer, if any.
    #[must_use]
    pub fn next_timer(&self) -> Option<Instant> {
        let timer = self.timers.peek().map(|entry| entry.0.0);
        match (timer, self.accept_retry_at) {
            (Some(a), Some(b)) => Some(a.min(b)),
            (a, b) => a.or(b),
        }
    }

    /// Starts a graceful shutdown: no new connections, each connection
    /// closes after its current answer. Upgraded sockets belong to the app.
    pub fn start_drain(&mut self) {
        self.draining = true;
        self.close_listener();
        let all: Vec<usize> = self.connections.iter().map(|(index, _)| index).collect();
        for index in all {
            let connection = &mut self.connections[index];
            connection.closing = true;
            if connection.websocket.is_none()
                && connection.slots.is_empty()
                && connection.body.is_none()
            {
                connection.shut = true;
            }
            self.service(index);
        }
        self.kill_dead();
    }

    /// True once, after a graceful shutdown is over: every connection is
    /// closed or only lingers, and Dart has all messages.
    pub fn take_drained(&mut self) -> bool {
        if self.draining
            && !self.drained_reported
            && self.outbox.is_empty()
            && self
                .connections
                .iter()
                .all(|(_, c)| c.linger.is_some() || c.is_live_websocket())
        {
            self.drained_reported = true;
            return true;
        }
        false
    }

    /// Stops the loop: closes the listener and every connection now.
    pub fn stop(&mut self) {
        self.stopped = true;
        self.close_listener();
        self.connections.clear();
        self.compressor.stop();
    }

    /// Waits up to `timeout` for events and handles them. Returns whether
    /// any event came.
    pub fn wait(&mut self, timeout: Option<Duration>) -> bool {
        if self.poll.poll(&mut self.events, timeout).is_err() {
            return false;
        }
        let mut any = false;
        let events = std::mem::replace(&mut self.events, Events::with_capacity(0));
        for event in &events {
            any = true;
            match event.token() {
                LISTENER => self.accept_pending = true,
                WAKER => {}
                Token(token) => {
                    let index = token - 1;
                    let Some(connection) = self.connections.get(index) else {
                        continue;
                    };
                    let readable =
                        event.is_readable() || event.is_read_closed() || event.is_error();
                    let paused = connection.paused
                        || connection.websocket.as_ref().is_some_and(|ws| ws.paused);
                    if readable && !paused {
                        self.queue(index);
                    }
                    if event.is_writable() && self.connections[index].pending() > 0 {
                        self.service(index);
                    }
                }
            }
        }
        self.events = events;
        self.kill_dead();
        any
    }

    // ---- connections ----------------------------------------------------

    fn close_listener(&mut self) {
        if let Some(Acceptor::Watched(mut listener)) = self.listener.take() {
            let _ = self.poll.registry().deregister(&mut listener);
        }
        self.accept_pending = false;
        self.accept_retry_at = None;
        if !self.released {
            self.released = true;
            listener::release(self.address);
        }
    }

    fn queue(&mut self, index: usize) {
        if let Some(connection) = self.connections.get_mut(index)
            && !connection.queued
        {
            connection.queued = true;
            self.ready.push_back(index);
        }
    }

    fn touch(&mut self, index: usize) {
        if let Some(connection) = self.connections.get_mut(index)
            && !connection.touched
        {
            connection.touched = true;
            self.touched.push(index);
        }
    }

    /// Closes a connection now and tells Dart about its streams and
    /// WebSocket.
    fn kill(&mut self, index: usize) {
        let Some(mut connection) = self.connections.try_remove(index) else {
            return;
        };
        let _ = self.poll.registry().deregister(&mut connection.socket);
        connection.end_streaming_body(&mut self.outbox, 400);
        for slot in &connection.slots {
            if let Some((stream, _)) = slot.stream
                && self.streams.remove(&stream).is_some()
            {
                self.outbox.push(stream, InboundKind::StreamGone, 0, b"");
            }
        }
        if let Some(ws) = connection.websocket {
            self.websockets.remove(&ws.id);
            if !ws.told_dart {
                let (code, reason) = ws.close_status.unwrap_or((ABNORMAL_CLOSURE, Vec::new()));
                self.outbox
                    .push(ws.id, InboundKind::WebSocketClosed, code, &reason);
            }
        }
    }

    fn kill_dead(&mut self) {
        while let Some(index) = self.dead.pop() {
            self.kill(index);
        }
    }

    fn flush_touched(&mut self) {
        while let Some(index) = self.touched.pop() {
            if let Some(connection) = self.connections.get_mut(index) {
                connection.touched = false;
                connection.advance_slots();
                self.service(index);
            }
        }
        self.kill_dead();
    }

    // ---- timers -----------------------------------------------------------

    /// Makes sure the timer of `index` fires by its next due time.
    fn arm_timer(&mut self, index: usize) {
        let limits = self.limits;
        let now = self.now;
        let Some(connection) = self.connections.get_mut(index) else {
            return;
        };
        let at = connection
            .due(&limits)
            .map_or(now + limits.idle_timeout, |due| due.0);
        if connection.timer.is_none_or(|timer| at < timer) {
            connection.timer = Some(at);
            self.timers.push(Reverse((at, index)));
        }
    }

    fn run_timers(&mut self) {
        let now = self.now;
        if self.accept_retry_at.is_some_and(|at| at <= now) {
            self.accept_retry_at = None;
            self.accept_pending = true;
        }
        while let Some(&Reverse((at, index))) = self.timers.peek() {
            if at > now {
                break;
            }
            self.timers.pop();
            let limits = self.limits;
            let Some(connection) = self.connections.get_mut(index) else {
                continue;
            };
            if connection.timer != Some(at) {
                continue; // a stale entry
            }
            connection.timer = None;
            if let Some((due_at, what)) = connection.due(&limits)
                && due_at <= now
            {
                match what {
                    Due::Body => {
                        if connection.streaming_body.is_some() {
                            connection.end_streaming_body(&mut self.outbox, 408);
                        } else {
                            connection.reject(408, self.date.bytes());
                        }
                        self.service(index);
                    }
                    Due::WebSocketPing => self.websocket_ping(index),
                    _ => self.kill(index),
                }
            }
            self.arm_timer(index);
        }
    }

    // ---- accept and read --------------------------------------------------

    fn accept_all(&mut self) {
        self.accept_pending = false;
        loop {
            let Some(listener) = &self.listener else {
                return;
            };
            if self.limits.max_connections > 0
                && self.connections.len() >= self.limits.max_connections
            {
                self.accept_retry_at = Some(self.now + ACCEPT_RETRY);
                return;
            }
            match listener.accept() {
                Ok((mut socket, address)) => {
                    let _ = socket.set_nodelay(true);
                    let entry = self.connections.vacant_entry();
                    let index = entry.key();
                    if self
                        .poll
                        .registry()
                        .register(
                            &mut socket,
                            Token(index + 1),
                            Interest::READABLE | Interest::WRITABLE,
                        )
                        .is_err()
                    {
                        continue;
                    }
                    let mut connection = Connection::new(socket, peer_bytes(address), self.now);
                    // The request is often there already.
                    connection.queued = true;
                    entry.insert(connection);
                    self.ready.push_back(index);
                    self.arm_timer(index);
                }
                Err(e) if e.kind() == ErrorKind::WouldBlock => return,
                Err(e) if e.kind() == ErrorKind::Interrupted => {}
                Err(_) => {
                    // E.g. too many open files: retry soon, do not spin.
                    self.accept_retry_at = Some(self.now + ACCEPT_RETRY);
                    return;
                }
            }
        }
    }

    /// Accepts, reads and parses into `inbox`, then adds the messages for
    /// Dart. Returns the bytes written.
    fn fill(&mut self, inbox: &mut [u8]) -> Result<usize, NeedsRoom> {
        if self.accept_pending {
            self.accept_all();
        }
        let mut used = 0;
        // One turn per connection per call; one queued again in this call
        // waits for the next, so Dart gets the others' requests first.
        let mut turns = self.ready.len();
        while turns > 0
            && let Some(&index) = self.ready.front()
        {
            turns -= 1;
            let Some(connection) = self.connections.get_mut(index) else {
                self.ready.pop_front();
                continue;
            };
            if connection.linger.is_some() {
                connection.queued = false;
                self.ready.pop_front();
                self.linger_read(index);
                continue;
            }
            if connection.is_live_websocket() {
                connection.queued = false;
                self.ready.pop_front();
                self.websocket_read(index);
                continue;
            }
            if connection.body.is_none() && (connection.closing || !connection.can_parse()) {
                connection.queued = false;
                self.ready.pop_front();
                if !connection.closing {
                    connection.paused = true; // read on once answers go out
                    continue;
                }
                // A closing connection reads no more requests: drop them.
                let borrowed = connection.borrow_scratch(&mut self.scratch);
                let ok = connection.read();
                connection.read_pos = connection.read_len;
                connection.return_scratch(&mut self.scratch, borrowed);
                if !ok || connection.is_finished() {
                    self.kill(index);
                }
                continue;
            }
            let borrowed = connection.borrow_scratch(&mut self.scratch);
            if !connection.read() {
                connection.return_scratch(&mut self.scratch, borrowed);
                self.ready.pop_front();
                self.kill(index);
                continue;
            }
            let parsed = connection.parse(&mut ParseContext {
                index,
                out: inbox,
                outbox: &mut self.outbox,
                used: &mut used,
                sequence: &mut self.sequence,
                limits: &self.limits,
                date_line: self.date.bytes(),
                now: self.now,
            });
            connection.return_scratch(&mut self.scratch, borrowed);
            if let Err(needs) = parsed {
                // Stays queued for the next call.
                if used == 0 {
                    return Err(needs);
                }
                break;
            }
            let connection = &mut self.connections[index];
            connection.queued = false;
            self.ready.pop_front();
            if connection
                .body
                .as_ref()
                .is_some_and(|body| body.last_progress() == self.now)
            {
                self.arm_timer(index);
            }
            self.service(index);
        }
        self.kill_dead();
        let moved = self.outbox.drain_into(&mut inbox[used..]);
        if moved == 0
            && used == 0
            && let Some(size) = self.outbox.first_len()
        {
            return Err(NeedsRoom(size));
        }
        Ok(used + moved)
    }

    /// Drops what a closing client still sends.
    fn linger_read(&mut self, index: usize) {
        let connection = &mut self.connections[index];
        let mut sink = [0u8; 16 * 1024];
        loop {
            match (&connection.socket).read(&mut sink) {
                Ok(0) => return self.kill(index),
                Ok(read) => {
                    let dropped = connection.linger.as_mut().map_or(0, |linger| {
                        linger.1 += read;
                        linger.1
                    });
                    if dropped > LINGER_MAX {
                        return self.kill(index);
                    }
                }
                Err(e) if e.kind() == ErrorKind::WouldBlock => return,
                Err(e) if e.kind() == ErrorKind::Interrupted => {}
                Err(_) => return self.kill(index),
            }
        }
    }

    /// Reads WebSocket frames; messages go to Dart.
    fn websocket_read(&mut self, index: usize) {
        let connection = &mut self.connections[index];
        let Connection {
            websocket,
            socket,
            write_buf,
            write_pos,
            ..
        } = connection;
        let Some(ws) = websocket.as_mut() else { return };
        let mut io = SocketIo {
            socket,
            out: write_buf,
            read_budget: WS_READ,
        };
        let mut read_again = false;
        let ending = loop {
            if self.outbox.unacked_websocket_bytes() > WS_UNACKED {
                // Dart is behind: read on after its ack.
                ws.paused = true;
                self.paused_websockets.push(index);
                break None;
            }
            if io.out.len() - *write_pos > WS_OUT_MAX {
                // The client does not read (e.g. pongs): read on once written.
                ws.paused = true;
                break None;
            }
            match ws.context.read(&mut io) {
                Ok(Message::Text(text)) => {
                    self.outbox
                        .push(ws.id, InboundKind::WebSocketText, 0, text.as_bytes());
                }
                Ok(Message::Binary(data)) => {
                    self.outbox
                        .push(ws.id, InboundKind::WebSocketBinary, 0, &data);
                }
                // The peer's close, or its answer to ours; tungstenite replies.
                Ok(Message::Close(frame)) => {
                    if ws.close_status.is_none() {
                        ws.close_status = Some(close_parts(frame));
                    }
                }
                Ok(Message::Pong(data)) if data.is_empty() && ws.awaiting_pong => {
                    ws.awaiting_pong = false;
                    ws.ping_due = ws.ping_interval.map(|interval| self.now + interval);
                }
                Ok(_) => {} // tungstenite answers pings itself
                Err(WsError::Io(e)) if e.kind() == ErrorKind::WouldBlock => {
                    read_again = io.read_budget == 0;
                    break None;
                }
                Err(WsError::Io(e)) if e.kind() == ErrorKind::Interrupted => {}
                Err(WsError::ConnectionClosed | WsError::AlreadyClosed) => break Some(None),
                Err(WsError::Capacity(_)) => break Some(Some(CloseCode::Size)),
                Err(WsError::Utf8(_)) => break Some(Some(CloseCode::Invalid)),
                Err(WsError::Protocol(
                    tungstenite::error::ProtocolError::ResetWithoutClosingHandshake,
                )) => {
                    return self.kill(index);
                }
                Err(WsError::Protocol(_)) => break Some(Some(CloseCode::Protocol)),
                Err(_) => return self.kill(index),
            }
        };
        match ending {
            None => {}
            // The close handshake is over: close once the last frame is out.
            Some(None) => connection.shut = true,
            // The client broke the protocol: send `code` and close.
            Some(Some(code)) => {
                if let Some(ws) = connection.websocket.as_mut() {
                    ws.close_status = Some((u16::from(code), Vec::new()));
                    let mut io = SocketIo {
                        socket: &connection.socket,
                        out: &mut connection.write_buf,
                        read_budget: 0,
                    };
                    let _ = ws.context.close(&mut io, close_frame(code));
                }
                connection.shut = true;
            }
        }
        self.service(index);
        if read_again {
            self.queue(index);
        }
    }

    // ---- write ----------------------------------------------------------

    /// After a change to a connection: switches to the WebSocket, hands it
    /// queued messages, writes, starts the lingering close or closes it,
    /// and queues it again when it can read on.
    #[allow(clippy::too_many_lines)]
    fn service(&mut self, index: usize) {
        let now = self.now;
        let Some(connection) = self.connections.get_mut(index) else {
            return;
        };
        if connection.switch_to_websocket {
            connection.switch_to_websocket = false;
            let early = connection.read_buf[connection.read_pos..connection.read_len].to_vec();
            connection.read_pos = 0;
            connection.read_len = 0;
            connection.read_buf = Vec::new();
            if let Some(ws) = connection.websocket.as_mut() {
                let config = WebSocketConfig::default()
                    .max_message_size(Some(ws.max_message))
                    .max_frame_size(Some(ws.max_message))
                    .read_buffer_size(READ_ROOM)
                    .write_buffer_size(0);
                ws.context =
                    WebSocketContext::from_partially_read(early, Role::Server, Some(config));
                ws.live = true;
            }
            connection.paused = false;
            connection.queued = true;
            self.ready.push_back(index);
        }
        let connection = &mut self.connections[index];
        let mut websocket_timer_started = false;
        if connection.is_live_websocket() {
            let Connection {
                websocket,
                socket,
                write_buf,
                write_pos,
                ..
            } = connection;
            if let Some(ws) = websocket.as_mut() {
                while write_buf.len() - *write_pos < WS_HOLD
                    && ws.closing_since.is_none()
                    && let Some(message) = ws.queue.pop_front()
                {
                    ws.queued_bytes = ws.queued_bytes.saturating_sub(message.len());
                    let mut io = SocketIo {
                        socket,
                        out: &mut *write_buf,
                        read_budget: 0,
                    };
                    if let Message::Close(frame) = message {
                        let _ = ws.context.close(&mut io, frame);
                        ws.closing_since = Some(now);
                        ws.queue.clear();
                        ws.queued_bytes = 0;
                        websocket_timer_started = true;
                    } else {
                        if matches!(message, Message::Ping(_)) {
                            ws.awaiting_pong = true;
                            ws.ping_due = ws.ping_interval.map(|interval| now + interval);
                            websocket_timer_started = true;
                        }
                        let _ = ws.context.write(&mut io, message);
                    }
                }
            }
        }
        let before = connection.written;
        if connection.pending() > 0 && !connection.flush() {
            self.kill(index);
            return;
        }
        let wait_starts = connection.stuck_since.is_none() && connection.pending() > 0;
        while let Some(&(end, stream, count)) = connection.stream_marks.front() {
            if end > connection.written {
                break;
            }
            connection.stream_marks.pop_front();
            self.outbox
                .push(stream, InboundKind::StreamSent, 0, &count.to_le_bytes());
        }
        if connection.pending() == 0 {
            connection.stuck_since = None;
            if connection.written > before && connection.slots.is_empty() {
                // The last answer is out: the idle time starts now.
                connection.idle_since = now;
            }
        } else if connection.written > before || connection.stuck_since.is_none() {
            connection.stuck_since = Some(now);
        }
        if connection.pending() == 0
            && connection.is_live_websocket()
            && connection
                .websocket
                .as_ref()
                .is_some_and(|ws| !ws.queue.is_empty())
        {
            return self.service(index);
        }
        let mut read_on = false;
        if connection.paused
            && (connection.body.is_some() || (!connection.closing && connection.can_parse()))
            && connection.linger.is_none()
            && !connection.is_live_websocket()
        {
            connection.paused = false;
            read_on = true;
        }
        let pending = connection.pending();
        if let Some(ws) = connection.websocket.as_mut()
            && ws.paused
            && pending < WS_HOLD
            && self.outbox.unacked_websocket_bytes() <= WS_UNACKED
        {
            ws.paused = false;
            read_on = true;
        }
        let mut linger_starts = false;
        if connection.pending() == 0 && connection.shut && connection.linger.is_none() {
            if self.stopped || connection.websocket.is_some() {
                self.kill(index);
                return;
            }
            let _ = connection.socket.shutdown(Shutdown::Write);
            connection.linger = Some((now, 0));
            connection.paused = false;
            linger_starts = true;
            read_on = true;
        } else if connection.is_finished() {
            self.kill(index);
            return;
        }
        if read_on {
            self.queue(index);
        }
        if linger_starts || websocket_timer_started || wait_starts {
            self.arm_timer(index);
        }
    }

    // ---- records from Dart ----------------------------------------------

    /// Handles the records Dart wrote.
    fn respond(&mut self, answers: &[u8]) {
        for record in ResponseRecords::new(answers) {
            match record.kind {
                OutboundKind::Answer
                | OutboundKind::WebSocketAccept
                | OutboundKind::StreamStart => {
                    self.answer(&record);
                }
                OutboundKind::WebSocketText
                | OutboundKind::WebSocketBinary
                | OutboundKind::WebSocketClose => {
                    self.websocket_send(&record);
                }
                OutboundKind::WebSocketAck => self.acknowledge(record.id),
                OutboundKind::WebSocketPingInterval => self.websocket_ping_interval(&record),
                OutboundKind::StreamPart => self.stream_part(record.id, record.body, false, true),
                OutboundKind::StreamEnd => {
                    self.stream_part(record.id, b"", true, record.status == 0);
                }
            }
        }
        self.flush_touched();
    }

    fn acknowledge(&mut self, bytes: u64) {
        let before = self.outbox.unacked_websocket_bytes();
        self.outbox
            .acknowledge(usize::try_from(bytes).unwrap_or(usize::MAX));
        if before > WS_UNACKED && self.outbox.unacked_websocket_bytes() <= WS_UNACKED {
            for index in std::mem::take(&mut self.paused_websockets) {
                if let Some(ws) = self
                    .connections
                    .get_mut(index)
                    .and_then(|c| c.websocket.as_mut())
                {
                    ws.paused = false;
                    self.queue(index);
                }
            }
        }
    }

    /// Finds the unanswered slot of request `id`.
    fn slot_of(&self, id: u64) -> Option<(usize, usize)> {
        let index = usize::try_from(id >> 32).ok()?;
        let sequence = (id & 0xffff_ffff) as u32;
        let connection = self.connections.get(index)?;
        let first = connection.slots.front()?.sequence;
        let position = sequence.wrapping_sub(first) as usize;
        let slot = connection.slots.get(position)?;
        (slot.sequence == sequence && !slot.answered).then_some((index, position))
    }

    /// An answer for a request: whole, a WebSocket accept or streamed.
    fn answer(&mut self, record: &ResponseRecord<'_>) {
        let Some((index, position)) = self.slot_of(record.id) else {
            // The client is gone, or a second answer: tell Dart to stop.
            match record.kind {
                OutboundKind::WebSocketAccept => {
                    if let Some(ws) = record.body_word(0) {
                        self.outbox
                            .push(ws, InboundKind::WebSocketClosed, ABNORMAL_CLOSURE, b"");
                    }
                }
                OutboundKind::StreamStart => {
                    if let Some(stream) = record.body_word(0) {
                        self.outbox.push(stream, InboundKind::StreamGone, 0, b"");
                    }
                }
                _ => {}
            }
            return;
        };
        let connection = &mut self.connections[index];
        // The last answer of a closing connection (e.g. a shutdown) says so.
        let last = connection.closing
            && position + 1 == connection.slots.len()
            && connection.body.is_none();
        let slot = &mut connection.slots[position];
        slot.answered = true;
        slot.request.close |= last && slot.request.websocket_key.is_none();
        if record.says_close() {
            slot.request.close = true;
            connection.closing = true;
            if record.kind == OutboundKind::Answer {
                connection.end_streaming_body(&mut self.outbox, 0);
            }
        }
        let slot = &mut connection.slots[position];
        let mut framing = slot.framing();
        framing.lines_say_close = record.says_close();
        match record.kind {
            OutboundKind::Answer
                if record.gzip() && !framing.is_head && !record.body.is_empty() =>
            {
                let job = CompressJob {
                    connection: index,
                    sequence: slot.sequence,
                    status: record.status,
                    lines: record.lines.to_vec(),
                    body: record.body.to_vec(),
                    date_line: self.date.bytes().to_vec(),
                    framing,
                };
                self.compressor.submit(job);
                return;
            }
            OutboundKind::Answer => {
                slot.done = true;
                let target = if position == 0 {
                    &mut connection.write_buf
                } else {
                    &mut slot.out
                };
                render_answer(
                    target,
                    record.status,
                    record.lines,
                    record.body,
                    self.date.bytes(),
                    framing,
                );
            }
            OutboundKind::WebSocketAccept => {
                self.accept_websocket(index, position, record, framing);
            }
            _ => self.start_stream(index, position, record, framing),
        }
        self.touch(index);
    }

    fn accept_websocket(
        &mut self,
        index: usize,
        position: usize,
        record: &ResponseRecord<'_>,
        framing: AnswerFraming,
    ) {
        let date = self.date.bytes();
        let connection = &mut self.connections[index];
        let slot = &mut connection.slots[position];
        slot.done = true;
        let key = slot.request.websocket_key.take();
        let (Some(key), Some(ws_id), Some(max)) = (key, record.body_word(0), record.body_word(1))
        else {
            // Dart accepted a request that cannot upgrade.
            let mut out = Vec::new();
            render_answer(&mut out, 400, b"", b"", date, framing);
            connection.put(position, &out, 0);
            if let Some(ws_id) = record.body_word(0) {
                self.outbox
                    .push(ws_id, InboundKind::WebSocketClosed, ABNORMAL_CLOSURE, b"");
            }
            return;
        };
        slot.upgrade = true;
        let max = usize::try_from(max.min(u64::from(u32::MAX))).unwrap_or(usize::MAX);
        let accept = tungstenite::handshake::derive_accept_key(&key);
        let extra = format!(
            "upgrade: websocket\r\nconnection: Upgrade\r\nsec-websocket-accept: {accept}\r\n"
        );
        let mut out = Vec::new();
        render_head(
            &mut out,
            101,
            record.lines,
            extra.as_bytes(),
            date,
            framing,
            BodyLength::None,
        );
        connection.put(position, &out, 0);
        connection.websocket = Some(Box::new(WebSocketState::new(ws_id, max)));
        self.websockets.insert(ws_id, index);
    }

    fn start_stream(
        &mut self,
        index: usize,
        position: usize,
        record: &ResponseRecord<'_>,
        mut framing: AnswerFraming,
    ) {
        let date = self.date.bytes();
        let connection = &mut self.connections[index];
        let slot = &mut connection.slots[position];
        let Some(stream) = record.body_word(0) else {
            slot.done = true;
            return;
        };
        let first = &record.body[8..];
        // Dart writes `content-length` itself when it knows it. Rust counts
        // the bytes: a wrong count closes the connection, so the rest can
        // not look like the next answer.
        let (length, tail) = match declared_length(record.lines) {
            _ if framing.is_head => (BodyLength::Open, StreamTail::Close),
            DeclaredLength::Exact(count) => (BodyLength::Open, StreamTail::Remaining(count)),
            DeclaredLength::Absent if !framing.http10 => (BodyLength::Chunked, StreamTail::Chunked),
            // An unreadable length, or HTTP/1.0: the close ends the body.
            DeclaredLength::Absent | DeclaredLength::Invalid => {
                framing.close = true;
                slot.request.close = true;
                (BodyLength::Open, StreamTail::Close)
            }
        };
        let mut out = Vec::new();
        render_head(
            &mut out,
            record.status,
            record.lines,
            b"",
            date,
            framing,
            length,
        );
        if framing.is_head {
            slot.done = true;
            connection.put(position, &out, 0);
            self.outbox.push(stream, InboundKind::StreamGone, 0, b"");
            return;
        }
        let sequence = slot.sequence;
        slot.stream = Some((stream, tail));
        connection.put(position, &out, 0);
        self.streams.insert(stream, (index, sequence));
        self.touch(index);
        self.stream_part(stream, first, false, true);
    }

    /// A part, or the end, of the streamed body `stream`.
    fn stream_part(&mut self, stream: u64, data: &[u8], end: bool, ok: bool) {
        let Some(&(index, sequence)) = self.streams.get(&stream) else {
            return;
        };
        let Some(connection) = self.connections.get_mut(index) else {
            return;
        };
        let Some(position) = connection
            .slots
            .iter()
            .position(|slot| slot.sequence == sequence)
        else {
            return;
        };
        let Some((_, tail)) = connection.slots[position].stream else {
            return;
        };
        let (mut data, mut end, mut ok) = (data, end, ok);
        if let StreamTail::Remaining(left) = tail {
            let count = data.len() as u64;
            if count > left {
                // More than declared: send what was declared, then cut.
                data = &data[..usize::try_from(left).unwrap_or(0)];
                (end, ok) = (true, false);
                self.outbox.push(stream, InboundKind::StreamGone, 0, b"");
            } else if end && count < left {
                ok = false; // too few: the client sees a short body
            }
            connection.slots[position].stream =
                Some((stream, StreamTail::Remaining(left.saturating_sub(count))));
        }
        let chunked = tail == StreamTail::Chunked;
        let mut out = Vec::new();
        render_part(&mut out, data, chunked);
        if end {
            self.streams.remove(&stream);
            let slot = &mut connection.slots[position];
            slot.done = true;
            if !ok {
                slot.request.close = true;
            } else if chunked {
                out.extend_from_slice(LAST_CHUNK);
            }
        }
        connection.put(position, &out, data.len() as u64);
        self.touch(index);
    }

    fn websocket_ping_interval(&mut self, record: &ResponseRecord<'_>) {
        let (Some(&index), Some(milliseconds)) =
            (self.websockets.get(&record.id), record.body_word(0))
        else {
            return;
        };
        if let Some(ws) = self.connections[index].websocket.as_mut() {
            let interval = Duration::from_millis(milliseconds).min(crate::limits::MAX_TIMEOUT);
            ws.ping_interval = (!interval.is_zero()).then_some(interval);
            ws.ping_due = ws.ping_interval.map(|interval| self.now + interval);
            ws.awaiting_pong = false;
            ws.queue
                .retain(|message| !matches!(message, Message::Ping(_)));
        }
        self.arm_timer(index);
    }

    fn websocket_ping(&mut self, index: usize) {
        let connection = &mut self.connections[index];
        let Some(ws) = connection.websocket.as_mut() else {
            return;
        };
        if ws.awaiting_pong {
            ws.ping_due = None;
            ws.queue.clear();
            ws.queued_bytes = 0;
            ws.queue
                .push_back(Message::Close(close_frame(CloseCode::Away)));
            if connection.pending() > 0 {
                self.kill(index);
                return;
            }
            connection.shut = true;
        } else {
            ws.ping_due = None;
            ws.queue.push_front(Message::Ping(Bytes::new()));
        }
        self.service(index);
    }

    /// A message or the close from Dart for a WebSocket.
    fn websocket_send(&mut self, record: &ResponseRecord<'_>) {
        let id = record.id;
        let Some(&index) = self.websockets.get(&id) else {
            return;
        };
        let Some(ws) = self
            .connections
            .get_mut(index)
            .and_then(|c| c.websocket.as_mut())
        else {
            return;
        };
        if ws.told_dart || ws.closing_since.is_some() {
            return;
        }
        let message = match record.kind {
            OutboundKind::WebSocketText => match Utf8Bytes::try_from(record.body.to_vec()) {
                Ok(text) => Message::Text(text),
                Err(_) => return, // Dart always sends UTF-8
            },
            OutboundKind::WebSocketBinary => Message::Binary(Bytes::copy_from_slice(record.body)),
            _ => Message::Close((record.status != 0).then(|| {
                CloseFrame {
                    code: CloseCode::from(record.status),
                    reason: Utf8Bytes::try_from(record.body.to_vec())
                        .unwrap_or_else(|_| Utf8Bytes::from_static("")),
                }
            })),
        };
        if !matches!(message, Message::Close(_)) && ws.queued_bytes + message.len() > ws.queue_cap {
            // The client reads too slowly: close with 1008, drop the queue.
            ws.queue.clear();
            ws.queued_bytes = 0;
            ws.close_status = Some((1008, Vec::new()));
            ws.told_dart = true;
            self.outbox
                .push(id, InboundKind::WebSocketClosed, 1008, b"");
            let connection = &mut self.connections[index];
            if connection.is_live_websocket() && connection.pending() > 0 {
                self.dead.push(index);
                return;
            }
            if let Some(ws) = connection.websocket.as_mut() {
                ws.queue
                    .push_back(Message::Close(close_frame(CloseCode::Policy)));
            }
            connection.shut = true;
        } else {
            ws.queued_bytes += message.len();
            ws.queue.push_back(message);
        }
        self.touch(index);
    }

    /// Puts finished gzip jobs in their slots.
    fn take_compressed(&mut self) {
        for answer in self.compressor.take_done() {
            let Some(connection) = self.connections.get_mut(answer.connection) else {
                continue;
            };
            let Some(position) = connection
                .slots
                .iter()
                .position(|slot| slot.sequence == answer.sequence)
            else {
                continue;
            };
            connection.slots[position].done = true;
            connection.put(position, &answer.bytes, 0);
            self.touch(answer.connection);
        }
        self.flush_touched();
    }
}

/// Where a loop accepts connections from.
enum Acceptor {
    /// A socket watched by the loop's poller.
    Watched(TcpListener),
    /// A socket shared with other loops, accepted from directly.
    #[cfg(windows)]
    Polled(Arc<std::net::TcpListener>),
}

impl Acceptor {
    fn new(source: ListenerSource, poll: &Poll) -> std::io::Result<Self> {
        match source {
            ListenerSource::Owned(listener) => {
                let mut listener = TcpListener::from_std(listener);
                poll.registry()
                    .register(&mut listener, LISTENER, Interest::READABLE)?;
                Ok(Self::Watched(listener))
            }
            #[cfg(windows)]
            ListenerSource::Shared(listener) => Ok(Self::Polled(listener)),
        }
    }

    /// Whether accepts must be polled, as no event announces them.
    fn is_polled(&self) -> bool {
        match self {
            Self::Watched(_) => false,
            #[cfg(windows)]
            Self::Polled(_) => true,
        }
    }

    fn accept(&self) -> std::io::Result<(mio::net::TcpStream, std::net::SocketAddr)> {
        match self {
            Self::Watched(listener) => listener.accept(),
            #[cfg(windows)]
            Self::Polled(listener) => {
                let (stream, address) = listener.accept()?;
                stream.set_nonblocking(true)?;
                Ok((mio::net::TcpStream::from_std(stream), address))
            }
        }
    }
}

/// What Dart's header lines say about the body length.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum DeclaredLength {
    /// No `content-length` line.
    Absent,
    /// A `content-length` that is not a number.
    Invalid,
    /// `content-length: n`.
    Exact(u64),
}

/// Finds the `content-length` among Dart's header lines.
fn declared_length(lines: &[u8]) -> DeclaredLength {
    let found = lines.split(|&c| c == b'\n').find_map(|line| {
        let colon = line.iter().position(|&c| c == b':')?;
        line[..colon]
            .trim_ascii()
            .eq_ignore_ascii_case(b"content-length")
            .then(|| parse_length(&line[colon + 1..]))
    });
    match found {
        None => DeclaredLength::Absent,
        Some(None) => DeclaredLength::Invalid,
        Some(Some(length)) => DeclaredLength::Exact(length),
    }
}

#[cfg(test)]
mod tests;
