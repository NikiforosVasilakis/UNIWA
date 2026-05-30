/*
 * Περιγραφή:
 *   Τρία POSIX threads τυπώνουν κυκλικά "What A Wonderful World!".
 *   Thread1: "What A " | Thread2: "Wonderful " | Thread3: "World! "
 *   Συγχρονισμός με named POSIX semaphores (sem_open) — ένας ανά thread.
 *   Κάθε thread κάνει sem_wait στον δικό του και sem_post στον επόμενο,
 *   επιβάλλοντας την αλυσίδα T1→T2→T3→T1. Προτιμήθηκαν έναντι condition
 *   variables λόγω απλούστερης υλοποίησης χωρίς mutex/predicate.
 *
 * Χρήση:
 *   gcc -Wall -o wonderful B_wonderful_world_sync.c -lpthread
 *   ./wonderful [επαναλήψεις]   (προεπιλογή: 5)
 */

#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <semaphore.h>
#include <fcntl.h>

/* Αριθμός επαναλήψεων (ορίζεται προαιρετικά από γραμμή εντολών) */
static int iterations = 5;

/* Ονόματα named semaphores — sem_open χρησιμοποιείται αντί sem_init (deprecated σε macOS) */
#define SEM_NAME_0 "/wonderful_sem0"
#define SEM_NAME_1 "/wonderful_sem1"
#define SEM_NAME_2 "/wonderful_sem2"

/* Ένας σημαφόρος ανά thread: [0]→T1, [1]→T2, [2]→T3 */
static sem_t *sem_ptr[3];

/* Κλείνει και διαγράφει τους named semaphores */
static void cleanup_semaphores(void)
{
    if (sem_ptr[0] && sem_ptr[0] != SEM_FAILED) { sem_close(sem_ptr[0]); }
    if (sem_ptr[1] && sem_ptr[1] != SEM_FAILED) { sem_close(sem_ptr[1]); }
    if (sem_ptr[2] && sem_ptr[2] != SEM_FAILED) { sem_close(sem_ptr[2]); }
    sem_unlink(SEM_NAME_0);
    sem_unlink(SEM_NAME_1);
    sem_unlink(SEM_NAME_2);
}

/* Thread 1: τυπώνει "What A " */
static void *thread_what(void *arg)
{
    (void)arg;

    for (int i = 0; i < iterations; i++) {
        sem_wait(sem_ptr[0]);
        printf("What A ");
        fflush(stdout);
        sem_post(sem_ptr[1]);
    }

    return NULL;
}

/* Thread 2: τυπώνει "Wonderful " */
static void *thread_wonderful(void *arg)
{
    (void)arg;

    for (int i = 0; i < iterations; i++) {
        sem_wait(sem_ptr[1]);
        printf("Wonderful ");
        fflush(stdout);
        sem_post(sem_ptr[2]);
    }

    return NULL;
}

/* Thread 3: τυπώνει "World! " */
static void *thread_world(void *arg)
{
    (void)arg;

    for (int i = 0; i < iterations; i++) {
        sem_wait(sem_ptr[2]);
        printf("World! ");
        fflush(stdout);
        sem_post(sem_ptr[0]); /* επιστροφή στο Thread 1 */
    }

    return NULL;
}

int main(int argc, char *argv[])
{
    if (argc == 2) {
        int n = atoi(argv[1]);
        if (n <= 0) {
            fprintf(stderr, "Χρήση: %s [επαναλήψεις > 0]\n", argv[0]);
            return EXIT_FAILURE;
        }
        iterations = n;
    }

    /* sem[0]=1 (T1 ξεκινά αμέσως), sem[1]=sem[2]=0 (T2,T3 αναμένουν) */
    sem_unlink(SEM_NAME_0);
    sem_unlink(SEM_NAME_1);
    sem_unlink(SEM_NAME_2);

    sem_ptr[0] = sem_open(SEM_NAME_0, O_CREAT | O_EXCL, 0600, 1);
    sem_ptr[1] = sem_open(SEM_NAME_1, O_CREAT | O_EXCL, 0600, 0);
    sem_ptr[2] = sem_open(SEM_NAME_2, O_CREAT | O_EXCL, 0600, 0);

    if (sem_ptr[0] == SEM_FAILED || sem_ptr[1] == SEM_FAILED ||
        sem_ptr[2] == SEM_FAILED) {
        perror("sem_open");
        cleanup_semaphores();
        return EXIT_FAILURE;
    }

    pthread_t t1, t2, t3;

    pthread_create(&t1, NULL, thread_what,      NULL);
    pthread_create(&t2, NULL, thread_wonderful, NULL);
    pthread_create(&t3, NULL, thread_world,     NULL);

    pthread_join(t1, NULL);
    pthread_join(t2, NULL);
    pthread_join(t3, NULL);

    printf("\n");
    cleanup_semaphores();

    return EXIT_SUCCESS;
}
