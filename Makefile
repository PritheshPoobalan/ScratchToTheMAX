# ScratchToTheMAX Makefile

CC ?= cc
CFLAGS ?= -Wall -Wextra -Isrc/kernel

KERNEL_SRCS := $(wildcard src/kernel/*.c)
KERNEL_OBJS := $(KERNEL_SRCS:.c=.o)

all: kernel-tests

kernel-tests: $(KERNEL_OBJS)
	$(CC) $(CFLAGS) -o build/kernel-tests $(KERNEL_OBJS)

src/kernel/%.o: src/kernel/%.c
	$(CC) $(CFLAGS) -c $< -o $@

test:
	./tests/run_tests.sh

clean:
	rm -f build/kernel-tests src/kernel/*.o

.PHONY: all test clean
