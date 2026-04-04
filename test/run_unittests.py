#!/usr/bin/env python3
"""
Run V8 unit tests, each test in a separate process.

V8's platform can only be initialized once per process and cannot be
re-initialized after disposal. Since test fixtures (WithDefaultPlatformMixin)
init+dispose V8 per test, only one test per process is possible.

Usage:
    python run_unittests.py <path/to/v8_unittests.exe> [options]

Options:
    --filter PATTERN    Only run tests matching regex pattern
    --suite PATTERN     Only run suites matching regex pattern
    --timeout SECS      Per-test timeout (default: 60)
    --list              List all tests without running
    --summary           Only print summary, not individual results
"""

import subprocess
import sys
import os
import re
import time
import argparse


def get_tests(exe_path):
    """Parse --gtest_list_tests into list of 'Suite.Test' strings."""
    result = subprocess.run(
        [exe_path, "--gtest_list_tests"],
        capture_output=True, text=True, timeout=30
    )
    tests = []
    current_suite = None
    for line in result.stdout.splitlines():
        if not line.startswith(" ") and line.strip().endswith("."):
            current_suite = line.strip()
        elif line.startswith("  ") and current_suite:
            test_name = line.strip().split("#")[0].strip()
            tests.append(f"{current_suite}{test_name}")
    return tests


def run_test(exe_path, test_name, timeout=60):
    """Run a single test. Returns (passed, failed, error_msg)."""
    try:
        result = subprocess.run(
            [exe_path, f"--gtest_filter={test_name}"],
            capture_output=True, text=True, timeout=timeout
        )
        output = result.stdout + result.stderr
        if "[  PASSED  ] 1 test" in output:
            return (True, None)
        elif "[  FAILED  ] 1 test" in output:
            # Extract failure reason
            lines = output.splitlines()
            reason = ""
            for i, line in enumerate(lines):
                if "error:" in line.lower() or "Expected" in line:
                    reason = line.strip()
                    break
            return (False, reason or "FAILED")
        elif result.returncode != 0:
            for line in output.splitlines():
                if "Fatal error" in line or "Check failed" in line:
                    return (False, line.strip())
            return (False, f"exit code {result.returncode}")
        else:
            return (True, None)
    except subprocess.TimeoutExpired:
        return (False, "TIMEOUT")
    except Exception as e:
        return (False, str(e))


def main():
    parser = argparse.ArgumentParser(description="V8 unittest runner")
    parser.add_argument("exe", help="Path to v8_unittests.exe")
    parser.add_argument("--filter", help="Regex filter on full test name")
    parser.add_argument("--suite", help="Regex filter on suite name only")
    parser.add_argument("--timeout", type=int, default=60)
    parser.add_argument("--list", action="store_true")
    parser.add_argument("--summary", action="store_true")
    args = parser.parse_args()

    if not os.path.exists(args.exe):
        print(f"Error: {args.exe} not found")
        sys.exit(1)

    print(f"Listing tests from {args.exe}...")
    tests = get_tests(args.exe)
    print(f"Found {len(tests)} tests")

    if args.suite:
        tests = [t for t in tests if re.search(args.suite, t.split(".")[0], re.IGNORECASE)]
    if args.filter:
        tests = [t for t in tests if re.search(args.filter, t, re.IGNORECASE)]

    print(f"Running {len(tests)} tests")

    if args.list:
        for t in tests:
            print(f"  {t}")
        return

    passed = 0
    failed = 0
    failures = []
    start = time.time()

    for i, test in enumerate(tests):
        ok, err = run_test(args.exe, test, args.timeout)
        if ok:
            passed += 1
            if not args.summary:
                print(f"  [{i+1}/{len(tests)}] PASS: {test}")
        else:
            failed += 1
            failures.append((test, err))
            print(f"  [{i+1}/{len(tests)}] FAIL: {test} — {err}")

        if (i + 1) % 100 == 0:
            elapsed = time.time() - start
            print(f"  ... {i+1}/{len(tests)} done ({elapsed:.0f}s, "
                  f"{passed} passed, {failed} failed)")

    elapsed = time.time() - start

    print(f"\n{'='*60}")
    print(f"V8 Unit Test Results ({elapsed:.1f}s)")
    print(f"  Total:  {len(tests)}")
    print(f"  Passed: {passed}")
    print(f"  Failed: {failed}")
    print(f"  Rate:   {passed*100/max(len(tests),1):.1f}%")

    if failures:
        print(f"\nFailures ({len(failures)}):")
        for test, err in failures:
            print(f"  {test}")
            print(f"    {err}")

    print(f"{'='*60}")
    sys.exit(0 if failed == 0 else 1)


if __name__ == "__main__":
    main()
