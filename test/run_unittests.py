#!/usr/bin/env python3
"""
Run V8 unit tests, each test suite in a separate process.
V8 requires platform to be initialized only once per process,
so we run each test suite (or individual test) separately.

Usage:
    python run_unittests.py [path/to/v8_unittests.exe] [--filter PATTERN]
"""

import subprocess
import sys
import os
import re
import time

def get_test_suites(exe_path):
    """Get list of test suites from --gtest_list_tests."""
    result = subprocess.run(
        [exe_path, "--gtest_list_tests"],
        capture_output=True, text=True, timeout=30
    )
    suites = []
    for line in result.stdout.splitlines():
        if line and not line.startswith(" ") and line.endswith("."):
            suites.append(line.rstrip("."))
    return suites


def run_suite(exe_path, suite_name, timeout=120):
    """Run a single test suite. Returns (passed, failed, errors)."""
    try:
        result = subprocess.run(
            [exe_path, f"--gtest_filter={suite_name}.*"],
            capture_output=True, text=True, timeout=timeout
        )
        output = result.stdout + result.stderr

        # Parse results
        passed = 0
        failed = 0
        match = re.search(r"\[  PASSED  \] (\d+) test", output)
        if match:
            passed = int(match.group(1))
        match = re.search(r"\[  FAILED  \] (\d+) test", output)
        if match:
            failed = int(match.group(1))

        if result.returncode != 0 and passed == 0 and failed == 0:
            return (0, 0, "CRASH")

        return (passed, failed, None)

    except subprocess.TimeoutExpired:
        return (0, 0, "TIMEOUT")
    except Exception as e:
        return (0, 0, str(e))


def main():
    exe_path = sys.argv[1] if len(sys.argv) > 1 else "build3/v8_unittests.exe"
    filter_pattern = None
    if "--filter" in sys.argv:
        idx = sys.argv.index("--filter")
        filter_pattern = sys.argv[idx + 1] if idx + 1 < len(sys.argv) else None

    if not os.path.exists(exe_path):
        print(f"Error: {exe_path} not found")
        sys.exit(1)

    print(f"Getting test suites from {exe_path}...")
    suites = get_test_suites(exe_path)
    print(f"Found {len(suites)} test suites")

    if filter_pattern:
        suites = [s for s in suites if re.search(filter_pattern, s, re.IGNORECASE)]
        print(f"Filtered to {len(suites)} suites matching '{filter_pattern}'")

    total_passed = 0
    total_failed = 0
    crashed = []
    timed_out = []
    failed_suites = []
    start_time = time.time()

    for i, suite in enumerate(suites):
        passed, failed, error = run_suite(exe_path, suite)
        total_passed += passed
        total_failed += failed

        status = ""
        if error == "CRASH":
            crashed.append(suite)
            status = "CRASH"
        elif error == "TIMEOUT":
            timed_out.append(suite)
            status = "TIMEOUT"
        elif error:
            crashed.append(suite)
            status = f"ERROR: {error}"
        elif failed > 0:
            failed_suites.append((suite, failed))
            status = f"FAIL({failed})"
        else:
            status = f"OK({passed})"

        print(f"  [{i+1}/{len(suites)}] {suite}: {status}")

    elapsed = time.time() - start_time
    print(f"\n{'='*60}")
    print(f"Results ({elapsed:.1f}s):")
    print(f"  Suites run:  {len(suites)}")
    print(f"  Tests passed: {total_passed}")
    print(f"  Tests failed: {total_failed}")
    print(f"  Suites crashed: {len(crashed)}")
    print(f"  Suites timed out: {len(timed_out)}")

    if failed_suites:
        print(f"\nFailed suites:")
        for suite, count in failed_suites:
            print(f"  {suite}: {count} failures")

    if crashed:
        print(f"\nCrashed suites ({len(crashed)}):")
        for s in crashed[:20]:
            print(f"  {s}")
        if len(crashed) > 20:
            print(f"  ... and {len(crashed) - 20} more")

    if timed_out:
        print(f"\nTimed out suites:")
        for s in timed_out:
            print(f"  {s}")

    sys.exit(1 if total_failed > 0 or crashed else 0)


if __name__ == "__main__":
    main()
