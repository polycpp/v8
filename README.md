# V8 MSVC Build

CMake build system for building the V8 JavaScript engine with MSVC on Windows,
without requiring Google's depot_tools or GN toolchain.

Targets **V8 14.3.127.18** (matching Node.js LTS).

## Test Results

| Suite | Result | Notes |
|-------|--------|-------|
| v8_unittests (C++) | **5728/5735 (99.88%)** | 7 failures are platform-specific, not engine bugs |
| mjsunit (JavaScript) | **967/992 (97.5%)** | 25 failures are Release-only flags, TZ diffs, and test runner limits |
| hello_v8.exe (smoke) | **PASS** | Arithmetic, JSON, closures, Map, WebAssembly |

See [docs/test-results.md](docs/test-results.md) for details,
[docs/unittest-analysis.md](docs/unittest-analysis.md) and
[docs/mjsunit-analysis.md](docs/mjsunit-analysis.md) for failure analysis.

## Prerequisites

- Visual Studio 2022+ with C++ workload (MSVC 19.x)
- CMake 3.20+
- Ninja
- Python 3
- Git

## Quick Start

```bash
# 1. Clone this repo
git clone <this-repo> v8-msvc
cd v8-msvc

# 2. Fetch V8 source and dependencies
python fetch_deps.py

# 3. Apply MSVC patches
cd v8-src && git apply ../patches/001-msvc-compatibility.patch && cd ..

# 4. Configure (from VS Developer Command Prompt)
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release

# Or from plain shell using the toolchain file:
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_TOOLCHAIN_FILE=cmake/msvc-toolchain.cmake

# 5. Build
cmake --build build
```

## Project Structure

```
CMakeLists.txt                  # Root CMake project
cmake/
  sources.cmake                 # V8 source file lists (Windows x64)
  torque.cmake                  # Torque compiler + code generation
  targets.cmake                 # Library targets + d8 shell
  snapshot.cmake                # Snapshot generation (mksnapshot)
  icu.cmake                     # ICU build (embeds icudtl.dat into binary)
  unittests.cmake               # Unit test binary
  abseil.cmake                  # Abseil C++ integration
  msvc-toolchain.cmake          # Auto-detect MSVC and Windows SDK
  generate_icu_data.py          # Converts icudtl.dat to COFF .obj
fetch_deps.py                   # Fetches V8 source + third-party deps
patches/
  001-msvc-compatibility.patch  # MSVC source compatibility fixes (~830 lines)
test/
  run_mjsunit.py                # mjsunit JavaScript test runner
```

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

## Build Targets

The build produces several static libraries plus executables:

**Libraries:**
- **v8_base** - Interface target (v8_base_without_compiler + v8_compiler)
- **v8_base_without_compiler** - Core V8 runtime
- **v8_compiler** - TurboFan/Turboshaft optimizing compiler
- **v8_initializers** - Builtin initialization (Torque-generated)
- **v8_snapshot** - Serialized startup snapshot
- **v8_libbase** - Platform abstraction layer
- **v8_libplatform** - Default platform implementation
- **v8_bigint** - BigInt implementation
- **v8_heap_base** - GC heap base
- **v8_cppgc** - C++ garbage collector
- **icuuc / icui18n / icudata** - ICU (data embedded from icudtl.dat)

**Executables:**
- **d8** - V8 developer shell (JS REPL, test runner)
- **v8_unittests** - C++ unit test binary (5735 tests)
- **hello_v8** - Minimal V8 embedding smoke test

**Build tools** (built during the build):
- **torque** - V8's Torque DSL compiler
- **mksnapshot** - Snapshot generator
- **bytecode_builtins_list_generator** - Bytecode list generator

## Dependencies

Fetched automatically by `fetch_deps.py`:

| Dependency | Source | Purpose |
|-----------|--------|---------|
| abseil-cpp | chromium | Hash maps, strings, synchronization |
| ICU | chromium | Unicode / i18n |
| zlib | chromium | Compression |
| simdutf | chromium | SIMD UTF conversion |
| highway | google | SIMD abstraction |
| dragonbox | jk-jeon | Float-to-string conversion |
| fast_float | fastfloat | String-to-float conversion |
| fp16 | Maratyszcza | Half-precision float |
| googletest | google | Testing framework (headers) |

## MSVC Patches

The `patches/` directory contains fixes for V8 code that doesn't compile with MSVC:

**001-msvc-compatibility.patch**:
- Replace GCC `__attribute__((packed))` with `#pragma pack` for MSVC
- Replace `__attribute__((visibility("default")))` with empty on Windows static builds
- Replace `__attribute__((tls_model(...)))` with plain `thread_local` for MSVC
- Fix qualified base class method calls that MSVC rejects

## Linking Against V8

After building, link against the `v8` interface target or the individual libraries:

```cmake
find_package(v8 CONFIG REQUIRED)
target_link_libraries(my_app PRIVATE v8::v8)
```

Or manually link the static libraries in this order:
```
v8_snapshot v8_initializers v8_compiler v8_base_without_compiler
v8_cppgc v8_heap_base v8_bigint v8_libplatform v8_libbase
icui18n icuuc icudata
dbghelp.lib winmm.lib ws2_32.lib advapi32.lib
```

Note: ICU data is embedded directly into the binary (no runtime `icudtl.dat` needed).

## Architecture

This project targets **x64** only. The source lists and architecture-specific files are configured for x64. Supporting other architectures (arm64, ia32) would require adding the corresponding source files in `cmake/sources.cmake`.

## Running Tests

```bash
# C++ unit tests
./build/v8_unittests.exe --gtest_filter="BitsTest*"    # Run specific suite
./build/v8_unittests.exe                                 # Run all (per-process)

# JavaScript tests (run from v8-src/ directory)
cd v8-src
../build/d8.exe --test test/mjsunit/mjsunit.js test/mjsunit/array-length.js

# Run all top-level mjsunit tests
for f in test/mjsunit/*.js; do
  FLAGS=$(grep "// Flags:" "$f" | sed 's|.*// Flags:||' | tr '\n' ' ')
  FILES=$(grep "// Files:" "$f" | sed 's|.*// Files:||' | tr '\n' ' ')
  timeout 30 ../build/d8.exe --test $FLAGS test/mjsunit/mjsunit.js $FILES "$f"
done
```

## MSVC Patches

The `patches/001-msvc-compatibility.patch` (~830 lines) fixes ~20 categories of
MSVC incompatibilities:
- GCC `__attribute__((packed))` → `#pragma pack`
- GCC `__attribute__((visibility))` → removed for static builds
- GCC `__attribute__((tls_model))` → plain `thread_local`
- Qualified base class method calls MSVC rejects
- `constexpr` + `inline` patterns MSVC handles differently
- Template metaprogramming patterns (regexp bytecodes, Turboshaft reducers)
- MSVC `initializer_list` materialization differences (test fixes)
- `__FUNCSIG__` format differences vs GCC `__PRETTY_FUNCTION__`

## Status

**Full V8 build + d8 shell + tests pass with MSVC 19.50 (VS 18).**

- ~2500 source files compiled, 0 code errors
- d8.exe: fully functional JavaScript shell
- v8_unittests.exe: 5728/5735 C++ tests pass
- mjsunit: 967/992 JavaScript tests pass
- Build time: ~4-6 hours at -j3 (full), ~5 min incremental for d8

## License

The build system files in this repo are provided as-is. V8 itself is licensed under the V8 project's BSD-style license. See `v8-src/LICENSE` after fetching.
