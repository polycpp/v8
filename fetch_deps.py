#!/usr/bin/env python3
"""Fetch pinned V8 12.4.254.21 source and third-party dependencies."""

import os
import subprocess

V8_VERSION = "12.4.254.21"
V8_REPO = "https://chromium.googlesource.com/v8/v8.git"
V8_DIR = "v8-src"

DEPS = {
    "abseil-cpp": {
        "url": "https://chromium.googlesource.com/chromium/src/third_party/abseil-cpp.git",
        "commit": "b3ae305fd5dbc6ad41eed9add26768c29181219f",
        "path": "v8-src/third_party/abseil-cpp",
    },
    "fp16": {
        "url": "https://chromium.googlesource.com/external/github.com/Maratyszcza/FP16.git",
        "commit": "0a92994d729ff76a58f692d3028ca1b64b145d91",
        "path": "v8-src/third_party/fp16/src",
    },
    "googletest": {
        "url": "https://chromium.googlesource.com/external/github.com/google/googletest.git",
        "commit": "b479e7a3c161d7087113a05f8cb034b870313a55",
        "path": "v8-src/third_party/googletest/src",
    },
    "icu": {
        "url": "https://chromium.googlesource.com/chromium/deps/icu.git",
        "commit": "a622de35ac311c5ad390a7af80724634e5dc61ed",
        "path": "v8-src/third_party/icu",
    },
    "zlib": {
        "url": "https://chromium.googlesource.com/chromium/src/third_party/zlib.git",
        "commit": "c5bf1b566e5df14e763507e2ce30cbfebefeeccf",
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
