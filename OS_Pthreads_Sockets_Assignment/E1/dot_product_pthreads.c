/*
 * dot_product_pthreads.c
 *
 * Παράλληλος υπολογισμός εσωτερικού γινομένου δύο διανυσμάτων Α και Β
 * μήκους n, χρησιμοποιώντας p POSIX Threads. Κάθε thread υπολογίζει
 * το επιμέρους άθροισμα n/p όρων τοπικά (local_sum) και στη συνέχεια
 * ενημερώνει την κοινή μεταβλητή total_sum μέσα στο κρίσιμο τμήμα
 * που προστατεύεται από mutex (αμοιβαίος αποκλεισμός).
 *
 * Μεταγλώττιση: gcc -O2 -o dot_product_pthreads dot_product_pthreads.c -lpthread
 * Χρήση:        ./dot_product_pthreads <n> <p>
 *               Το n πρέπει να είναι θετικό πολλαπλάσιο του p.
 *               Τα διανύσματα αρχικοποιούνται με τυχαίους αριθμούς.
 *
 * Χρονομέτρηση: Μετριέται ο wall-clock χρόνος με clock_gettime(CLOCK_MONOTONIC).
 *               Δοκιμάστε με p = 1, 2, 4, 8 threads για σύγκριση επιδόσεων.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <time.h>

/* ---------- κοινά (shared) δεδομένα ---------- */

static long   n;              /* μήκος διανυσμάτων (πολλαπλάσιο του p)  */
static int    p;              /* αριθμός threads                         */
static double *A, *B;         /* διανύσματα εισόδου                      */

static double        total_sum = 0.0;   /* αθροίζει τα επιμέρους αθροίσματα */
static pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;

/* ---------- δομή ορισμάτων ανά thread ---------- */

typedef struct {
    long start;   /* αρχικός δείκτης που ανήκει στο thread (συμπεριλαμβάνεται) */
    long end;     /* τελικός δείκτης που ανήκει στο thread (αποκλείεται)        */
} ThreadArg;

/* ---------- συνάρτηση thread ---------- */

static void *dot_partial(void *arg)
{
    ThreadArg *targ = (ThreadArg *)arg;
    double local_sum = 0.0;

    /* Υπολογισμός επιμέρους εσωτερικού γινομένου — δεν απαιτείται κοινή πρόσβαση εδώ */
    for (long i = targ->start; i < targ->end; i++) {
        local_sum += A[i] * B[i];
    }

    /* ---- κρίσιμο τμήμα: ενημέρωση της κοινής total_sum ---- */
    pthread_mutex_lock(&mutex);
    total_sum += local_sum;
    pthread_mutex_unlock(&mutex);
    /* --------------------------------------------------------- */

    return NULL;
}

/* ---------- βοηθητικές συναρτήσεις ---------- */

static double elapsed_ms(struct timespec t0, struct timespec t1)
{
    return (t1.tv_sec - t0.tv_sec) * 1000.0
         + (t1.tv_nsec - t0.tv_nsec) / 1e6;
}

static void fill_random(double *v, long len)
{
    for (long i = 0; i < len; i++)
        v[i] = (double)rand() / ((double)RAND_MAX + 1.0);
}

/* ---------- κύρια συνάρτηση ---------- */

int main(int argc, char *argv[])
{
    if (argc != 3) {
        fprintf(stderr, "Χρήση: %s <n> <p>\n"
                        "  n : μήκος διανυσμάτων (θετικό, πολλαπλάσιο του p)\n"
                        "  p : αριθμός threads (θετικό)\n", argv[0]);
        return EXIT_FAILURE;
    }

    n = atol(argv[1]);
    p = atoi(argv[2]);

    if (n <= 0 || p <= 0) {
        fprintf(stderr, "Σφάλμα: τα n και p πρέπει να είναι θετικοί ακέραιοι.\n");
        return EXIT_FAILURE;
    }
    if (n % p != 0) {
        fprintf(stderr, "Σφάλμα: το n (%ld) πρέπει να είναι πολλαπλάσιο του p (%d).\n", n, p);
        return EXIT_FAILURE;
    }

    /* Δέσμευση μνήμης για τα διανύσματα */
    A = (double *)malloc((size_t)n * sizeof(double));
    B = (double *)malloc((size_t)n * sizeof(double));
    if (!A || !B) {
        fprintf(stderr, "Σφάλμα: αποτυχία δέσμευσης μνήμης.\n");
        free(A); free(B);
        return EXIT_FAILURE;
    }

    srand((unsigned)time(NULL));
    fill_random(A, n);
    fill_random(B, n);

    /* Δέσμευση μνήμης για τα thread handles και τα ορίσματα */
    pthread_t  *threads = (pthread_t  *)malloc((size_t)p * sizeof(pthread_t));
    ThreadArg  *args    = (ThreadArg  *)malloc((size_t)p * sizeof(ThreadArg));
    if (!threads || !args) {
        fprintf(stderr, "Σφάλμα: αποτυχία δέσμευσης μνήμης.\n");
        free(A); free(B); free(threads); free(args);
        return EXIT_FAILURE;
    }

    long chunk = n / p;

    /* Αρχικοποίηση κοινής μεταβλητής */
    total_sum = 0.0;

    /* Έναρξη μέτρησης χρόνου */
    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);

    /* Δημιουργία threads */
    for (int i = 0; i < p; i++) {
        args[i].start = (long)i * chunk;
        args[i].end   = args[i].start + chunk;
        if (pthread_create(&threads[i], NULL, dot_partial, &args[i]) != 0) {
            fprintf(stderr, "Σφάλμα: pthread_create απέτυχε για το thread %d.\n", i);
            /* Αναμονή των ήδη δημιουργημένων threads πριν την έξοδο */
            for (int j = 0; j < i; j++) pthread_join(threads[j], NULL);
            free(A); free(B); free(threads); free(args);
            return EXIT_FAILURE;
        }
    }

    /* Αναμονή ολοκλήρωσης όλων των threads */
    for (int i = 0; i < p; i++) {
        pthread_join(threads[i], NULL);
    }

    /* Λήξη μέτρησης χρόνου */
    clock_gettime(CLOCK_MONOTONIC, &t1);

    printf("n                = %ld\n", n);
    printf("p (threads)      = %d\n",  p);
    printf("εσωτερικό γινόμενο = %.6f\n", total_sum);
    printf("χρόνος           = %.3f ms\n", elapsed_ms(t0, t1));

    /* Καταστροφή mutex και αποδέσμευση μνήμης */
    pthread_mutex_destroy(&mutex);
    free(A); free(B); free(threads); free(args);

    return EXIT_SUCCESS;
}
