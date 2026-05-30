#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>

#define HELLO_MSG  "hello from your child"
#define SRC_FILE   __FILE__

int main(int argc, char *argv[])
{
    /* N = number of direct children P2 creates (default 3 → P4, P5, P6) */
    int N = 3;
    if (argc >= 2) {
        N = atoi(argv[1]);
        if (N < 1) { fprintf(stderr, "N must be >= 1\n"); return 1; }
    }

    pid_t pid1, pid2;

    /*fork p1 */
    pid1 = fork();
    if (pid1 < 0) { perror("fork(P1)"); exit(EXIT_FAILURE); }

    if (pid1 == 0) {

        int fd[2];
        if (pipe(fd) == -1) { perror("pipe"); exit(EXIT_FAILURE); }

        /* fork P3 */
        pid_t pid3 = fork();
        if (pid3 < 0) { perror("fork(P3)"); exit(EXIT_FAILURE); }

        if (pid3 == 0) {
            
            close(fd[0]); /* P3 only writes */

            printf("[P3] PID=%-6d  PPID=%-6d\n",
                   (int)getpid(), (int)getppid());
            fflush(stdout);

            const char *msg = HELLO_MSG;
            if (write(fd[1], msg, strlen(msg) + 1) == -1)
                perror("write");
            close(fd[1]);
            exit(EXIT_SUCCESS);
        }

        /* P1: read message sent by P3 */
        close(fd[1]); /* P1 only reads */

        char buf[128] = {0};
        ssize_t n = read(fd[0], buf, sizeof(buf) - 1);
        close(fd[0]);
        if (n > 0)
            printf("[P1] Received from P3: \"%s\"\n", buf);

        waitpid(pid3, NULL, 0);

        printf("[P1] PID=%-6d  PPID=%-6d  -> exiting with value 42\n",
               (int)getpid(), (int)getppid());
        fflush(stdout);
        exit(42);
    }


    /* fork P2 */
    pid2 = fork();
    if (pid2 < 0) { perror("fork(P2)"); exit(EXIT_FAILURE); }

    if (pid2 == 0) {
        printf("[P2] PID=%-6d  PPID=%-6d  (creating %d children)\n",
               (int)getpid(), (int)getppid(), N);
        fflush(stdout);

        for (int i = 0; i < N; i++) {
            pid_t child = fork();
            if (child < 0) { perror("fork(P2->child)"); exit(EXIT_FAILURE); }

            if (child == 0) {
                printf("[P%-2d] PID=%-6d  PPID=%-6d\n",
                       4 + i, (int)getpid(), (int)getppid());
                fflush(stdout);
                exit(EXIT_SUCCESS);
            }
        }

        /* wait for at least 2 children and print their PIDs */
        int reaped = 0;
        pid_t finished;
        int st;
        printf("[P2] Waiting for at least 2 children to finish...\n");
        fflush(stdout);

        while ((finished = wait(&st)) > 0) {
            reaped++;
            printf("[P2] Child PID=%-6d finished (exit value=%d)\n",
                   (int)finished,
                   WIFEXITED(st) ? WEXITSTATUS(st) : -1);
            fflush(stdout);
            if (reaped >= 2) break;
        }
        while (wait(NULL) > 0)
            ;

        exit(EXIT_SUCCESS);
    }

    
    /* P0*/
    printf("[P0] PID=%-6d  PPID=%-6d  (P1=%d  P2=%d)\n",
           (int)getpid(), (int)getppid(), (int)pid1, (int)pid2);
    fflush(stdout);

    /* wait for P1 and print its exit value */
    int st;
    waitpid(pid1, &st, 0);
    if (WIFEXITED(st))
        printf("[P0] P1 (PID=%d) exit value: %d\n", (int)pid1, WEXITSTATUS(st));

    /* wait for P2 before exec so output is clean and P2 is never orphaned */
    waitpid(pid2, NULL, 0);
    fflush(stdout);

    /*replace P0 with 'cat' to print this source file */
    printf("[P0] Replacing process with: cat %s\n", SRC_FILE);
    fflush(stdout);

    execlp("cat", "cat", SRC_FILE, NULL);
    perror("execlp(cat)");
    exit(EXIT_FAILURE);
}
