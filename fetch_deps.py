#!/usr/bin/env python3
"""
Fetch V8 source and dependencies for MSVC build.

Usage:
    python fetch_deps.py [--v8-version 14.3.127.18]

This script clones V8 and its required third-party dependencies
that are not included in the V8 git repository.
"""

import argparse
import os
import subprocess
import sys

V8_VERSION = "14.3.127.18"
V8_DIR = "v8-src"

CHROMIUM_URL = "https://chromium.googlesource.com"

# Dependencies that need separate fetching (not in V8 repo)
DEPS = {
    "third_party/abseil-cpp": {
        "url": f"{CHROMIUM_URL}/chromium/src/third_party/abseil-cpp.git",
    },
    "third_party/icu": {
        "url": f"{CHROMIUM_URL}/chromium/deps/icu.git",
    },
    "third_party/zlib": {
        "url": f"{CHROMIUM_URL}/chromium/src/third_party/zlib.git",
    },
    "third_party/simdutf": {
        "url": f"{CHROMIUM_URL}/chromium/src/third_party/simdutf",
    },
    "third_party/dragonbox/src": {
        "url": f"{CHROMIUM_URL}/external/github.com/jk-jeon/dragonbox.git",
    },
    "third_party/fast_float/src": {
        "url": f"{CHROMIUM_URL}/external/github.com/fastfloat/fast_float.git",
    },
    "third_party/fp16/src": {
        "url": f"{CHROMIUM_URL}/external/github.com/Maratyszcza/FP16.git",
    },
    "third_party/highway/src": {
        "url": f"{CHROMIUM_URL}/external/github.com/google/highway.git",
    },
    "third_party/googletest/src": {
        "url": f"{CHROMIUM_URL}/external/github.com/google/googletest.git",
    },
}


def run(cmd, cwd=None):
    print(f"  > {' '.join(cmd)}")
    subprocess.check_call(cmd, cwd=cwd)


def clone_or_update(url, dest, depth=1):
    if os.path.exists(dest) and os.path.isdir(os.path.join(dest, ".git")):
        print(f"  Already exists: {dest}")
        return
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    run(["git", "clone", "--depth", str(depth), url, dest])


def main():
    parser = argparse.ArgumentParser(description="Fetch V8 dependencies")
    parser.add_argument("--v8-version", default=V8_VERSION, help="V8 version tag")
    parser.add_argument("--v8-dir", default=V8_DIR, help="V8 source directory name")
    args = parser.parse_args()

    script_dir = os.path.dirname(os.path.abspath(__file__))
    v8_path = os.path.join(script_dir, args.v8_dir)

    # Clone V8 source
    print(f"\n=== Cloning V8 {args.v8_version} ===")
    if os.path.exists(v8_path) and os.path.isdir(os.path.join(v8_path, ".git")):
        print(f"  V8 already cloned at {v8_path}")
    else:
        run([
            "git", "clone", "--depth", "1",
            "--branch", args.v8_version,
            "https://chromium.googlesource.com/v8/v8.git",
            v8_path,
        ])

    # Clone dependencies
    for dep_path, dep_info in DEPS.items():
        full_path = os.path.join(v8_path, dep_path)
        print(f"\n=== Fetching {dep_path} ===")
        clone_or_update(dep_info["url"], full_path)

    print("\n=== All dependencies fetched successfully ===")
    print(f"\nV8 source is at: {v8_path}")
    print("You can now configure with CMake:")
    print(f"  cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release")
    print(f"  cmake --build build")


if __name__ == "__main__":
    main()
