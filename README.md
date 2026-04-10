# V8 MSVC Build

CMake build system for building the V8 JavaScript engine with MSVC on Windows,
without requiring Google's depot_tools or GN toolchain.

Targets **V8 10.2.154.26** (Node.js v18 "Hydrogen").

## Test Results

| Suite | Result | Notes |
|-------|--------|-------|
| v8_unittests (C++) | **3901/3902 (100.0%)** | 1 failure: VirtualAddressSpaceTest |
| mjsunit (JavaScript) | **5455/5557 (98.2%)** | 102 failures, 97 skipped (debug-only flags) |
| hello_v8.exe (smoke) | **PASS** | Arithmetic, JSON, closures, Map, WebAssembly, Intl |
| d8.exe (smoke) | **PASS** | `d8 -e "print(1+2)"` outputs `3` |

## Quick Start

```bash
git clone https://github.com/polycpp/v8.git v8-msvc
cd v8-msvc && git checkout v8-10.2.154.26
python fetch_deps.py
cd v8-src && git apply ../patches/001-msvc-compatibility.patch && cd ..
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_TOOLCHAIN_FILE=cmake/msvc-toolchain.cmake
cmake --build build -j 8
```

## Version-Specific Notes

- **C++17**, no Turboshaft, no abseil/fp16/highway/simdutf
- **ICU 70**, `__builtin_ctz` replaced for MSVC in caged-heap
- **Web snapshot** experimental feature (later removed)
- **MASM .asm** created from .S file for push_registers
- **Chromium trace event** stub required

## License

The build system files in this repo are provided as-is. V8 itself is licensed
under the V8 project's BSD-style license.
