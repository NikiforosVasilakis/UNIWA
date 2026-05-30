/*
 * Περιγραφή:
 *   Server με UNIX-domain stream sockets. Κάθε client εξυπηρετείται σε ξεχωριστό thread.
 *   Λαμβάνει ακολουθία ακεραίων, υπολογίζει μέσο όρο:
 *     μ.ο. < 50  → "Sequence Ok (Μέσος Όρος: X.XX)"
 *     μ.ο. >= 50 → "Check Failed"
 *
 * Χρήση:
 *   gcc -Wall -o server server.c -lpthread
 *   ./server
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <pthread.h>
#include <sys/socket.h>
#include <sys/un.h>

#define SOCKET_PATH "/tmp/seq_sock"
#define BACKLOG     10
#define RESP_SIZE   128

/* Διαβάζει ακριβώς n bytes (χειρίζεται μερικές αναγνώσεις) */
static ssize_t readn(int fd, void *buf, size_t n)
{
    size_t left = n;
    char  *p    = buf;
    while (left > 0) {
        ssize_t r = read(fd, p, left);
        if (r <= 0) return r;
        p    += r;
        left -= (size_t)r;
    }
    return (ssize_t)n;
}

/* Thread: εξυπηρετεί έναν client μέχρι να κλείσει τη σύνδεση */
static void *handle_client(void *arg)
{
    int cfd = *(int *)arg;
    free(arg);

    int n;
    while (readn(cfd, &n, sizeof(int)) == sizeof(int)) {
        int *arr = malloc((size_t)n * sizeof(int));
        if (!arr || readn(cfd, arr, (size_t)n * sizeof(int)) != (ssize_t)(n * sizeof(int))) {
            free(arr);
            break;
        }

        long sum = 0;
        for (int i = 0; i < n; i++) sum += arr[i];
        double avg = (double)sum / n;

        printf("Ακολουθία από client (fd=%d): [", cfd);
        for (int i = 0; i < n; i++)
            printf(i < n - 1 ? "%d," : "%d", arr[i]);
        printf("]\n");
        fflush(stdout);

        free(arr);

        char resp[RESP_SIZE];
        if (avg < 50.0)
            snprintf(resp, sizeof(resp), "Sequence Ok (Μέσος Όρος: %.2f)", avg);
        else
            snprintf(resp, sizeof(resp), "Check Failed");

        write(cfd, resp, RESP_SIZE);

        /* Επανάληψη ακολουθίας όσο ο client απαντά 'y' */
        char ack;
        while (readn(cfd, &ack, 1) == 1 && (ack == 'y' || ack == 'Y'))
            write(cfd, resp, RESP_SIZE);
    }

    close(cfd);
    return NULL;
}

int main(void)
{
    int sfd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (sfd < 0) { perror("socket"); return EXIT_FAILURE; }

    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, SOCKET_PATH, sizeof(addr.sun_path) - 1);

    unlink(SOCKET_PATH);
    if (bind(sfd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        perror("bind"); return EXIT_FAILURE;
    }
    if (listen(sfd, BACKLOG) < 0) {
        perror("listen"); return EXIT_FAILURE;
    }

    printf("Server έτοιμος, αναμονή clients...\n");

    while (1) {
        int *cfd = malloc(sizeof(int));
        *cfd = accept(sfd, NULL, NULL);
        if (*cfd < 0) { free(cfd); continue; }

        pthread_t tid;
        pthread_create(&tid, NULL, handle_client, cfd);
        pthread_detach(tid);
    }

    close(sfd);
    unlink(SOCKET_PATH);
    return EXIT_SUCCESS;
}
