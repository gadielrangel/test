# GitHub Actions Workflow Testing Guide

Complete guide for testing and validating GitHub Actions workflows locally before pushing to GitHub.

## Quick Start

```bash
# Validate workflow syntax and best practices
just validate-workflows

# Test CI workflow locally (requires Docker + act)
just test-ci
```

---

## Workflow Validation

### What is Validated?

Our validation script checks:

**✅ YAML Syntax**
- Valid YAML structure
- No syntax errors
- Proper indentation

**✅ Required Fields**
- Workflow name
- Trigger conditions (on:)
- Jobs definition

**✅ Action Versions**
- Pinned versions (no @main/@master)
- Reproducible builds

**✅ Best Practices**
- Checkout action present
- Caching configured
- Job timeouts set
- GTK3 dependencies installed

**✅ CI Workflow Specifics**
- Test execution
- Format checking
- Build steps
- Platform dependencies

**✅ Release Workflow Specifics**
- Tag-based triggers
- Semantic versioning
- Release creation
- Checksum generation
- Multi-platform builds

### Running Validation

```bash
# Via justfile (recommended)
just validate-workflows

# Direct script execution
./tools/validate_workflows.sh

# Check validation exists
[ -x tools/validate_workflows.sh ] && echo "Validator ready" || echo "Validator missing"
```

### Validation Output

```
🔍 GitHub Actions Workflow Validator
=======================================

📄 Validating: ci.yml
----------------------------------------
✓ Valid YAML syntax: ci.yml
✓ Required fields present: ci.yml
✓ Action versions pinned: ci.yml
✓ Uses checkout action: ci.yml
✓ Uses caching: ci.yml
✓ Job timeout configured: ci.yml

Validating CI Workflow
----------------------
✓ Runs tests
✓ Checks code formatting
✓ Builds project
✓ Installs GTK3 dependencies

📄 Validating: release.yml
----------------------------------------
✓ Valid YAML syntax: release.yml
✓ Required fields present: release.yml
✓ Action versions pinned: release.yml
✓ Uses checkout action: release.yml
✓ Uses caching: release.yml
✓ Job timeout configured: release.yml

Validating Release Workflow
----------------------------
✓ Triggered by tags
✓ Uses semantic version tags
✓ Creates GitHub release
✓ Generates checksums
✓ Multi-platform builds configured (x86_64 + ARM64)

=======================================
Validation Summary
=======================================
Total checks: 21
✓ Passed
⚠ Warnings: 0
✗ Errors: 0

✅ All validations passed!
```

---

## Local Testing with act

### What is act?

**act** is a tool that runs your GitHub Actions workflows locally using Docker. It simulates GitHub's hosted runners on your machine.

**Benefits:**
- Test workflows without pushing to GitHub
- Faster iteration cycles
- No CI/CD minutes consumed
- Catch errors early

**Links:**
- GitHub: https://github.com/nektos/act
- Docs: https://nektosact.com/

### Installation

**Linux:**
```bash
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash
```

**macOS:**
```bash
brew install act
```

**Via mise (when Docker is available):**
```bash
# Uncomment in .mise.toml:
# act = "latest"

mise install act
```

### Prerequisites

**Docker** is required for act to work:

```bash
# Check if Docker is installed
docker --version

# Ubuntu/Debian
sudo apt-get install docker.io
sudo usermod -aG docker $USER  # Add yourself to docker group
newgrp docker                   # Refresh groups

# Fedora
sudo dnf install docker
sudo systemctl start docker
sudo usermod -aG docker $USER

# Arch
sudo pacman -S docker
sudo systemctl start docker
sudo usermod -aG docker $USER
```

### Basic Usage

**List available workflows:**
```bash
act -l
```

**Test CI workflow:**
```bash
# Via justfile
just test-ci

# Direct execution
act -j build-and-test

# With verbose output
act -j build-and-test -v

# Dry run (show what would run)
act -j build-and-test -n
```

**Test specific event:**
```bash
# Test push event
act push

# Test pull request
act pull_request

# Test tag push (release workflow)
act -e tag.json  # Requires event file
```

**Select runner image:**
```bash
# Use medium Ubuntu image (recommended)
act -j build-and-test -P ubuntu-latest=catthehacker/ubuntu:act-latest

# Use full Ubuntu image (slower but more complete)
act -j build-and-test -P ubuntu-latest=catthehacker/ubuntu:full-latest

# Use micro image (fastest, minimal tools)
act -j build-and-test -P ubuntu-latest=node:16-buster-slim
```

### Testing Release Workflow

Create a test event file for tag pushes:

**`test/tag-event.json`:**
```json
{
  "ref": "refs/tags/v1.0.0",
  "repository": {
    "name": "menubar",
    "full_name": "user/menubar"
  }
}
```

**Run release workflow:**
```bash
act -e test/tag-event.json -j create-release
act -e test/tag-event.json -j build-release
```

### Common Options

```bash
# Show secrets used
act -j build-and-test --secret-file .secrets

# Reuse containers (faster subsequent runs)
act -j build-and-test --reuse

# Bind workspace (use local directory)
act -j build-and-test --bind

# Container architecture
act -j build-and-test --container-architecture linux/amd64

# Specify platform
act -j build-and-test --platform ubuntu-latest=catthehacker/ubuntu:act-latest
```

### Troubleshooting

**Issue: Docker permission denied**
```bash
# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Or run with sudo (not recommended)
sudo act -j build-and-test
```

**Issue: Large image downloads**
```bash
# Use micro image for faster testing
act -j build-and-test -P ubuntu-latest=node:16-buster-slim

# Pull image once, reuse containers
docker pull catthehacker/ubuntu:act-latest
act -j build-and-test --reuse
```

**Issue: Missing tools in container**
```bash
# Use full image (includes more tools)
act -j build-and-test -P ubuntu-latest=catthehacker/ubuntu:full-latest

# Or install in workflow (already done in our workflows)
```

**Issue: Secrets not available**
```bash
# Create .secrets file (gitignored)
echo "GITHUB_TOKEN=your_token" > .secrets
act -j build-and-test --secret-file .secrets

# Or set environment variable
GITHUB_TOKEN=your_token act -j build-and-test
```

---

## CI/CD Best Practices

### Workflow Design

**✅ DO:**
- Pin action versions (e.g., `@v4`, not `@main`)
- Set job timeouts to prevent hanging
- Cache dependencies for faster builds
- Use matrix builds for multi-platform support
- Generate checksums for releases
- Install all required dependencies explicitly

**❌ DON'T:**
- Use unpinned versions (`@main`, `@master`)
- Leave jobs without timeouts
- Rebuild without caching
- Hard-code platform-specific paths
- Skip dependency installation
- Assume tools are pre-installed

### Testing Strategy

**Before Pushing:**
1. Run `just validate-workflows` - catches syntax errors
2. Run `just test-ci` (if Docker available) - full local test
3. Run `just check` - ensures code quality
4. Push to feature branch first
5. Verify CI passes before merging to main

**On Every Push:**
- CI workflow runs automatically
- Tests, formatting, and build verified
- Feedback in ~1 minute

**On Tags:**
- Release workflow triggers automatically
- Multi-platform binaries built
- GitHub release created with assets

### Optimization Tips

**Faster CI:**
- Use caching (we do this ✅)
- Run jobs in parallel where possible
- Use specific runners (ubuntu-latest is fast)
- Minimize dependencies

**Faster Local Testing:**
- Use act with `--reuse` flag
- Use smaller Docker images for quick tests
- Run only changed workflows
- Cache Docker images locally

---

## Integration with Development Workflow

### Pre-Commit Hook

Validate workflows before committing:

```bash
# Add to .lefthook.yml
pre-commit:
  commands:
    validate-workflows:
      glob: ".github/workflows/*.{yml,yaml}"
      run: ./tools/validate_workflows.sh
```

### Git Hooks

```bash
# .git/hooks/pre-push
#!/bin/bash
echo "Validating workflows before push..."
just validate-workflows || exit 1
```

### CI/CD Pipeline

```yaml
# Add validation step to CI
- name: Validate workflows
  run: ./tools/validate_workflows.sh
```

---

## Continuous Improvement

### Monitoring

**Check workflow runs:**
```bash
# Via GitHub CLI
gh run list
gh run view <run-id>
gh run watch

# Check latest run status
gh run list --limit 1
```

**Workflow insights:**
- Track CI duration trends
- Monitor failure rates
- Identify slow steps
- Optimize caching strategies

### Regular Maintenance

**Monthly:**
- Update action versions (check for @v5, @v6, etc.)
- Review and remove unused workflows
- Check for deprecated actions
- Update runner images

**Quarterly:**
- Review timeout values
- Audit caching strategies
- Check for security updates
- Benchmark CI performance

---

## Reference

### File Locations

```
.github/workflows/ci.yml          # CI workflow
.github/workflows/release.yml     # Release workflow
tools/validate_workflows.sh       # Validation script
.mise.toml                        # Tool versions (includes act)
justfile                          # Task runner (validate-workflows, test-ci)
```

### Commands Summary

```bash
# Validation
just validate-workflows           # Validate workflow files
./tools/validate_workflows.sh     # Direct validation

# Local testing (requires Docker + act)
just test-ci                      # Test CI workflow
act -l                           # List available jobs
act -j <job-name>                # Run specific job
act push                         # Simulate push event

# GitHub CLI (requires gh)
gh run list                      # List workflow runs
gh run watch                     # Watch latest run
gh workflow list                 # List workflows
```

### Exit Codes

```
0 - All validations passed
1 - Validation errors found
Non-zero - Script error
```

### Resources

- **act documentation**: https://nektosact.com/
- **GitHub Actions docs**: https://docs.github.com/en/actions
- **Action version finder**: https://github.com/actions
- **Workflow syntax**: https://docs.github.com/en/actions/reference/workflow-syntax-for-github-actions

---

*Last updated: November 2024*
