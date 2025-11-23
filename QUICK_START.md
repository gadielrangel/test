# Quick Start Guide

Get productive in < 2 minutes.

## Setup

```bash
# 1. Install Mise (one-time)
curl https://mise.run | sh

# 2. Clone and setup
git clone <repo-url>
cd <repo-name>
mise install
just setup

# 3. Start coding!
just build
just run
```

## Common Commands

```bash
just            # List all commands
just build      # Build project
just test       # Run tests
just run        # Run example
just check      # Full validation
just fmt        # Format code
just doctor     # Check environment
```

## Git Workflow

```bash
# Make changes
vim src/menu.zig

# Commit (auto-formats)
git commit -m "feat: new feature"

# Push (CI validates)
git push
```

## Troubleshooting

### Mise not found
```bash
# Add to shell profile
eval "$(~/.local/bin/mise activate bash)"
source ~/.bashrc
```

### GTK3 not found
```bash
# Ubuntu/Debian
just install-deps-ubuntu
```

## Next Steps

- Check `README.md` for API docs
- See `docs/DEPLOYMENT_STRATEGY.md` for details
- Run `just doctor` to verify setup
