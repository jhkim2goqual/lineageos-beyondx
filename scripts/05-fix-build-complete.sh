#!/bin/bash

# Script: 05-fix-build-complete.sh
# Purpose: Complete fix for LineageOS beyondx build issues
# This script includes ALL fixes discovered during the build process
# Date: 2025-09-29

echo "================================================"
echo " Complete Build Fix for LineageOS beyondx"
echo " Samsung Galaxy S10 5G (SM-G977B)"
echo "================================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Base paths
CONTAINER_NAME="lineageos-beyondx-builder"

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

# ==============================================================
# FIX 1: Android.mk endif issue
# ==============================================================
print_info "Fixing Android.mk endif issues..."

docker exec "$CONTAINER_NAME" bash -c '
fix_android_mk() {
    local mk_file="$1"
    if grep -q "^ifeq" "$mk_file" && ! grep -q "^endif" "$mk_file"; then
        echo "endif" >> "$mk_file"
        return 0
    fi
    return 1
}

fixed_count=0
total_count=0

if [ -d "/home/builder/android/lineage/vendor/samsung" ]; then
    while IFS= read -r -d "" mk_file; do
        total_count=$((total_count + 1))
        if fix_android_mk "$mk_file"; then
            fixed_count=$((fixed_count + 1))
            echo "Fixed: $mk_file"
        fi
    done < <(find /home/builder/android/lineage/vendor/samsung -name "Android.mk" -print0)
fi

echo "Checked $total_count Android.mk files, fixed $fixed_count"
'

# ==============================================================
# FIX 2: libvkmanager_vendor dependency issue
# ==============================================================
print_info "Fixing libvkmanager_vendor dependency..."

# Remove shim mapping from extract-files.py
docker exec "$CONTAINER_NAME" bash -c '
EXTRACT_FILE="/home/builder/android/lineage/device/samsung/exynos9820-common/extract-files.py"
if [ -f "$EXTRACT_FILE" ]; then
    sed -i "s/.*'\''libvkmanager_vendor'\''.*lib_fixup_device_dep.*/#    '\''libvkmanager_vendor'\'': lib_fixup_device_dep,  # Fixed: Use actual vendor lib/" "$EXTRACT_FILE"
    echo "Fixed extract-files.py lib_fixups"
fi
'

# Remove duplicate libvkmanager_vendor.so from beyondx (if exists)
docker exec "$CONTAINER_NAME" bash -c '
DUPLICATE_LIB="/home/builder/android/lineage/vendor/samsung/beyondx/proprietary/vendor/lib64/libvkmanager_vendor.so"
if [ -f "$DUPLICATE_LIB" ]; then
    rm "$DUPLICATE_LIB"
    echo "Removed duplicate libvkmanager_vendor.so from beyondx"
fi
'

# ==============================================================
# FIX 3: Git repository for vendor/samsung
# ==============================================================
print_info "Initializing git repository for vendor/samsung..."

docker exec "$CONTAINER_NAME" bash -c '
cd /home/builder/android/lineage/vendor/samsung
if [ ! -d .git ]; then
    git init
    git add .
    git commit -m "Initial vendor commit for build" 2>&1 | tail -5
    echo "Git repository initialized for vendor/samsung"
else
    echo "Git repository already exists"
fi
'

# ==============================================================
# FIX 4: Clean kernel build directory (if restat issues)
# ==============================================================
print_info "Cleaning kernel build directory to avoid restat issues..."

docker exec "$CONTAINER_NAME" bash -c '
KERNEL_OBJ="/home/builder/android/lineage/out/target/product/beyondx/obj/KERNEL_OBJ"
if [ -d "$KERNEL_OBJ" ]; then
    # Only clean if there are timestamp issues
    if [ -f "$KERNEL_OBJ/.config" ] && [ -f "$KERNEL_OBJ/arch/arm64/boot/Image" ]; then
        CONFIG_TIME=$(stat -c %Y "$KERNEL_OBJ/.config")
        IMAGE_TIME=$(stat -c %Y "$KERNEL_OBJ/arch/arm64/boot/Image" 2>/dev/null || echo 0)

        if [ "$IMAGE_TIME" -lt "$CONFIG_TIME" ]; then
            rm -rf "$KERNEL_OBJ"
            echo "Kernel build directory cleaned due to timestamp issues"
        else
            echo "Kernel timestamps OK, no cleaning needed"
        fi
    fi
fi
'

# ==============================================================
# FIX 5: Ensure proprietary blobs are properly extracted
# ==============================================================
print_info "Verifying proprietary blobs..."

docker exec "$CONTAINER_NAME" bash -c '
# Check if proprietary files exist
VENDOR_DIR="/home/builder/android/lineage/vendor/samsung"
if [ -d "$VENDOR_DIR/exynos9820-common/proprietary" ]; then
    BLOB_COUNT=$(find "$VENDOR_DIR/exynos9820-common/proprietary" -type f | wc -l)
    echo "Found $BLOB_COUNT proprietary blobs in exynos9820-common"
else
    echo "WARNING: Proprietary blobs directory not found!"
fi

if [ -d "$VENDOR_DIR/beyondx/proprietary" ]; then
    BLOB_COUNT=$(find "$VENDOR_DIR/beyondx/proprietary" -type f | wc -l)
    echo "Found $BLOB_COUNT proprietary blobs in beyondx"
fi
'

echo ""
print_success "All fixes have been applied!"
echo ""
echo "You can now run the build with:"
echo "  cd /home/builder/android/lineage"
echo "  source build/envsetup.sh"
echo "  brunch beyondx"
echo ""
echo "Or use the automated build script:"
echo "  ./04-build-lineage-auto.sh"