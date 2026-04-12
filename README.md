# V8 CMake Build

CMake build system for building the V8 JavaScript engine on Windows (MSVC),
Linux (GCC/Clang), and FreeBSD (Clang), without requiring Google's depot_tools
or GN toolchain.

Targets **V8 14.3.127.18**.

## Test Results

### Windows (MSVC 19.50)

| Suite | Result | Notes |
|-------|--------|-------|
| v8_unittests (C++) | **5963/5968 (99.9%)** | 5 failures: 2 logging crashes, 2 WeakMaps/WeakSets shrink checks, 1 double edge-case |
| mjsunit (JavaScript) | **7763/8150 (95.3%)** | 387 failures from flag conflicts, platform/TZ differences, unsupported experimental paths, and memory/timeouts |
| hello_v8.exe (smoke) | **PASS** | Arithmetic, JSON, closures, Map, WebAssembly |

Windows results above were collected on April 9, 2026 (MSVC 19.50, Release).

### Linux (GCC 13.3.0)

| Suite | Result | Notes |
|-------|--------|-------|
| v8_unittests (C++) | **5964/5970 (99.9%)** | 5 crashes (WeakMaps, LogAll, BytecodeGolden), 1 param test skip |
| mjsunit (JavaScript) | **6757/8150 (82.9%)** | Most failures from flag conflicts and missing test helpers |
| hello_v8 (smoke) | **PASS** | Arithmetic, JSON, closures, Map, WebAssembly, Intl |

### FreeBSD (Clang 19.1.7)

| Suite | Result | Notes |
|-------|--------|-------|
| v8_unittests (C++) | **5960/5965 (99.9%)** | 5 failures: 2 logging crashes, 2 WeakMaps/WeakSets shrink checks, 1 VirtualAddressSpace reservation |
| mjsunit (JavaScript) | **7783/8150 (95.5%)** | ~99% excluding sandbox/flag-conflict tests; 9 timezone tests are the only FreeBSD-specific candidates |
| hello_v8 (smoke) | **PASS** | Arithmetic, JSON, closures, Map, WebAssembly, Intl |

FreeBSD results above were collected on April 12, 2026 (FreeBSD 15.0-RELEASE, clang 19.1.7, Release).

See [docs/test-results.md](docs/test-results.md) for full results,
[docs/unittest-analysis.md](docs/unittest-analysis.md) and
[docs/mjsunit-analysis.md](docs/mjsunit-analysis.md) for failure analysis.

## Supported Platforms

- **Windows** — MSVC 2019+ (tested with VS 2025 / MSVC 19.50)
- **Linux** — GCC 13+, Clang 16+ (tested with GCC 13.3.0)
- **FreeBSD** — Clang 16+ (tested with FreeBSD 15.0, clang 19.1.7)

## Prerequisites

**Windows:**
- Visual Studio with C++ workload (MSVC 19.x)

**Linux / FreeBSD:**
- GCC 13+ or Clang 16+ (FreeBSD base clang is sufficient)

**All platforms:**
- CMake 3.20+
- Ninja
- Python 3
- Git

## Quick Start

### Windows (MSVC)

```bash
git clone git@github.com:polycpp/v8.git && cd v8
python fetch_deps.py
cd v8-src && git apply ../patches/001-msvc-compatibility.patch && cd ..
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

### Linux (GCC / Clang)

```bash
git clone git@github.com:polycpp/v8.git && cd v8
python3 fetch_deps.py
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++
cmake --build build
```

### FreeBSD (Clang)

```bash
git clone git@github.com:polycpp/v8.git && cd v8
python3 fetch_deps.py
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++
cmake --build build
```

No patches are needed on Linux or FreeBSD — only the Windows MSVC patch applies.

### Run tests

```bash
# C++ unit tests (each test in a separate process)
python3 test/run_unittests.py build/v8_unittests --summary

# JavaScript tests (full mjsunit tree)
python3 test/run_mjsunit.py build/d8 --timeout 30

# Smoke test
./build/hello_v8
```

## Project Structure

```
CMakeLists.txt                  # Root CMake project
cmake/
  sources.cmake                 # V8 source file lists (x64, platform-aware)
  targets.cmake                 # Library targets + d8 shell
  torque.cmake                  # Torque compiler + code generation
  snapshot.cmake                # Snapshot generation (mksnapshot)
  icu.cmake                     # ICU build (embeds icudtl.dat into binary)
  unittests.cmake               # Unit test binary
  abseil.cmake                  # Abseil C++ integration
  msvc-toolchain.cmake          # Auto-detect MSVC and Windows SDK
  generate_icu_data.py          # Converts icudtl.dat to COFF .obj
patches/
  001-msvc-compatibility.patch  # MSVC source compatibility fixes (~830 lines)
test/
  run_mjsunit.py                # mjsunit JavaScript test runner
  run_unittests.py              # one-test-per-process unittest runner
docs/
  test-results.md               # Test results summary
  unittest-analysis.md          # C++ test failure root causes
  mjsunit-analysis.md           # JS test failure root causes
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
- **v8_unittests** — C++ unit test binary (5968 tests)
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

Build V8 alongside your project. Simple, no install step required.

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

```bash
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DV8_SOURCE_DIR=path/to/v8
cmake --build build
```

### Option 2: `find_package` (pre-built SDK)

Install V8 once, then use it from any project without rebuilding.

```bash
# First, build and install V8
cd path/to/v8
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
cmake --install build --prefix C:/v8-sdk
```

```cmake
cmake_minimum_required(VERSION 3.20)
project(myapp LANGUAGES CXX C ASM_MASM)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(MSVC)
  set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
endif()

find_package(v8 REQUIRED)

add_executable(myapp main.cpp)
target_link_libraries(myapp PRIVATE v8::v8)
```

```bash
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=C:/v8-sdk
cmake --build build
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
# C++ unit tests
python3 test/run_unittests.py build/v8_unittests --summary
python3 test/run_unittests.py build/v8_unittests --filter "BitsTest"

# JavaScript tests (full mjsunit tree)
python3 test/run_mjsunit.py build/d8 --jobs 4 --timeout 30
python3 test/run_mjsunit.py build/d8 --filter "wasm/" --jobs 4

# Smoke test
./build/hello_v8
```

On Windows, use `.exe` suffixes (`build/v8_unittests.exe`, `build/d8.exe`, etc.).

## MSVC Patches

The `patches/001-msvc-compatibility.patch` (~830 lines) fixes ~20 categories
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

Fetched automatically by `fetch_deps.py` and pinned to the exact commits from
the upstream V8 `14.3.127.18` DEPS file:

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
