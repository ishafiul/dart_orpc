//! Reads a request body that did not arrive with its head: by length or
//! chunked, with the size limit and the drain of a too big body.

use std::time::Instant;

use crate::limits::{DRAIN_MAX, EXTERNAL_MIN, MAX_CHUNK_LINE, MAX_HEAD};
use crate::protocol::request_record::finish_with_body;

use super::head::RequestInfo;

/// What new bytes did to a body.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BodyProgress {
    /// More bytes are needed.
    More,
    /// Refuse the request with this status.
    Reject(u16),
    /// The body is whole.
    Whole,
}

/// Where a chunked body is.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum ChunkState {
    Size,
    Data(usize),
    DataEnd,
    Trailer,
}

/// A request body read apart from its head.
#[derive(Debug)]
pub struct BodyReader {
    /// The record head and names; id and body length are set at the end.
    prefix: Vec<u8>,
    info: RequestInfo,
    data: Vec<u8>,
    /// Length mode: bytes still to come.
    left: usize,
    /// Chunked mode: where the decoder is.
    chunk: Option<ChunkState>,
    max: usize,
    /// All body bytes seen, also dropped ones.
    seen: usize,
    /// Over the limit: drop the bytes and answer 413 at the end.
    too_big: bool,
    whole: bool,
    streaming: bool,
    /// When the last body bytes came, for the body timeout.
    last_progress: Instant,
}

impl BodyReader {
    /// A reader for a body of `length` bytes, or a chunked one.
    #[must_use]
    pub fn new(
        prefix: Vec<u8>,
        info: RequestInfo,
        chunked: bool,
        length: usize,
        max: usize,
        reserve: usize,
        now: Instant,
    ) -> Self {
        Self {
            prefix,
            info,
            data: Vec::with_capacity(reserve),
            left: length,
            chunk: chunked.then_some(ChunkState::Size),
            max,
            seen: 0,
            too_big: false,
            whole: false,
            streaming: false,
            last_progress: now,
        }
    }

    /// Publish parsed chunks and fail immediately at the body limit.
    pub fn set_streaming(&mut self) {
        self.streaming = true;
    }

    /// Whether the body is complete and waits for room in Dart's buffer.
    #[must_use]
    pub fn is_whole(&self) -> bool {
        self.whole
    }

    /// When the last body bytes came.
    #[must_use]
    pub fn last_progress(&self) -> Instant {
        self.last_progress
    }

    /// Records that body bytes came at `now`.
    pub fn touch(&mut self, now: Instant) {
        self.last_progress = now;
    }

    /// Size of the record once the body is whole.
    #[must_use]
    pub fn record_size(&self) -> usize {
        let body = if self.data.len() >= EXTERNAL_MIN {
            crate::native_memory::EXTERNAL_BODY_LEN
        } else {
            self.data.len()
        };
        self.prefix.len() + body
    }

    /// Writes the record into `out` with `id` and returns its length and
    /// the request info.
    ///
    /// # Errors
    /// `Err(size)` when `out` is too small; the reader is unchanged.
    pub fn into_record(
        self,
        id: u64,
        out: &mut [u8],
    ) -> Result<(usize, RequestInfo), (Box<Self>, usize)> {
        let size = self.record_size();
        if out.len() < size {
            return Err((Box::new(self), size));
        }
        let Self {
            prefix, info, data, ..
        } = self;
        let written = finish_with_body(&prefix, id, data, EXTERNAL_MIN, out).unwrap_or_default();
        Ok((written, info))
    }

    /// Takes body bytes from `buf[*pos..]` and moves `*pos` past them.
    /// `buf` is the read buffer, so a body may come in many calls.
    pub fn feed(&mut self, buf: &[u8], pos: &mut usize) -> BodyProgress {
        if self.whole {
            return BodyProgress::Whole;
        }
        if self.streaming && self.left > self.max && self.chunk.is_none() && self.seen == 0 {
            return BodyProgress::Reject(413);
        }
        loop {
            let available = &buf[*pos..];
            match self.chunk {
                None => {
                    let taken = self.take_data(available, self.left);
                    if let Err(status) = taken {
                        return BodyProgress::Reject(status);
                    }
                    let taken = taken.unwrap_or_default();
                    *pos += taken;
                    self.left -= taken;
                    if self.left > 0 {
                        return BodyProgress::More;
                    }
                    break;
                }
                Some(ChunkState::Data(want)) => {
                    let taken = match self.take_data(available, want) {
                        Ok(taken) => taken,
                        Err(status) => return BodyProgress::Reject(status),
                    };
                    *pos += taken;
                    if taken < want {
                        self.chunk = Some(ChunkState::Data(want - taken));
                        return BodyProgress::More;
                    }
                    self.chunk = Some(ChunkState::DataEnd);
                }
                Some(ChunkState::Size) => match httparse::parse_chunk_size(available) {
                    // A long line is refused also when it came whole, so the
                    // answer does not depend on how the bytes were split.
                    Ok(httparse::Status::Complete((used, _))) if used > MAX_CHUNK_LINE => {
                        return BodyProgress::Reject(400);
                    }
                    Ok(httparse::Status::Complete((used, 0))) => {
                        *pos += used;
                        self.chunk = Some(ChunkState::Trailer);
                    }
                    Ok(httparse::Status::Complete((used, size))) => {
                        *pos += used;
                        let Ok(size) = usize::try_from(size) else {
                            return BodyProgress::Reject(413);
                        };
                        self.chunk = Some(ChunkState::Data(size));
                    }
                    Ok(httparse::Status::Partial) if available.len() < MAX_CHUNK_LINE => {
                        return BodyProgress::More;
                    }
                    _ => return BodyProgress::Reject(400),
                },
                Some(ChunkState::DataEnd) => {
                    if available.len() < 2 {
                        return BodyProgress::More;
                    }
                    if &available[..2] != b"\r\n" {
                        return BodyProgress::Reject(400);
                    }
                    *pos += 2;
                    self.chunk = Some(ChunkState::Size);
                }
                Some(ChunkState::Trailer) => {
                    // No trailer is an empty line; else lines up to one.
                    if available.starts_with(b"\r\n") {
                        *pos += 2;
                        break;
                    }
                    match available.windows(4).position(|w| w == b"\r\n\r\n") {
                        Some(at) if at + 4 > MAX_HEAD => return BodyProgress::Reject(431),
                        Some(at) => {
                            *pos += at + 4;
                            break;
                        }
                        None if available.len() > MAX_HEAD => return BodyProgress::Reject(431),
                        None => return BodyProgress::More,
                    }
                }
            }
        }
        if self.too_big {
            return BodyProgress::Reject(413);
        }
        self.whole = true;
        BodyProgress::Whole
    }

    /// Takes up to `want` bytes of `available`. Over the limit the bytes
    /// are dropped; over the limit plus [`DRAIN_MAX`] the request fails.
    fn take_data(&mut self, available: &[u8], want: usize) -> Result<usize, u16> {
        let taken = want.min(available.len());
        if taken == 0 {
            return Ok(0);
        }
        self.seen += taken;
        if self.seen > self.max {
            if self.streaming || self.seen > self.max.saturating_add(DRAIN_MAX) {
                return Err(413);
            }
            self.too_big = true;
        }
        if !self.too_big {
            self.data.extend_from_slice(&available[..taken]);
        }
        Ok(taken)
    }

    /// The request metadata for the streamed head.
    #[must_use]
    pub fn request_info(&self) -> RequestInfo {
        self.info.clone()
    }

    /// Bytes decoded this turn in streaming mode.
    pub fn take_chunk(&mut self) -> Vec<u8> {
        std::mem::take(&mut self.data)
    }

    /// The body read so far. For tests.
    #[cfg(test)]
    #[must_use]
    pub fn data(&self) -> &[u8] {
        &self.data
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn chunked(max: usize) -> BodyReader {
        BodyReader::new(
            Vec::new(),
            RequestInfo::default(),
            true,
            0,
            max,
            0,
            Instant::now(),
        )
    }

    fn feed_in_pieces(body: &[u8], piece: usize) -> (BodyProgress, Vec<u8>) {
        let mut reader = chunked(1 << 20);
        let mut buf = Vec::new();
        let mut pos = 0;
        let mut progress = BodyProgress::More;
        for part in body.chunks(piece) {
            buf.extend_from_slice(part);
            progress = reader.feed(&buf, &mut pos);
            if progress != BodyProgress::More {
                break;
            }
        }
        (progress, reader.data().to_vec())
    }

    #[test]
    fn a_chunked_body_decodes_whole_or_in_pieces() {
        let body = b"5\r\nhello\r\n6;ext=1\r\n world\r\n0\r\ntrailer: x\r\n\r\n";
        for piece in [1, 2, 7, body.len()] {
            assert_eq!(
                feed_in_pieces(body, piece),
                (BodyProgress::Whole, b"hello world".to_vec()),
                "piece {piece}"
            );
        }
    }

    #[test]
    fn long_chunk_lines_fail_the_same_whole_or_in_pieces() {
        let line = format!("1;{}\r\nx\r\n0\r\n\r\n", "e".repeat(MAX_CHUNK_LINE));
        for piece in [1, 100, line.len()] {
            assert_eq!(
                feed_in_pieces(line.as_bytes(), piece).0,
                BodyProgress::Reject(400)
            );
        }
    }

    #[test]
    fn a_missing_crlf_after_chunk_data_is_refused() {
        assert_eq!(feed_in_pieces(b"1\r\nxyz", 10).0, BodyProgress::Reject(400));
    }

    #[test]
    fn a_too_big_body_is_drained_then_refused() {
        let mut reader = BodyReader::new(
            Vec::new(),
            RequestInfo::default(),
            false,
            20,
            10,
            0,
            Instant::now(),
        );
        let mut pos = 0;
        assert_eq!(reader.feed(&[0; 20], &mut pos), BodyProgress::Reject(413));
        assert_eq!(pos, 20);
        assert!(reader.data().len() <= 10);
    }

    #[test]
    fn a_length_body_waits_for_all_bytes() {
        let mut reader = BodyReader::new(
            Vec::new(),
            RequestInfo::default(),
            false,
            4,
            10,
            4,
            Instant::now(),
        );
        let mut pos = 0;
        assert_eq!(reader.feed(b"ab", &mut pos), BodyProgress::More);
        assert_eq!(reader.feed(b"abcd", &mut pos), BodyProgress::Whole);
        assert_eq!(reader.data(), b"abcd");
    }
}
