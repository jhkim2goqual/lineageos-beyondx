#!/bin/bash

# Script: 02-sync-sources.sh
# Purpose: Sync LineageOS source code

set -e

echo "================================================"
echo " LineageOS Source Code Sync"
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

print_progress() {
    echo -e "${BLUE}[SYNC]${NC} $1"
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

# Check if repo is initialized
if [ ! -d .repo ]; then
    print_error "Repository not initialized! Run 01-setup-env.sh first."
    exit 1
fi

# Function to calculate download size
estimate_download_size() {
    local BRANCH=${1:-lineage-22.2}
    case $BRANCH in
        lineage-22.2|lineage-22.1)
            echo "50-60GB"
            ;;
        lineage-21.0|lineage-20.0)
            echo "45-55GB"
            ;;
        *)
            echo "40-50GB"
            ;;
    esac
}

print_info "Preparing to sync LineageOS ${DEVICE_BRANCH:-lineage-22.2} source code..."
print_warn "This will download approximately $(estimate_download_size ${DEVICE_BRANCH}) of data"
print_warn "This may take 1-3 hours depending on your internet connection"
echo ""

# Ask for confirmation
read -p "Do you want to continue? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Sync cancelled by user"
    exit 0
fi

# Start time tracking
START_TIME=$(date +%s)

# Sync sources with retry logic
MAX_RETRIES=3
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    print_progress "Starting sync attempt $((RETRY_COUNT + 1)) of $MAX_RETRIES..."

    if repo sync -c -j${REPO_SYNC_JOBS:-4} \
                 --force-sync \
                 --no-clone-bundle \
                 --no-tags \
                 --optimized-fetch \
                 --prune; then
        print_info "Source sync completed successfully!"
        break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            print_warn "Sync failed. Retrying in 30 seconds..."
            sleep 30
        else
            print_error "Sync failed after $MAX_RETRIES attempts!"
            exit 1
        fi
    fi
done

# Calculate elapsed time
END_TIME=$(date +%s)
ELAPSED_TIME=$((END_TIME - START_TIME))
HOURS=$((ELAPSED_TIME / 3600))
MINUTES=$(((ELAPSED_TIME % 3600) / 60))
SECONDS=$((ELAPSED_TIME % 60))

print_info "Sync completed in ${HOURS}h ${MINUTES}m ${SECONDS}s"

# Download device-specific sources
print_info "Preparing device-specific sources for beyondx..."

# Source build environment
source build/envsetup.sh

# Run breakfast to get device-specific repos
print_info "Running breakfast for beyondx..."
breakfast beyondx || {
    print_warn "breakfast failed, this might be normal on first run"
    print_info "Trying to sync device-specific repos manually..."

    # Sync again to get device-specific repos
    repo sync -c -j${REPO_SYNC_JOBS:-4} --force-sync
}

# Verify critical directories exist
print_info "Verifying source tree..."

REQUIRED_DIRS=(
    "device/samsung"
    "kernel/samsung"
    "vendor/lineage"
    "hardware/samsung"
)

MISSING_DIRS=()
for dir in "${REQUIRED_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        MISSING_DIRS+=("$dir")
    fi
done

if [ ${#MISSING_DIRS[@]} -gt 0 ]; then
    print_warn "Some expected directories are missing:"
    for dir in "${MISSING_DIRS[@]}"; do
        echo "  - $dir"
    done
    print_warn "This might be normal, device-specific repos will be downloaded during build"
fi

# Display disk usage
print_info "Disk usage after sync:"
du -sh /home/builder/android/lineage

# Display source tree statistics
print_info "Source tree statistics:"
echo "Total repositories: $(find .repo/projects -type d | wc -l)"
echo "Total size: $(du -sh . | awk '{print $1}')"

print_info "Source sync complete!"
echo ""
echo "Next steps:"
echo "1. Run ./scripts/03-extract-blobs.sh to get proprietary files"
echo "   OR download from https://download.lineageos.org/devices/beyondx"
echo "2. Run ./scripts/04-build-lineage.sh to start the build"
echo ""