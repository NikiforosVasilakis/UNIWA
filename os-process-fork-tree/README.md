# os-process-fork-tree

C programs demonstrating Unix process creation with `fork()`.

---

## E1 — fork-analysis

Analyzes the following fork sequence and identifies all 10 resulting processes:

```c
pid1 = fork();
if (pid1 != 0) { pid2 = fork(); }
else { pid3 = fork(); pid4 = fork(); pid5 = fork(); }
```

### Build & Run

```bash
cd E1
gcc -Wall -o fork-analysis fork-analysis.c
./fork-analysis
```

---

## E2 — fork-process-tree

Creates the following process hierarchy:

```
        P0
       /  \
      P1   P2
      |   /|\
      P3 P4 P5 P6 ... (N children)
```

- **P0** waits for P1 (prints its exit value), waits for P2, then `exec`s `cat` to print the source file.
- **P1** waits for a pipe message `"hello from your child"` from P3.
- **P2** creates N children, waits for at least 2 of them, and prints their PIDs.

### Build

```bash
cd E2
gcc -Wall -o fork-process-tree fork-process-tree.c
```

### Run with default N=3 (P4, P5, P6)

```bash
./fork-process-tree
```

### Run with custom N

```bash
./fork-process-tree 5   # P2 creates 5 children instead of 3
```
