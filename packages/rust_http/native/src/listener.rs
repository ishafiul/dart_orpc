//! Listening sockets, shared between the isolates of one process.
//!
//! - Linux spreads connections over `SO_REUSEPORT` sockets, so each
//!   isolate binds its own.
//! - macOS and Windows give all connections to one such socket, so there
//!   every isolate gets a duplicate of one shared socket and they accept
//!   from the same queue.

use std::net::{IpAddr, Ipv4Addr, Ipv6Addr, SocketAddr, TcpListener};
#[cfg(not(any(target_os = "linux", target_os = "android")))]
use std::sync::Mutex;

use socket2::{Domain, Protocol, Socket, Type};

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
    socket.listen(1024)?;
    socket.set_nonblocking(true)?;
    Ok(socket.into())
}

/// A bound listening socket. Dropping it does not release a shared
/// socket; call [`release`].
pub struct BoundListener {
    /// The socket.
    pub listener: TcpListener,
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
        listener,
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
    listener: TcpListener,
    shared: bool,
    users: usize,
}

/// Listening sockets of this process.
#[cfg(not(any(target_os = "linux", target_os = "android")))]
static REGISTERED: Mutex<Vec<Registered>> = Mutex::new(Vec::new());

/// Binds `address`. With `shared`, other `shared` binds of the same
/// address in this process get a duplicate of one socket, like dart:io;
/// a bind that is not `shared`, or one onto an unshared socket, fails with
/// `AddrInUse`.
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
        if !(shared && entry.shared) {
            return Err(std::io::ErrorKind::AddrInUse.into());
        }
        let listener = entry.listener.try_clone()?;
        entry.users += 1;
        return Ok(BoundListener { listener, address });
    }
    let listener = bind_new(address, shared)?;
    let real = address.with_port(listener.local_addr()?.port());
    registered.push(Registered {
        address: real,
        listener: listener.try_clone()?,
        shared,
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

    #[test]
    fn peers_are_ipv4_mapped() {
        let peer = peer_bytes("1.2.3.4:513".parse().unwrap());
        assert_eq!(&peer[10..16], &[0xff, 0xff, 1, 2, 3, 4]);
        assert_eq!(u16::from_le_bytes([peer[16], peer[17]]), 513);
    }
}
