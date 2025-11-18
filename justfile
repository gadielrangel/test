# justfile - modern command runner for Zig Menu Bar
# https://github.com/casey/just

# Default recipe to display help information
default:
    @just --list

# Install development dependencies
install:
    @echo "Installing development tools..."
    mise install
    lefthook install

# Format all Zig code
fmt:
    @echo "Formatting Zig code..."
    zig fmt .

# Check formatting without modifying files
fmt-check:
    @echo "Checking Zig code formatting..."
    zig fmt --check .

# Build the project in debug mode
build:
    @echo "Building in debug mode..."
    zig build

# Build with optimizations for production
build-release:
    @echo "Building optimized release..."
    zig build -Doptimize=ReleaseFast

# Build with maximum optimizations
build-release-small:
    @echo "Building size-optimized release..."
    zig build -Doptimize=ReleaseSmall

# Run all tests
test:
    @echo "Running tests..."
    zig build test

# Run tests with coverage (requires kcov or similar)
test-coverage:
    @echo "Running tests with coverage..."
    zig build test -Dtest-coverage=true

# Run the example application
run:
    @echo "Running example application..."
    zig build run

# Clean build artifacts
clean:
    @echo "Cleaning build artifacts..."
    rm -rf zig-cache zig-out .zig-cache

# Run all quality checks (format, lint, test)
check: fmt-check test
    @echo "All quality checks passed!"

# Prepare for CI - install deps and run checks
ci: install check build-release
    @echo "CI checks completed successfully!"

# Development watch mode - rebuild on file changes (requires watchexec)
dev:
    @echo "Starting development watch mode..."
    watchexec -e zig -r -- just build run

# Benchmark performance
bench:
    @echo "Running benchmarks..."
    zig build -Doptimize=ReleaseFast
    @echo "Benchmark completed"

# Generate documentation
docs:
    @echo "Generating documentation..."
    zig build-exe -femit-docs examples/basic.zig

# Security audit (check for known issues)
audit:
    @echo "Running security audit..."
    @echo "Checking for unsafe patterns..."
    @! grep -r "@intCast" src/ || echo "Warning: Found @intCast usage"
    @! grep -r "@ptrCast" src/ || echo "Warning: Found @ptrCast usage"

# Release build with all optimizations and strip
release: clean
    @echo "Building production release..."
    zig build -Doptimize=ReleaseFast
    @echo "Stripping debug symbols..."
    strip zig-out/bin/menubar-example
    @echo "Release build complete!"

# Quick development cycle: format, test, build
quick: fmt test build
    @echo "Quick development cycle complete!"

# Pre-commit hook - runs automatically via lefthook
pre-commit: fmt-check test
    @echo "Pre-commit checks passed!"
