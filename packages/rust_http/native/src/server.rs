//! One server per Dart isolate: the event loop behind a mutex, plus the
//! idle helper thread.
//!
//! While Dart is busy it drives the loop itself through `rust_http_run`.
//! When a call finds nothing, the idle helper takes over: it sleeps until
//! the poll file has an event or the next timer is due — without taking
//! the loop's mutex, so Dart never waits for it — then posts `[1]` to the
//! Dart port. The `armed` flag makes sure only one side wakes Dart.
//!
//! A Dart isolate may move to another OS thread between event loop turns,
//! so all state is `Send` and behind the mutex; nothing is thread local.
//!
//! The helper also probes every [`PROBE`] that the isolate is alive. When
//! a post fails the isolate is gone, and the server closes so the port is
//! free.

use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Arc, Condvar, Mutex, MutexGuard, PoisonError};
use std::thread::JoinHandle;
use std::time::{Duration, Instant};

use mio::Waker;

use crate::connection::NeedsRoom;
use crate::dart_api;
use crate::event_loop::EventLoop;
use crate::limits::{Limits, PROBE};
use crate::listener::{self, ListenAddress};

/// Message to Dart: the sockets have work.
pub const WAKE: u8 = 1;
/// Message to Dart: a graceful shutdown is complete.
pub const DRAINED: u8 = 2;

/// Why [`Server::bind`] failed.
#[derive(Debug)]
pub enum BindError {
    /// The OS refused the bind.
    Os(std::io::Error),
    /// No poller or helper thread could be created.
    Resources,
}

/// One server.
pub struct Server {
    event_loop: Mutex<EventLoop>,
    waker: Arc<Waker>,
    /// The poll file, watched by the idle helper.
    #[cfg(unix)]
    poll_fd: i32,
    /// Dart is idle: the helper watches and wakes Dart when work comes.
    armed: AtomicBool,
    /// The loop's next timer, in nanoseconds after `base`; `u64::MAX`: none.
    next_timer: AtomicU64,
    base: Instant,
    /// Wakes the helper when Dart goes idle.
    kick: Mutex<bool>,
    kicked: Condvar,
    stopped: AtomicBool,
    dart_port: i64,
    port: u16,
    helper: Mutex<Option<JoinHandle<()>>>,
}

fn lock<T>(mutex: &Mutex<T>) -> MutexGuard<'_, T> {
    mutex.lock().unwrap_or_else(PoisonError::into_inner)
}

impl Server {
    /// Binds `address` (see [`listener::bind`] for `shared`) and starts the
    /// idle helper, which posts to `dart_port`.
    ///
    /// # Errors
    /// [`BindError`] when the socket, poller or thread cannot be made.
    pub fn bind(
        address: ListenAddress,
        shared: bool,
        limits: Limits,
        dart_port: i64,
    ) -> Result<Arc<Self>, BindError> {
        let bound = listener::bind(address, shared).map_err(BindError::Os)?;
        let real = bound.address;
        let Ok(event_loop) = EventLoop::new(bound.listener, real, limits) else {
            listener::release(real);
            return Err(BindError::Resources);
        };
        let server = Arc::new(Self {
            waker: event_loop.waker(),
            #[cfg(unix)]
            poll_fd: event_loop.poll_fd(),
            port: event_loop.port(),
            event_loop: Mutex::new(event_loop),
            // A new server may have connections waiting: Dart reads at once.
            armed: AtomicBool::new(true),
            next_timer: AtomicU64::new(u64::MAX),
            base: Instant::now(),
            kick: Mutex::new(true),
            kicked: Condvar::new(),
            stopped: AtomicBool::new(false),
            dart_port,
            helper: Mutex::new(None),
        });
        let for_helper = server.clone();
        let Ok(helper) = std::thread::Builder::new()
            .name("rust-http-idle".into())
            .spawn(move || for_helper.watch_while_idle())
        else {
            lock(&server.event_loop).stop();
            return Err(BindError::Resources);
        };
        *lock(&server.helper) = Some(helper);
        Ok(server)
    }

    /// The bound port.
    #[must_use]
    pub fn port(&self) -> u16 {
        self.port
    }

    /// One turn for Dart; see `rust_http_run`.
    ///
    /// # Errors
    /// [`NeedsRoom`] when one record is bigger than all of `inbox`.
    pub fn run(
        &self,
        answers: &[u8],
        inbox: &mut [u8],
        budget: Duration,
    ) -> Result<usize, NeedsRoom> {
        // Disarm before locking: a Windows helper holding the loop then
        // stops at once instead of making Dart wait.
        self.armed.store(false, Ordering::Release);
        self.interrupt_helper();
        let mut event_loop = lock(&self.event_loop);
        let got = event_loop.run(answers, inbox, budget);
        if event_loop.take_drained() {
            let _ = dart_api::post_bytes(self.dart_port, &[DRAINED]);
        }
        match got {
            Ok(0) if event_loop.has_work() => {
                // A connection waits for its next turn: come back after one
                // turn of Dart's event loop.
                drop(event_loop);
                let _ = dart_api::post_bytes(self.dart_port, &[WAKE]);
                Ok(0)
            }
            Ok(0) => {
                self.set_next_timer(event_loop.next_timer());
                self.armed.store(true, Ordering::Release);
                drop(event_loop);
                self.kick_helper();
                Ok(0)
            }
            other => other,
        }
    }

    /// Starts a graceful shutdown. Dart gets `[2]` once it is complete.
    pub fn shutdown(&self) {
        self.interrupt_helper();
        let mut event_loop = lock(&self.event_loop);
        event_loop.update_clock();
        event_loop.start_drain();
        if event_loop.take_drained() {
            let _ = dart_api::post_bytes(self.dart_port, &[DRAINED]);
        }
        // Lingering closes have timers: the helper must wake for them.
        self.set_next_timer(event_loop.next_timer());
    }

    /// Stops the helper and closes every socket.
    pub fn stop(&self) {
        self.stopped.store(true, Ordering::Release);
        let _ = self.waker.wake();
        self.kick_helper();
        if let Some(helper) = lock(&self.helper).take() {
            let _ = helper.join();
        }
        lock(&self.event_loop).stop();
    }

    fn kick_helper(&self) {
        *lock(&self.kick) = true;
        self.kicked.notify_one();
    }

    fn set_next_timer(&self, at: Option<Instant>) {
        let nanos = at.map_or(u64::MAX, |at| {
            let since = at.saturating_duration_since(self.base).as_nanos();
            u64::try_from(since)
                .unwrap_or(u64::MAX - 1)
                .min(u64::MAX - 1)
        });
        self.next_timer.store(nanos, Ordering::Release);
    }

    /// Time until the loop's next timer, if any.
    fn next_timer_in(&self) -> Option<Duration> {
        let nanos = self.next_timer.load(Ordering::Acquire);
        (nanos != u64::MAX).then(|| {
            (self.base + Duration::from_nanos(nanos)).saturating_duration_since(Instant::now())
        })
    }

    /// Whether the poll file has an event within `wait`. Neither reads the
    /// event nor takes the loop: `rust_http_run` does that.
    #[cfg(unix)]
    fn ready_within(&self, wait: Duration) -> bool {
        let mut poll_fd = libc::pollfd {
            fd: self.poll_fd,
            events: libc::POLLIN,
            revents: 0,
        };
        // Round up, so a timer just ahead does not spin.
        let millis = i32::try_from(wait.as_micros().div_ceil(1000)).unwrap_or(i32::MAX);
        // SAFETY: `poll_fd` is a valid `pollfd` for the call.
        let ready = unsafe { libc::poll(&raw mut poll_fd, 1, millis) };
        ready > 0 && poll_fd.revents & libc::POLLIN != 0
    }

    /// Windows has no poll file to watch, so the helper polls the loop
    /// itself while holding it. Dart never waits for that: before it takes
    /// the loop it calls [`Self::interrupt_helper`], which ends the poll.
    #[cfg(not(unix))]
    fn ready_within(&self, wait: Duration) -> bool {
        let mut event_loop = lock(&self.event_loop);
        if !self.armed.load(Ordering::Acquire) {
            return false; // Dart wants the loop
        }
        event_loop.update_clock();
        event_loop.wait(Some(wait));
        event_loop.has_work()
    }

    /// Ends a poll of the Windows helper, which holds the loop meanwhile.
    /// On Unix the helper never holds the loop, so there is nothing to do.
    #[cfg_attr(unix, allow(clippy::unused_self))]
    fn interrupt_helper(&self) {
        #[cfg(not(unix))]
        let _ = self.waker.wake();
    }

    /// The isolate is gone without stopping the server (e.g. an uncaught
    /// error). Close the sockets so the port is free and new clients get
    /// "connection refused".
    fn isolate_gone(&self) {
        self.stopped.store(true, Ordering::Release);
        lock(&self.event_loop).stop();
    }

    /// Probes the isolate. False when it is gone.
    fn isolate_alive(&self) -> bool {
        dart_api::post_bytes(self.dart_port, &[])
    }

    /// The idle helper loop.
    fn watch_while_idle(&self) {
        let mut probed = Instant::now();
        loop {
            {
                let mut kick = lock(&self.kick);
                while !*kick && !self.stopped.load(Ordering::Acquire) {
                    kick = self
                        .kicked
                        .wait_timeout(kick, PROBE)
                        .unwrap_or_else(PoisonError::into_inner)
                        .0;
                    if !*kick && probed.elapsed() >= PROBE {
                        // Dart owns the sockets; a dead isolate never calls
                        // `rust_http_run` again, so check it here too.
                        probed = Instant::now();
                        if !self.isolate_alive() {
                            drop(kick);
                            return self.isolate_gone();
                        }
                    }
                }
                *kick = false;
            }
            while self.armed.load(Ordering::Acquire) && !self.stopped.load(Ordering::Acquire) {
                let wait = self.next_timer_in().map_or(PROBE, |due| due.min(PROBE));
                let ready = self.ready_within(wait);
                if self.stopped.load(Ordering::Acquire) {
                    return;
                }
                if ready || self.next_timer_in() == Some(Duration::ZERO) {
                    // Only the side that clears `armed` wakes Dart.
                    if self
                        .armed
                        .compare_exchange(true, false, Ordering::AcqRel, Ordering::Acquire)
                        .is_ok()
                        && !dart_api::post_bytes(self.dart_port, &[WAKE])
                    {
                        return self.isolate_gone();
                    }
                    break;
                }
                if probed.elapsed() >= PROBE {
                    probed = Instant::now();
                    if !self.isolate_alive() {
                        return self.isolate_gone();
                    }
                }
            }
            if self.stopped.load(Ordering::Acquire) {
                return;
            }
        }
    }
}
