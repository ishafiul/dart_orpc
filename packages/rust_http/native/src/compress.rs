//! Gzips answer bodies on a helper thread, so the isolate does not wait.

use std::io::Write;
use std::sync::{Arc, Mutex, mpsc};

use flate2::Compression;
use flate2::write::GzEncoder;
use mio::Waker;

use crate::http::render::{AnswerFraming, render_answer};

/// Gzips `data` at the default level, like `dart:io` `gzip.encode`.
#[must_use]
pub fn gzip(data: &[u8]) -> Vec<u8> {
    let mut encoder = GzEncoder::new(Vec::with_capacity(data.len() / 2), Compression::default());
    // Writes to a Vec cannot fail.
    let _ = encoder.write_all(data);
    encoder.finish().unwrap_or_default()
}

/// One answer to gzip and render.
#[derive(Debug)]
pub struct CompressJob {
    /// The connection.
    pub connection: usize,
    /// The request sequence number on that connection.
    pub sequence: u32,
    /// The status.
    pub status: u16,
    /// Dart's header lines.
    pub lines: Vec<u8>,
    /// The body to gzip.
    pub body: Vec<u8>,
    /// The date line at the time of the answer.
    pub date_line: Vec<u8>,
    /// How to frame the answer.
    pub framing: AnswerFraming,
}

/// A finished job: the rendered answer.
#[derive(Debug)]
pub struct CompressedAnswer {
    /// The connection.
    pub connection: usize,
    /// The request sequence number on that connection.
    pub sequence: u32,
    /// The whole rendered answer.
    pub bytes: Vec<u8>,
}

impl CompressJob {
    fn run(self) -> CompressedAnswer {
        let zipped = gzip(&self.body);
        let mut bytes = Vec::with_capacity(zipped.len() + 256);
        render_answer(
            &mut bytes,
            self.status,
            &self.lines,
            &zipped,
            &self.date_line,
            self.framing,
        );
        CompressedAnswer {
            connection: self.connection,
            sequence: self.sequence,
            bytes,
        }
    }
}

/// Owns the gzip thread of one server. The thread starts with the first
/// job and ends when this is dropped.
pub struct Compressor {
    sender: Option<mpsc::Sender<CompressJob>>,
    done: Arc<Mutex<Vec<CompressedAnswer>>>,
    waker: Arc<Waker>,
}

impl Compressor {
    /// A compressor that wakes the event loop through `waker`.
    #[must_use]
    pub fn new(waker: Arc<Waker>) -> Self {
        Self {
            sender: None,
            done: Arc::default(),
            waker,
        }
    }

    /// Queues a job. Without a thread, it runs here.
    pub fn submit(&mut self, job: CompressJob) {
        if self.sender.is_none() {
            self.sender = self.spawn();
        }
        match &self.sender {
            Some(sender) => {
                if let Err(mpsc::SendError(job)) = sender.send(job) {
                    self.push(job.run());
                }
            }
            None => self.push(job.run()),
        }
    }

    /// The finished answers since the last call.
    pub fn take_done(&self) -> Vec<CompressedAnswer> {
        std::mem::take(
            &mut *self
                .done
                .lock()
                .unwrap_or_else(std::sync::PoisonError::into_inner),
        )
    }

    /// Whether finished answers wait to be taken.
    #[must_use]
    pub fn has_done(&self) -> bool {
        !self
            .done
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner)
            .is_empty()
    }

    /// Stops the thread.
    pub fn stop(&mut self) {
        self.sender = None;
    }

    fn push(&self, answer: CompressedAnswer) {
        self.done
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner)
            .push(answer);
    }

    fn spawn(&self) -> Option<mpsc::Sender<CompressJob>> {
        let (sender, receiver) = mpsc::channel::<CompressJob>();
        let (done, waker) = (self.done.clone(), self.waker.clone());
        std::thread::Builder::new()
            .name("rust-http-gzip".into())
            .spawn(move || {
                for job in receiver {
                    let answer = job.run();
                    done.lock()
                        .unwrap_or_else(std::sync::PoisonError::into_inner)
                        .push(answer);
                    let _ = waker.wake();
                }
            })
            .ok()
            .map(|_| sender)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Read;

    #[test]
    fn gzip_round_trips() {
        let data = b"hello hello hello hello".repeat(50);
        let zipped = gzip(&data);
        assert!(zipped.len() < data.len());
        let mut back = Vec::new();
        flate2::read::GzDecoder::new(&zipped[..])
            .read_to_end(&mut back)
            .unwrap();
        assert_eq!(back, data);
    }

    #[test]
    fn jobs_finish_on_the_thread_and_wake_the_loop() {
        let poll = mio::Poll::new().unwrap();
        let waker = Arc::new(Waker::new(poll.registry(), mio::Token(0)).unwrap());
        let mut compressor = Compressor::new(waker);
        compressor.submit(CompressJob {
            connection: 3,
            sequence: 4,
            status: 200,
            lines: Vec::new(),
            body: b"abc".repeat(100),
            date_line: Vec::new(),
            framing: AnswerFraming::default(),
        });
        let mut done = Vec::new();
        for _ in 0..200 {
            done = compressor.take_done();
            if !done.is_empty() {
                break;
            }
            std::thread::sleep(std::time::Duration::from_millis(5));
        }
        assert_eq!((done[0].connection, done[0].sequence), (3, 4));
        assert!(done[0].bytes.starts_with(b"HTTP/1.1 200 OK"));
    }
}
