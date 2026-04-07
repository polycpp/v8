# V8 MSVC Build

CMake build system for building the V8 JavaScript engine with MSVC on Windows,
without requiring Google's depot_tools or GN toolchain.

Targets **V8 11.3.244.8** (Node.js v20 LTS "Iron").

## Test Results

### Windows (MSVC 19.50)

| Suite | Result | Notes |
|-------|--------|-------|
| v8_unittests (C++) | **5334/5337 (99.9%)** | 3 failures: weak collections, DiyFp |
| mjsunit (JavaScript) | **5904/5980 (98.7%)** | 76 failures, 106 skipped (debug-only flags) |
| hello_v8.exe (smoke) | **PASS** | Arithmetic, JSON, closures, Map, WebAssembly, Intl |
| d8.exe (smoke) | **PASS** | `d8 -e "print(1+2)"` outputs `3` |

### Linux (GCC 13.3.0)

| Suite | Result | Notes |
|-------|--------|-------|
| v8_unittests (C++) | **5356/5358 (100.0%)** | 2 failures: WeakMaps/Sets shrinking only |
| mjsunit (JavaScript) | **5898/5980 (98.6%)** | 82 failures, 106 skipped (debug-only flags) |
| hello_v8 (smoke) | **PASS** | Arithmetic, JSON, closures, Map, WebAssembly, Intl |

## Prerequisites

- Visual Studio with C++ workload (MSVC 19.x -- tested with VS 2025 / MSVC 19.50)
- CMake 3.20+
- Ninja
- Python 3
- Git

## Quick Start

```bash
git clone https://github.com/polycpp/v8.git v8-msvc
cd v8-msvc && git checkout v8-11.3.244.8
python fetch_deps.py
cd v8-src && git apply ../patches/001-msvc-compatibility.patch && cd ..
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_TOOLCHAIN_FILE=cmake/msvc-toolchain.cmake
cmake --build build -j 8
```

## Version-Specific Notes

V8 11.3 is significantly different from newer versions:

- **C++17** (not C++20)
- **No abseil** third-party dependency
- **No fp16, highway, simdutf, fast_float, dragonbox**
- **ICU 72** with C++20 operator== ambiguity fix
- **Maglev** present but early/experimental
- **Turboshaft** present but very limited (fewer phases than 12.4+)
- **Wasm interpreter** still present (removed in later versions)
- **Mid-tier register allocator** exists (removed in later versions)
- **Chromium trace event dependency** -- stub provided

## License

The build system files in this repo are provided as-is. V8 itself is licensed
under the V8 project's BSD-style license.
