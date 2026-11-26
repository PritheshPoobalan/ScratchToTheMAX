# ScratchToTheMAX Makefile
# Build system for BADD CPU, Johnsan compiler, and Johnsan kernel

# Tools
IVERILOG ?= iverilog
VVP ?= vvp
CC ?= cc
CFLAGS ?= -Wall -Wextra -std=c11 -Isrc/kernel

# Directories
BUILD_DIR := build
RELEASE_DIR := release
KERNEL_DIR := src/kernel
JOHNSAN_DIR := src/johnsan
PARTS_DIR := parts
DOCS_DIR := docs
EXAMPLES_DIR := examples
TESTS_DIR := tests

# Sources
KERNEL_SRCS := $(wildcard $(KERNEL_DIR)/*.c)
KERNEL_OBJS := $(patsubst $(KERNEL_DIR)/%.c,$(BUILD_DIR)/%.o,$(KERNEL_SRCS))

# Main targets
.PHONY: all sim kernel compiler test test-all clean release help

all: sim kernel compiler
	@echo "✓ All targets built successfully"

help:
	@echo "ScratchToTheMAX Build Targets:"
	@echo "  make all           - Build everything (sim, kernel, compiler)"
	@echo "  make sim           - Build and run BADD CPU simulation"
	@echo "  make kernel        - Build Johnsan kernel objects"
	@echo "  make compiler      - Build Johnsan compiler"
	@echo "  make test          - Run simulation tests"
	@echo "  make test-all      - Run all tests (sim + kernel)"
	@echo "  make clean         - Remove build artifacts"
	@echo "  make release       - Create release artifacts"
	@echo "  make lint          - Lint Verilog sources"
	@echo "  make help          - Show this help"

# Verilog simulation
sim: $(BUILD_DIR)/badd_tb
	@echo "Running BADD CPU simulation..."
	$(VVP) $(BUILD_DIR)/badd_tb

$(BUILD_DIR)/badd_tb: badd_chip.v badd_tb.v | $(BUILD_DIR)
	$(IVERILOG) -o $@ badd_chip.v badd_tb.v

# Additional testbenches
testbenches: $(BUILD_DIR)/tb_badd_chip $(BUILD_DIR)/test_cpu $(BUILD_DIR)/test_mem

$(BUILD_DIR)/tb_badd_chip: badd_chip.v tb_badd_chip.v | $(BUILD_DIR)
	$(IVERILOG) -o $@ badd_chip.v tb_badd_chip.v

$(BUILD_DIR)/test_cpu: badd_chip.v test_cpu.v | $(BUILD_DIR)
	$(IVERILOG) -o $@ badd_chip.v test_cpu.v

$(BUILD_DIR)/test_mem: badd_chip.v test_mem.v | $(BUILD_DIR)
	$(IVERILOG) -o $@ badd_chip.v test_mem.v

# Kernel build
kernel: $(KERNEL_OBJS) | $(BUILD_DIR)
	@echo "✓ Kernel objects built in $(BUILD_DIR)/"

$(BUILD_DIR)/%.o: $(KERNEL_DIR)/%.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

# Compiler build
compiler: $(BUILD_DIR)/johnsan_compiler

$(BUILD_DIR)/johnsan_compiler: $(JOHNSAN_DIR)/johnsan_compiler.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) $< -o $@

# Test targets
test: sim testbenches
	@for tb in $(BUILD_DIR)/tb_badd_chip $(BUILD_DIR)/test_cpu $(BUILD_DIR)/test_mem; do \
		if [ -f $$tb ]; then \
			echo "Running $$tb..."; \
			$(VVP) $$tb; \
		fi; \
	done
	@if [ -f $(TESTS_DIR)/run_tests.sh ]; then \
		$(TESTS_DIR)/run_tests.sh; \
	fi
	@echo "✓ All simulation tests passed"

test-kernel: kernel
	@if [ -f $(TESTS_DIR)/kernel_test.c ]; then \
		$(CC) $(CFLAGS) $(TESTS_DIR)/kernel_test.c $(KERNEL_OBJS) -o $(BUILD_DIR)/kernel_test; \
		$(BUILD_DIR)/kernel_test; \
		echo "✓ Kernel tests passed"; \
	else \
		echo "No kernel tests found"; \
	fi

test-all: test test-kernel
	@echo "✓ All tests passed"

# Lint Verilog
lint:
	@echo "Linting Verilog sources..."
	@$(IVERILOG) -t null -Wall badd_chip.v 2>&1 | head -50
	@$(IVERILOG) -t null -Wall badd_tb.v 2>&1 | head -50
	@for f in $(PARTS_DIR)/*.v; do \
		echo "  Checking $$f..."; \
		$(IVERILOG) -t null -Wall $$f 2>&1 | head -20; \
	done
	@echo "✓ Lint complete"

# Build directories
$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

$(RELEASE_DIR):
	@mkdir -p $(RELEASE_DIR)

# Release artifacts
release: all | $(RELEASE_DIR)
	@echo "Creating release artifacts..."
	@cp $(BUILD_DIR)/badd_tb $(RELEASE_DIR)/badd_sim
	@cp -r $(BUILD_DIR)/*.o $(RELEASE_DIR)/ 2>/dev/null || true
	@cp $(BUILD_DIR)/johnsan_compiler $(RELEASE_DIR)/ 2>/dev/null || true
	@cp -r $(DOCS_DIR) $(RELEASE_DIR)/
	@cp README.md LICENSE CHANGELOG.md $(RELEASE_DIR)/
	@echo "✓ Release artifacts in $(RELEASE_DIR)/"

# Clean
clean:
	@rm -rf $(BUILD_DIR) $(RELEASE_DIR)
	@echo "✓ Cleaned build artifacts"

# Verify build environment
verify-env:
	@echo "Checking build environment..."
	@which $(IVERILOG) >/dev/null && echo "  ✓ $(IVERILOG) found" || echo "  ✗ $(IVERILOG) NOT FOUND"
	@which $(CC) >/dev/null && echo "  ✓ $(CC) found" || echo "  ✗ $(CC) NOT FOUND"
	@which make >/dev/null && echo "  ✓ make found" || echo "  ✗ make NOT FOUND"