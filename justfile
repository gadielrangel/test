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

# 🔍 Validate build configuration
validate-build:
    @echo "🔍 Validating build configuration..."
    @./tools/validate_build.sh

# 🔍 Validate GitHub Actions workflows
validate-workflows:
    @echo "🔍 Validating GitHub Actions workflows..."
    @./tools/validate_workflows.sh

# ✅ Validate everything (build config + workflows)
validate-all: validate-build validate-workflows
    @echo "✅ All validations passed!"

# 🚀 Test GitHub Actions locally (requires Docker + act)
test-ci:
    @echo "🚀 Testing CI workflow locally..."
    @if command -v act &> /dev/null; then \
        act -j build-and-test; \
    else \
        echo "❌ act not installed. Install: curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash"; \
        exit 1; \
    fi

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

# 🔁 Rebuild from scratch
rebuild: clean build
    @echo "🔁 Rebuild complete!"

# 👀 Watch and rebuild on changes (requires inotifywait)
watch:
    @echo "👀 Watching for changes..."
    @while true; do \
        inotifywait -q -r -e modify,create,delete src/ build.zig 2>/dev/null || \
        (echo "⚠️  Install inotify-tools for watch mode: sudo apt-get install inotify-tools" && exit 1); \
        clear; \
        echo "🔄 Rebuilding..."; \
        zig build 2>&1 && echo "✅ Build successful!" || echo "❌ Build failed!"; \
    done

# 🌐 Install system dependencies (Ubuntu/Debian)
install-deps-ubuntu:
    @echo "🌐 Installing system dependencies..."
    sudo apt-get update
    sudo apt-get install -y libgtk-3-dev

# 🌐 Install system dependencies (Fedora/RHEL)
install-deps-fedora:
    @echo "🌐 Installing system dependencies..."
    sudo dnf install -y gtk3-devel

# 🌐 Install system dependencies (Arch)
install-deps-arch:
    @echo "🌐 Installing system dependencies..."
    sudo pacman -S --needed gtk3
