# Sub-Agent Prompt: Test Verification

## Task

Run tests against a successful V8 `{V8_VERSION}` build and report results.

## Input

- `BUILD_DIR`: Path to the build directory
- `SOURCE_DIR`: Path to the V8 source tree
- `REFERENCE_RESULTS`: Expected pass rates from reference branch (if available)

## Test Sequence

### 1. Smoke Test (must pass before proceeding)
```bash
cd {BUILD_DIR}
echo "console.log(1+2)" | ./d8.exe
# Expected output: 3
```

If d8 crashes or produces wrong output, stop and report immediately.

### 2. Hello V8 Embedding Test
```bash
./hello_v8.exe
# Expected: "External V8 embedding test PASSED!" or similar
```

### 3. JavaScript Tests (mjsunit)
```bash
cd {SOURCE_DIR}/v8-src
python ../test/run_mjsunit.py ../build/d8.exe
```

Record: total tests, passed, failed, skipped, timeout.

### 4. C++ Unit Tests
```bash
cd {BUILD_DIR}
./v8_unittests.exe --gtest_output=json:test_results.json
```

Record: total tests, passed, failed, disabled.

## Output Format

```json
{
  "version": "{V8_VERSION}",
  "smoke_test": {"passed": true|false, "output": "..."},
  "hello_v8": {"passed": true|false, "output": "..."},
  "mjsunit": {
    "total": N,
    "passed": N,
    "failed": N,
    "skipped": N,
    "timeout": N,
    "pass_rate": "XX.X%",
    "failed_tests": ["test1.js", "test2.js", ...]
  },
  "unittests": {
    "total": N,
    "passed": N,
    "failed": N,
    "disabled": N,
    "pass_rate": "XX.X%",
    "failed_tests": ["Suite.Test1", "Suite.Test2", ...]
  },
  "comparison_to_reference": {
    "mjsunit_delta": "+X/-Y",
    "unittests_delta": "+X/-Y",
    "notes": "..."
  },
  "overall_verdict": "PASS|ACCEPTABLE|FAIL",
  "notes": "..."
}
```

## Verdict Criteria

- **PASS**: Smoke test passes, mjsunit >95%, unittests >99%
- **ACCEPTABLE**: Smoke test passes, mjsunit >90%, unittests >95%
- **FAIL**: Smoke test fails, or mjsunit <90%, or unittests <95%

## Important

- Always run smoke test first — if d8 crashes, no point running full test suites
- mjsunit must be run from the `v8-src/` directory (it needs relative paths to test fixtures)
- Some test failures are expected (timezone-dependent, Release-only flags, etc.) — compare to reference
- Timeout individual tests at 30 seconds
- If unittests binary doesn't exist (build didn't include tests), note this and skip
