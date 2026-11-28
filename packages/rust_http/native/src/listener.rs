//! Listening sockets, shared between the isolates of one process.
//!
//! - Linux spreads connections over `SO_REUSEPORT` sockets, so each
//!   isolate binds its own.
//! - macOS gives all connections to one such socket, so there every
//!   isolate gets a duplicate of one shared socket and they accept from the
//!   same queue.
//! - Windows breaks duplicated sockets in this use, so there isolates share
//!   the very same socket ([`ListenerSource::Shared`]) and each accepts from
//!   it directly.

use std::net::{IpAddr, Ipv4Addr, Ipv6Addr, SocketAddr, TcpListener};
#[cfg(windows)]
use std::sync::Arc;
use std::sync::Mutex;
#[cfg(unix)]
use std::{
    os::unix::net::UnixListener,
    path::{Path, PathBuf},
};

#[cfg(unix)]
use socket2::SockAddr;
use socket2::{Domain, Protocol, Socket, Type};

use crate::limits::LISTEN_BACKLOG;
use crate::protocol::request_record::Peer;

/// Where to listen.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ListenAddress {
    /// The host, or `None` for all interfaces (dual stack).
    pub ip: Option<IpAddr>,
    /// The port; 0 picks a free one.
    pub port: u16,
}

impl ListenAddress {
    /// The address Dart encodes as a family (0 all, 4 IPv4, 6 IPv6) and
    /// the high and low 64 bits of the IP.
    #[must_use]
    pub fn from_dart(family: i32, high: u64, low: u64, port: u16) -> Self {
        let ip = match family {
            4 => Some(IpAddr::V4(Ipv4Addr::from(
                u32::try_from(low & 0xffff_ffff).unwrap_or(0),
            ))),
            6 => Some(IpAddr::V6(Ipv6Addr::from(
                (u128::from(high) << 64) | u128::from(low),
            ))),
            _ => None,
        };
        Self { ip, port }
    }

    fn with_port(self, port: u16) -> Self {
        Self { port, ..self }
    }
}

/// What a server listens on.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Endpoint {
    /// A TCP address.
    Inet(ListenAddress),
    /// A Unix domain socket path.
    #[cfg(unix)]
    Unix(PathBuf),
}

impl Endpoint {
    /// The TCP port; 0 for a Unix domain socket, like dart:io.
    #[must_use]
    pub fn port(&self) -> u16 {
        match self {
            Self::Inet(address) => address.port,
            #[cfg(unix)]
            Self::Unix(_) => 0,
        }
    }
}

impl From<ListenAddress> for Endpoint {
    fn from(address: ListenAddress) -> Self {
        Self::Inet(address)
    }
}

/// Releases the share of `endpoint` taken by [`bind`] or [`bind_unix`].
pub fn release_endpoint(endpoint: &Endpoint) {
    match endpoint {
        Endpoint::Inet(address) => release(*address),
        #[cfg(unix)]
        Endpoint::Unix(path) => release_unix(path),
    }
}

/// Binds a new non-blocking listening socket for `address`. Only a
/// `shared` socket lets other sockets bind the same port.
fn bind_new(address: ListenAddress, shared: bool) -> std::io::Result<TcpListener> {
    let (socket, bind_to) = match address.ip {
        Some(ip) => {
            let target = SocketAddr::new(ip, address.port);
            let socket = Socket::new(
                Domain::for_address(target),
                Type::STREAM,
                Some(Protocol::TCP),
            )?;
            if target.is_ipv6() {
                // `::` also takes IPv4, like dart:io.
                let _ = socket.set_only_v6(false);
            }
            (socket, target)
        }
        // Dual stack like dart:io `anyIPv6`; IPv4 only without IPv6.
        None => match Socket::new(Domain::IPV6, Type::STREAM, Some(Protocol::TCP)) {
            Ok(socket) if socket.set_only_v6(false).is_ok() => (
                socket,
                SocketAddr::new(Ipv6Addr::UNSPECIFIED.into(), address.port),
            ),
            _ => (
                Socket::new(Domain::IPV4, Type::STREAM, Some(Protocol::TCP))?,
                SocketAddr::new(Ipv4Addr::UNSPECIFIED.into(), address.port),
            ),
        },
    };
    #[cfg(unix)]
    socket.set_reuse_address(true)?;
    #[cfg(any(target_os = "linux", target_os = "android"))]
    socket.set_reuse_port(shared)?;
    #[cfg(not(any(target_os = "linux", target_os = "android")))]
    let _ = shared;
    socket.bind(&bind_to.into())?;
    socket.listen(LISTEN_BACKLOG)?;
    socket.set_nonblocking(true)?;
    Ok(socket.into())
}

/// How a server gets its connections.
#[derive(Debug)]
pub enum ListenerSource {
    /// A socket of its own (or a duplicate), watched by the server's
    /// poller.
    Owned(TcpListener),
    /// A Unix domain socket of its own (or a duplicate), watched by the
    /// server's poller.
    #[cfg(unix)]
    Unix(UnixListener),
    /// One socket shared by several servers of this process; each accepts
    /// from it directly, with no poller watching it (Windows).
    #[cfg(windows)]
    Shared(Arc<TcpListener>),
}

impl ListenerSource {
    /// The local address of the socket.
    ///
    /// # Errors
    /// The OS error, if any.
    pub fn local_addr(&self) -> std::io::Result<SocketAddr> {
        match self {
            Self::Owned(listener) => listener.local_addr(),
            #[cfg(unix)]
            Self::Unix(_) => Err(std::io::ErrorKind::Unsupported.into()),
            #[cfg(windows)]
            Self::Shared(listener) => listener.local_addr(),
        }
    }
}

/// A bound listening socket. Dropping it does not release a shared
/// socket; call [`release`].
pub struct BoundListener {
    /// The socket.
    pub listener: ListenerSource,
    /// The address with the real port.
    pub address: ListenAddress,
}

/// Binds `address`. With `shared`, other `shared` binds of the same
/// address in this process succeed too, like dart:io; without it, they
/// fail with `AddrInUse`.
///
/// # Errors
/// The OS error of the bind.
#[cfg(any(target_os = "linux", target_os = "android"))]
pub fn bind(address: ListenAddress, shared: bool) -> std::io::Result<BoundListener> {
    let listener = bind_new(address, shared)?;
    let port = listener.local_addr()?.port();
    Ok(BoundListener {
        listener: ListenerSource::Owned(listener),
        address: address.with_port(port),
    })
}

/// Releases the share of `address` taken by [`bind`].
#[cfg(any(target_os = "linux", target_os = "android"))]
pub fn release(_address: ListenAddress) {}

/// A listening socket of this process.
#[cfg(not(any(target_os = "linux", target_os = "android")))]
struct Registered {
    address: ListenAddress,
    /// The socket of a shared bind; none for an unshared one.
    socket: Option<SharedSocket>,
    users: usize,
}

/// The socket other shared binds of an address get.
#[cfg(all(not(any(target_os = "linux", target_os = "android")), not(windows)))]
type SharedSocket = TcpListener;
#[cfg(windows)]
type SharedSocket = Arc<TcpListener>;

/// Listening sockets of this process.
#[cfg(not(any(target_os = "linux", target_os = "android")))]
static REGISTERED: Mutex<Vec<Registered>> = Mutex::new(Vec::new());

/// What one more user of a shared socket gets.
#[cfg(all(not(any(target_os = "linux", target_os = "android")), not(windows)))]
fn share(socket: &SharedSocket) -> std::io::Result<ListenerSource> {
    Ok(ListenerSource::Owned(socket.try_clone()?))
}

#[cfg(windows)]
#[allow(clippy::unnecessary_wraps)]
fn share(socket: &SharedSocket) -> std::io::Result<ListenerSource> {
    Ok(ListenerSource::Shared(socket.clone()))
}

/// Keeps a freshly bound shared socket for later users.
#[cfg(all(not(any(target_os = "linux", target_os = "android")), not(windows)))]
fn keep(listener: TcpListener) -> SharedSocket {
    listener
}

#[cfg(windows)]
fn keep(listener: TcpListener) -> SharedSocket {
    Arc::new(listener)
}

/// Binds `address`. With `shared`, other `shared` binds of the same
/// address in this process share one socket, like dart:io; a bind that is
/// not `shared`, or one onto an unshared socket, fails with `AddrInUse`.
///
/// # Errors
/// The OS error of the bind.
#[cfg(not(any(target_os = "linux", target_os = "android")))]
pub fn bind(address: ListenAddress, shared: bool) -> std::io::Result<BoundListener> {
    let mut registered = REGISTERED
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner);
    if address.port != 0
        && let Some(entry) = registered.iter_mut().find(|entry| entry.address == address)
    {
        let Some(socket) = entry.socket.as_ref().filter(|_| shared) else {
            return Err(std::io::ErrorKind::AddrInUse.into());
        };
        let listener = share(socket)?;
        entry.users += 1;
        return Ok(BoundListener { listener, address });
    }
    let listener = bind_new(address, shared)?;
    let real = address.with_port(listener.local_addr()?.port());
    let (socket, listener) = if shared {
        let socket = keep(listener);
        let listener = share(&socket)?;
        (Some(socket), listener)
    } else {
        (None, ListenerSource::Owned(listener))
    };
    registered.push(Registered {
        address: real,
        socket,
        users: 1,
    });
    Ok(BoundListener {
        listener,
        address: real,
    })
}

/// Releases the share of `address` taken by [`bind`]. The last release
/// closes the socket, so the port is free.
#[cfg(not(any(target_os = "linux", target_os = "android")))]
pub fn release(address: ListenAddress) {
    let mut registered = REGISTERED
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner);
    if let Some(index) = registered.iter().position(|entry| entry.address == address) {
        registered[index].users -= 1;
        if registered[index].users == 0 {
            registered.swap_remove(index);
        }
    }
}

/// A Unix domain socket of this process; see [`bind_unix`].
#[cfg(unix)]
struct UnixRegistered {
    path: PathBuf,
    /// The socket of a shared bind; none for an unshared one.
    socket: Option<UnixListener>,
    users: usize,
}

/// Unix domain sockets of this process.
#[cfg(unix)]
static UNIX_REGISTERED: Mutex<Vec<UnixRegistered>> = Mutex::new(Vec::new());

/// Binds a Unix domain socket at `path`, like dart:io: the file must not
/// exist yet, and other binds of the same path in this process succeed
/// only when every one of them is `shared`. They get a duplicate of one
/// socket and accept from the same queue. The last [`release_unix`]
/// removes the file.
///
/// # Errors
/// The OS error of the bind; `AddrInUse` for a path this process already
/// binds and cannot share; `ENAMETOOLONG` for a path too long for a
/// socket address.
#[cfg(unix)]
pub fn bind_unix(path: &Path, shared: bool) -> std::io::Result<ListenerSource> {
    let mut registered = UNIX_REGISTERED
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner);
    if let Some(entry) = registered.iter_mut().find(|entry| entry.path == path) {
        let Some(socket) = entry.socket.as_ref().filter(|_| shared) else {
            return Err(std::io::ErrorKind::AddrInUse.into());
        };
        let listener = socket.try_clone()?;
        entry.users += 1;
        return Ok(ListenerSource::Unix(listener));
    }
    let listener = bind_new_unix(path)?;
    let socket = if shared {
        match listener.try_clone() {
            Ok(socket) => Some(socket),
            Err(error) => {
                let _ = std::fs::remove_file(path);
                return Err(error);
            }
        }
    } else {
        None
    };
    registered.push(UnixRegistered {
        path: path.to_path_buf(),
        socket,
        users: 1,
    });
    Ok(ListenerSource::Unix(listener))
}

#[cfg(unix)]
fn bind_new_unix(path: &Path) -> std::io::Result<UnixListener> {
    let address = SockAddr::unix(path).map_err(|error| {
        if error.kind() == std::io::ErrorKind::InvalidInput {
            std::io::Error::from_raw_os_error(libc::ENAMETOOLONG)
        } else {
            error
        }
    })?;
    let socket = Socket::new(Domain::UNIX, Type::STREAM, None)?;
    socket.bind(&address)?;
    // The bind made the file: remove it again if the socket is unusable.
    if let Err(error) = socket
        .listen(LISTEN_BACKLOG)
        .and_then(|()| socket.set_nonblocking(true))
    {
        let _ = std::fs::remove_file(path);
        return Err(error);
    }
    Ok(socket.into())
}

/// Releases the share of `path` taken by [`bind_unix`]. The last release
/// closes the socket and removes its file, like dart:io.
#[cfg(unix)]
pub fn release_unix(path: &Path) {
    let mut registered = UNIX_REGISTERED
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner);
    if let Some(index) = registered.iter().position(|entry| entry.path == path) {
        registered[index].users -= 1;
        if registered[index].users == 0 {
            registered.swap_remove(index);
            let _ = std::fs::remove_file(path);
        }
    }
}

/// The peer as 16 IP bytes (IPv4 mapped) and a little-endian port.
#[must_use]
pub fn peer_bytes(address: SocketAddr) -> Peer {
    let ip = match address.ip() {
        IpAddr::V4(v4) => v4.to_ipv6_mapped(),
        IpAddr::V6(v6) => v6,
    };
    let mut out = [0; 18];
    out[..16].copy_from_slice(&ip.octets());
    out[16..].copy_from_slice(&address.port().to_le_bytes());
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    fn loopback() -> ListenAddress {
        ListenAddress::from_dart(4, 0, u64::from(u32::from(Ipv4Addr::LOCALHOST)), 0)
    }

    #[test]
    fn binds_one_host_only() {
        let bound = bind(loopback(), false).unwrap();
        let local = bound.listener.local_addr().unwrap();
        assert_eq!(local.ip(), IpAddr::V4(Ipv4Addr::LOCALHOST));
        assert_eq!(bound.address.port, local.port());
        release(bound.address);
    }

    #[test]
    fn only_shared_binds_share_a_port() {
        let first = bind(loopback(), false).unwrap();
        let again = loopback().with_port(first.address.port);
        assert_eq!(
            bind(again, true).err().map(|e| e.kind()),
            Some(std::io::ErrorKind::AddrInUse)
        );
        release(first.address);
        drop(first);

        let shared = bind(loopback(), true).unwrap();
        let again = loopback().with_port(shared.address.port);
        let second = bind(again, true).unwrap();
        assert_eq!(second.address.port, shared.address.port);
        release(second.address);
        release(shared.address);
    }

    #[test]
    fn decodes_ipv6_from_two_words() {
        let address = ListenAddress::from_dart(6, 0, 1, 80);
        assert_eq!(address.ip, Some(IpAddr::V6(Ipv6Addr::LOCALHOST)));
    }

    #[cfg(unix)]
    fn socket_path(name: &str) -> PathBuf {
        std::env::temp_dir().join(format!("rh_{}_{name}.sock", std::process::id()))
    }

    #[cfg(unix)]
    #[test]
    fn a_unix_bind_makes_the_file_and_its_release_removes_it() {
        let path = socket_path("lifecycle");
        let _ = std::fs::remove_file(&path);
        let listener = bind_unix(&path, false).unwrap();
        assert!(std::fs::symlink_metadata(&path).is_ok());
        std::os::unix::net::UnixStream::connect(&path).unwrap();
        drop(listener);
        release_unix(&path);
        assert!(std::fs::symlink_metadata(&path).is_err());
    }

    #[cfg(unix)]
    #[test]
    fn only_shared_unix_binds_share_a_path() {
        let path = socket_path("shared");
        let _ = std::fs::remove_file(&path);
        let first = bind_unix(&path, false).unwrap();
        assert_eq!(
            bind_unix(&path, true).err().map(|e| e.kind()),
            Some(std::io::ErrorKind::AddrInUse)
        );
        drop(first);
        release_unix(&path);

        let first = bind_unix(&path, true).unwrap();
        let second = bind_unix(&path, true).unwrap();
        drop(first);
        release_unix(&path);
        // The second user still holds the path.
        assert!(std::fs::symlink_metadata(&path).is_ok());
        drop(second);
        release_unix(&path);
        assert!(std::fs::symlink_metadata(&path).is_err());
    }

    #[cfg(unix)]
    #[test]
    fn a_unix_bind_refuses_an_existing_file() {
        let path = socket_path("existing");
        std::fs::write(&path, b"x").unwrap();
        assert_eq!(
            bind_unix(&path, false).err().map(|e| e.kind()),
            Some(std::io::ErrorKind::AddrInUse)
        );
        // The file someone else made stays.
        assert!(std::fs::symlink_metadata(&path).is_ok());
        std::fs::remove_file(&path).unwrap();
    }

    #[cfg(unix)]
    #[test]
    fn a_unix_path_too_long_is_reported() {
        let path = PathBuf::from(format!("/tmp/{}.sock", "x".repeat(200)));
        assert_eq!(
            bind_unix(&path, false).err().and_then(|e| e.raw_os_error()),
            Some(libc::ENAMETOOLONG)
        );
    }

    #[test]
    fn peers_are_ipv4_mapped() {
        let peer = peer_bytes("1.2.3.4:513".parse().unwrap());
        assert_eq!(&peer[10..16], &[0xff, 0xff, 1, 2, 3, 4]);
        assert_eq!(u16::from_le_bytes([peer[16], peer[17]]), 513);
    }
}
