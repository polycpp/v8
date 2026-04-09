#!/usr/bin/env python3
"""Fetch pinned V8 14.3.127.18 source and third-party dependencies.

This script enforces exact revisions from the V8 14.3.127.18 DEPS file,
including when repositories already exist locally.
"""

import argparse
import os
import subprocess
import sys

V8_VERSION = "14.3.127.18"
V8_DIR = "v8-src"
V8_REPO = "https://chromium.googlesource.com/v8/v8.git"
CHROMIUM_URL = "https://chromium.googlesource.com"

# Pinned from v8/v8 DEPS at refs/tags/14.3.127.18.
DEPS = {
    "abseil-cpp": {
        "url": f"{CHROMIUM_URL}/chromium/src/third_party/abseil-cpp.git",
        "commit": "3fb321d9764442ceaf2e17b6e68ab6b6836bc78a",
        "path": "third_party/abseil-cpp",
    },
    "dragonbox": {
        "url": f"{CHROMIUM_URL}/external/github.com/jk-jeon/dragonbox.git",
        "commit": "6c7c925b571d54486b9ffae8d9d18a822801cbda",
        "path": "third_party/dragonbox/src",
    },
    "fast_float": {
        "url": f"{CHROMIUM_URL}/external/github.com/fastfloat/fast_float.git",
        "commit": "cb1d42aaa1e14b09e1452cfdef373d051b8c02a4",
        "path": "third_party/fast_float/src",
    },
    "fp16": {
        "url": f"{CHROMIUM_URL}/external/github.com/Maratyszcza/FP16.git",
        "commit": "3d2de1816307bac63c16a297e8c4dc501b4076df",
        "path": "third_party/fp16/src",
    },
    "googletest": {
        "url": f"{CHROMIUM_URL}/external/github.com/google/googletest.git",
        "commit": "b2b9072ecbe874f5937054653ef8f2731eb0f010",
        "path": "third_party/googletest/src",
    },
    "highway": {
        "url": f"{CHROMIUM_URL}/external/github.com/google/highway.git",
        "commit": "84379d1c73de9681b54fbe1c035a23c7bd5d272d",
        "path": "third_party/highway/src",
    },
    "icu": {
        "url": f"{CHROMIUM_URL}/chromium/deps/icu.git",
        "commit": "f27805b7d7d8618fa73ce89e9d28e0a8b2216fec",
        "path": "third_party/icu",
    },
    "simdutf": {
        "url": f"{CHROMIUM_URL}/chromium/src/third_party/simdutf",
        "commit": "acd71a451c1bcb808b7c3a77e0242052909e381e",
        "path": "third_party/simdutf",
    },
    "zlib": {
        "url": f"{CHROMIUM_URL}/chromium/src/third_party/zlib.git",
        "commit": "85f05b0835f934e52772efc308baa80cdd491838",
        "path": "third_party/zlib",
    },
}


def run(cmd, cwd=None, capture_output=False):
    print(f"  > {' '.join(cmd)}")
    if capture_output:
        return subprocess.check_output(cmd, cwd=cwd, text=True).strip()
    subprocess.check_call(cmd, cwd=cwd)
    return ""


def is_git_repo(path):
    return os.path.isdir(os.path.join(path, ".git"))


def ensure_commit(repo_path, commit):
    has_commit = subprocess.call(
        ["git", "cat-file", "-e", f"{commit}^{{commit}}"],
        cwd=repo_path,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if has_commit != 0:
        run(["git", "fetch", "--depth=1", "origin", commit], cwd=repo_path)
    run(["git", "checkout", "--force", commit], cwd=repo_path)


def ensure_v8_checkout(v8_path, v8_version):
    if os.path.exists(v8_path):
        if not is_git_repo(v8_path):
            raise RuntimeError(
                f"{v8_path} exists but is not a git repo. Remove it or pass --v8-dir."
            )
        print(f"  Existing V8 checkout found: {v8_path}")
        run(
            ["git", "fetch", "--depth=1", "origin", f"refs/tags/{v8_version}"],
            cwd=v8_path,
        )
        ensure_commit(v8_path, v8_version)
        return

    run(["git", "clone", "--depth=1", "--branch", v8_version, V8_REPO, v8_path])


def ensure_dep(v8_path, dep_name, dep_info):
    dep_path = os.path.join(v8_path, dep_info["path"])
    dep_dir = os.path.dirname(dep_path)
    os.makedirs(dep_dir, exist_ok=True)
    commit = dep_info["commit"]
    url = dep_info["url"]

    print(f"\n=== Fetching {dep_name} ===")
    if os.path.exists(dep_path):
        if not is_git_repo(dep_path):
            raise RuntimeError(
                f"{dep_path} exists but is not a git repo. Remove it and retry."
            )
        ensure_commit(dep_path, commit)
        return

    run(["git", "clone", "--depth=1", url, dep_path])
    ensure_commit(dep_path, commit)


def main():
    parser = argparse.ArgumentParser(description="Fetch V8 dependencies")
    parser.add_argument("--v8-version", default=V8_VERSION, help="V8 version tag")
    parser.add_argument("--v8-dir", default=V8_DIR, help="V8 source directory name")
    args = parser.parse_args()

    if args.v8_version != V8_VERSION:
        print(
            f"Error: this branch is pinned for V8 {V8_VERSION}. "
            f"Requested {args.v8_version}.",
            file=sys.stderr,
        )
        sys.exit(2)

    script_dir = os.path.dirname(os.path.abspath(__file__))
    v8_path = os.path.join(script_dir, args.v8_dir)

    print(f"\n=== Ensuring V8 {args.v8_version} ===")
    ensure_v8_checkout(v8_path, args.v8_version)

    for dep_name, dep_info in DEPS.items():
        ensure_dep(v8_path, dep_name, dep_info)

    head = run(["git", "rev-parse", "--short", "HEAD"], cwd=v8_path, capture_output=True)
    print("\n=== All dependencies fetched successfully ===")
    print(f"V8 source is at: {v8_path}")
    print(f"V8 HEAD: {head} (expected tag {args.v8_version})")
    print("You can now configure with CMake:")
    print("  cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release")
    print("  cmake --build build")


if __name__ == "__main__":
    main()
