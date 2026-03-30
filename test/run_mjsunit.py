#!/usr/bin/env python3
"""Simple mjsunit test runner for V8 MSVC builds.

Runs mjsunit JavaScript tests through d8, parsing test-specific flags
from comment directives in each test file.

Usage:
    python run_mjsunit.py <d8_path> [--limit N] [--timeout SECS] [--filter PATTERN]
"""

import os
import re
import subprocess
import sys
import argparse
import time
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed

FLAGS_PATTERN = re.compile(r"//\s+Flags:\s*(.*)")
FILES_PATTERN = re.compile(r"//\s+Files:\s*(.*)")
NO_HARNESS_PATTERN = re.compile(r"^//\s*NO HARNESS\s*$", re.MULTILINE)


def parse_test_directives(test_path):
    """Parse // Flags:, // Files:, and // NO HARNESS from test file."""
    flags = []
    files = []
    no_harness = False
    try:
        with open(test_path, 'r', encoding='utf-8', errors='replace') as f:
            content = f.read(4096)  # Only check first 4KB
    except Exception:
        return flags, files, no_harness

    for m in FLAGS_PATTERN.finditer(content):
        flags.extend(m.group(1).strip().split())

    for m in FILES_PATTERN.finditer(content):
        files.extend(m.group(1).strip().split())

    if NO_HARNESS_PATTERN.search(content):
        no_harness = True

    return flags, files, no_harness


def run_test(d8_path, test_path, mjsunit_js, v8_root, timeout):
    """Run a single mjsunit test. Returns (test_name, passed, duration, error)."""
    flags, extra_files, no_harness = parse_test_directives(test_path)

    cmd = [d8_path, "--test"]
    cmd.extend(flags)

    if not no_harness:
        cmd.append(str(mjsunit_js))

    # Resolve extra files relative to test directory
    test_dir = os.path.dirname(test_path)
    for f in extra_files:
        resolved = os.path.join(v8_root, f) if not os.path.isabs(f) else f
        if not os.path.exists(resolved):
            resolved = os.path.join(test_dir, f)
        cmd.append(resolved)

    cmd.append(str(test_path))

    test_name = os.path.relpath(test_path, os.path.join(v8_root, "test", "mjsunit"))

    start = time.time()
    try:
        result = subprocess.run(
            cmd, capture_output=True, text=True, timeout=timeout,
            cwd=os.path.dirname(d8_path)
        )
        duration = time.time() - start
        if result.returncode == 0:
            return test_name, True, duration, None
        else:
            error = result.stderr.strip() or result.stdout.strip()
            # Truncate long error messages
            if len(error) > 200:
                error = error[:200] + "..."
            return test_name, False, duration, error
    except subprocess.TimeoutExpired:
        duration = time.time() - start
        return test_name, False, duration, "TIMEOUT"
    except Exception as e:
        duration = time.time() - start
        return test_name, False, duration, str(e)


def collect_tests(mjsunit_dir, filter_pattern=None):
    """Collect all .js test files, excluding harness files."""
    exclude = {"mjsunit.js", "mjsunit_numfuzz.js"}
    tests = []
    for root, dirs, files in os.walk(mjsunit_dir):
        for f in sorted(files):
            if f.endswith(".js") and f not in exclude:
                path = os.path.join(root, f)
                rel = os.path.relpath(path, mjsunit_dir)
                if filter_pattern and not re.search(filter_pattern, rel):
                    continue
                tests.append(path)
    return tests


def main():
    parser = argparse.ArgumentParser(description="V8 mjsunit test runner")
    parser.add_argument("d8", help="Path to d8 executable")
    parser.add_argument("--limit", type=int, default=0, help="Max tests to run (0=all)")
    parser.add_argument("--timeout", type=int, default=30, help="Timeout per test in seconds")
    parser.add_argument("--filter", default=None, help="Regex filter for test names")
    parser.add_argument("--jobs", "-j", type=int, default=1, help="Parallel test jobs")
    parser.add_argument("--v8-root", default=None, help="V8 source root")
    parser.add_argument("--verbose", "-v", action="store_true", help="Show all results")
    args = parser.parse_args()

    d8_path = os.path.abspath(args.d8)
    if not os.path.exists(d8_path):
        print(f"Error: d8 not found at {d8_path}", file=sys.stderr)
        sys.exit(1)

    # Auto-detect V8 root
    v8_root = args.v8_root
    if not v8_root:
        # Try relative to d8
        candidate = os.path.join(os.path.dirname(d8_path), "..", "v8-src")
        if os.path.isdir(candidate):
            v8_root = os.path.abspath(candidate)
        else:
            print("Error: Cannot find V8 root. Use --v8-root.", file=sys.stderr)
            sys.exit(1)

    mjsunit_dir = os.path.join(v8_root, "test", "mjsunit")
    mjsunit_js = os.path.join(mjsunit_dir, "mjsunit.js")

    if not os.path.exists(mjsunit_js):
        print(f"Error: mjsunit.js not found at {mjsunit_js}", file=sys.stderr)
        sys.exit(1)

    tests = collect_tests(mjsunit_dir, args.filter)
    if args.limit > 0:
        tests = tests[:args.limit]

    total = len(tests)
    print(f"Running {total} mjsunit tests (timeout={args.timeout}s, jobs={args.jobs})")
    print()

    passed = 0
    failed = 0
    errors = []
    start_time = time.time()

    if args.jobs <= 1:
        for i, test in enumerate(tests):
            name, ok, dur, err = run_test(d8_path, test, mjsunit_js, v8_root, args.timeout)
            if ok:
                passed += 1
                if args.verbose:
                    print(f"  PASS  {name} ({dur:.1f}s)")
            else:
                failed += 1
                errors.append((name, err))
                print(f"  FAIL  {name} ({dur:.1f}s) -- {err}")

            if (i + 1) % 100 == 0:
                print(f"  ... {i+1}/{total} ({passed} pass, {failed} fail)")
    else:
        with ThreadPoolExecutor(max_workers=args.jobs) as pool:
            futures = {
                pool.submit(run_test, d8_path, t, mjsunit_js, v8_root, args.timeout): t
                for t in tests
            }
            done = 0
            for future in as_completed(futures):
                done += 1
                name, ok, dur, err = future.result()
                if ok:
                    passed += 1
                    if args.verbose:
                        print(f"  PASS  {name} ({dur:.1f}s)")
                else:
                    failed += 1
                    errors.append((name, err))
                    print(f"  FAIL  {name} ({dur:.1f}s) -- {err}")

                if done % 100 == 0:
                    print(f"  ... {done}/{total} ({passed} pass, {failed} fail)")

    elapsed = time.time() - start_time
    print()
    print(f"{'='*60}")
    print(f"Results: {passed}/{total} passed, {failed} failed ({elapsed:.0f}s)")
    print(f"Pass rate: {100*passed/total:.1f}%" if total > 0 else "No tests")
    print(f"{'='*60}")

    if errors and not args.verbose:
        print(f"\nFailed tests ({len(errors)}):")
        for name, err in sorted(errors)[:50]:
            print(f"  {name}: {err}")
        if len(errors) > 50:
            print(f"  ... and {len(errors)-50} more")

    sys.exit(0 if failed == 0 else 1)


if __name__ == "__main__":
    main()
