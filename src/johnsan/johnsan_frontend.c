/* johnsan_frontend.c - Johnsan compiler frontend: lexer and tokenizer */
#include <stdio.h>
#include <ctype.h>

/* Tokenize a Johnsan source line into words. */
int johnsan_tokenize(const char *src, char *out, int out_size) {
    int n = 0;
    while (*src && n < out_size - 1) {
        while (isspace((unsigned char)*src)) src++;
        if (!*src) break;
        out[n++] = *src++;
    }
    out[n] = '\0';
    return n;
}

/* Skip leading whitespace before returning the next token. */

/* Return the number of tokens written. */
