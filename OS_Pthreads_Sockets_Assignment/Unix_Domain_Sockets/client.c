/*
 * Περιγραφή:
 *   Client που επικοινωνεί με τον server μέσω UNIX-domain stream socket.
 *   Στέλνει ακολουθίες ακεραίων, εκτυπώνει την απάντηση και επαναλαμβάνει
 *   μέχρι ο χρήστης να επιλέξει τερματισμό.
 *
 * Χρήση:
 *   gcc -Wall -o client client.c
 *   ./client
 *   (ο server πρέπει να τρέχει πριν ξεκινήσει ο client)
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>

#define SOCKET_PATH "/tmp/seq_sock"
#define RESP_SIZE   128

int main(void)
{
    int sfd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (sfd < 0) { perror("socket"); return EXIT_FAILURE; }

    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, SOCKET_PATH, sizeof(addr.sun_path) - 1);

    if (connect(sfd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        perror("connect"); return EXIT_FAILURE;
    }

    char again;
    do {
        int n;
        printf("Πλήθος ακεραίων: ");
        if (scanf("%d", &n) != 1 || n <= 0) break;

        int *arr = malloc((size_t)n * sizeof(int));
        for (int i = 0; i < n; i++) {
            printf("  [%d]: ", i + 1);
            scanf("%d", &arr[i]);
        }

        /* Αποστολή πλήθους και ακολουθίας στον server */
        write(sfd, &n, sizeof(int));
        write(sfd, arr, (size_t)n * sizeof(int));
        free(arr);

        /* Λήψη και εκτύπωση απάντησης, επανάληψη αν ο χρήστης επιλέξει */
        char resp[RESP_SIZE];
        if (read(sfd, resp, RESP_SIZE) > 0)
            printf("Server: %s\n", resp);

        char repeat;
        do {
            printf("Επανάληψη ακολουθίας; (y/n): ");
            scanf(" %c", &repeat);
            write(sfd, &repeat, 1);
            if (repeat == 'y' || repeat == 'Y') {
                if (read(sfd, resp, RESP_SIZE) > 0)
                    printf("Server: %s\n", resp);
            }
        } while (repeat == 'y' || repeat == 'Y');

        printf("Νέα ακολουθία; (y/n): ");
        scanf(" %c", &again);

    } while (again == 'y' || again == 'Y');

    close(sfd);
    return EXIT_SUCCESS;
}
