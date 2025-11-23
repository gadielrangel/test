#!/usr/bin/env bash
# Workflow Validation Script
# Validates GitHub Actions workflows for syntax, best practices, and common issues

set -uo pipefail  # Don't use -e so validation functions can fail gracefully

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

WORKFLOWS_DIR=".github/workflows"
ERRORS=0
WARNINGS=0
CHECKS=0

echo -e "${BLUE}🔍 GitHub Actions Workflow Validator${NC}"
echo "======================================="
echo ""

# Check if workflows directory exists
if [ ! -d "$WORKFLOWS_DIR" ]; then
    echo -e "${RED}✗ Workflows directory not found: $WORKFLOWS_DIR${NC}"
    exit 1
fi

# Function to validate YAML syntax
validate_yaml() {
    local file=$1
    ((CHECKS++))

    # Basic YAML validation using Python (portable)
    if command -v python3 &> /dev/null; then
        if python3 -c "import yaml, sys; yaml.safe_load(open('$file'))" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Valid YAML syntax: $(basename "$file")"
        else
            echo -e "${RED}✗${NC} Invalid YAML syntax: $(basename "$file")"
            ((ERRORS++))
            return 1
        fi
    else
        echo -e "${YELLOW}⚠${NC} Python3 not available, skipping YAML validation"
        ((WARNINGS++))
    fi
}

# Function to check required fields
check_required_fields() {
    local file=$1
    local filename=$(basename "$file")
    ((CHECKS++))

    local missing=()

    grep -q "^name:" "$file" || missing+=("name")
    grep -q "^on:" "$file" || missing+=("on/trigger")
    grep -q "^jobs:" "$file" || missing+=("jobs")

    if [ ${#missing[@]} -eq 0 ]; then
        echo -e "${GREEN}✓${NC} Required fields present: $filename"
    else
        echo -e "${RED}✗${NC} Missing required fields in $filename: ${missing[*]}"
        ((ERRORS++))
    fi
}

# Function to check for action versions
check_action_versions() {
    local file=$1
    local filename=$(basename "$file")
    ((CHECKS++))

    # Check for @main or @master (should use pinned versions)
    if grep -qE "uses:.*@(main|master)" "$file"; then
        echo -e "${YELLOW}⚠${NC} Unpinned action versions (@main/@master) in $filename"
        echo "   Consider using pinned versions (e.g., @v4) for reproducibility"
        ((WARNINGS++))
    else
        echo -e "${GREEN}✓${NC} Action versions pinned: $filename"
    fi
}

# Function to check for common best practices
check_best_practices() {
    local file=$1
    local filename=$(basename "$file")

    # Check for checkout action
    ((CHECKS++))
    if grep -q "actions/checkout@" "$file"; then
        echo -e "${GREEN}✓${NC} Uses checkout action: $filename"
    else
        echo -e "${YELLOW}⚠${NC} No checkout action found in $filename"
        ((WARNINGS++))
    fi

    # Check for caching
    ((CHECKS++))
    if grep -qE "(actions/cache@|cache:|Zig cache)" "$file"; then
        echo -e "${GREEN}✓${NC} Uses caching: $filename"
    else
        echo -e "${YELLOW}⚠${NC} No caching configured in $filename (may slow CI)"
        ((WARNINGS++))
    fi

    # Check for timeout
    ((CHECKS++))
    if grep -q "timeout-minutes:" "$file"; then
        echo -e "${GREEN}✓${NC} Job timeout configured: $filename"
    else
        echo -e "${YELLOW}⚠${NC} No timeout configured in $filename"
        ((WARNINGS++))
    fi
}

# Function to check CI workflow specifics
check_ci_workflow() {
    local file=$1
    echo ""
    echo -e "${BLUE}Validating CI Workflow${NC}"
    echo "----------------------"

    ((CHECKS++))
    if grep -q "zig build test" "$file"; then
        echo -e "${GREEN}✓${NC} Runs tests"
    else
        echo -e "${RED}✗${NC} No test execution found"
        ((ERRORS++))
    fi

    ((CHECKS++))
    if grep -q "zig fmt.*--check" "$file"; then
        echo -e "${GREEN}✓${NC} Checks code formatting"
    else
        echo -e "${RED}✗${NC} No format check found"
        ((ERRORS++))
    fi

    ((CHECKS++))
    if grep -q "zig build" "$file"; then
        echo -e "${GREEN}✓${NC} Builds project"
    else
        echo -e "${RED}✗${NC} No build step found"
        ((ERRORS++))
    fi

    # Check for GTK3 dependency installation
    ((CHECKS++))
    if grep -q "libgtk-3-dev" "$file"; then
        echo -e "${GREEN}✓${NC} Installs GTK3 dependencies"
    else
        echo -e "${RED}✗${NC} GTK3 dependencies not installed (required for build)"
        ((ERRORS++))
    fi
}

# Function to check release workflow specifics
check_release_workflow() {
    local file=$1
    echo ""
    echo -e "${BLUE}Validating Release Workflow${NC}"
    echo "----------------------------"

    ((CHECKS++))
    if grep -q "tags:" "$file"; then
        echo -e "${GREEN}✓${NC} Triggered by tags"
    else
        echo -e "${RED}✗${NC} Not triggered by tags (releases should use tags)"
        ((ERRORS++))
    fi

    ((CHECKS++))
    if grep -qE "v\*\.\*\.\*|v[0-9]" "$file"; then
        echo -e "${GREEN}✓${NC} Uses semantic version tags"
    else
        echo -e "${YELLOW}⚠${NC} Tag pattern doesn't match semantic versioning"
        ((WARNINGS++))
    fi

    ((CHECKS++))
    if grep -q "create-release\|create_release" "$file"; then
        echo -e "${GREEN}✓${NC} Creates GitHub release"
    else
        echo -e "${RED}✗${NC} No release creation found"
        ((ERRORS++))
    fi

    ((CHECKS++))
    if grep -q "sha256sum\|checksum" "$file"; then
        echo -e "${GREEN}✓${NC} Generates checksums"
    else
        echo -e "${YELLOW}⚠${NC} No checksum generation (recommended for security)"
        ((WARNINGS++))
    fi

    # Check for multi-platform builds
    ((CHECKS++))
    if grep -q "x86_64" "$file" && grep -q "aarch64" "$file"; then
        echo -e "${GREEN}✓${NC} Multi-platform builds configured (x86_64 + ARM64)"
    elif grep -qE "matrix:.*target" "$file"; then
        echo -e "${GREEN}✓${NC} Multi-platform builds configured (matrix strategy)"
    else
        echo -e "${YELLOW}⚠${NC} Only single platform build"
        ((WARNINGS++))
    fi
}

# Main validation loop
for workflow in "$WORKFLOWS_DIR"/*.yml "$WORKFLOWS_DIR"/*.yaml; do
    [ -f "$workflow" ] || continue

    echo ""
    echo -e "${BLUE}📄 Validating: $(basename "$workflow")${NC}"
    echo "----------------------------------------"

    validate_yaml "$workflow"
    check_required_fields "$workflow"
    check_action_versions "$workflow"
    check_best_practices "$workflow"

    # Workflow-specific checks
    case "$(basename "$workflow")" in
        ci.yml|ci.yaml)
            check_ci_workflow "$workflow"
            ;;
        release.yml|release.yaml)
            check_release_workflow "$workflow"
            ;;
    esac
done

# Summary
echo ""
echo "======================================="
echo -e "${BLUE}Validation Summary${NC}"
echo "======================================="
echo "Total checks: $CHECKS"
echo -e "${GREEN}✓ Passed${NC}"
echo -e "${YELLOW}⚠ Warnings: $WARNINGS${NC}"
echo -e "${RED}✗ Errors: $ERRORS${NC}"
echo ""

if [ $ERRORS -gt 0 ]; then
    echo -e "${RED}❌ Validation failed with $ERRORS error(s)${NC}"
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Validation passed with $WARNINGS warning(s)${NC}"
    exit 0
else
    echo -e "${GREEN}✅ All validations passed!${NC}"
    exit 0
fi
