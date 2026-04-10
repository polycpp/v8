#!/usr/bin/env python3
"""Fetch pinned V8 13.6.233.17 source and third-party dependencies."""

import os
import subprocess

V8_VERSION = "13.6.233.17"
V8_REPO = "https://chromium.googlesource.com/v8/v8.git"
V8_DIR = "v8-src"

DEPS = {
    "abseil-cpp": {
        "url": "https://chromium.googlesource.com/chromium/src/third_party/abseil-cpp.git",
        "commit": "3fbb10e80d80e3430224b75add53c47c7a711612",
        "path": "v8-src/third_party/abseil-cpp",
    },
    "fast_float": {
        "url": "https://chromium.googlesource.com/external/github.com/fastfloat/fast_float.git",
        "commit": "cb1d42aaa1e14b09e1452cfdef373d051b8c02a4",
        "path": "v8-src/third_party/fast_float/src",
    },
    "fp16": {
        "url": "https://chromium.googlesource.com/external/github.com/Maratyszcza/FP16.git",
        "commit": "0a92994d729ff76a58f692d3028ca1b64b145d91",
        "path": "v8-src/third_party/fp16/src",
    },
    "googletest": {
        "url": "https://chromium.googlesource.com/external/github.com/google/googletest.git",
        "commit": "52204f78f94d7512df1f0f3bea1d47437a2c3a58",
        "path": "v8-src/third_party/googletest/src",
    },
    "highway": {
        "url": "https://chromium.googlesource.com/external/github.com/google/highway.git",
        "commit": "00fe003dac355b979f36157f9407c7c46448958e",
        "path": "v8-src/third_party/highway/src",
    },
    "icu": {
        "url": "https://chromium.googlesource.com/chromium/deps/icu.git",
        "commit": "c9fb4b3a6fb54aa8c20a03bbcaa0a4a985ffd34b",
        "path": "v8-src/third_party/icu",
    },
    "simdutf": {
        "url": "https://chromium.googlesource.com/chromium/src/third_party/simdutf",
        "commit": "40d1fa26cd5ca221605c974e22c001ca2fb12fde",
        "path": "v8-src/third_party/simdutf",
    },
    "zlib": {
        "url": "https://chromium.googlesource.com/chromium/src/third_party/zlib.git",
        "commit": "788cb3c270e8700b425c7bdca1f9ce6b0c1400a9",
        "path": "v8-src/third_party/zlib",
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
            raise RuntimeError(f"{v8_path} exists but is not a git repo.")
        print(f"  Existing V8 checkout found: {v8_path}")
        run(
            [
                "git",
                "fetch",
                "--depth=1",
                "origin",
                f"refs/tags/{v8_version}:refs/tags/{v8_version}",
            ],
            cwd=v8_path,
        )
        run(["git", "checkout", "--force", f"refs/tags/{v8_version}"], cwd=v8_path)
        return

    run(["git", "clone", "--depth=1", "--branch", v8_version, V8_REPO, v8_path])


def ensure_dep(dep_name, dep_info):
    dep_path = dep_info["path"]
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
    script_dir = os.path.dirname(os.path.abspath(__file__))
    v8_path = os.path.join(script_dir, V8_DIR)

    print(f"\n=== Ensuring V8 {V8_VERSION} ===")
    ensure_v8_checkout(v8_path, V8_VERSION)

    for dep_name, dep_info in DEPS.items():
        dep_info["path"] = os.path.join(script_dir, dep_info["path"])
        ensure_dep(dep_name, dep_info)

    head = run(["git", "rev-parse", "--short", "HEAD"], cwd=v8_path, capture_output=True)
    print("\n=== All dependencies fetched successfully ===")
    print(f"V8 source is at: {v8_path}")
    print(f"V8 HEAD: {head} (expected tag {V8_VERSION})")


if __name__ == "__main__":
    main()
