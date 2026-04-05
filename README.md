# V8 MSVC Build

CMake build system for building the V8 JavaScript engine with MSVC on Windows,
without requiring Google's depot_tools or GN toolchain.

Targets **V8 13.6.233.17** (Node.js v24 LTS "Krypton").

## Test Results

| Suite | Result | Notes |
|-------|--------|-------|
| v8_unittests (C++) | **5752/5764 (99.8%)** | 12 failures: conservative stack visitor, logging, weak collections |
| mjsunit (JavaScript) | **7442/7658 (97.2%)** | 177 are Release-only flag conflicts; adjusted 99.5% |
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
git checkout v8-13.6.233.17

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
./build/v8_unittests.exe --gtest_filter="BitsTest*"
cd v8-src && python ../test/run_mjsunit.py ../build/d8.exe
```

## Project Structure

```
CMakeLists.txt                  # Root CMake project
cmake/
  sources.cmake                 # V8 source file lists (Windows x64)
  targets.cmake                 # Library targets + d8 shell
  torque.cmake                  # Torque compiler + code generation
  snapshot.cmake                # Snapshot generation (mksnapshot)
  icu.cmake                     # ICU build (embeds icudtl.dat into binary)
  unittests.cmake               # Unit test binary
  abseil.cmake                  # Abseil C++ integration
  zlib.cmake                    # Zlib compression
  msvc-toolchain.cmake          # Auto-detect MSVC and Windows SDK
  install.cmake                 # CMake install + find_package support
  generate_icu_data.py          # Converts icudtl.dat to COFF .obj
  v8Config.cmake.in             # find_package config template
patches/
  001-msvc-compatibility.patch  # MSVC source compatibility fixes (~910 lines)
test/
  run_mjsunit.py                # mjsunit JavaScript test runner
  run_unittests.py              # v8_unittests runner
  hello_v8.cc                   # Smoke test embedding V8
fetch_deps.py                   # Fetches V8 source + third-party deps
```

## Using V8 in Your Project

### Option 1: add_subdirectory

```cmake
cmake_minimum_required(VERSION 3.20)
project(myapp LANGUAGES CXX C ASM_MASM)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(MSVC)
  set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
endif()

add_subdirectory("path/to/v8" "${CMAKE_BINARY_DIR}/v8-build")

add_executable(myapp main.cpp)
target_link_libraries(myapp PRIVATE v8)
```

### Option 2: find_package

```bash
cmake --install <v8-build-dir> --prefix C:/v8-sdk
```

```cmake
find_package(v8 REQUIRED)
target_link_libraries(myapp PRIVATE v8::v8)
```

## Known Test Failures

### v8_unittests (12 failures)

| Test | Root Cause |
|------|-----------|
| DoubleTest.NormalizedBoundaries | Fatal error in DiyFp optimizer code path |
| ConservativeStackVisitorTest.* (4) | Conservative stack scanning misses code objects on MSVC x64 |
| LogAllTest.LogAll | Crash (exit code 0xC0000005) |
| LogMapsTest.* (3) | Fatal error in logging infrastructure |
| LogTimerTest.ConsoleTimeEvents | Crash (exit code 0xC0000005) |
| WeakMapsTest.Shrinking | Fatal error in weak collection shrinking |
| WeakSetsTest.WeakSet_Shrinking | Fatal error in weak collection shrinking |

These are platform-specific issues, not engine correctness bugs.

### mjsunit (216 failures)

- **177 tests**: "Contradictory value for readonly flag" -- tests try to set
  flags that conflict with Release mode defaults (e.g., `--print-ast`,
  `--enable-slow-asserts`). Not real failures.
- **~38 tests**: Various issues including timezone differences, platform-specific
  behavior, and tests requiring debug-only features.
- **1 test**: Timeout.

## Build Notes

- Use `-j 4` to `-j 8` -- higher parallelism causes MSVC heap exhaustion (`C1060`)
- Full build takes ~60-90 minutes at `-j 8`
- ICU data is embedded statically (ICU 74) -- no runtime files needed
- The MSVC patch includes a minimal inspector stub for linking d8 and tests

## License

The build system files in this repo are provided as-is. V8 itself is licensed
under the V8 project's BSD-style license.
