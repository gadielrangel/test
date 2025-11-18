# Justfile - Modern Task Runner
# https://github.com/casey/just
#
# Run `just` to see all available commands
# Run `just <command>` to execute a command

# Set shell for all recipes
set shell := ["bash", "-uc"]

# Default recipe - show help
default:
    @just --list --unsorted

# 🔨 Build the project
build:
    @echo "🔨 Building project..."
    zig build

# 🚀 Build and run the example application
run: build
    @echo "🚀 Running example..."
    ./zig-out/bin/menubar-example

# 🧪 Run all tests
test:
    @echo "🧪 Running tests..."
    zig build test

# ✨ Format all Zig code
fmt:
    @echo "✨ Formatting code..."
    zig fmt .

# 🔍 Check if code is formatted
fmt-check:
    @echo "🔍 Checking formatting..."
    zig fmt --check .

# 🏗️ Build in release mode
build-release:
    @echo "🏗️ Building release..."
    zig build -Doptimize=ReleaseFast

# 🧹 Clean build artifacts
clean:
    @echo "🧹 Cleaning..."
    rm -rf zig-out zig-cache .zig-cache

# ✅ Full validation (what CI runs)
check: fmt-check test
    @echo "✅ All checks passed!"

# 🔧 Development setup
setup:
    @mise run setup

# 🩺 Check development environment
doctor:
    @mise run doctor

# 📊 Show project statistics
stats:
    @echo "📊 Project Statistics"
    @echo "===================="
    @echo "Lines of code:"
    @find src -name "*.zig" | xargs wc -l | tail -1

# 🌐 Install system dependencies (Ubuntu/Debian)
install-deps-ubuntu:
    @echo "🌐 Installing system dependencies..."
    sudo apt-get update
    sudo apt-get install -y libgtk-3-dev
