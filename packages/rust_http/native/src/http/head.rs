//! Parses a request head and decides how its body is framed.
//!
//! The framing rules follow RFC 9112 section 6 and refuse every ambiguity
//! that could smuggle a request: two different lengths, a length and
//! chunked together, `Transfer-Encoding` in HTTP/1.0 or twice, and any
//! coding other than `chunked`.

use std::io::Write;
use std::mem::MaybeUninit;
use std::time::Instant;

use crate::limits::{DRAIN_MAX, EXTERNAL_MIN, Limits, MAX_HEAD, MAX_HEADERS, MAX_RESERVE};
use crate::protocol::kinds::request_flags;
use crate::protocol::request_record::{HEAD_LEN, Peer, RecordHead, header_entry_len, write_names};

use super::body::BodyReader;
use super::{has_token, parse_length};

/// What a request needs from its answer.
#[derive(Debug, Default, Clone, PartialEq, Eq)]
pub struct RequestInfo {
    /// Close the connection after the answer.
    pub close: bool,
    /// The method is `HEAD`: the answer has no body.
    pub is_head: bool,
    /// The request is HTTP/1.0.
    pub http10: bool,
    /// The `Sec-WebSocket-Key` of a valid upgrade request.
    pub websocket_key: Option<Box<[u8]>>,
}

/// The result of parsing the bytes of one request.
#[derive(Debug)]
pub enum HeadParse {
    /// The head is not complete yet.
    Incomplete,
    /// A bad request: answer with this status and close.
    Reject(u16),
    /// The record does not fit in Dart's buffer; it needs this many bytes.
    NoRoom(usize),
    /// The whole request was written as a record.
    Complete {
        /// Bytes of the input used.
        used: usize,
        /// What the answer needs.
        info: RequestInfo,
    },
    /// The head was read; the body arrives separately.
    BodyFollows {
        /// Bytes of the input used (the head).
        used: usize,
        /// Reads the body.
        body: Box<BodyReader>,
        /// Answer `100 Continue` before the body.
        send_continue: bool,
    },
}

/// What the headers say about framing and upgrades.
#[derive(Default)]
struct HeaderFacts<'a> {
    close_token: bool,
    keep_alive_token: bool,
    content_length: Option<usize>,
    chunked: bool,
    expect_continue: bool,
    multipart: bool,
    connection_upgrade: bool,
    upgrade_websocket: bool,
    version_13: bool,
    version_count: u32,
    key: Option<&'a [u8]>,
    key_count: u32,
    headers_len: usize,
}

impl<'a> HeaderFacts<'a> {
    /// Collects the facts, or the status to reject the request with.
    fn collect(headers: &[httparse::Header<'a>], http10: bool) -> Result<Self, u16> {
        let mut facts = Self::default();
        for header in headers {
            facts.headers_len += header_entry_len(header.name, header.value);
            let name = header.name.as_bytes();
            let value = header.value;
            // The first byte picks the few names that matter, so most
            // headers cost one compare.
            match name.first().map(u8::to_ascii_lowercase) {
                Some(b'c') if name.eq_ignore_ascii_case(b"content-length") => {
                    match parse_length(value).and_then(|v| usize::try_from(v).ok()) {
                        Some(length) if facts.content_length.is_none_or(|c| c == length) => {
                            facts.content_length = Some(length);
                        }
                        _ => return Err(400),
                    }
                }
                Some(b'c') if name.eq_ignore_ascii_case(b"connection") => {
                    // `close` anywhere wins over `keep-alive` (RFC 9112 9.3).
                    facts.close_token |= has_token(value, "close");
                    facts.keep_alive_token |= !facts.close_token && has_token(value, "keep-alive");
                    facts.connection_upgrade |= has_token(value, "upgrade");
                }
                Some(b'c') if name.eq_ignore_ascii_case(b"content-type") => {
                    // The last `content-type` decides the body limit.
                    let mime = value.split(|&c| c == b';').next().unwrap_or_default();
                    facts.multipart = mime
                        .trim_ascii()
                        .eq_ignore_ascii_case(b"multipart/form-data");
                }
                Some(b't') if name.eq_ignore_ascii_case(b"transfer-encoding") => {
                    if http10 || facts.chunked {
                        return Err(400);
                    }
                    if !value.trim_ascii().eq_ignore_ascii_case(b"chunked") {
                        return Err(501);
                    }
                    facts.chunked = true;
                }
                Some(b'e') if name.eq_ignore_ascii_case(b"expect") => {
                    facts.expect_continue |=
                        value.trim_ascii().eq_ignore_ascii_case(b"100-continue");
                }
                Some(b'u') if name.eq_ignore_ascii_case(b"upgrade") => {
                    facts.upgrade_websocket |= has_token(value, "websocket");
                }
                Some(b's') if name.eq_ignore_ascii_case(b"sec-websocket-version") => {
                    facts.version_13 = value.trim_ascii() == b"13";
                    facts.version_count += 1;
                }
                Some(b's') if name.eq_ignore_ascii_case(b"sec-websocket-key") => {
                    facts.key = Some(value.trim_ascii());
                    facts.key_count += 1;
                }
                _ => {}
            }
        }
        if facts.chunked && facts.content_length.is_some() {
            return Err(400);
        }
        Ok(facts)
    }

    /// A valid WebSocket upgrade (RFC 6455 4.2.1): version and key once.
    fn is_websocket_upgrade(&self, method: &[u8], http10: bool) -> bool {
        let has_body = self.chunked || self.content_length.unwrap_or(0) > 0;
        method == b"GET"
            && !http10
            && !has_body
            && self.connection_upgrade
            && self.upgrade_websocket
            && self.version_13
            && self.version_count == 1
            && self.key_count == 1
            && self.key.is_some_and(is_valid_websocket_key)
    }
}

/// Parses one request from `data` and writes its record to `out[at..]`.
#[must_use]
pub fn parse_request(
    data: &[u8],
    id: u64,
    peer: &Peer,
    out: &mut [u8],
    at: usize,
    limits: &Limits,
    now: Instant,
) -> HeadParse {
    let mut storage = [const { MaybeUninit::<httparse::Header>::uninit() }; MAX_HEADERS];
    let mut request = httparse::Request::new(&mut []);
    let head_len = match request.parse_with_uninit_headers(data, &mut storage) {
        Ok(httparse::Status::Complete(len)) if len > MAX_HEAD => return HeadParse::Reject(431),
        Ok(httparse::Status::Complete(len)) => len,
        Ok(httparse::Status::Partial) if data.len() > MAX_HEAD => return HeadParse::Reject(431),
        Ok(httparse::Status::Partial) => return HeadParse::Incomplete,
        Err(httparse::Error::TooManyHeaders) => return HeadParse::Reject(431),
        Err(_) => return HeadParse::Reject(400),
    };
    let http10 = request.version == Some(0);
    let facts = match HeaderFacts::collect(request.headers, http10) {
        Ok(facts) => facts,
        Err(status) => return HeadParse::Reject(status),
    };
    let method = request.method.unwrap_or_default().as_bytes();
    let raw_target = request.path.unwrap_or_default().as_bytes();
    let escaped;
    let target = if raw_target.is_ascii() {
        raw_target
    } else {
        escaped = escape_target(raw_target);
        &escaped[..]
    };
    let upgrade = facts.is_websocket_upgrade(method, http10);
    let info = RequestInfo {
        close: facts.close_token || (http10 && !facts.keep_alive_token),
        is_head: method == b"HEAD",
        http10,
        websocket_key: upgrade.then(|| facts.key.map(Box::from)).flatten(),
    };
    let mut flags = 0;
    if http10 {
        flags |= request_flags::HTTP10;
    }
    if upgrade {
        flags |= request_flags::WEBSOCKET_UPGRADE;
    }
    let content_length = facts.content_length.unwrap_or(0);
    let max = limits.body_for(facts.multipart);
    if content_length > max
        && (facts.expect_continue || content_length > max.saturating_add(DRAIN_MAX))
    {
        // Too big, and the client waits for our go (or would send far too
        // much): refuse at once.
        return HeadParse::Reject(413);
    }
    let mut head = RecordHead::request(flags, method.len(), target.len(), facts.headers_len, peer);
    let names_len = HEAD_LEN + method.len() + target.len() + facts.headers_len;
    let whole = !facts.chunked && data.len() >= head_len + content_length;
    if whole && content_length < EXTERNAL_MIN && content_length <= max {
        // The common case: the whole request is here.
        let size = names_len + content_length;
        if out.len() - at < size {
            return HeadParse::NoRoom(size);
        }
        let record = &mut out[at..at + size];
        head.id = id;
        head.body_len = u32::try_from(content_length).unwrap_or(u32::MAX);
        head.write(record);
        write_names(&mut record[HEAD_LEN..], method, target, request.headers);
        record[names_len..].copy_from_slice(&data[head_len..head_len + content_length]);
        return HeadParse::Complete {
            used: head_len + content_length,
            info,
        };
    }
    // The body arrives separately: keep the record prefix until it is whole.
    let mut prefix = vec![0; names_len];
    head.write(&mut prefix);
    write_names(&mut prefix[HEAD_LEN..], method, target, request.headers);
    let reserve = if facts.chunked {
        0
    } else {
        content_length.min(MAX_RESERVE).min(max)
    };
    let body = BodyReader::new(
        prefix,
        info,
        facts.chunked,
        content_length,
        max,
        reserve,
        now,
    );
    let more = facts.chunked || data.len() < head_len + content_length;
    HeadParse::BodyFollows {
        used: head_len,
        body: Box::new(body),
        send_continue: facts.expect_continue && more,
    }
}

/// A `Sec-WebSocket-Key` is base64 of 16 bytes: 22 base64 characters,
/// then `==` (RFC 6455 4.2.1).
#[must_use]
pub fn is_valid_websocket_key(key: &[u8]) -> bool {
    key.len() == 24
        && key.ends_with(b"==")
        && key[..22]
            .iter()
            .all(|&c| c.is_ascii_alphanumeric() || c == b'+' || c == b'/')
}

/// Escapes bytes over 0x7f as `%XX`. Dart reads the target as ASCII and
/// `Uri` decodes `%XX` as UTF-8.
#[must_use]
pub fn escape_target(target: &[u8]) -> Vec<u8> {
    let mut out = Vec::with_capacity(target.len() * 3);
    for &c in target {
        if c.is_ascii() {
            out.push(c);
        } else {
            let _ = write!(out, "%{c:02X}");
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::Duration;

    fn limits() -> Limits {
        Limits {
            body: 10,
            multipart: 20,
            body_timeout: Duration::from_millis(50),
            idle_timeout: Duration::from_secs(30),
            max_connections: 0,
        }
    }

    fn parse(request: &[u8]) -> HeadParse {
        let mut out = vec![0; 4096];
        parse_request(request, 1, &[0; 18], &mut out, 0, &limits(), Instant::now())
    }

    fn info(request: &[u8]) -> RequestInfo {
        match parse(request) {
            HeadParse::Complete { info, .. } => info,
            other => panic!("not complete: {other:?}"),
        }
    }

    fn rejected(request: &[u8]) -> Option<u16> {
        match parse(request) {
            HeadParse::Reject(status) => Some(status),
            _ => None,
        }
    }

    #[test]
    fn a_whole_request_becomes_one_record() {
        let mut out = vec![0; 256];
        let request = b"POST /x HTTP/1.1\r\nHost: a\r\nContent-Length: 2\r\n\r\nhi";
        let parsed = parse_request(request, 9, &[0; 18], &mut out, 0, &limits(), Instant::now());
        let HeadParse::Complete { used, .. } = parsed else {
            panic!("{parsed:?}")
        };
        assert_eq!(used, request.len());
        let head = RecordHead::read(&out);
        assert_eq!(head.id, 9);
        assert_eq!(&out[head.body_offset()..head.record_len()], b"hi");
    }

    #[test]
    fn framing_ambiguities_are_refused() {
        assert_eq!(
            rejected(b"POST / HTTP/1.1\r\nContent-Length: 1\r\nContent-Length: 2\r\n\r\n"),
            Some(400)
        );
        assert_eq!(
            rejected(b"POST / HTTP/1.1\r\nContent-Length: 1\r\nTransfer-Encoding: chunked\r\n\r\n"),
            Some(400)
        );
        assert_eq!(
            rejected(b"POST / HTTP/1.0\r\nTransfer-Encoding: chunked\r\n\r\n"),
            Some(400)
        );
        assert_eq!(
            rejected(b"POST / HTTP/1.1\r\nTransfer-Encoding: chunked\r\nTransfer-Encoding: chunked\r\n\r\n"),
            Some(400)
        );
        assert_eq!(
            rejected(b"POST / HTTP/1.1\r\nTransfer-Encoding: gzip\r\n\r\n"),
            Some(501)
        );
        assert_eq!(
            rejected(b"POST / HTTP/1.1\r\nContent-Length: +5\r\n\r\n"),
            Some(400)
        );
        assert_eq!(rejected(b"garbage\r\n\r\n"), Some(400));
    }

    #[test]
    fn equal_duplicate_lengths_are_fine() {
        assert_eq!(
            rejected(b"POST / HTTP/1.1\r\nContent-Length: 1\r\nContent-Length: 1\r\n\r\nx"),
            None
        );
    }

    #[test]
    fn heads_over_the_limit_get_431() {
        let long = format!("GET / HTTP/1.1\r\nx: {}\r\n\r\n", "a".repeat(MAX_HEAD));
        assert_eq!(rejected(long.as_bytes()), Some(431));
        let many = (0..=MAX_HEADERS).fold(String::new(), |mut all, i| {
            use std::fmt::Write as _;
            let _ = write!(all, "h{i}: v\r\n");
            all
        });
        assert_eq!(
            rejected(format!("GET / HTTP/1.1\r\n{many}\r\n").as_bytes()),
            Some(431)
        );
    }

    #[test]
    fn connection_close_wins_over_keep_alive() {
        assert!(info(b"GET / HTTP/1.1\r\nConnection: close, keep-alive\r\n\r\n").close);
        assert!(
            info(b"GET / HTTP/1.1\r\nConnection: keep-alive\r\nConnection: close\r\n\r\n").close
        );
        assert!(info(b"GET / HTTP/1.0\r\n\r\n").close);
        assert!(!info(b"GET / HTTP/1.0\r\nConnection: keep-alive\r\n\r\n").close);
        assert!(!info(b"GET / HTTP/1.1\r\n\r\n").close);
    }

    #[test]
    fn websocket_upgrades_need_one_version_and_one_valid_key() {
        let upgrade = |extra: &str| {
            let request = format!(
                "GET / HTTP/1.1\r\nConnection: Upgrade\r\nUpgrade: websocket\r\n{extra}\r\n"
            );
            info(request.as_bytes()).websocket_key.is_some()
        };
        let key = "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n";
        assert!(upgrade(&format!("Sec-WebSocket-Version: 13\r\n{key}")));
        assert!(!upgrade(&format!(
            "Sec-WebSocket-Version: 13\r\n{key}{key}"
        )));
        assert!(!upgrade(&format!(
            "Sec-WebSocket-Version: 13\r\nSec-WebSocket-Version: 13\r\n{key}"
        )));
        assert!(!upgrade(&format!("Sec-WebSocket-Version: 8\r\n{key}")));
        assert!(!upgrade(
            "Sec-WebSocket-Version: 13\r\nSec-WebSocket-Key: short==\r\n"
        ));
    }

    #[test]
    fn websocket_keys_are_16_bytes_of_base64() {
        assert!(is_valid_websocket_key(b"dGhlIHNhbXBsZSBub25jZQ=="));
        assert!(!is_valid_websocket_key(b"dGhlIHNhbXBsZSBub25jZQ="));
        assert!(!is_valid_websocket_key(b"dGhlIHNhbXBsZSBub25jZ!=="));
    }

    #[test]
    fn only_multipart_forms_get_the_multipart_limit() {
        let body = "x".repeat(15);
        let form = format!(
            "POST / HTTP/1.1\r\nContent-Type: multipart/form-data; boundary=b\r\nContent-Length: 15\r\n\r\n{body}"
        );
        assert!(matches!(parse(form.as_bytes()), HeadParse::Complete { .. }));
        let json = format!(
            "POST / HTTP/1.1\r\nContent-Type: application/json\r\nContent-Length: 15\r\n\r\n{body}"
        );
        assert!(matches!(
            parse(json.as_bytes()),
            HeadParse::BodyFollows { .. }
        ));
    }

    #[test]
    fn a_too_big_body_with_expect_continue_gets_413_at_once() {
        assert_eq!(
            rejected(b"POST / HTTP/1.1\r\nExpect: 100-continue\r\nContent-Length: 11\r\n\r\n"),
            Some(413)
        );
    }

    #[test]
    fn raw_bytes_in_the_target_are_escaped() {
        assert_eq!(escape_target("/é".as_bytes()), b"/%C3%A9");
    }

    #[test]
    fn a_partial_head_waits() {
        assert!(matches!(
            parse(b"GET / HTTP/1.1\r\nHost"),
            HeadParse::Incomplete
        ));
    }
}
