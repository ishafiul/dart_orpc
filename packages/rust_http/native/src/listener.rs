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

/// Binds a new non-blocking listening socket for `address`.
fn bind_new(address: ListenAddress) -> std::io::Result<TcpListener> {
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
    socket.set_reuse_port(true)?;
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

/// Binds `address`, sharing a socket with other isolates where the OS
/// needs it.
///
/// # Errors
/// The OS error of the bind.
#[cfg(any(target_os = "linux", target_os = "android"))]
pub fn bind(address: ListenAddress) -> std::io::Result<BoundListener> {
    let listener = bind_new(address)?;
    let port = listener.local_addr()?.port();
    Ok(BoundListener {
        listener,
        address: address.with_port(port),
    })
}

/// Releases the share of `address` taken by [`bind`].
#[cfg(any(target_os = "linux", target_os = "android"))]
pub fn release(_address: ListenAddress) {}

/// Listening sockets of this process with their user count.
#[cfg(not(any(target_os = "linux", target_os = "android")))]
static SHARED: Mutex<Vec<(ListenAddress, TcpListener, usize)>> = Mutex::new(Vec::new());

/// Binds `address`, sharing a socket with other isolates where the OS
/// needs it.
///
/// # Errors
/// The OS error of the bind.
#[cfg(not(any(target_os = "linux", target_os = "android")))]
pub fn bind(address: ListenAddress) -> std::io::Result<BoundListener> {
    let mut shared = SHARED
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner);
    if address.port != 0
        && let Some(entry) = shared.iter_mut().find(|entry| entry.0 == address)
    {
        entry.2 += 1;
        return Ok(BoundListener {
            listener: entry.1.try_clone()?,
            address,
        });
    }
    let listener = bind_new(address)?;
    let real = address.with_port(listener.local_addr()?.port());
    shared.push((real, listener.try_clone()?, 1));
    Ok(BoundListener {
        listener,
        address: real,
    })
}

/// Releases the share of `address` taken by [`bind`]. The last release
/// closes the socket, so the port is free.
#[cfg(not(any(target_os = "linux", target_os = "android")))]
pub fn release(address: ListenAddress) {
    let mut shared = SHARED
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner);
    if let Some(index) = shared.iter().position(|entry| entry.0 == address) {
        shared[index].2 -= 1;
        if shared[index].2 == 0 {
            shared.swap_remove(index);
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
        let bound = bind(loopback()).unwrap();
        let local = bound.listener.local_addr().unwrap();
        assert_eq!(local.ip(), IpAddr::V4(Ipv4Addr::LOCALHOST));
        assert_eq!(bound.address.port, local.port());
        release(bound.address);
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
