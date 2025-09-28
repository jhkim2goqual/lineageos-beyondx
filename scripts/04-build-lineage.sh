#!/bin/bash

# Script: 04-build-lineage.sh
# Purpose: Build LineageOS for beyondx

set -e

echo "================================================"
echo " LineageOS Build Process"
echo " Device: Samsung Galaxy S10 5G (beyondx)"
echo "================================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_build() {
    echo -e "${CYAN}[BUILD]${NC} $1"
}

# Check if running inside container
if [ ! -f /.dockerenv ]; then
    print_warn "This script should be run inside the Docker container!"
    exit 1
fi

# Load environment variables
if [ -f ~/config/build-config.env ]; then
    export $(cat ~/config/build-config.env | grep -v '^#' | xargs)
fi

cd /home/builder/android/lineage

# Check if source is synced
if [ ! -f build/envsetup.sh ]; then
    print_error "Source not synced! Run 02-sync-sources.sh first."
    exit 1
fi

# Source build environment
print_info "Setting up build environment..."
source build/envsetup.sh

# Function to format time
format_time() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))
    printf "%02d:%02d:%02d" $hours $minutes $secs
}

# Function to monitor build progress
monitor_build() {
    local log_file=$1
    local start_time=$(date +%s)

    while true; do
        if [ -f "$log_file" ]; then
            local current_time=$(date +%s)
            local elapsed=$((current_time - start_time))
            local last_line=$(tail -n 1 "$log_file" 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g')

            printf "\r${CYAN}[$(format_time $elapsed)]${NC} Building... ${last_line:0:80}"
        fi
        sleep 2
    done
}

# System information
print_info "System Information:"
echo "  CPU Cores: $(nproc)"
echo "  Total RAM: $(free -h | awk '/^Mem:/ {print $2}')"
echo "  Available RAM: $(free -h | awk '/^Mem:/ {print $7}')"
echo "  ccache size: $(ccache -s | grep 'cache size' | awk '{print $3, $4}')"
echo ""

# Check disk space
AVAILABLE_SPACE=$(df -BG /home/builder/android/lineage | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "$AVAILABLE_SPACE" -lt 50 ]; then
    print_error "Insufficient disk space! Need at least 50GB free, have ${AVAILABLE_SPACE}GB"
    exit 1
fi
print_info "Available disk space: ${AVAILABLE_SPACE}GB"

# Clean previous build (optional)
if [ -d "out" ]; then
    read -p "Clean previous build? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Cleaning previous build..."
        make clean
    else
        print_info "Keeping previous build artifacts (incremental build)"
    fi
fi

# Set up device
print_info "Setting up device configuration..."
breakfast beyondx || {
    print_error "Failed to set up device configuration!"
    exit 1
}

# Display build configuration
print_info "Build Configuration:"
echo "  Device: $TARGET_DEVICE"
echo "  Product: $TARGET_PRODUCT"
echo "  Variant: ${BUILD_TYPE:-userdebug}"
echo "  Jobs: ${BUILD_JOBS:-$(nproc)}"
echo ""

# Confirm build
echo "Ready to build LineageOS ${DEVICE_BRANCH:-22.2} for beyondx"
read -p "Start build? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Build cancelled by user"
    exit 0
fi

# Create output directory
OUTPUT_DIR="/home/builder/output/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUTPUT_DIR"
print_info "Output directory: $OUTPUT_DIR"

# Start build
BUILD_START=$(date +%s)
BUILD_LOG="$OUTPUT_DIR/build.log"

print_build "Starting build process..."
print_build "This will take 1-4 hours depending on your system"
print_build "Build log: $BUILD_LOG"
echo ""

# Start progress monitor in background
monitor_build "$BUILD_LOG" &
MONITOR_PID=$!

# Kill monitor on exit
trap "kill $MONITOR_PID 2>/dev/null" EXIT

# Run the actual build
if brunch beyondx 2>&1 | tee "$BUILD_LOG"; then
    BUILD_SUCCESS=true
else
    BUILD_SUCCESS=false
fi

# Stop progress monitor
kill $MONITOR_PID 2>/dev/null || true

# Calculate build time
BUILD_END=$(date +%s)
BUILD_TIME=$((BUILD_END - BUILD_START))

echo ""
if [ "$BUILD_SUCCESS" = true ]; then
    print_info "Build completed successfully!"
    print_info "Build time: $(format_time $BUILD_TIME)"

    # Copy output files
    print_info "Copying output files to $OUTPUT_DIR..."

    if [ -d "out/target/product/beyondx" ]; then
        # Copy important files
        FILES_TO_COPY=(
            "lineage-*.zip"
            "recovery.img"
            "boot.img"
            "dtbo.img"
            "dtb.img"
            "vbmeta.img"
            "super_empty.img"
        )

        for pattern in "${FILES_TO_COPY[@]}"; do
            for file in out/target/product/beyondx/$pattern; do
                if [ -f "$file" ]; then
                    cp -v "$file" "$OUTPUT_DIR/"
                fi
            done
        done

        # Create checksums
        print_info "Generating checksums..."
        cd "$OUTPUT_DIR"
        sha256sum *.img *.zip > SHA256SUMS 2>/dev/null || true
        cd - > /dev/null

        # Display output files
        print_info "Build artifacts:"
        ls -lh "$OUTPUT_DIR"

        # Display ccache statistics
        print_info "ccache statistics:"
        ccache -s
    else
        print_error "Output directory not found!"
    fi
else
    print_error "Build failed! Check $BUILD_LOG for details"
    print_info "Common issues:"
    echo "  - Missing proprietary blobs"
    echo "  - Insufficient RAM (need 16GB minimum, 32GB recommended)"
    echo "  - Insufficient disk space"
    echo "  - Java heap size issues (adjust ANDROID_JACK_VM_ARGS)"

    # Show last errors from log
    print_error "Last 20 lines of build log:"
    tail -n 20 "$BUILD_LOG"
    exit 1
fi

echo ""
print_info "Build Summary:"
echo "  Device: beyondx"
echo "  Branch: ${DEVICE_BRANCH:-lineage-22.2}"
echo "  Build time: $(format_time $BUILD_TIME)"
echo "  Output: $OUTPUT_DIR"
echo ""
echo "Next steps:"
echo "1. Run ./scripts/05-verify-build.sh to verify the build"
echo "2. Flash the ROM to your device using:"
echo "   - TWRP/LineageOS Recovery"
echo "   - Heimdall/Odin (for Samsung devices)"
echo ""