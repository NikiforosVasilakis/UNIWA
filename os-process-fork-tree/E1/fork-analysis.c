#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>

int main(void)
{
    pid_t pid1, pid2, pid3, pid4, pid5;

    printf("=== Fork-tree analysis ===\n");
    printf("P0: PID=%-6d  (initial process)\n\n", (int)getpid());
    fflush(stdout);
    pid1 = fork();

    if (pid1 != 0) {

        pid2 = fork();

        if (pid2 != 0) {
            printf("[P0 ]  PID=%-6d  PPID=%-6d  pid1=%-6d  pid2=%-6d"
                   "  (initial)\n",
                   (int)getpid(), (int)getppid(), (int)pid1, (int)pid2);
        } else {
            printf("[P2 ]  PID=%-6d  PPID=%-6d  pid2==0"
                   "  (child of P0, from pid2=fork)\n",
                   (int)getpid(), (int)getppid());
        }
        fflush(stdout);

    } else {

        pid3 = fork();

        pid4 = fork();

        pid5 = fork();

        /* identify each process by the combination of pid3/pid4/pid5 */
        if (pid3 != 0 && pid4 != 0 && pid5 != 0)
            printf("[P1 ]  PID=%-6d  PPID=%-6d  (child of P0, from pid1=fork, else)\n",
                   (int)getpid(), (int)getppid());

        else if (pid3 == 0 && pid4 != 0 && pid5 != 0)
            printf("[P3 ]  PID=%-6d  PPID=%-6d  (child of P1, from pid3=fork)\n",
                   (int)getpid(), (int)getppid());

        else if (pid3 != 0 && pid4 == 0 && pid5 != 0)
            printf("[P4 ]  PID=%-6d  PPID=%-6d  (child of P1, from pid4=fork)\n",
                   (int)getpid(), (int)getppid());

        else if (pid3 == 0 && pid4 == 0 && pid5 != 0)
            printf("[P5 ]  PID=%-6d  PPID=%-6d  (child of P3, from pid4=fork)\n",
                   (int)getpid(), (int)getppid());

        else if (pid3 != 0 && pid4 != 0 && pid5 == 0)
            printf("[P6 ]  PID=%-6d  PPID=%-6d  (child of P1, from pid5=fork)\n",
                   (int)getpid(), (int)getppid());

        else if (pid3 == 0 && pid4 != 0 && pid5 == 0)
            printf("[P7 ]  PID=%-6d  PPID=%-6d  (child of P3, from pid5=fork)\n",
                   (int)getpid(), (int)getppid());

        else if (pid3 != 0 && pid4 == 0 && pid5 == 0)
            printf("[P8 ]  PID=%-6d  PPID=%-6d  (child of P4, from pid5=fork)\n",
                   (int)getpid(), (int)getppid());

        else /* pid3==0 && pid4==0 && pid5==0 */
            printf("[P9 ]  PID=%-6d  PPID=%-6d  (child of P5, from pid5=fork)\n",
                   (int)getpid(), (int)getppid());

        fflush(stdout);
    }

    /* each process waits for its children */
    while (wait(NULL) > 0)
        ;

    return 0;
}
