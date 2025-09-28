#!/bin/bash

# Script: 03-extract-blobs.sh
# Purpose: Extract or download proprietary blobs for beyondx

set -e

echo "================================================"
echo " Proprietary Blobs Extraction/Download"
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

# Check if running inside container
if [ ! -f /.dockerenv ]; then
    print_warn "This script should be run inside the Docker container!"
    exit 1
fi

cd /home/builder/android/lineage

# Check if source is synced
if [ ! -f build/envsetup.sh ]; then
    print_error "Source not synced! Run 02-sync-sources.sh first."
    exit 1
fi

# Source build environment
source build/envsetup.sh

print_info "Checking for proprietary blobs..."

# Option 1: Check if blobs already exist (from TheMuppets)
if [ -d "vendor/samsung/beyondx" ] && [ -f "vendor/samsung/beyondx/proprietary/lib/libsec-ril.so" ]; then
    print_info "Proprietary blobs already present (from TheMuppets repository)"
    print_info "No extraction needed!"
    exit 0
fi

# Option 2: Download from official LineageOS build
print_info "Proprietary blobs not found. We have two options:"
echo ""
echo "1. Extract from a device running LineageOS (requires USB connection)"
echo "2. Download from official LineageOS build and extract"
echo "3. Skip (use TheMuppets repository - already configured)"
echo ""
read -p "Select option (1/2/3): " -n 1 -r
echo ""

case $REPLY in
    1)
        # Extract from device
        print_info "Extracting from device..."

        # Check for device
        if ! adb devices | grep -q "device$"; then
            print_error "No device found! Please connect your S10 5G with:"
            echo "  - USB debugging enabled"
            echo "  - Root access enabled"
            echo "  - Running LineageOS ${DEVICE_BRANCH:-22.2}"
            exit 1
        fi

        # Navigate to device directory
        if [ ! -d "device/samsung/beyondx" ]; then
            print_error "Device tree not found! Run breakfast beyondx first."
            exit 1
        fi

        cd device/samsung/beyondx

        # Check for extraction script
        if [ -f "extract-files.sh" ]; then
            print_info "Running extraction script..."
            ./extract-files.sh
        elif [ -f "extract-files.py" ]; then
            print_info "Running Python extraction script..."
            python3 extract-files.py
        else
            print_error "No extraction script found!"
            exit 1
        fi

        print_info "Extraction complete!"
        ;;

    2)
        # Download from official build
        print_info "Downloading official LineageOS build..."

        DOWNLOAD_DIR="/home/builder/downloads"
        mkdir -p $DOWNLOAD_DIR

        # Get latest build URL (you may need to update this)
        LINEAGE_VERSION="22.2"
        BUILD_DATE="20250924"
        BUILD_FILE="lineage-${LINEAGE_VERSION}-${BUILD_DATE}-nightly-beyondx-signed.zip"
        BUILD_URL="https://download.lineageos.org/devices/beyondx/builds/${BUILD_FILE}"

        if [ ! -f "$DOWNLOAD_DIR/$BUILD_FILE" ]; then
            print_info "Downloading $BUILD_FILE..."
            wget -c "$BUILD_URL" -O "$DOWNLOAD_DIR/$BUILD_FILE" || {
                print_error "Download failed!"
                print_warn "Please manually download from:"
                echo "  https://download.lineageos.org/devices/beyondx"
                echo "  Place the file in: $DOWNLOAD_DIR"
                exit 1
            }
        else
            print_info "Build file already downloaded"
        fi

        # Extract blobs from zip
        print_info "Extracting proprietary files from official build..."

        # Create temporary extraction directory
        EXTRACT_DIR="/tmp/lineage-extract-$$"
        mkdir -p "$EXTRACT_DIR"

        # Extract system images from OTA
        print_info "Extracting OTA package..."
        cd "$EXTRACT_DIR"
        unzip -q "$DOWNLOAD_DIR/$BUILD_FILE" "system.transfer.list" "system.new.dat*" || true

        # Check if we have the necessary files
        if [ -f "system.new.dat.br" ]; then
            print_info "Decompressing brotli compressed system image..."
            brotli -d system.new.dat.br
        fi

        if [ -f "system.new.dat" ] && [ -f "system.transfer.list" ]; then
            print_info "Converting system image..."
            # This would require sdat2img.py tool
            if [ -f "/home/builder/android/lineage/vendor/lineage/build/tools/sdat2img.py" ]; then
                python3 /home/builder/android/lineage/vendor/lineage/build/tools/sdat2img.py \
                    system.transfer.list system.new.dat system.img
            else
                print_error "sdat2img.py not found!"
                print_warn "Manual extraction required. Please refer to:"
                echo "  https://wiki.lineageos.org/extracting_blobs_from_zips"
            fi
        fi

        # Clean up
        rm -rf "$EXTRACT_DIR"

        print_warn "Automatic extraction from OTA is complex."
        print_info "Recommend using TheMuppets repository instead (option 3)"
        ;;

    3)
        # Use TheMuppets
        print_info "Using TheMuppets repository for proprietary blobs..."

        # TheMuppets should be configured in local_manifests
        if [ -f ".repo/local_manifests/beyondx.xml" ]; then
            print_info "TheMuppets repository configured in local manifests"
            print_info "Running repo sync to fetch proprietary blobs..."

            repo sync -c -j4 --force-sync vendor/samsung

            if [ -d "vendor/samsung" ]; then
                print_info "Proprietary blobs synced successfully!"
            else
                print_error "Failed to sync proprietary blobs!"
                exit 1
            fi
        else
            print_warn "TheMuppets not configured. Adding to local manifests..."

            mkdir -p .repo/local_manifests
            cat > .repo/local_manifests/beyondx.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <remote name="TheMuppets"
          fetch="https://github.com/TheMuppets" />

  <project name="TheMuppets/proprietary_vendor_samsung"
           path="vendor/samsung"
           remote="TheMuppets"
           revision="lineage-${LINEAGE_VERSION:-22.2}" />
</manifest>
EOF

            print_info "Syncing TheMuppets repository..."
            repo sync -c -j4 --force-sync vendor/samsung
        fi
        ;;

    *)
        print_error "Invalid option!"
        exit 1
        ;;
esac

# Verify blobs are present
print_info "Verifying proprietary blobs..."

BLOB_CHECK_PATHS=(
    "vendor/samsung/beyondx"
    "vendor/samsung/exynos9820-common"
)

MISSING_BLOBS=false
for path in "${BLOB_CHECK_PATHS[@]}"; do
    if [ ! -d "/home/builder/android/lineage/$path" ]; then
        print_warn "Missing: $path"
        MISSING_BLOBS=true
    else
        print_info "Found: $path"
    fi
done

if [ "$MISSING_BLOBS" = true ]; then
    print_warn "Some proprietary blobs might be missing"
    print_warn "Build might fail or have missing features"
else
    print_info "All proprietary blobs verified!"
fi

print_info "Blob preparation complete!"
echo ""
echo "Next step:"
echo "Run ./scripts/04-build-lineage.sh to start the build"
echo ""