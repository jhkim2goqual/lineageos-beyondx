#!/bin/bash

# Script: 05-verify-build.sh
# Purpose: Verify and compare build with official LineageOS

set -e

echo "================================================"
echo " LineageOS Build Verification"
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

print_verify() {
    echo -e "${CYAN}[VERIFY]${NC} $1"
}

# Function to format file size
format_size() {
    local size=$1
    if [ $size -gt 1073741824 ]; then
        echo "$(echo "scale=2; $size / 1073741824" | bc) GB"
    elif [ $size -gt 1048576 ]; then
        echo "$(echo "scale=2; $size / 1048576" | bc) MB"
    else
        echo "$(echo "scale=2; $size / 1024" | bc) KB"
    fi
}

# Check if running inside container
if [ ! -f /.dockerenv ]; then
    print_warn "This script should be run inside the Docker container!"
    exit 1
fi

# Find latest output directory
if [ -z "$1" ]; then
    OUTPUT_DIR=$(ls -dt /home/builder/output/*/ 2>/dev/null | head -n1)
    if [ -z "$OUTPUT_DIR" ]; then
        print_error "No output directory found!"
        print_info "Usage: $0 [output_directory]"
        exit 1
    fi
else
    OUTPUT_DIR="$1"
fi

if [ ! -d "$OUTPUT_DIR" ]; then
    print_error "Output directory not found: $OUTPUT_DIR"
    exit 1
fi

print_info "Verifying build in: $OUTPUT_DIR"
echo ""

# Step 1: Check for required files
print_verify "Checking for required build artifacts..."

REQUIRED_FILES=(
    "lineage-*.zip"
    "recovery.img"
    "boot.img"
)

OPTIONAL_FILES=(
    "dtbo.img"
    "dtb.img"
    "vbmeta.img"
    "super_empty.img"
)

MISSING_FILES=()
FOUND_FILES=()

for pattern in "${REQUIRED_FILES[@]}"; do
    found=false
    for file in $OUTPUT_DIR/$pattern; do
        if [ -f "$file" ]; then
            found=true
            FOUND_FILES+=("$(basename $file)")
            break
        fi
    done
    if [ "$found" = false ]; then
        MISSING_FILES+=("$pattern")
    fi
done

if [ ${#MISSING_FILES[@]} -gt 0 ]; then
    print_error "Missing required files:"
    for file in "${MISSING_FILES[@]}"; do
        echo "  - $file"
    done
    exit 1
else
    print_info "All required files present ✓"
fi

# Check optional files
print_verify "Checking optional files..."
for pattern in "${OPTIONAL_FILES[@]}"; do
    for file in $OUTPUT_DIR/$pattern; do
        if [ -f "$file" ]; then
            FOUND_FILES+=("$(basename $file)")
        else
            print_warn "Optional file not found: $pattern"
        fi
    done
done

echo ""
print_info "Found build artifacts:"
for file in "${FOUND_FILES[@]}"; do
    if [ -f "$OUTPUT_DIR/$file" ]; then
        size=$(stat -c%s "$OUTPUT_DIR/$file")
        echo "  - $file ($(format_size $size))"
    fi
done

# Step 2: Download official build for comparison
DOWNLOAD_DIR="/home/builder/downloads"
mkdir -p "$DOWNLOAD_DIR"

print_verify "Downloading official build for comparison..."

# Get latest official build info
OFFICIAL_BUILD="lineage-22.2-20250924-nightly-beyondx-signed.zip"
OFFICIAL_URL="https://download.lineageos.org/devices/beyondx/builds/$OFFICIAL_BUILD"

if [ ! -f "$DOWNLOAD_DIR/$OFFICIAL_BUILD" ]; then
    print_info "Downloading official build..."
    if wget -q --show-progress "$OFFICIAL_URL" -O "$DOWNLOAD_DIR/$OFFICIAL_BUILD"; then
        print_info "Official build downloaded"
    else
        print_warn "Could not download official build for comparison"
        print_warn "You can manually download from:"
        echo "  $OFFICIAL_URL"
    fi
else
    print_info "Official build already downloaded"
fi

# Step 3: Compare builds
echo ""
print_verify "Comparing with official build..."

# Find our build
OUR_BUILD=$(ls -1 $OUTPUT_DIR/lineage-*.zip 2>/dev/null | head -n1)

if [ -f "$OUR_BUILD" ] && [ -f "$DOWNLOAD_DIR/$OFFICIAL_BUILD" ]; then
    print_info "Our build: $(basename $OUR_BUILD)"
    print_info "Official: $OFFICIAL_BUILD"
    echo ""

    # Compare file sizes
    OUR_SIZE=$(stat -c%s "$OUR_BUILD")
    OFFICIAL_SIZE=$(stat -c%s "$DOWNLOAD_DIR/$OFFICIAL_BUILD")
    SIZE_DIFF=$((OUR_SIZE - OFFICIAL_SIZE))
    SIZE_DIFF_PCT=$(echo "scale=2; ($SIZE_DIFF * 100) / $OFFICIAL_SIZE" | bc)

    print_verify "File size comparison:"
    echo "  Our build:      $(format_size $OUR_SIZE)"
    echo "  Official build: $(format_size $OFFICIAL_SIZE)"
    echo "  Difference:     $(format_size ${SIZE_DIFF#-}) ($SIZE_DIFF_PCT%)"

    if [ ${SIZE_DIFF#-} -gt 52428800 ]; then  # 50MB difference
        print_warn "Significant size difference detected (>50MB)"
    else
        print_info "Size difference within acceptable range ✓"
    fi

    # Compare ZIP contents
    print_verify "Comparing ZIP structure..."

    OUR_CONTENTS="/tmp/our_build_contents.txt"
    OFFICIAL_CONTENTS="/tmp/official_contents.txt"

    unzip -l "$OUR_BUILD" | awk '{print $NF}' | sort > "$OUR_CONTENTS"
    unzip -l "$DOWNLOAD_DIR/$OFFICIAL_BUILD" | awk '{print $NF}' | sort > "$OFFICIAL_CONTENTS"

    # Find differences
    MISSING_IN_OURS=$(comm -13 "$OUR_CONTENTS" "$OFFICIAL_CONTENTS" | grep -v "^$" | wc -l)
    EXTRA_IN_OURS=$(comm -23 "$OUR_CONTENTS" "$OFFICIAL_CONTENTS" | grep -v "^$" | wc -l)

    if [ $MISSING_IN_OURS -gt 0 ]; then
        print_warn "Files in official but not in our build: $MISSING_IN_OURS"
    fi

    if [ $EXTRA_IN_OURS -gt 0 ]; then
        print_warn "Extra files in our build: $EXTRA_IN_OURS"
    fi

    if [ $MISSING_IN_OURS -eq 0 ] && [ $EXTRA_IN_OURS -eq 0 ]; then
        print_info "ZIP structure matches official build ✓"
    fi

    # Clean up temp files
    rm -f "$OUR_CONTENTS" "$OFFICIAL_CONTENTS"
else
    print_warn "Cannot perform detailed comparison (missing builds)"
fi

# Step 4: Verify image headers
echo ""
print_verify "Verifying boot images..."

for img in boot.img recovery.img dtbo.img; do
    if [ -f "$OUTPUT_DIR/$img" ]; then
        # Check Android boot image magic
        MAGIC=$(xxd -p -l 8 "$OUTPUT_DIR/$img" 2>/dev/null | tr -d '\n')

        case "$img" in
            boot.img|recovery.img)
                if [[ "$MAGIC" == "414e44524f494421" ]]; then  # "ANDROID!"
                    print_info "$img: Valid Android boot image ✓"
                else
                    print_warn "$img: Unexpected magic header"
                fi
                ;;
            dtbo.img)
                # DTBO images have different magic
                print_info "$img: Present (verification skipped)"
                ;;
        esac
    fi
done

# Step 5: Generate verification report
REPORT_FILE="$OUTPUT_DIR/verification-report.txt"
print_verify "Generating verification report..."

cat > "$REPORT_FILE" <<EOF
LineageOS Build Verification Report
====================================
Date: $(date)
Device: Samsung Galaxy S10 5G (beyondx)
Branch: lineage-22.2

Build Artifacts:
----------------
EOF

for file in $OUTPUT_DIR/*.{img,zip} 2>/dev/null; do
    if [ -f "$file" ]; then
        echo "$(basename $file): $(sha256sum $file | awk '{print $1}')" >> "$REPORT_FILE"
    fi
done

cat >> "$REPORT_FILE" <<EOF

Verification Results:
--------------------
- Required files: $([ ${#MISSING_FILES[@]} -eq 0 ] && echo "PASS" || echo "FAIL")
- Size comparison: $([ ${SIZE_DIFF#-} -lt 52428800 ] && echo "PASS" || echo "WARNING")
- Structure check: $([ $MISSING_IN_OURS -eq 0 ] && [ $EXTRA_IN_OURS -eq 0 ] && echo "PASS" || echo "WARNING")

Notes:
------
- Build is UNOFFICIAL (not signed with LineageOS keys)
- Size differences are expected due to signing and optimization
- Always backup your device before flashing
- Test thoroughly before daily use

EOF

print_info "Verification report saved to:"
echo "  $REPORT_FILE"

# Final summary
echo ""
echo "========================================"
print_info "Verification Summary:"
echo "========================================"

VERIFICATION_PASSED=true

if [ ${#MISSING_FILES[@]} -eq 0 ]; then
    echo "✓ All required files present"
else
    echo "✗ Missing required files"
    VERIFICATION_PASSED=false
fi

if [ -f "$OUR_BUILD" ]; then
    echo "✓ ROM package built successfully"
    echo "  Size: $(format_size $(stat -c%s "$OUR_BUILD"))"
else
    echo "✗ ROM package not found"
    VERIFICATION_PASSED=false
fi

if [ -f "$OUTPUT_DIR/recovery.img" ]; then
    echo "✓ Recovery image present"
else
    echo "✗ Recovery image missing"
fi

if [ "$VERIFICATION_PASSED" = true ]; then
    echo ""
    print_info "Build verification PASSED! ✓"
    echo ""
    echo "Your build is ready for flashing!"
    echo "Remember to:"
    echo "  1. Backup your current ROM"
    echo "  2. Wipe data/cache when switching ROMs"
    echo "  3. Flash via custom recovery (TWRP/LineageOS Recovery)"
    echo "  4. Test basic functions before daily use"
else
    echo ""
    print_error "Build verification FAILED"
    echo "Please check the errors above and rebuild if necessary"
fi

echo ""