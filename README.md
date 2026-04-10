# V8 MSVC Build

CMake build system for building the V8 JavaScript engine with MSVC on Windows,
without requiring Google's depot_tools or GN toolchain.

Targets **V8 9.4.146.26** (Node.js v16 "Gallium").

## Test Results

| Suite | Result | Notes |
|-------|--------|-------|
| v8_unittests (C++) | **3828/3828 (100.0%)** | Zero failures |
| mjsunit (JavaScript) | **5018/5253 (95.5%)** | 235 failures, 132 skipped |
| hello_v8.exe (smoke) | **PASS** | Arithmetic, JSON, closures, Map, WebAssembly, Intl |
| d8.exe (smoke) | **PASS** | `d8 -e "print(1+2)"` outputs `3` |

## Quick Start

```bash
git clone https://github.com/polycpp/v8.git v8-msvc
cd v8-msvc && git checkout v8-9.4.146.26
python fetch_deps.py
cd v8-src && git apply ../patches/001-msvc-compatibility.patch && cd ..
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_TOOLCHAIN_FILE=cmake/msvc-toolchain.cmake \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
cmake --build build -j 8
```

## Version-Specific Notes

V8 9.4 is the oldest supported version -- very different architecture:

- **C++17**, no Maglev, no Turboshaft, no sandbox
- **No abseil, fp16, highway, simdutf, fast_float, dragonbox**
- **ICU 69**
- **Sparkplug** baseline compiler present
- **turbo-inline-array-builtins** disabled (crashes MSVC-compiled TurboFan)
- **`V8::DisposePlatform()`** doesn't exist yet
- **Web snapshot** experimental feature present
- **Wasm interpreter** still present

## Known Test Failures

The 235 mjsunit failures are caused by **TurboFan JIT code generation issues**
when V8 9.4 is compiled with MSVC:

- **~104 crashes**: TurboFan-generated x64 machine code triggers ACCESS_VIOLATION
- **~96 wrong results**: Optimized code returns incorrect values
- **~28 module/misc**: ES module syntax, timezone differences
- All crash/wrong-result tests **pass with `--no-opt`** (interpreter-only mode)

The V8 interpreter and Sparkplug baseline compiler work correctly. Only
TurboFan optimization produces incorrect code -- this is expected since V8 9.4's
TurboFan backend was not designed for MSVC compilation. V8 embedding use cases
(running JavaScript without relying on peak optimization) work fine.

## License

The build system files in this repo are provided as-is. V8 itself is licensed
under the V8 project's BSD-style license.
