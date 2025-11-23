#!/usr/bin/env bash
# Build Configuration Validator
# Ensures consistency between build.zig, workflows, and justfile

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ERRORS=0
WARNINGS=0
CHECKS=0

echo -e "${BLUE}🔍 Build Configuration Validator${NC}"
echo "======================================"
echo ""

# Extract executable name from build.zig
extract_exe_name() {
    # Look for .name = "..." within addExecutable block
    sed -n '/addExecutable/,/^    });/p' build.zig | grep '\.name = ' | head -1 | sed 's/.*"\([^"]*\)".*/\1/'
}

EXE_NAME=$(extract_exe_name)

if [ -z "$EXE_NAME" ]; then
    echo -e "${RED}✗${NC} Could not extract executable name from build.zig"
    ((ERRORS++))
    exit 1
fi

echo -e "${GREEN}✓${NC} Found executable name: ${BLUE}$EXE_NAME${NC}"
echo ""

# Check justfile references
echo -e "${BLUE}Checking justfile...${NC}"
((CHECKS++))
if grep -q "zig-out/bin/$EXE_NAME" justfile; then
    echo -e "${GREEN}✓${NC} justfile uses correct binary path: zig-out/bin/$EXE_NAME"
else
    echo -e "${RED}✗${NC} justfile does not reference zig-out/bin/$EXE_NAME"
    echo "   Found:"
    grep "zig-out/bin/" justfile | sed 's/^/   /'
    ((ERRORS++))
fi

# Check CI workflow
echo ""
echo -e "${BLUE}Checking CI workflow...${NC}"
((CHECKS++))
if [ -f .github/workflows/ci.yml ]; then
    # CI doesn't typically copy the binary, just builds it
    if grep -q "zig build" .github/workflows/ci.yml; then
        echo -e "${GREEN}✓${NC} CI workflow builds the project"
    else
        echo -e "${YELLOW}⚠${NC} CI workflow may not build the project"
        ((WARNINGS++))
    fi
else
    echo -e "${YELLOW}⚠${NC} CI workflow not found"
    ((WARNINGS++))
fi

# Check release workflow
echo ""
echo -e "${BLUE}Checking release workflow...${NC}"
((CHECKS++))
if [ -f .github/workflows/release.yml ]; then
    if grep -q "zig-out/bin/$EXE_NAME" .github/workflows/release.yml; then
        echo -e "${GREEN}✓${NC} Release workflow uses correct binary path: zig-out/bin/$EXE_NAME"
    else
        echo -e "${RED}✗${NC} Release workflow does not reference zig-out/bin/$EXE_NAME"
        echo "   Found:"
        grep -n "zig-out/bin/" .github/workflows/release.yml | sed 's/^/   /' || echo "   No zig-out/bin/ references found"
        ((ERRORS++))
    fi

    # Check if zig build is called
    ((CHECKS++))
    if grep -q "zig build.*Release" .github/workflows/release.yml; then
        echo -e "${GREEN}✓${NC} Release workflow builds in release mode"
    else
        echo -e "${YELLOW}⚠${NC} Release workflow may not build in release mode"
        ((WARNINGS++))
    fi
else
    echo -e "${YELLOW}⚠${NC} Release workflow not found"
    ((WARNINGS++))
fi

# Check build.zig structure
echo ""
echo -e "${BLUE}Checking build.zig structure...${NC}"

((CHECKS++))
if grep -q "linkSystemLibrary.*gtk" build.zig; then
    echo -e "${GREEN}✓${NC} build.zig links GTK3"
else
    echo -e "${YELLOW}⚠${NC} build.zig may not link GTK3"
    ((WARNINGS++))
fi

((CHECKS++))
if grep -q "linkLibC" build.zig; then
    echo -e "${GREEN}✓${NC} build.zig links libc"
else
    echo -e "${RED}✗${NC} build.zig does not link libc (required for GTK)"
    ((ERRORS++))
fi

((CHECKS++))
if grep -q 'b\.step("test"' build.zig; then
    echo -e "${GREEN}✓${NC} build.zig defines test step"
else
    echo -e "${YELLOW}⚠${NC} build.zig may not define test step"
    ((WARNINGS++))
fi

((CHECKS++))
if grep -q 'b\.step("run"' build.zig; then
    echo -e "${GREEN}✓${NC} build.zig defines run step"
else
    echo -e "${YELLOW}⚠${NC} build.zig may not define run step"
    ((WARNINGS++))
fi

# Check if source files exist
echo ""
echo -e "${BLUE}Checking source files...${NC}"

check_file() {
    local file=$1
    ((CHECKS++))
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} Found: $file"
    else
        echo -e "${RED}✗${NC} Missing: $file"
        ((ERRORS++))
    fi
}

# Extract root source file from build.zig
ROOT_SOURCE=$(grep -E 'root_source_file.*examples' build.zig | sed 's/.*b\.path("\([^"]*\)").*/\1/' | head -1)
if [ -n "$ROOT_SOURCE" ]; then
    check_file "$ROOT_SOURCE"
fi

# Check library source
LIB_SOURCE=$(grep -E 'root_source_file.*src' build.zig | sed 's/.*b\.path("\([^"]*\)").*/\1/' | head -1)
if [ -n "$LIB_SOURCE" ]; then
    check_file "$LIB_SOURCE"
fi

# Summary
echo ""
echo "======================================"
echo -e "${BLUE}Validation Summary${NC}"
echo "======================================"
echo "Total checks: $CHECKS"
echo -e "${GREEN}✓ Passed${NC}"
echo -e "${YELLOW}⚠ Warnings: $WARNINGS${NC}"
echo -e "${RED}✗ Errors: $ERRORS${NC}"
echo ""

if [ $ERRORS -gt 0 ]; then
    echo -e "${RED}❌ Validation failed with $ERRORS error(s)${NC}"
    echo ""
    echo "Common fixes:"
    echo "  - Update workflow files to use: zig-out/bin/$EXE_NAME"
    echo "  - Update justfile to use: zig-out/bin/$EXE_NAME"
    echo "  - Ensure build.zig links required libraries"
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Validation passed with $WARNINGS warning(s)${NC}"
    exit 0
else
    echo -e "${GREEN}✅ All validations passed!${NC}"
    exit 0
fi
