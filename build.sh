#!/bin/bash
# =============================================================================
# V8 Linux build script
# Usage: ./build.sh [debug|release] [--build-dir DIR]
# =============================================================================
set -e

BUILD_TYPE="Release"
BUILD_DIR="build"

while [[ $# -gt 0 ]]; do
  case "$1" in
    debug)   BUILD_TYPE="Debug"; shift ;;
    release) BUILD_TYPE="Release"; shift ;;
    --build-dir) BUILD_DIR="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Fetch dependencies if not already present
if [ ! -d "v8-src/src" ]; then
  echo "=== Fetching dependencies ==="
  python3 fetch_deps.py
fi

# Configure
echo "=== Configuring (${BUILD_TYPE}) ==="
cmake -B "${BUILD_DIR}" -G Ninja \
  -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
  -DCMAKE_C_COMPILER="${CC:-gcc}" \
  -DCMAKE_CXX_COMPILER="${CXX:-g++}"

# Build
echo "=== Building ==="
cmake --build "${BUILD_DIR}" --parallel "$(nproc)"

echo "=== Build complete ==="
echo "Binaries are in ${BUILD_DIR}/"
