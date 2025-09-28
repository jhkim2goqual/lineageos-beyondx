#!/bin/bash

set -e

echo "========================================"
echo "Automated Proprietary Blobs Extraction"
echo "========================================"
echo ""

ZIP_FILE="/home/builder/downloads/lineage-22.2-20250924-nightly-beyondx-signed.zip"
WORK_DIR="/home/builder/blob_extract"
DEVICE_DIR="/home/builder/android/lineage/device/samsung/beyondx"

# Cleanup previous attempts
sudo umount $WORK_DIR/system 2>/dev/null || true
sudo umount $WORK_DIR/vendor 2>/dev/null || true
rm -rf $WORK_DIR
mkdir -p $WORK_DIR
cd $WORK_DIR

echo "=== Step 1: Extract partition files from ZIP ==="
unzip -q $ZIP_FILE system.transfer.list system.new.dat.br vendor.transfer.list vendor.new.dat.br

echo "=== Step 2: Decompress brotli files ==="
brotli --decompress --output=system.new.dat system.new.dat.br
brotli --decompress --output=vendor.new.dat vendor.new.dat.br

echo "=== Step 3: Clone sdat2img tool ==="
git clone -q https://github.com/xpirt/sdat2img

echo "=== Step 4: Convert to IMG files ==="
python3 sdat2img/sdat2img.py system.transfer.list system.new.dat system.img
python3 sdat2img/sdat2img.py vendor.transfer.list vendor.new.dat vendor.img

echo "=== Step 5: Mount images ==="
mkdir -p system vendor
sudo mount -o loop,ro system.img system/
sudo mount -o loop,ro vendor.img vendor/

echo "=== Step 6: Verify mounts ==="
echo "System partitions:"
ls system/system/ | head -5
echo ""
echo "Vendor partitions:"
ls vendor/ | head -5

echo ""
echo "=== Step 7: Create simplified dump structure ==="
# Create structure that extract-files.py expects
mkdir -p dump/system dump/vendor
sudo cp -a system/system/* dump/system/
sudo cp -a vendor/* dump/vendor/
sudo chown -R builder:builder dump/

echo "=== Step 8: Run extraction ==="
cd $DEVICE_DIR
./extract-files.py $WORK_DIR/dump

echo ""
echo "=== Step 9: Cleanup ==="
cd /home/builder
sudo umount $WORK_DIR/system
sudo umount $WORK_DIR/vendor
rm -rf $WORK_DIR

echo ""
echo "=== Extraction Complete! ==="
ls -la /home/builder/android/lineage/vendor/samsung/

echo ""
echo "Extracted proprietary blobs for:"
ls /home/builder/android/lineage/vendor/samsung/