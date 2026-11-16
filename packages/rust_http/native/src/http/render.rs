//! Writes answer heads and bodies.

use std::io::Write;
use std::time::{SystemTime, UNIX_EPOCH};

/// How an answer must be framed for its request.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct AnswerFraming {
    /// The request was HTTP/1.0.
    pub http10: bool,
    /// The request was `HEAD`: no body goes out.
    pub is_head: bool,
    /// Close the connection after this answer.
    pub close: bool,
    /// Dart's header lines already contain `connection: close`.
    pub lines_say_close: bool,
}

/// How the length of an answer body is declared.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BodyLength {
    /// `content-length: n`.
    Exact(usize),
    /// `transfer-encoding: chunked`.
    Chunked,
    /// No length header: the body ends with the connection, or Dart wrote
    /// `content-length` itself.
    Open,
    /// No body and no length (a `101`).
    None,
}

/// Whether `status` never has a body (RFC 9110 6.4.1).
#[must_use]
pub fn status_has_no_body(status: u16) -> bool {
    status < 200 || status == 204 || status == 304
}

/// Writes a status line, header lines and the blank line.
pub fn render_head(
    out: &mut Vec<u8>,
    status: u16,
    lines: &[u8],
    extra_lines: &[u8],
    date_line: &[u8],
    framing: AnswerFraming,
    length: BodyLength,
) {
    let status = if (100..=999).contains(&status) {
        status
    } else {
        500
    };
    out.extend_from_slice(if framing.http10 {
        b"HTTP/1.0 "
    } else {
        b"HTTP/1.1 "
    });
    let _ = write!(out, "{status} {}\r\n", reason_phrase(status));
    out.extend_from_slice(lines);
    out.extend_from_slice(extra_lines);
    if !status_has_no_body(status) {
        match length {
            BodyLength::Exact(n) => {
                let _ = write!(out, "content-length: {n}\r\n");
            }
            BodyLength::Chunked => out.extend_from_slice(b"transfer-encoding: chunked\r\n"),
            BodyLength::Open | BodyLength::None => {}
        }
    }
    out.extend_from_slice(date_line);
    if framing.close && !framing.lines_say_close {
        out.extend_from_slice(b"connection: close\r\n");
    } else if framing.http10 && !framing.close {
        out.extend_from_slice(b"connection: keep-alive\r\n");
    }
    out.extend_from_slice(b"\r\n");
}

/// Writes a whole answer with `body`.
pub fn render_answer(
    out: &mut Vec<u8>,
    status: u16,
    lines: &[u8],
    body: &[u8],
    date_line: &[u8],
    framing: AnswerFraming,
) {
    render_head(
        out,
        status,
        lines,
        b"",
        date_line,
        framing,
        BodyLength::Exact(body.len()),
    );
    if !status_has_no_body(status) && !framing.is_head {
        out.extend_from_slice(body);
    }
}

/// Writes one part of a streamed body, chunk framed when `chunked`.
pub fn render_part(out: &mut Vec<u8>, part: &[u8], chunked: bool) {
    if part.is_empty() {
        return;
    }
    if chunked {
        let _ = write!(out, "{:x}\r\n", part.len());
    }
    out.extend_from_slice(part);
    if chunked {
        out.extend_from_slice(b"\r\n");
    }
}

/// The last chunk of a chunked body.
pub const LAST_CHUNK: &[u8] = b"0\r\n\r\n";

/// The `date` header line, rebuilt at most once a second.
#[derive(Debug, Default)]
pub struct DateLine {
    second: u64,
    line: Vec<u8>,
}

impl DateLine {
    /// Refreshes the line for the current time.
    pub fn update(&mut self) {
        let now = SystemTime::now();
        let second = now.duration_since(UNIX_EPOCH).map_or(0, |d| d.as_secs());
        if second != self.second || self.line.is_empty() {
            self.second = second;
            self.line = format!("date: {}\r\n", httpdate::fmt_http_date(now)).into_bytes();
        }
    }

    /// The current line, `date: ...\r\n`.
    #[must_use]
    pub fn bytes(&self) -> &[u8] {
        &self.line
    }
}

/// The reason phrase of a status code (RFC 9110 section 15).
#[must_use]
pub fn reason_phrase(status: u16) -> &'static str {
    match status {
        100 => "Continue",
        101 => "Switching Protocols",
        200 => "OK",
        201 => "Created",
        202 => "Accepted",
        203 => "Non-Authoritative Information",
        204 => "No Content",
        205 => "Reset Content",
        206 => "Partial Content",
        300 => "Multiple Choices",
        301 => "Moved Permanently",
        302 => "Found",
        303 => "See Other",
        304 => "Not Modified",
        307 => "Temporary Redirect",
        308 => "Permanent Redirect",
        400 => "Bad Request",
        401 => "Unauthorized",
        402 => "Payment Required",
        403 => "Forbidden",
        404 => "Not Found",
        405 => "Method Not Allowed",
        406 => "Not Acceptable",
        407 => "Proxy Authentication Required",
        408 => "Request Timeout",
        409 => "Conflict",
        410 => "Gone",
        411 => "Length Required",
        412 => "Precondition Failed",
        413 => "Payload Too Large",
        414 => "URI Too Long",
        415 => "Unsupported Media Type",
        416 => "Range Not Satisfiable",
        417 => "Expectation Failed",
        421 => "Misdirected Request",
        422 => "Unprocessable Entity",
        426 => "Upgrade Required",
        428 => "Precondition Required",
        429 => "Too Many Requests",
        431 => "Request Header Fields Too Large",
        451 => "Unavailable For Legal Reasons",
        500 => "Internal Server Error",
        501 => "Not Implemented",
        502 => "Bad Gateway",
        503 => "Service Unavailable",
        504 => "Gateway Timeout",
        505 => "HTTP Version Not Supported",
        _ => "",
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn text(bytes: &[u8]) -> String {
        String::from_utf8_lossy(bytes).into_owned()
    }

    #[test]
    fn an_answer_has_its_length_and_body() {
        let mut out = Vec::new();
        render_answer(
            &mut out,
            200,
            b"x: y\r\n",
            b"hi",
            b"date: d\r\n",
            AnswerFraming::default(),
        );
        assert_eq!(
            text(&out),
            "HTTP/1.1 200 OK\r\nx: y\r\ncontent-length: 2\r\ndate: d\r\n\r\nhi"
        );
    }

    #[test]
    fn no_body_statuses_and_head_requests_send_no_body() {
        let mut out = Vec::new();
        render_answer(&mut out, 204, b"", b"x", b"", AnswerFraming::default());
        assert_eq!(text(&out), "HTTP/1.1 204 No Content\r\n\r\n");
        let mut out = Vec::new();
        let head = AnswerFraming {
            is_head: true,
            ..AnswerFraming::default()
        };
        render_answer(&mut out, 200, b"", b"x", b"", head);
        assert_eq!(text(&out), "HTTP/1.1 200 OK\r\ncontent-length: 1\r\n\r\n");
    }

    #[test]
    fn connection_headers_follow_the_framing() {
        let mut out = Vec::new();
        let http10 = AnswerFraming {
            http10: true,
            ..AnswerFraming::default()
        };
        render_head(&mut out, 200, b"", b"", b"", http10, BodyLength::Open);
        assert!(text(&out).contains("connection: keep-alive"));
        let mut out = Vec::new();
        let said = AnswerFraming {
            close: true,
            lines_say_close: true,
            ..AnswerFraming::default()
        };
        render_head(
            &mut out,
            200,
            b"connection: close\r\n",
            b"",
            b"",
            said,
            BodyLength::Open,
        );
        assert_eq!(text(&out).matches("connection").count(), 1);
    }

    #[test]
    fn an_invalid_status_becomes_500() {
        let mut out = Vec::new();
        render_head(
            &mut out,
            42,
            b"",
            b"",
            b"",
            AnswerFraming::default(),
            BodyLength::None,
        );
        assert!(text(&out).starts_with("HTTP/1.1 500 Internal Server Error"));
    }

    #[test]
    fn parts_are_chunk_framed() {
        let mut out = Vec::new();
        render_part(&mut out, &[b'a'; 17], true);
        assert!(text(&out).starts_with("11\r\n"));
        assert!(text(&out).ends_with("\r\n"));
    }
}
