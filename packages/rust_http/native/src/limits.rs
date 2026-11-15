//! Limits of the server. Each one keeps a slow or hostile peer from making
//! memory or time grow without bound.

use std::time::Duration;

/// Max size of a request line plus headers. Bigger gets 431.
pub const MAX_HEAD: usize = 16 * 1024;
/// Max number of request headers. More gets 431.
pub const MAX_HEADERS: usize = 100;
/// Max length of a chunk size line. Longer gets 400.
pub const MAX_CHUNK_LINE: usize = 1024;
/// Bytes a too big body may still send before the connection is closed,
/// so the client reads the 413 instead of a reset.
pub const DRAIN_MAX: usize = 64 * 1024 * 1024;
/// Most memory reserved up front for a body. `Content-Length` comes from
/// the client, so a bigger body grows the buffer only as bytes arrive.
pub const MAX_RESERVE: usize = 64 * 1024;
/// A body this big or bigger moves to Dart without a copy.
pub const EXTERNAL_MIN: usize = 64 * 1024;
/// Free room kept in a read buffer before a read.
pub const READ_ROOM: usize = 16 * 1024;
/// Most requests of one connection that wait for an answer.
pub const MAX_INFLIGHT: usize = 64;
/// Most answer bytes of one connection waiting to be written before Rust
/// stops reading that connection.
pub const MAX_PENDING: usize = 1 << 20;
/// A write buffer this large is shrunk once written.
pub const BIG_WRITE_BUFFER: usize = 1 << 20;
/// A write buffer above this capacity is freed once empty.
pub const KEEP_WRITE_BUFFER: usize = 64 * 1024;
/// How long a closing connection drops what the client still sends.
pub const LINGER: Duration = Duration::from_secs(1);
/// Most bytes dropped during a lingering close.
pub const LINGER_MAX: usize = 1 << 20;
/// Wait before accepting again after an accept error or at the limit.
pub const ACCEPT_RETRY: Duration = Duration::from_millis(10);
/// How long a write may make no progress before the peer counts as gone.
pub const SEND_WAIT: Duration = Duration::from_secs(30);
/// How long a closing WebSocket waits for the peer's close frame.
pub const CLOSE_WAIT: Duration = Duration::from_secs(5);
/// Write bytes a WebSocket may have pending before more messages wait.
pub const WS_HOLD: usize = 64 * 1024;
/// Most bytes read from one WebSocket per turn.
pub const WS_READ: usize = 256 * 1024;
/// Pending writes (e.g. pongs) above which frames of a WebSocket are not
/// read.
pub const WS_OUT_MAX: usize = 4 * WS_HOLD;
/// The send queue of one WebSocket holds at least this many bytes.
pub const WS_MIN_QUEUE: usize = 1 << 20;
/// Client message bytes Dart may leave unacknowledged before Rust stops
/// reading WebSocket frames.
pub const WS_UNACKED: usize = 8 << 20;
/// How often the idle helper checks that the isolate is alive.
pub const PROBE: Duration = Duration::from_millis(100);
/// Upper bound for configured timeouts, so `Instant + timeout` never
/// overflows.
pub const MAX_TIMEOUT: Duration = Duration::from_secs(365 * 24 * 3600);

/// The limits Dart configures for one server.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Limits {
    /// Max bytes of a body that is not a multipart form.
    pub body: usize,
    /// Max bytes of a multipart form.
    pub multipart: usize,
    /// Max idle time between body bytes. Longer gets 408.
    pub body_timeout: Duration,
    /// Keep-alive timeout, and the time a request head may take.
    pub idle_timeout: Duration,
    /// Most open connections; 0 is no limit.
    pub max_connections: usize,
}

impl Limits {
    /// Limits from the raw values Dart passes. Negative values become 0
    /// and timeouts are capped at [`MAX_TIMEOUT`].
    #[must_use]
    pub fn from_dart(
        max_body: i64,
        max_multipart: i64,
        body_timeout_ms: i64,
        max_connections: i64,
        idle_timeout_ms: i64,
    ) -> Self {
        Self {
            body: to_usize(max_body),
            multipart: to_usize(max_multipart),
            body_timeout: millis(body_timeout_ms),
            idle_timeout: millis(idle_timeout_ms),
            max_connections: to_usize(max_connections),
        }
    }

    /// The body limit for a request.
    #[must_use]
    pub fn body_for(&self, multipart: bool) -> usize {
        if multipart { self.multipart } else { self.body }
    }
}

fn to_usize(value: i64) -> usize {
    usize::try_from(value.max(0)).unwrap_or(usize::MAX)
}

fn millis(value: i64) -> Duration {
    Duration::from_millis(u64::try_from(value.max(0)).unwrap_or(0)).min(MAX_TIMEOUT)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn negative_values_become_zero_and_timeouts_are_capped() {
        let limits = Limits::from_dart(-1, 5, i64::MAX, -3, 10);
        assert_eq!(limits.body, 0);
        assert_eq!(limits.multipart, 5);
        assert_eq!(limits.body_timeout, MAX_TIMEOUT);
        assert_eq!(limits.max_connections, 0);
        assert_eq!(limits.idle_timeout, Duration::from_millis(10));
    }

    #[test]
    fn multipart_forms_get_their_own_limit() {
        let limits = Limits::from_dart(10, 20, 0, 0, 0);
        assert_eq!(limits.body_for(false), 10);
        assert_eq!(limits.body_for(true), 20);
    }
}
