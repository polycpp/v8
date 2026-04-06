# V8 MSVC Build

CMake build system for building the V8 JavaScript engine with MSVC on Windows,
without requiring Google's depot_tools or GN toolchain.

Targets **V8 12.4.254.21** (Node.js v22 LTS "Jod").

## Test Results

| Suite | Result | Notes |
|-------|--------|-------|
| v8_unittests (C++) | **5487/5490 (99.9%)** | 3 failures: weak collections shrinking, DiyFp |
| mjsunit (JavaScript) | **6383/6475 (98.6%)** | 92 failures, 109 skipped (debug-only flags) |
| hello_v8.exe (smoke) | **PASS** | Arithmetic, JSON, closures, Map, WebAssembly, Intl |
| d8.exe (smoke) | **PASS** | `d8 -e "print(1+2)"` outputs `3` |

## Prerequisites

- Visual Studio with C++ workload (MSVC 19.x -- tested with VS 2025 / MSVC 19.50)
- CMake 3.20+
- Ninja
- Python 3
- Git

## Quick Start

```bash
# 1. Clone this repo and checkout this branch
git clone https://github.com/polycpp/v8.git v8-msvc
cd v8-msvc
git checkout v8-12.4.254.21

# 2. Fetch V8 source and dependencies
python fetch_deps.py

# 3. Apply MSVC patches
cd v8-src && git apply ../patches/001-msvc-compatibility.patch && cd ..

# 4. Configure (from VS Developer Command Prompt)
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release

# Or from plain shell using the toolchain file:
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_TOOLCHAIN_FILE=cmake/msvc-toolchain.cmake

# 5. Build everything (libraries + d8 + tests)
cmake --build build -j 8

# 6. Run tests
python test/run_unittests.py build/v8_unittests.exe
python test/run_mjsunit.py build/d8.exe
```

## Version-Specific Notes

V8 12.4 differs from newer versions in several ways:

- **No highway, simdutf, fast_float, dragonbox** third-party dependencies
- **No leaptiering** -- feature didn't exist yet
- **Older heap internals** -- page.cc, mutable-page.cc instead of page-metadata.cc
- **Chromium trace event dependency** -- stub provided for `base/trace_event/common/trace_event_common.h`
- **ICU 73** with C++20 `operator==` ambiguity fix (patched `measure.h`)
- **`std::assume_aligned<4GB>`** -- MSVC rejects alignments > 2^31; patched `v8config.h`
- **Wasm fuzzer stub** -- `GenerateRandomWasmModule` stubbed out (no fuzzer library)

## Known Test Failures

### v8_unittests (3 failures)

| Test | Root Cause |
|------|-----------|
| DoubleTest.NormalizedBoundaries | Fatal error in DiyFp optimizer code path |
| WeakMapsTest.Shrinking | Fatal error in weak collection shrinking |
| WeakSetsTest.WeakSet_Shrinking | Fatal error in weak collection shrinking |

### mjsunit (92 failures, 109 skipped)

- **109 tests skipped**: Require debug-only flags (`--verify-heap`,
  `--enable-slow-asserts`, etc.) that are readonly in Release builds.
- **~92 tests failed**: Various issues including timezone differences,
  shared heap assertions, platform-specific behavior.

## License

The build system files in this repo are provided as-is. V8 itself is licensed
under the V8 project's BSD-style license.
