/* errors.c - Johnsan compiler error reporting */
#include <stdio.h>

void johnsan_error(const char *msg) {
    fprintf(stderr, "johnsan: error: %s\n", msg);
}

/* Errors print to stderr and do not abort the process. */
