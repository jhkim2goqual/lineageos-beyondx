#!/bin/bash

# Script: 01-setup-env.sh
# Purpose: Initialize LineageOS build environment

set -e

echo "================================================"
echo " LineageOS Build Environment Setup"
echo " Device: Samsung Galaxy S10 5G (beyondx)"
echo "================================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check if running inside container
if [ ! -f /.dockerenv ]; then
    print_warn "This script should be run inside the Docker container!"
    print_info "Use: docker-compose run lineageos-builder ./scripts/01-setup-env.sh"
    exit 1
fi

# Load environment variables
if [ -f ~/config/build-config.env ]; then
    print_info "Loading build configuration..."
    export $(cat ~/config/build-config.env | grep -v '^#' | xargs)
fi

print_info "Setting up build environment..."

# Check available disk space
AVAILABLE_SPACE=$(df -BG /home/builder/android/lineage | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "$AVAILABLE_SPACE" -lt 300 ]; then
    print_error "Insufficient disk space! Need at least 300GB, have ${AVAILABLE_SPACE}GB"
    exit 1
fi
print_info "Available disk space: ${AVAILABLE_SPACE}GB"

# Initialize repo if not already done
if [ ! -d /home/builder/android/lineage/.repo ]; then
    print_info "Initializing LineageOS repository..."
    cd /home/builder/android/lineage

    repo init -u ${LINEAGE_MANIFEST_URL:-https://github.com/LineageOS/android.git} \
              -b ${DEVICE_BRANCH:-lineage-22.2} \
              --git-lfs \
              --no-clone-bundle

    print_info "Repository initialized successfully!"
else
    print_info "Repository already initialized."
fi

# Create local manifests directory
mkdir -p /home/builder/android/lineage/.repo/local_manifests

# Create local manifest for proprietary blobs (TheMuppets)
cat > /home/builder/android/lineage/.repo/local_manifests/beyondx.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <!-- Samsung Galaxy S10 5G proprietary blobs -->
  <project name="TheMuppets/proprietary_vendor_samsung"
           path="vendor/samsung"
           remote="github"
           revision="lineage-22.2" />
</manifest>
EOF

print_info "Local manifest created for proprietary blobs"

# Setup ccache
if [ ! -d ~/.ccache ]; then
    print_info "Setting up ccache..."
    ccache -M ${CCACHE_SIZE:-50G}
    ccache -o compression=true
fi

# Display ccache stats
print_info "Current ccache statistics:"
ccache -s

# Create output directory
mkdir -p ~/output

print_info "Environment setup complete!"
echo ""
echo "Next steps:"
echo "1. Run ./scripts/02-sync-sources.sh to download source code"
echo "2. Run ./scripts/03-extract-blobs.sh to get proprietary files"
echo "3. Run ./scripts/04-build-lineage.sh to start the build"
echo ""