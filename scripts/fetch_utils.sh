#!/bin/bash
# MeliPet Fetch Utilities
# Helper functions for fetching content

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_header() {
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "$1"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
}

# Format bytes to human readable
format_bytes() {
    local bytes=$1
    if [ "$bytes" -lt 1024 ]; then
        echo "${bytes} B"
    elif [ "$bytes" -lt 1048576 ]; then
        echo "$(echo "scale=2; $bytes / 1024" | bc) KB"
    elif [ "$bytes" -lt 1073741824 ]; then
        echo "$(echo "scale=2; $bytes / 1048576" | bc) MB"
    else
        echo "$(echo "scale=2; $bytes / 1073741824" | bc) GB"
    fi
}

# Detect file type from content-type
detect_extension() {
    local content_type="$1"
    
    case "$content_type" in
        *text/html*) echo ".html" ;;
        *application/json*) echo ".json" ;;
        *text/plain*) echo ".txt" ;;
        *application/pdf*) echo ".pdf" ;;
        *image/jpeg*|*image/jpg*) echo ".jpg" ;;
        *image/png*) echo ".png" ;;
        *image/gif*) echo ".gif" ;;
        *image/webp*) echo ".webp" ;;
        *image/svg*) echo ".svg" ;;
        *application/zip*) echo ".zip" ;;
        *application/x-gzip*|*application/gzip*) echo ".gz" ;;
        *application/x-tar*) echo ".tar" ;;
        *application/x-7z-compressed*) echo ".7z" ;;
        *application/x-rar*) echo ".rar" ;;
        *application/java-archive*) echo ".jar" ;;
        *application/vnd.android.package-archive*) echo ".apk" ;;
        *application/x-msdownload*|*application/x-msdos-program*) echo ".exe" ;;
        *application/x-debian-package*) echo ".deb" ;;
        *application/x-rpm*) echo ".rpm" ;;
        *application/octet-stream*) echo ".bin" ;;
        *video/mp4*) echo ".mp4" ;;
        *video/x-matroska*) echo ".mkv" ;;
        *video/webm*) echo ".webm" ;;
        *audio/mpeg*) echo ".mp3" ;;
        *audio/wav*) echo ".wav" ;;
        *audio/ogg*) echo ".ogg" ;;
        *application/xml*|*text/xml*) echo ".xml" ;;
        *text/csv*) echo ".csv" ;;
        *application/vnd.ms-excel*) echo ".xls" ;;
        *application/vnd.openxmlformats-officedocument.spreadsheetml.sheet*) echo ".xlsx" ;;
        *application/msword*) echo ".doc" ;;
        *application/vnd.openxmlformats-officedocument.wordprocessingml.document*) echo ".docx" ;;
        *) echo ".bin" ;;
    esac
}

# Extract filename from URL
extract_filename() {
    local url="$1"
    local filename=$(basename "$url" | sed 's/[?#].*//')
    
    # Remove query parameters and fragments
    filename=$(echo "$filename" | cut -d'?' -f1 | cut -d'#' -f1)
    
    # If empty or just slash, return empty
    if [ -z "$filename" ] || [ "$filename" = "/" ]; then
        echo ""
    else
        echo "$filename"
    fi
}

# Download with curl and extract metadata
fetch_with_curl() {
    local url="$1"
    local output_file="$2"
    local max_size="${3:-104857600}" # Default 100MB
    local timeout="${4:-600}" # Default 10 minutes
    
    log_info "Fetching: $url"
    log_info "Max size: $(format_bytes $max_size)"
    log_info "Timeout: ${timeout}s"
    
    # Curl options
    local curl_opts=(
        -L                          # Follow redirects
        --max-time "$timeout"       # Total timeout
        --connect-timeout 30        # Connection timeout
        --retry 3                   # Retry 3 times
        --retry-delay 2             # Wait 2s between retries
        --retry-max-time 120        # Max retry time
        --max-filesize "$max_size"  # Max file size
        -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        --compressed                # Accept compressed responses
        -w "\n%{http_code}\n%{content_type}\n%{size_download}\n%{url_effective}\n%{time_total}\n%{speed_download}"
        -o "$output_file"
    )
    
    # Execute curl
    local info_file=$(mktemp)
    if curl "${curl_opts[@]}" "$url" > "$info_file" 2>&1; then
        # Parse curl output
        local http_code=$(sed -n '2p' "$info_file")
        local content_type=$(sed -n '3p' "$info_file")
        local size=$(sed -n '4p' "$info_file")
        local final_url=$(sed -n '5p' "$info_file")
        local time_total=$(sed -n '6p' "$info_file")
        local speed=$(sed -n '7p' "$info_file")
        
        # Calculate speed in MB/s
        local speed_mb=$(echo "scale=2; $speed / 1048576" | bc)
        
        log_success "Download successful"
        log_info "HTTP Status: $http_code"
        log_info "Content-Type: $content_type"
        log_info "Size: $(format_bytes $size)"
        log_info "Speed: ${speed_mb} MB/s"
        log_info "Time: ${time_total}s"
        
        # Return metadata as JSON
        cat <<EOF
{
  "success": true,
  "http_code": "$http_code",
  "content_type": "$content_type",
  "size": $size,
  "final_url": "$final_url",
  "time_total": $time_total,
  "speed": $speed
}
EOF
        rm -f "$info_file"
        return 0
    else
        log_error "Download failed"
        cat "$info_file"
        rm -f "$info_file"
        return 1
    fi
}

# Check if URL is accessible
check_url() {
    local url="$1"
    
    log_info "Checking URL accessibility..."
    
    if curl -I -L --max-time 10 --silent --fail "$url" > /dev/null 2>&1; then
        log_success "URL is accessible"
        return 0
    else
        log_error "URL is not accessible"
        return 1
    fi
}

# Get file info without downloading
get_file_info() {
    local url="$1"
    
    log_info "Getting file information..."
    
    local headers=$(curl -I -L --max-time 10 --silent "$url")
    
    local content_length=$(echo "$headers" | grep -i "content-length:" | tail -1 | cut -d' ' -f2 | tr -d '\r')
    local content_type=$(echo "$headers" | grep -i "content-type:" | tail -1 | cut -d' ' -f2 | tr -d '\r')
    local last_modified=$(echo "$headers" | grep -i "last-modified:" | tail -1 | cut -d' ' -f2- | tr -d '\r')
    
    if [ -n "$content_length" ]; then
        log_info "Size: $(format_bytes $content_length)"
    fi
    if [ -n "$content_type" ]; then
        log_info "Type: $content_type"
    fi
    if [ -n "$last_modified" ]; then
        log_info "Modified: $last_modified"
    fi
    
    cat <<EOF
{
  "content_length": "${content_length:-0}",
  "content_type": "${content_type:-unknown}",
  "last_modified": "${last_modified:-unknown}"
}
EOF
}

# Verify downloaded file
verify_file() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        log_error "File not found: $file"
        return 1
    fi
    
    local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    
    if [ "$size" -eq 0 ]; then
        log_error "File is empty: $file"
        return 1
    fi
    
    log_success "File verified: $(format_bytes $size)"
    return 0
}

# Export functions
export -f log_info log_success log_warning log_error log_header
export -f format_bytes detect_extension extract_filename
export -f fetch_with_curl check_url get_file_info verify_file
