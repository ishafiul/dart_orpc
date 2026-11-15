//! Random bytes as one request: the parser never panics, and a record it
//! writes is consistent with what `httparse` reads from the same bytes.
#![no_main]

use std::time::{Duration, Instant};

use libfuzzer_sys::fuzz_target;
use rust_http::http::head::{HeadParse, parse_request};
use rust_http::limits::Limits;
use rust_http::protocol::request_record::{HEAD_LEN, RecordHead, free_external_body};

fuzz_target!(|data: &[u8]| {
    let limits = Limits {
        body: 64,
        multipart: 128,
        body_timeout: Duration::from_secs(1),
        idle_timeout: Duration::from_secs(1),
        max_connections: 0,
    };
    let mut out = vec![0u8; 64 * 1024];
    let parsed = parse_request(data, 1, &[0; 18], &mut out, 0, &limits, Instant::now());
    if let HeadParse::Complete { used, .. } = parsed {
        assert!(used <= data.len());
        let head = RecordHead::read(&out);
        assert!(head.record_len() <= out.len());
        let mut headers = [httparse::EMPTY_HEADER; 128];
        let mut request = httparse::Request::new(&mut headers);
        assert!(matches!(request.parse(data), Ok(httparse::Status::Complete(_))));
        let method = request.method.unwrap_or_default().as_bytes();
        assert_eq!(&out[HEAD_LEN..HEAD_LEN + method.len()], method);
        assert_eq!(head.headers_len as usize, request.headers.iter().map(|h| 4 + h.name.len() + h.value.len()).sum::<usize>());
        free_external_body(&out);
    }
});
