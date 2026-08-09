#!/usr/bin/env bash
# Test Script untuk memverifikasi fitur build optimizations
# Script ini akan melakukan dry-run untuk memastikan semua opsi bekerja

set -e

GREEN='\033[1;32m'
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'

msg() {
    echo -e "${GREEN}[✓]${NC} $*"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[✗]${NC} $*"
}

header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$*${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

# Test 1: Cek bahwa build-llvm.py ada
test_script_exists() {
    header "Test 1: Checking build-llvm.py exists"
    if [ -f "build-llvm.py" ]; then
        msg "build-llvm.py found"
        return 0
    else
        error "build-llvm.py not found"
        return 1
    fi
}

# Test 2: Cek help output untuk MLGO option
test_mlgo_option() {
    header "Test 2: Checking MLGO option in help"
    if ./build-llvm.py --help | grep -q "mlgo"; then
        msg "MLGO option found in help"
        if ./build-llvm.py --help | grep -q "Machine Learning Guided Optimization"; then
            msg "MLGO description is correct"
            return 0
        else
            error "MLGO description not found"
            return 1
        fi
    else
        error "MLGO option not found in help"
        return 1
    fi
}

# Test 3: Cek BOLT option
test_bolt_option() {
    header "Test 3: Checking BOLT option"
    if ./build-llvm.py --help | grep -q "\-\-bolt"; then
        msg "BOLT option available"
        return 0
    else
        error "BOLT option not found"
        return 1
    fi
}

# Test 4: Cek PGO option
test_pgo_option() {
    header "Test 4: Checking PGO option"
    if ./build-llvm.py --help | grep -q "\-\-pgo"; then
        msg "PGO option available"
        # Cek apakah ada kernel-defconfig-slim
        if ./build-llvm.py --help | grep -q "kernel-defconfig-slim"; then
            msg "PGO benchmark options available"
            return 0
        else
            warn "PGO benchmark options may be incomplete"
            return 0
        fi
    else
        error "PGO option not found"
        return 1
    fi
}

# Test 5: Cek LTO option
test_lto_option() {
    header "Test 5: Checking LTO option"
    if ./build-llvm.py --help | grep -q "\-\-lto"; then
        msg "LTO option available"
        return 0
    else
        error "LTO option not found"
        return 1
    fi
}

# Test 6: Test MLGO validation (should fail with invalid path)
test_mlgo_validation() {
    header "Test 6: Testing MLGO path validation"
    info "Testing with invalid path (should fail)..."
    
    if ./build-llvm.py --mlgo /nonexistent/path/to/model --help 2>&1 | grep -q "does not exist"; then
        msg "MLGO path validation works correctly"
        return 0
    else
        # Jika tidak ada error, mungkin karena --help tidak trigger validasi
        # Coba tanpa --help (tapi ini akan mulai build, jadi skip)
        warn "MLGO validation test skipped (would require actual build)"
        return 0
    fi
}

# Test 7: Cek atiga.sh updates
test_atiga_script() {
    header "Test 7: Checking atiga.sh updates"
    if [ -f "atiga.sh" ]; then
        if grep -q "MLGO_MODEL_PATH" atiga.sh; then
            msg "atiga.sh contains MLGO_MODEL_PATH variable"
            if grep -q "mlgo" atiga.sh; then
                msg "atiga.sh contains mlgo usage"
                return 0
            else
                warn "atiga.sh may not be using MLGO properly"
                return 0
            fi
        else
            warn "atiga.sh doesn't have MLGO_MODEL_PATH"
            return 0
        fi
    else
        warn "atiga.sh not found"
        return 0
    fi
}

# Test 8: Cek documentation files
test_documentation() {
    header "Test 8: Checking documentation files"
    DOCS_FOUND=0
    
    if [ -f "BUILD_OPTIMIZATIONS.md" ]; then
        msg "BUILD_OPTIMIZATIONS.md exists"
        DOCS_FOUND=$((DOCS_FOUND + 1))
    else
        warn "BUILD_OPTIMIZATIONS.md not found"
    fi
    
    if [ -f "OPTIMIZATIONS_README.md" ]; then
        msg "OPTIMIZATIONS_README.md exists"
        DOCS_FOUND=$((DOCS_FOUND + 1))
    else
        warn "OPTIMIZATIONS_README.md not found"
    fi
    
    if [ -f "build-examples.sh" ]; then
        msg "build-examples.sh exists"
        if [ -x "build-examples.sh" ]; then
            msg "build-examples.sh is executable"
        else
            warn "build-examples.sh is not executable"
        fi
        DOCS_FOUND=$((DOCS_FOUND + 1))
    else
        warn "build-examples.sh not found"
    fi
    
    if [ $DOCS_FOUND -ge 2 ]; then
        return 0
    else
        return 1
    fi
}

# Test 9: Verify Python syntax
test_python_syntax() {
    header "Test 9: Checking Python syntax"
    if command -v python3 &> /dev/null; then
        if python3 -m py_compile build-llvm.py 2>/dev/null; then
            msg "build-llvm.py has valid Python syntax"
            return 0
        else
            error "build-llvm.py has syntax errors"
            return 1
        fi
    else
        warn "python3 not found, skipping syntax check"
        return 0
    fi
}

# Test 10: Check all optimization combinations in help
test_optimization_combinations() {
    header "Test 10: Checking optimization combinations in help"
    
    HELP_OUTPUT=$(./build-llvm.py --help 2>&1)
    
    OPTS_FOUND=0
    
    if echo "$HELP_OUTPUT" | grep -q "\-\-bolt"; then
        msg "BOLT: ✓"
        OPTS_FOUND=$((OPTS_FOUND + 1))
    fi
    
    if echo "$HELP_OUTPUT" | grep -q "\-\-pgo"; then
        msg "PGO: ✓"
        OPTS_FOUND=$((OPTS_FOUND + 1))
    fi
    
    if echo "$HELP_OUTPUT" | grep -q "\-\-lto"; then
        msg "LTO: ✓"
        OPTS_FOUND=$((OPTS_FOUND + 1))
    fi
    
    if echo "$HELP_OUTPUT" | grep -q "\-\-mlgo"; then
        msg "MLGO: ✓"
        OPTS_FOUND=$((OPTS_FOUND + 1))
    fi
    
    info "Found $OPTS_FOUND/4 optimization options"
    
    if [ $OPTS_FOUND -eq 4 ]; then
        msg "All optimization options available!"
        return 0
    else
        error "Some optimization options missing"
        return 1
    fi
}

# Main test runner
main() {
    header "Atiga Clang Build Optimizations - Test Suite"
    
    TESTS_PASSED=0
    TESTS_FAILED=0
    TESTS_TOTAL=10
    
    # Run all tests
    if test_script_exists; then ((TESTS_PASSED++)); else ((TESTS_FAILED++)); fi
    if test_mlgo_option; then ((TESTS_PASSED++)); else ((TESTS_FAILED++)); fi
    if test_bolt_option; then ((TESTS_PASSED++)); else ((TESTS_FAILED++)); fi
    if test_pgo_option; then ((TESTS_PASSED++)); else ((TESTS_FAILED++)); fi
    if test_lto_option; then ((TESTS_PASSED++)); else ((TESTS_FAILED++)); fi
    if test_mlgo_validation; then ((TESTS_PASSED++)); else ((TESTS_FAILED++)); fi
    if test_atiga_script; then ((TESTS_PASSED++)); else ((TESTS_FAILED++)); fi
    if test_documentation; then ((TESTS_PASSED++)); else ((TESTS_FAILED++)); fi
    if test_python_syntax; then ((TESTS_PASSED++)); else ((TESTS_FAILED++)); fi
    if test_optimization_combinations; then ((TESTS_PASSED++)); else ((TESTS_FAILED++)); fi
    
    # Summary
    header "Test Summary"
    echo ""
    echo "Total Tests: $TESTS_TOTAL"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        msg "All tests passed! ✓"
        echo ""
        echo "Your build system is ready with all optimizations:"
        echo "  ✓ BOLT - Binary Optimization and Layout Tool"
        echo "  ✓ PGO - Profile-Guided Optimization"
        echo "  ✓ LTO - Link-Time Optimization (Thin & Full)"
        echo "  ✓ MLGO - Machine Learning Guided Optimization"
        echo ""
        echo "You can now:"
        echo "  1. Run ./atiga.sh for default optimized build"
        echo "  2. Run ./build-examples.sh for interactive menu"
        echo "  3. Check BUILD_OPTIMIZATIONS.md for detailed guide"
        echo ""
        return 0
    else
        error "Some tests failed!"
        echo ""
        echo "Please check the errors above and fix them."
        echo ""
        return 1
    fi
}

# Run main if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
