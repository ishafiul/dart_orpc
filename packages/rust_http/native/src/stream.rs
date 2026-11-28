//! A connection's socket: TCP, or a Unix domain socket on Unix.
//!
//! Everything past accept treats both alike: reads and writes go through
//! `&Stream`, the poller registers it as one [`Source`].

use std::io::{Read, Write};
use std::net::Shutdown;

use mio::event::Source;
use mio::net::TcpStream;
#[cfg(unix)]
use mio::net::UnixStream;
use mio::{Interest, Registry, Token};

/// An accepted, non-blocking connection socket.
#[derive(Debug)]
pub enum Stream {
    /// A TCP connection.
    Tcp(TcpStream),
    /// A Unix domain socket connection.
    #[cfg(unix)]
    Unix(UnixStream),
}

impl Stream {
    /// Turns off Nagle's algorithm on TCP; Unix sockets have none.
    ///
    /// # Errors
    /// The OS error, if any.
    pub fn set_nodelay(&self, nodelay: bool) -> std::io::Result<()> {
        match self {
            Self::Tcp(stream) => stream.set_nodelay(nodelay),
            #[cfg(unix)]
            Self::Unix(_) => Ok(()),
        }
    }

    /// Shuts down the read, write or both halves.
    ///
    /// # Errors
    /// The OS error, if any.
    pub fn shutdown(&self, how: Shutdown) -> std::io::Result<()> {
        match self {
            Self::Tcp(stream) => stream.shutdown(how),
            #[cfg(unix)]
            Self::Unix(stream) => stream.shutdown(how),
        }
    }
}

#[cfg(test)]
impl Stream {
    /// Reads without consuming. Only TCP streams support it here.
    pub(crate) fn peek(&self, buf: &mut [u8]) -> std::io::Result<usize> {
        match self {
            Self::Tcp(stream) => stream.peek(buf),
            #[cfg(unix)]
            Self::Unix(_) => Err(std::io::ErrorKind::Unsupported.into()),
        }
    }
}

#[cfg(unix)]
impl std::os::fd::AsFd for Stream {
    fn as_fd(&self) -> std::os::fd::BorrowedFd<'_> {
        match self {
            Self::Tcp(stream) => stream.as_fd(),
            Self::Unix(stream) => stream.as_fd(),
        }
    }
}

#[cfg(windows)]
impl std::os::windows::io::AsSocket for Stream {
    fn as_socket(&self) -> std::os::windows::io::BorrowedSocket<'_> {
        match self {
            Self::Tcp(stream) => stream.as_socket(),
        }
    }
}

impl From<TcpStream> for Stream {
    fn from(stream: TcpStream) -> Self {
        Self::Tcp(stream)
    }
}

#[cfg(unix)]
impl From<UnixStream> for Stream {
    fn from(stream: UnixStream) -> Self {
        Self::Unix(stream)
    }
}

impl Read for &Stream {
    fn read(&mut self, buf: &mut [u8]) -> std::io::Result<usize> {
        match *self {
            Stream::Tcp(stream) => (&*stream).read(buf),
            #[cfg(unix)]
            Stream::Unix(stream) => (&*stream).read(buf),
        }
    }
}

impl Write for &Stream {
    fn write(&mut self, buf: &[u8]) -> std::io::Result<usize> {
        match *self {
            Stream::Tcp(stream) => (&*stream).write(buf),
            #[cfg(unix)]
            Stream::Unix(stream) => (&*stream).write(buf),
        }
    }

    fn flush(&mut self) -> std::io::Result<()> {
        match *self {
            Stream::Tcp(stream) => (&*stream).flush(),
            #[cfg(unix)]
            Stream::Unix(stream) => (&*stream).flush(),
        }
    }
}

impl Source for Stream {
    fn register(
        &mut self,
        registry: &Registry,
        token: Token,
        interests: Interest,
    ) -> std::io::Result<()> {
        match self {
            Self::Tcp(stream) => stream.register(registry, token, interests),
            #[cfg(unix)]
            Self::Unix(stream) => stream.register(registry, token, interests),
        }
    }

    fn reregister(
        &mut self,
        registry: &Registry,
        token: Token,
        interests: Interest,
    ) -> std::io::Result<()> {
        match self {
            Self::Tcp(stream) => stream.reregister(registry, token, interests),
            #[cfg(unix)]
            Self::Unix(stream) => stream.reregister(registry, token, interests),
        }
    }

    fn deregister(&mut self, registry: &Registry) -> std::io::Result<()> {
        match self {
            Self::Tcp(stream) => stream.deregister(registry),
            #[cfg(unix)]
            Self::Unix(stream) => stream.deregister(registry),
        }
    }
}

#[cfg(all(test, unix))]
mod tests {
    use super::*;

    #[test]
    fn reads_and_writes_a_unix_pair() {
        let (a, b) = std::os::unix::net::UnixStream::pair().unwrap();
        let a = Stream::from(UnixStream::from_std(a));
        let b = Stream::from(UnixStream::from_std(b));
        (&a).write_all(b"ping").unwrap();
        let mut buf = [0; 4];
        (&b).read_exact(&mut buf).unwrap();
        assert_eq!(&buf, b"ping");
        a.set_nodelay(true).unwrap();
        a.shutdown(Shutdown::Write).unwrap();
        assert_eq!((&b).read(&mut buf).unwrap(), 0);
    }
}
