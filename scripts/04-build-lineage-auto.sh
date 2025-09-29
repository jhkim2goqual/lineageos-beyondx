#!/bin/bash

# Script: 04-build-lineage-auto.sh
# Purpose: Build LineageOS for beyondx with automatic fixes
# This version includes automatic fixes for known issues

set -e

echo "================================================"
echo " LineageOS Build with Auto-Fixes"
echo " Device: Samsung Galaxy S10 5G (beyondx)"
echo "================================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Configuration
CONTAINER_NAME="lineageos-beyondx-builder"
DOCKER_COMPOSE_DIR="$(dirname "$0")/../docker"
SCRIPTS_DIR="$(dirname "$0")"

# Check if container is running
if ! docker ps | grep -q "$CONTAINER_NAME"; then
    print_info "Starting Docker container..."
    cd "$DOCKER_COMPOSE_DIR"
    docker compose up -d
    cd -
    sleep 5
fi

# Step 1: Apply automatic fixes
print_info "Applying automatic fixes for known issues..."
echo ""

# Copy fix scripts to container
docker cp "$SCRIPTS_DIR/fix-makefiles.sh" "$CONTAINER_NAME:/home/builder/scripts/" 2>/dev/null || true
docker cp "$SCRIPTS_DIR/fix-vendor-libs.sh" "$CONTAINER_NAME:/home/builder/scripts/" 2>/dev/null || true

# Make scripts executable
docker exec "$CONTAINER_NAME" chmod +x /home/builder/scripts/fix-makefiles.sh 2>/dev/null || true
docker exec "$CONTAINER_NAME" chmod +x /home/builder/scripts/fix-vendor-libs.sh 2>/dev/null || true

# Run vendor library fixes (includes Android.mk fixes)
print_info "Fixing vendor library dependencies..."
docker exec "$CONTAINER_NAME" bash -c "
    if [ -f /home/builder/scripts/fix-vendor-libs.sh ]; then
        /home/builder/scripts/fix-vendor-libs.sh
    fi
"

echo ""
print_info "All automatic fixes applied!"
echo ""

# Step 2: Start the build
print_info "Starting LineageOS build..."
echo ""

# Build options
BUILD_TYPE="${1:-userdebug}"
CLEAN_BUILD="${2:-false}"
JOBS="${3:-$(nproc)}"

# Clean if requested
if [ "$CLEAN_BUILD" = "true" ]; then
    print_warn "Performing clean build..."
    docker exec "$CONTAINER_NAME" bash -c "
        cd /home/builder/android/lineage
        make clean
    "
fi

# Main build command with progress tracking
print_info "Build configuration:"
echo "  - Build type: $BUILD_TYPE"
echo "  - Jobs: $JOBS"
echo "  - Clean build: $CLEAN_BUILD"
echo ""

print_info "Starting build process..."
print_info "This will take 1-3 hours depending on your system..."
echo ""

# Create build timestamp
BUILD_TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="logs/build-$BUILD_TIMESTAMP.log"

# Run the build
docker exec -it "$CONTAINER_NAME" bash -c "
    cd /home/builder/android/lineage
    source build/envsetup.sh

    # Set up build environment
    breakfast beyondx

    # Start build with time tracking
    echo '================================================'
    echo ' Build started at: $(date)'
    echo '================================================'

    time brunch beyondx 2>&1 | tee /home/builder/build.log

    BUILD_RESULT=\$?

    echo '================================================'
    echo ' Build finished at: $(date)'
    echo '================================================'

    if [ \$BUILD_RESULT -eq 0 ]; then
        echo -e '\033[0;32m[SUCCESS]\033[0m Build completed successfully!'

        # List output files
        echo ''
        echo 'Output files:'
        ls -lh /home/builder/output/target/product/beyondx/*.zip 2>/dev/null || true
        ls -lh /home/builder/output/target/product/beyondx/*.img 2>/dev/null || true
    else
        echo -e '\033[0;31m[ERROR]\033[0m Build failed with error code: \$BUILD_RESULT'
        echo ''
        echo 'Check the log for errors. Common issues:'
        echo '  - Missing dependencies'
        echo '  - Insufficient memory/storage'
        echo '  - Network issues during sync'
        echo ''
        echo 'You can check the build log at: /home/builder/build.log'
    fi

    exit \$BUILD_RESULT
"

BUILD_RESULT=$?

# Copy build log to host
docker cp "$CONTAINER_NAME:/home/builder/build.log" "$LOG_FILE" 2>/dev/null || true

if [ $BUILD_RESULT -eq 0 ]; then
    print_success "Build completed successfully!"
    echo ""
    echo "Output location: volumes/output/target/product/beyondx/"
    echo "Build log saved to: $LOG_FILE"

    # List the output files
    echo ""
    echo "Generated files:"
    ls -lh volumes/output/target/product/beyondx/*.zip 2>/dev/null || echo "  No zip files found"
    ls -lh volumes/output/target/product/beyondx/*.img 2>/dev/null || echo "  No img files found"
else
    print_error "Build failed! Check $LOG_FILE for details"
    exit $BUILD_RESULT
fi

echo ""
print_info "Build script completed!"