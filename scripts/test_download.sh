#!/bin/bash
# Test script for MeliPet downloader
# Tests various download scenarios

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/fetch_utils.sh"

log_header "🧪 MeliPet Download Test Suite"

# Test 1: Simple file download
test_simple_download() {
    log_header "Test 1: Simple File Download"
    
    local test_url="https://httpbin.org/json"
    local output_file="/tmp/test_simple.json"
    
    if fetch_with_curl "$test_url" "$output_file" 1048576 30; then
        if verify_file "$output_file"; then
            log_success "Test 1 PASSED"
            rm -f "$output_file"
            return 0
        fi
    fi
    
    log_error "Test 1 FAILED"
    return 1
}

# Test 2: Large file with progress
test_large_download() {
    log_header "Test 2: Large File Download"
    
    local test_url="https://httpbin.org/bytes/1048576" # 1MB
    local output_file="/tmp/test_large.bin"
    
    if fetch_with_curl "$test_url" "$output_file" 10485760 60; then
        if verify_file "$output_file"; then
            log_success "Test 2 PASSED"
            rm -f "$output_file"
            return 0
        fi
    fi
    
    log_error "Test 2 FAILED"
    return 1
}

# Test 3: URL accessibility check
test_url_check() {
    log_header "Test 3: URL Accessibility Check"
    
    if check_url "https://httpbin.org/status/200"; then
        log_success "Test 3 PASSED"
        return 0
    fi
    
    log_error "Test 3 FAILED"
    return 1
}

# Test 4: File info retrieval
test_file_info() {
    log_header "Test 4: File Info Retrieval"
    
    local info=$(get_file_info "https://httpbin.org/json")
    
    if [ -n "$info" ]; then
        echo "$info"
        log_success "Test 4 PASSED"
        return 0
    fi
    
    log_error "Test 4 FAILED"
    return 1
}

# Test 5: Extension detection
test_extension_detection() {
    log_header "Test 5: Extension Detection"
    
    local tests=(
        "text/html:.html"
        "application/json:.json"
        "image/png:.png"
        "application/zip:.zip"
        "application/java-archive:.jar"
    )
    
    local passed=0
    local failed=0
    
    for test in "${tests[@]}"; do
        local content_type="${test%%:*}"
        local expected="${test##*:}"
        local result=$(detect_extension "$content_type")
        
        if [ "$result" = "$expected" ]; then
            log_success "$content_type -> $result"
            ((passed++))
        else
            log_error "$content_type -> $result (expected $expected)"
            ((failed++))
        fi
    done
    
    if [ $failed -eq 0 ]; then
        log_success "Test 5 PASSED ($passed/$((passed+failed)))"
        return 0
    else
        log_error "Test 5 FAILED ($passed/$((passed+failed)))"
        return 1
    fi
}

# Run all tests
main() {
    local total=0
    local passed=0
    
    tests=(
        "test_simple_download"
        "test_large_download"
        "test_url_check"
        "test_file_info"
        "test_extension_detection"
    )
    
    for test in "${tests[@]}"; do
        ((total++))
        if $test; then
            ((passed++))
        fi
        echo ""
    done
    
    log_header "📊 Test Results"
    echo "Total: $total"
    echo "Passed: $passed"
    echo "Failed: $((total - passed))"
    
    if [ $passed -eq $total ]; then
        log_success "All tests passed! ✨"
        return 0
    else
        log_error "Some tests failed"
        return 1
    fi
}

# Run tests
main "$@"
