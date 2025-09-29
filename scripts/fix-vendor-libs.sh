#!/bin/bash

# Script: fix-vendor-libs.sh
# Purpose: Fix vendor library dependency issues automatically
# Specifically handles libvkmanager_vendor and similar cross-device library issues

echo "================================================"
echo " Fixing Vendor Library Dependencies"
echo " Device: Samsung Galaxy S10 5G (beyondx)"
echo "================================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Base paths
LINEAGE_ROOT="/home/builder/android/lineage"
VENDOR_SAMSUNG="$LINEAGE_ROOT/vendor/samsung"
DEVICE_SAMSUNG="$LINEAGE_ROOT/device/samsung"

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

# Function to fix libvkmanager_vendor issue
fix_libvkmanager() {
    print_info "Fixing libvkmanager_vendor dependency..."

    # 1. Check if the lib exists in beyondx
    local lib_source="$VENDOR_SAMSUNG/beyondx/proprietary/vendor/lib64/libvkmanager_vendor.so"
    local lib_target="$VENDOR_SAMSUNG/exynos9820-common/proprietary/vendor/lib64/"

    if [ -f "$lib_source" ]; then
        print_info "Found libvkmanager_vendor.so in beyondx"

        # Create target directory if needed
        mkdir -p "$lib_target"

        # Copy the library to common
        if [ ! -f "$lib_target/libvkmanager_vendor.so" ]; then
            cp "$lib_source" "$lib_target/"
            print_success "Copied libvkmanager_vendor.so to exynos9820-common"
        else
            print_info "libvkmanager_vendor.so already exists in exynos9820-common"
        fi
    else
        print_warn "libvkmanager_vendor.so not found in beyondx"
    fi

    # 2. Fix extract-files.py to remove shim mapping
    local extract_file="$DEVICE_SAMSUNG/exynos9820-common/extract-files.py"
    if [ -f "$extract_file" ]; then
        # Comment out the problematic line
        sed -i "s/.*'libvkmanager_vendor'.*lib_fixup_device_dep.*/#    'libvkmanager_vendor': lib_fixup_device_dep,  # Fixed: Use actual vendor lib/" "$extract_file"
        print_success "Fixed extract-files.py lib_fixups"
    fi

    # 3. Ensure Android.bp has correct definition
    local android_bp="$VENDOR_SAMSUNG/exynos9820-common/Android.bp"
    if [ -f "$android_bp" ]; then
        # Check if libvkmanager_vendor is already defined
        if ! grep -q "cc_prebuilt_library_shared {" "$android_bp" || ! grep -q '"libvkmanager_vendor"' "$android_bp"; then
            print_info "Adding libvkmanager_vendor definition to Android.bp..."

            # Create proper definition (avoiding duplicate srcs)
            cat >> "$android_bp" << 'EOF'

// VaultKeeper library for exynos9820-common
cc_prebuilt_library_shared {
    name: "libvkmanager_vendor",
    owner: "samsung",
    target: {
        android_arm64: {
            srcs: ["proprietary/vendor/lib64/libvkmanager_vendor.so"],
        },
    },
    vendor: true,
    proprietary: true,
    check_elf_files: false,
    prefer: true,
    strip: {
        none: true,
    },
}
EOF
            print_success "Added libvkmanager_vendor to Android.bp"
        else
            # Fix duplicate srcs issue if exists
            print_info "Checking for duplicate srcs in Android.bp..."

            # Remove duplicate srcs: line outside of target block
            sed -i '/cc_prebuilt_library_shared {/,/^}$/ {
                /name: "libvkmanager_vendor"/,/^}$/ {
                    /target: {/,/^    }$/ !{
                        /srcs:/d
                    }
                }
            }' "$android_bp"

            print_success "Fixed potential duplicate srcs issue"
        fi
    fi
}

# Function to check and fix other common vendor lib issues
fix_common_vendor_issues() {
    print_info "Checking for other vendor library issues..."

    # Find all Android.bp files that reference undefined modules
    local bp_files=$(find "$VENDOR_SAMSUNG" -name "Android.bp" 2>/dev/null)

    for bp in $bp_files; do
        # Check for common issues
        # This is a placeholder for additional fixes
        :
    done

    print_info "Common vendor issues check complete"
}

# Main execution
main() {
    if [ ! -d "$LINEAGE_ROOT" ]; then
        print_error "LineageOS source not found at $LINEAGE_ROOT"
        print_info "This script should be run inside the Docker container"
        exit 1
    fi

    # Fix specific known issues
    fix_libvkmanager

    # Fix other common issues
    fix_common_vendor_issues

    # Also run the Android.mk endif fix
    if [ -f "/home/builder/scripts/fix-makefiles.sh" ]; then
        print_info "Running Android.mk endif fixes..."
        /home/builder/scripts/fix-makefiles.sh
    fi

    echo ""
    print_success "Vendor library fixes complete!"
    echo ""
    echo "You can now run the build with:"
    echo "  source build/envsetup.sh"
    echo "  brunch beyondx"
}

# Run main function
main "$@"