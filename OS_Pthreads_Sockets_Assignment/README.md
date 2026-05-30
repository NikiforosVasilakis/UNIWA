# OS Pthreads & Sockets Assignment

Operating Systems Assignment — POSIX Threads & UNIX Domain Sockets in C.

---

## Structure

```
E1/   dot_product_pthreads.c   — Parallel dot product using pthreads
E2/   B_wonderful_world_sync.c — Thread synchronisation with POSIX semaphores
Unix_Domain_Sockets/
      server.c                 — Concurrent stream socket server (one thread per client)
      client.c                 — Interactive stream socket client
```

---

## E1 — Parallel Dot Product

Computes the dot product of two vectors of length `n` using `p` threads. Each thread calculates its partial sum locally and updates the shared result inside a mutex-protected critical section.

```bash
gcc -O2 -o dot_product_pthreads E1/dot_product_pthreads.c -lpthread
./dot_product_pthreads <n> <p>
# Example: ./dot_product_pthreads 1000000 4
```

---

## E2 — What A Wonderful World (Thread Sync)

Three threads repeatedly print `What A Wonderful World!` in order, synchronised via named POSIX semaphores in a T1→T2→T3→T1 chain. Named semaphores (`sem_open`) are used instead of unnamed ones (`sem_init`) for macOS compatibility.

```bash
gcc -Wall -o wonderful E2/B_wonderful_world_sync.c -lpthread
./wonderful [iterations]     # default: 5
```

---

## Unix Domain Sockets — Server / Client

### Overview

UNIX domain sockets (`AF_UNIX`) are an IPC mechanism that allows processes on the **same host** to communicate through the filesystem. They use the same `socket`/`bind`/`listen`/`accept`/`connect` API as TCP sockets but bypass the network stack entirely, making them faster and lower-overhead than TCP loopback. The socket appears as a special file (here `/tmp/seq_sock`) and is removed with `unlink` on server shutdown.

This exercise uses `SOCK_STREAM` (connection-oriented, reliable, ordered byte stream), which mirrors TCP semantics locally.

### How It Works

```
Client                          Server
──────                          ──────
socket(AF_UNIX, SOCK_STREAM)    socket(AF_UNIX, SOCK_STREAM)
                                bind("/tmp/seq_sock")
                                listen()
connect("/tmp/seq_sock") ──────► accept() → spawns new pthread
                                              │
send int n                ──────►             │ readn(&n)
send n integers           ──────►             │ readn(arr, n*4)
                                              │ compute average
                                              │   avg < 50 → "Sequence Ok (avg: X.XX)"
recv 128-byte response    ◄──────             │   avg ≥ 50 → "Check Failed"
print response                                │
ask user for next sequence                    │ loop back to readn
   ...                                        │
close(sfd)                ──────►             │ read returns 0 → thread exits
```

### Concurrency Model

The server runs a single `accept()` loop. For each incoming connection it allocates a heap-allocated `int` for the file descriptor and passes it to a **detached pthread** (`pthread_detach`). Detached threads free their resources automatically on exit, so the server never needs to call `pthread_join`. Multiple clients can therefore be served simultaneously without blocking each other.

### Wire Protocol

| Direction | Data | Size |
|-----------|------|------|
| client → server | count `n` | `sizeof(int)` = 4 bytes |
| client → server | `n` integers | `n × 4` bytes |
| server → client | response string | 128 bytes (fixed, null-terminated) |

A `readn()` helper is used on the server side to guard against short reads — `read()` is not guaranteed to return all requested bytes in a single call on a stream socket.

### Build & Run

```bash
# Compile
gcc -Wall -o server Unix_Domain_Sockets/server.c -lpthread
gcc -Wall -o client Unix_Domain_Sockets/client.c

# Terminal 1 — start server
./server

# Terminal 2 (repeat as many times as needed)
./client
```

### Example Session

```
$ ./client
Πλήθος ακεραίων: 4
  [1]: 10
  [2]: 20
  [3]: 15
  [4]: 5
Server: Sequence Ok (Μέσος Όρος: 12.50)
Νέα ακολουθία; (y/n): y
Πλήθος ακεραίων: 3
  [1]: 60
  [2]: 70
  [3]: 80
Server: Check Failed
Νέα ακολουθία; (y/n): n
```

### Key System Calls

| Call | Purpose |
|------|---------|
| `socket(AF_UNIX, SOCK_STREAM, 0)` | Create a UNIX domain stream socket |
| `bind(fd, addr, len)` | Attach the socket to a filesystem path |
| `listen(fd, backlog)` | Mark the socket as passive; `backlog=10` sets the pending-connection queue |
| `accept(fd, NULL, NULL)` | Block until a client connects; returns a new connected fd |
| `connect(fd, addr, len)` | Client-side: establish connection to the server path |
| `unlink(path)` | Remove the socket file (called before `bind` and on shutdown) |
