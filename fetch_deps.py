#!/usr/bin/env python3
"""Fetch pinned V8 10.2.154.26 source and third-party dependencies."""

import os
import subprocess

V8_VERSION = "10.2.154.26"
V8_REPO = "https://chromium.googlesource.com/v8/v8.git"
V8_DIR = "v8-src"

DEPS = {
    "googletest": {
        "url": "https://chromium.googlesource.com/external/github.com/google/googletest.git",
        "commit": "af29db7ec28d6df1c7f0f745186884091e602e07",
        "path": "v8-src/third_party/googletest/src",
    },
    "icu": {
        "url": "https://chromium.googlesource.com/chromium/deps/icu.git",
        "commit": "1fd0dbea04448c3f73fe5cb7599f9472f0f107f1",
        "path": "v8-src/third_party/icu",
    },
    "zlib": {
        "url": "https://chromium.googlesource.com/chromium/src/third_party/zlib.git",
        "commit": "a6d209ab932df0f1c9d5b7dc67cfa74e8a3272c0",
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
