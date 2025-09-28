#!/bin/bash

set -e

echo "========================================"
echo "Extract Proprietary Blobs from ZIP"
echo "Following LineageOS Wiki Method"
echo "========================================"
echo ""

ZIP_PATH="$HOME/downloads/lineage-22.2-20250924-nightly-beyondx-signed.zip"
DUMP_DIR="$HOME/android/system_dump"
DEVICE_DIR="$HOME/android/lineage/device/samsung/beyondx"

echo "Step 1: Create temporary directory"
mkdir -p $DUMP_DIR
cd $DUMP_DIR

echo "Step 2: Extract system files from ZIP"
unzip $ZIP_PATH system.transfer.list system.new.dat*

echo "Step 3: Extract vendor files from ZIP"
unzip $ZIP_PATH vendor.transfer.list vendor.new.dat*

echo "Step 4: Decompress brotli files"
brotli --decompress --output=system.new.dat system.new.dat.br
brotli --decompress --output=vendor.new.dat vendor.new.dat.br

echo "Step 5: Clone sdat2img tool"
git clone https://github.com/xpirt/sdat2img

echo "Step 6: Convert system.new.dat to system.img"
python sdat2img/sdat2img.py system.transfer.list system.new.dat system.img

echo "Step 7: Convert vendor.new.dat to vendor.img"
python sdat2img/sdat2img.py vendor.transfer.list vendor.new.dat vendor.img

echo "Step 8: Mount system.img"
mkdir -p system/
sudo mount system.img system/

echo "Step 9: Remove vendor symlink and create vendor directory"
sudo rm -rf system/vendor
sudo mkdir system/vendor

echo "Step 10: Mount vendor.img inside system/vendor (trying EROFS)"
sudo mount -t erofs -o loop vendor.img system/vendor/ || sudo mount -t ext4 -o loop vendor.img system/vendor/

echo "Step 11: Verify mounts"
echo "System contents:"
ls system/ | head -5
echo ""
echo "Vendor contents:"
ls system/vendor/ | head -5

echo ""
echo "Step 11b: Copy mounted files to writable location"
mkdir -p dump_copy/system dump_copy/vendor
sudo cp -a system/system/* dump_copy/system/
sudo cp -a system/vendor/* dump_copy/vendor/
sudo chown -R builder:builder dump_copy/

echo ""
echo "Step 12: Run extract-files script on copied files"
cd $DEVICE_DIR
sudo ./extract-files.py $DUMP_DIR/dump_copy
sudo chown -R builder:builder $HOME/android/lineage/vendor/

echo ""
echo "Step 13: Unmount vendor"
sudo umount $DUMP_DIR/system/vendor

echo "Step 14: Unmount system"
sudo umount $DUMP_DIR/system

echo "Step 15: Cleanup"
rm -rf $DUMP_DIR

echo ""
echo "========================================"
echo "Extraction Complete!"
echo "========================================"
echo ""
echo "Proprietary blobs extracted to:"
ls -la $HOME/android/lineage/vendor/samsung/