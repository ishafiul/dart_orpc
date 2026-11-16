//! A chunked body fed whole and in random pieces gives the same result.
#![no_main]

use std::time::Instant;

use libfuzzer_sys::fuzz_target;
use rust_http::http::body::{BodyProgress, BodyReader};
use rust_http::http::head::RequestInfo;

fn feed(body: &[u8], cuts: &[usize]) -> (BodyProgress, usize) {
    let mut reader = BodyReader::new(Vec::new(), RequestInfo::default(), true, 0, 1 << 16, 0, Instant::now());
    let mut buffer = Vec::new();
    let mut pos = 0;
    let mut progress = BodyProgress::More;
    let mut start = 0;
    for &cut in cuts.iter().chain(std::iter::once(&body.len())) {
        let end = cut.clamp(start, body.len());
        buffer.extend_from_slice(&body[start..end]);
        start = end;
        progress = reader.feed(&buffer, &mut pos);
        if progress != BodyProgress::More {
            break;
        }
    }
    (progress, pos)
}

fuzz_target!(|data: &[u8]| {
    let Some((&seed, body)) = data.split_first() else { return };
    let mut cuts: Vec<usize> = body
        .iter()
        .step_by(usize::from(seed % 7) + 1)
        .map(|&b| usize::from(b) * body.len() / 256)
        .collect();
    cuts.sort_unstable();
    assert_eq!(feed(body, &[]), feed(body, &cuts));
});
