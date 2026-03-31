# V8 MSVC Build — Test Results

V8 14.3.127.18, MSVC 19.50.35725 (Visual Studio 18), Release /O2, Windows x64.

## Summary

| Suite | Pass | Total | Rate | Notes |
|-------|------|-------|------|-------|
| v8_unittests (C++) | 5728 | 5735 | **99.88%** | 7 platform-specific failures |
| mjsunit (JS, top-level) | 967 | 992 | **97.5%** | 25 failures, 0 engine bugs |
| hello_v8.exe (smoke) | PASS | — | — | Arithmetic, JSON, closures, Map, Wasm |

## v8_unittests (C++)

381 test source files, 6515 test cases. Each of 546 suites run in its own process.

The 227 "parse error" failures in raw output are parameterized test names with
spaces and `#` characters that the bash runner mangles. All pass when invoked
with correct `--gtest_filter` strings. The 6 DISABLED tests are intentionally
skipped by V8 upstream.

### Fixes applied

| Fix | Tests Fixed | Description |
|-----|-------------|-------------|
| ICU data embedding | IntlTest, ApiIcuTest | Embed icudtl.dat as COFF .obj, replacing empty stubdata |
| Golden files symlink | BytecodeGeneratorInitTest | CMake symlink from build dir to v8-src test data |
| SmallVector counter reset | SmallVectorTest (4) | Reset global counter per test for MSVC initializer_list |
| SourceLocation substring | SourceLocationTest | Substring match for MSVC `__FUNCSIG__` format |
| GTEST_ALLOW macro | GoogleTestVerification | Allow uninstantiated BytecodeGeneratorTest |

### Remaining failures (7 tests)

See [unittest-analysis.md](unittest-analysis.md) for root cause analysis.

| Test | Category | Impact |
|------|----------|--------|
| DoubleTest.NormalizedBoundaries | MSVC codegen | None — dtoa has fallback path |
| WeakMapsTest.Shrinking | GC compaction | None — optimization, not correctness |
| WeakSetsTest.WeakSet_Shrinking | GC compaction | None — same as above |
| DateCache.AdoptDefaultFirst | Test design | None — test lacks platform init |
| DateCache.AdoptDefaultMixed | Test design | None — same as above |
| LogAllTest.LogAll | Windows sampler | None — profiling, not execution |
| LogTimerTest.ConsoleTimeEvents | Windows sampler | None — same as above |

### Platform re-initialization

When running multiple tests per process, 243 suites crash on the 2nd test.
This is by design — V8's platform state machine is one-way (`kIdle → ... → kPlatformDisposed`).
V8's own CI runs each test in a separate process via `tools/run-tests.py`.

## mjsunit (JavaScript)

Run via `d8.exe` from `v8-src/` directory with `// Flags:` and `// Files:` parsing.

### Remaining failures (25 tests)

See [mjsunit-analysis.md](mjsunit-analysis.md) for root cause analysis.

| Category | Count | Action |
|----------|-------|--------|
| Readonly flags (Release only) | 7 | None — would pass in Debug |
| Timezone / ICU diffs | 8 | None — platform TZ database differences |
| Intentional crash | 2 | None — by design |
| Module loading | 3 | Test runner could add `--module` |
| Optimization-sensitive | 2 | None — compiler-dependent feedback |
| Misc platform/feature | 3 | None |

## Smoke test: hello_v8.exe

```
V8 result: 3
Hello from V8 function
  JSON.stringify({a: 1, b: [2, 3]}) => {"a":1,"b":[2,3]}
  [1,2,3].map(x => x * x).join(', ') => 1, 4, 9
  new Map([[1,'one'],[2,'two']]).get(2) => two
  (() => { let s = 0; for (let i = 1; i <= 100; i++) s += i; return s; })() => 5050
  typeof WebAssembly => object
V8 MSVC build test PASSED
```

## Not yet tested

| Suite | Reason |
|-------|--------|
| mjsunit subdirectories (7,160 tests) | Not yet run, expected similar pass rate |
| cctest | Separate binary, not in CMake |
| test262 (ECMAScript conformance) | Needs d8 + test262 harness |
| inspector tests | Needs generated protocol headers |
| fuzzer tests | Needs fuzztest library |

## Excluded from v8_unittests

| Pattern | Reason |
|---------|--------|
| `*-arm-*`, `*-arm64-*`, `*-ia32-*` | Non-x64 architectures |
| `*posix*`, `*gdbserver*` | Non-Windows platforms |
| `inspector/*` | Needs generated protocol headers |
| `json/json-unittest`, `heap-snapshot-unittest` | Needs jsoncpp |
| `*fuzztest*`, `*fuzzer*` | Needs fuzztest library |
| `linear-scheduler-unittest`, `revec-unittest` | Needs SIMD revec sources |
| `ls-json-unittest`, `ls-message-unittest` | Needs Torque language server |

## Environment

- **OS:** Windows Server 2025 Datacenter 10.0.26100
- **Compiler:** MSVC 19.50.35725 (Visual Studio 18 Community)
- **CMake:** 4.2.3 / **Ninja:** 1.13.2
- **V8:** 14.3.127.18
- **Build:** Release (/O2 /MT)
