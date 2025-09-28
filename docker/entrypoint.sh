#!/bin/bash

# EntryPoint script for LineageOS build container
set -e

echo "========================================"
echo "LineageOS Build Environment for beyondx"
echo "========================================"
echo ""

# Check if this is first run
if [ ! -f ~/.first_run_complete ]; then
    echo "First run detected. Setting up environment..."

    # Setup git if not configured
    if [ -z "$(git config --global user.email)" ]; then
        git config --global user.email "${GIT_USER_EMAIL:-builder@localhost}"
        git config --global user.name "${GIT_USER_NAME:-LineageOS Builder}"
    fi

    # Configure git-lfs
    git lfs install 2>/dev/null || true

    # Set up ccache if not already configured
    if [ ! -f ~/.ccache/ccache.conf ]; then
        ccache -M ${CCACHE_SIZE:-50G}
        ccache -o compression=true
        echo "ccache configured with ${CCACHE_SIZE:-50G} limit"
    fi

    touch ~/.first_run_complete
    echo "Initial setup complete!"
    echo ""
fi

# Display environment info
echo "Environment Information:"
echo "------------------------"
echo "User: $(whoami)"
echo "Home: $HOME"
echo "Java: $(java -version 2>&1 | head -n 1)"
echo "Python: $(python --version)"
echo "Repo: $(repo --version 2>&1 | head -n 1)"
echo "Git: $(git --version)"
echo "ccache: $(ccache -s | grep 'cache size' || echo 'Not initialized')"
echo ""

# Source build environment if available
if [ -f /home/builder/android/lineage/build/envsetup.sh ]; then
    echo "Sourcing build environment..."
    source /home/builder/android/lineage/build/envsetup.sh
    echo "Build environment loaded!"
else
    echo "Build environment not found. Run sync-sources.sh first."
fi

echo ""
echo "Ready for LineageOS build!"
echo "========================================"
echo ""

# Execute command passed to docker run
exec "$@"