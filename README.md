# V8 MSVC Build

CMake build system for building the V8 JavaScript engine with MSVC on Windows,
without requiring Google's depot_tools or GN toolchain.

Targets **V8 14.1.146.11** (Node.js v25).

## Test Results

### Windows (MSVC 19.50)

| Suite | Result | Notes |
|-------|--------|-------|
| v8_unittests (C++) | **6013/6018 (99.9%)** | 5 failures are platform-specific, not engine bugs |
| mjsunit (JavaScript) | **965/989 (97.6%)** | 24 failures are Release-only flags, TZ diffs, etc. |
| hello_v8.exe (smoke) | **PASS** | Arithmetic, JSON, closures, Map, WebAssembly |

### Linux (GCC 13.3.0)

| Suite | Result | Notes |
|-------|--------|-------|
| v8_unittests (C++) | **6021/6025 (99.9%)** | 4 failures: LogAll, ConsoleTimeEvents, WeakMaps/Sets shrinking |
| mjsunit (JavaScript) | **6585/7946 (82.9%)** | Most failures from flag conflicts and missing test helpers |
| hello_v8 (smoke) | **PASS** | Arithmetic, JSON, closures, Map, WebAssembly, Intl |

## Prerequisites

- Visual Studio with C++ workload (MSVC 19.x — tested with VS 2025 / MSVC 19.50)
- CMake 3.20+
- Ninja
- Python 3
- Git

## Quick Start

```bash
# 1. Clone this repo
git clone git@github.com:polycpp/v8.git v8-msvc
cd v8-msvc
git checkout v8-14.1.146.11

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
cmake --build build

# 6. Run tests
./build/v8_unittests.exe --gtest_filter="BitsTest*"
cd v8-src && ../build/d8.exe --test test/mjsunit/mjsunit.js test/mjsunit/array-length.js
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
  zlib.cmake                    # Zlib integration
  install.cmake                 # CMake install / find_package support
  msvc-toolchain.cmake          # Auto-detect MSVC and Windows SDK
  generate_icu_data.py          # Converts icudtl.dat to COFF .obj
patches/
  001-msvc-compatibility.patch  # MSVC source compatibility fixes (~880 lines)
test/
  run_mjsunit.py                # mjsunit JavaScript test runner
  run_unittests.py              # C++ unit test runner (one test per process)
fetch_deps.py                   # Fetches V8 source + third-party deps
```

## Build Targets

**Libraries:**
- **v8_base** — Interface target (v8_base_without_compiler + v8_compiler)
- **v8_base_without_compiler** — Core V8 runtime
- **v8_compiler** — TurboFan/Turboshaft optimizing compiler
- **v8_initializers** — Builtin initialization (Torque-generated)
- **v8_snapshot** — Serialized startup snapshot
- **v8_libbase** — Platform abstraction layer
- **v8_libplatform** — Default platform implementation
- **v8_bigint** — BigInt implementation
- **v8_heap_base** — GC heap base
- **v8_cppgc** — C++ garbage collector
- **icuuc / icui18n / icudata** — ICU with embedded data from icudtl.dat

**Executables:**
- **d8** — V8 developer shell (JS REPL, test runner)
- **v8_unittests** — C++ unit test binary (6018 tests)
- **hello_v8** — Minimal V8 embedding smoke test

**Build tools** (built automatically during the build):
- **torque** — Torque DSL compiler
- **mksnapshot** — Snapshot generator
- **bytecode_builtins_list_generator** — Bytecode list generator

## CMake Options

| Option | Default | Description |
|--------|---------|-------------|
| `V8_ENABLE_I18N` | ON | Internationalization support (ICU) |
| `V8_ENABLE_WEBASSEMBLY` | ON | WebAssembly support |
| `V8_ENABLE_MAGLEV` | ON | Maglev mid-tier compiler |
| `V8_ENABLE_SPARKPLUG` | ON | Sparkplug baseline compiler |
| `V8_ENABLE_TURBOFAN` | ON | TurboFan optimizing compiler |
| `V8_ENABLE_POINTER_COMPRESSION` | ON | Pointer compression (reduces memory) |
| `V8_ENABLE_SANDBOX` | OFF | V8 sandbox |
| `V8_ENABLE_ETW` | ON | ETW stack walking (Windows) |
| `V8_ENABLE_SNAPSHOT` | ON | Build with startup snapshot |
| `V8_SHARED_LIBRARY` | OFF | Build as DLL (default: static /MT) |

## Using V8 in Your Project

There are two ways to consume V8 from an external CMake project. In both cases,
the `v8` target automatically propagates include paths, compile definitions
(`V8_COMPRESS_POINTERS`, etc.), and MSVC flags (`/Zc:__cplusplus`) — no manual
setup needed beyond linking.

> **Note:** V8 defaults to static CRT (`/MT`). Your project must match by setting
> `CMAKE_MSVC_RUNTIME_LIBRARY` to `"MultiThreaded$<$<CONFIG:Debug>:Debug>"`.

### Option 1: `add_subdirectory` (build from source)

```cmake
cmake_minimum_required(VERSION 3.20)
project(myapp LANGUAGES CXX C ASM_MASM)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(MSVC)
  set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
endif()

set(V8_SOURCE_DIR "path/to/v8" CACHE PATH "V8 MSVC CMake repo root")
add_subdirectory("${V8_SOURCE_DIR}" "${CMAKE_BINARY_DIR}/v8-build")

add_executable(myapp main.cpp)
target_link_libraries(myapp PRIVATE v8)

if(MSVC)
  target_link_options(myapp PRIVATE /FORCE:MULTIPLE)
endif()
```

### Option 2: `find_package` (pre-built SDK)

```bash
# Build and install V8
cmake --install build --prefix C:/v8-sdk
```

```cmake
find_package(v8 REQUIRED)
target_link_libraries(myapp PRIVATE v8::v8)
```

### Minimal C++ Example

```cpp
#include "v8.h"
#include "libplatform/libplatform.h"
#include <iostream>
#include <memory>

int main(int argc, char* argv[]) {
  v8::V8::InitializeICUDefaultLocation(argv[0]);
  v8::V8::InitializeExternalStartupData(argv[0]);
  std::unique_ptr<v8::Platform> platform = v8::platform::NewDefaultPlatform();
  v8::V8::InitializePlatform(platform.get());
  v8::V8::Initialize();

  v8::Isolate::CreateParams params;
  params.array_buffer_allocator = v8::ArrayBuffer::Allocator::NewDefaultAllocator();
  v8::Isolate* isolate = v8::Isolate::New(params);
  {
    v8::Isolate::Scope isolate_scope(isolate);
    v8::HandleScope handle_scope(isolate);
    v8::Local<v8::Context> context = v8::Context::New(isolate);
    v8::Context::Scope context_scope(context);

    v8::Local<v8::String> source =
        v8::String::NewFromUtf8Literal(isolate, "1 + 2");
    v8::Local<v8::Script> script =
        v8::Script::Compile(context, source).ToLocalChecked();
    v8::Local<v8::Value> result = script->Run(context).ToLocalChecked();
    v8::String::Utf8Value utf8(isolate, result);
    std::cout << "Result: " << *utf8 << std::endl;
  }

  isolate->Dispose();
  v8::V8::Dispose();
  v8::V8::DisposePlatform();
  delete params.array_buffer_allocator;
  return 0;
}
```

ICU data is embedded directly into the binary — no runtime `icudtl.dat` file needed.

## Running Tests

```bash
# C++ unit tests (one-at-a-time runner for V8's init/dispose limitation)
python test/run_unittests.py build/v8_unittests.exe --summary

# Run specific suite
python test/run_unittests.py build/v8_unittests.exe --suite "Bits"

# JavaScript tests (must run from v8-src/ directory)
cd v8-src
python ../test/run_mjsunit.py ../build/d8.exe

# Smoke test
./build/hello_v8.exe
```

## MSVC Patches

The `patches/001-msvc-compatibility.patch` (~880 lines) fixes ~20 categories
of MSVC incompatibilities:

- GCC `__attribute__((packed))` → `#pragma pack`
- GCC `__attribute__((visibility))` → removed for static builds
- GCC `__attribute__((tls_model))` → plain `thread_local`
- Qualified base class method calls MSVC rejects
- `constexpr` + `inline` patterns MSVC handles differently
- Template metaprogramming patterns (regexp bytecodes, Turboshaft reducers)
- MSVC `initializer_list` materialization differences (test fixes)
- `__FUNCSIG__` format differences vs GCC `__PRETTY_FUNCTION__`

## Dependencies

Fetched automatically by `fetch_deps.py`:

| Dependency | Purpose |
|-----------|---------|
| abseil-cpp | Hash maps, strings, synchronization |
| ICU | Unicode / internationalization |
| zlib | Compression |
| simdutf | SIMD UTF conversion |
| highway | SIMD abstraction |
| dragonbox | Float-to-string conversion |
| fast_float | String-to-float conversion |
| fp16 | Half-precision float |
| googletest | Testing framework |

## Architecture

This project targets **x64 only**. Source lists and architecture-specific files
are configured for x64. Supporting arm64 or ia32 would require adding the
corresponding source files in `cmake/sources.cmake`.

## License

The build system files in this repo are provided as-is. V8 itself is licensed
under the V8 project's BSD-style license. See `v8-src/LICENSE` after fetching.
