#!/usr/bin/env python3
"""Orchestrate adding a new V8 version to the build system.

This is the master script that runs the automated discovery and generation
phases. Manual phases (MSVC patching, build fixing) are handled by agents
using the prompts in prompts/.

Usage:
    python scripts/orchestrate.py --version 13.6.233.17 --node-version v24.14.1
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
from datetime import datetime


SCRIPTS_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPTS_DIR)


def run(cmd, **kwargs):
    """Run a command and return (returncode, stdout)."""
    print(f"  $ {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=True, text=True, **kwargs)
    if result.returncode != 0 and result.stderr:
        print(f"  stderr: {result.stderr[:500]}")
    return result.returncode, result.stdout


def phase_1_setup(version: str, node_version: str):
    """Phase 1: Generate fetch_deps.py and fetch V8 source."""
    print("\n" + "=" * 60)
    print(f"PHASE 1: Setup & Discovery for V8 {version}")
    print("=" * 60)

    # Step 1: Generate fetch_deps.py
    print("\n[1/3] Generating fetch_deps.py...")
    rc, _ = run([
        sys.executable,
        os.path.join(SCRIPTS_DIR, "generate_fetch_deps.py"),
        "--version", version,
        "--output", os.path.join(REPO_ROOT, "fetch_deps.py"),
    ])
    if rc != 0:
        print("ERROR: Failed to generate fetch_deps.py")
        return False

    # Step 2: Fetch V8 source and deps
    print("\n[2/3] Fetching V8 source and dependencies...")
    rc, _ = run(
        [sys.executable, os.path.join(REPO_ROOT, "fetch_deps.py")],
        cwd=REPO_ROOT,
    )
    if rc != 0:
        print("ERROR: Failed to fetch V8 source")
        return False

    # Step 3: Detect features
    print("\n[3/3] Detecting version features...")
    features_path = os.path.join(REPO_ROOT, "version_features.json")
    rc, _ = run([
        sys.executable,
        os.path.join(SCRIPTS_DIR, "detect_features.py"),
        "--source-dir", os.path.join(REPO_ROOT, "v8-src"),
        "--output", features_path,
    ])
    if rc != 0:
        print("ERROR: Failed to detect features")
        return False

    with open(features_path) as f:
        features = json.load(f)
    print(f"\nDetected features for V8 {features.get('version', version)}:")
    print(json.dumps(features, indent=2))
    return True


def phase_2_generate(version: str):
    """Phase 2: Generate CMake files from templates and V8 source."""
    print("\n" + "=" * 60)
    print(f"PHASE 2: Code Generation for V8 {version}")
    print("=" * 60)

    features_path = os.path.join(REPO_ROOT, "version_features.json")
    source_dir = os.path.join(REPO_ROOT, "v8-src")

    # Step 1: Generate sources.cmake
    print("\n[1/3] Generating cmake/sources.cmake...")
    os.makedirs(os.path.join(REPO_ROOT, "cmake"), exist_ok=True)
    rc, _ = run([
        sys.executable,
        os.path.join(SCRIPTS_DIR, "generate_sources.py"),
        "--source-dir", source_dir,
        "--features", features_path,
        "--output", os.path.join(REPO_ROOT, "cmake", "sources.cmake"),
    ])
    if rc != 0:
        print("WARNING: Source generation had issues (may need manual adjustment)")

    # Step 2: Generate torque file list
    print("\n[2/3] Generating torque file list...")
    rc, _ = run([
        sys.executable,
        os.path.join(SCRIPTS_DIR, "generate_torque_list.py"),
        "--source-dir", source_dir,
        "--output", os.path.join(REPO_ROOT, "torque_files.json"),
        "--format", "json",
    ])

    # Step 3: Copy stable cmake modules from dev branch
    print("\n[3/3] Copying stable cmake modules...")
    stable_modules = [
        "icu.cmake",
        "abseil.cmake",
        "zlib.cmake",
        "snapshot.cmake",
        "install.cmake",
        "unittests.cmake",
        "msvc-toolchain.cmake",
        "generate_icu_data.py",
        "v8Config.cmake.in",
    ]
    cmake_src = os.path.join(REPO_ROOT, "cmake")
    for module in stable_modules:
        src = os.path.join(cmake_src, module)
        if os.path.exists(src):
            print(f"  {module}: exists")
        else:
            print(f"  {module}: MISSING (needs to be created or copied from reference branch)")

    return True


def phase_3_report(version: str):
    """Generate a report of what needs manual attention."""
    print("\n" + "=" * 60)
    print(f"PHASE 3: Status Report for V8 {version}")
    print("=" * 60)

    features_path = os.path.join(REPO_ROOT, "version_features.json")
    if os.path.exists(features_path):
        with open(features_path) as f:
            features = json.load(f)
    else:
        features = {}

    print("\n--- Generated files ---")
    generated = [
        "fetch_deps.py",
        "version_features.json",
        "cmake/sources.cmake",
        "torque_files.json",
    ]
    for f in generated:
        path = os.path.join(REPO_ROOT, f)
        if os.path.exists(path):
            size = os.path.getsize(path)
            print(f"  [OK] {f} ({size} bytes)")
        else:
            print(f"  [MISSING] {f}")

    print("\n--- Manual work needed ---")
    print("  1. Review and fix cmake/sources.cmake (GN parser may miss edge cases)")
    print("  2. Create cmake/targets.cmake (link libraries, dependencies)")
    print("  3. Create cmake/torque.cmake (torque build rules + file list)")
    print("  4. Create CMakeLists.txt (compile definitions, options)")
    print("  5. Attempt build and create MSVC patches")
    print("  6. Iterate until build succeeds")
    print("  7. Run tests and document results")

    print("\n--- Recommended next steps ---")
    print("  Use the coordinator prompt (prompts/coordinator.md) to guide")
    print("  an agent through the manual phases.")
    print(f"\n  Reference the nearest working branch for cmake/ file templates.")

    # Save state
    state = {
        "version": version,
        "phase": "manual_work_needed",
        "features": features,
        "generated_at": datetime.now().isoformat(),
        "generated_files": [f for f in generated
                           if os.path.exists(os.path.join(REPO_ROOT, f))],
    }
    state_path = os.path.join(REPO_ROOT, "build_state.json")
    with open(state_path, "w") as f:
        json.dump(state, f, indent=2)
    print(f"\n  State saved to {state_path}")


def main():
    parser = argparse.ArgumentParser(
        description="Orchestrate adding a new V8 version"
    )
    parser.add_argument("--version", required=True, help="V8 version (e.g., 13.6.233.17)")
    parser.add_argument("--node-version", default="", help="Node.js version (e.g., v24.14.1)")
    parser.add_argument("--skip-fetch", action="store_true", help="Skip fetching if v8-src exists")
    parser.add_argument(
        "--stop-after",
        choices=["setup", "generate", "report"],
        default="report",
        help="Stop after this phase",
    )
    args = parser.parse_args()

    print(f"V8 MSVC CMake Build — Adding V8 {args.version}")
    if args.node_version:
        print(f"  Node.js: {args.node_version}")
    print(f"  Date: {datetime.now().strftime('%Y-%m-%d %H:%M')}")

    # Phase 1
    if not args.skip_fetch:
        if not phase_1_setup(args.version, args.node_version):
            print("\nPhase 1 failed. Fix issues and retry.")
            sys.exit(1)
    else:
        print("\nSkipping fetch (--skip-fetch)")
        # Still run feature detection
        features_path = os.path.join(REPO_ROOT, "version_features.json")
        run([
            sys.executable,
            os.path.join(SCRIPTS_DIR, "detect_features.py"),
            "--source-dir", os.path.join(REPO_ROOT, "v8-src"),
            "--output", features_path,
        ])

    if args.stop_after == "setup":
        print("\nStopped after setup phase.")
        return

    # Phase 2
    phase_2_generate(args.version)
    if args.stop_after == "generate":
        print("\nStopped after generate phase.")
        return

    # Phase 3
    phase_3_report(args.version)


if __name__ == "__main__":
    main()
