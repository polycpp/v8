# V8 CMake Build

CMake build system for the [V8 JavaScript engine](https://v8.dev/) — no
depot_tools or GN required. Supports **Windows (MSVC)** and **Linux (GCC/Clang)**.

Each V8 version lives on its own branch with pinned sources, patches, and
tested CMake build files. Pick a branch below and follow the instructions there.

## Available Versions

| Branch | V8 Version | Platform | Status |
|--------|-----------|----------|--------|
| [`v8-14.3.127.18`](../../tree/v8-14.3.127.18) | 14.3.127.18 | Windows, Linux | **v8_unittests 99.88%**, **mjsunit 97.5%** |
| [`v8-14.1.146.11`](../../tree/v8-14.1.146.11) | 14.1.146.11 | Windows, Linux | **v8_unittests 99.9%**, **mjsunit 97.6%** |
| [`v8-13.6.233.17`](../../tree/v8-13.6.233.17) | 13.6.233.17 | Windows, Linux | **v8_unittests 99.8%**, **mjsunit 99.2%** |
| [`v8-12.4.254.21`](../../tree/v8-12.4.254.21) | 12.4.254.21 | Windows, Linux | **v8_unittests 99.9%**, **mjsunit 98.6%** |
| [`v8-11.3.244.8`](../../tree/v8-11.3.244.8) | 11.3.244.8 | Windows, Linux | **v8_unittests 99.9%**, **mjsunit 98.7%** |
| [`v8-10.2.154.26`](../../tree/v8-10.2.154.26) | 10.2.154.26 | Windows | **v8_unittests 100.0%**, **mjsunit 98.2%** |
| [`v8-9.4.146.26`](../../tree/v8-9.4.146.26) | 9.4.146.26 | Windows | **v8_unittests 100.0%**, **mjsunit 94.5%** |

## What You Get

- Full V8 static library build (all tiers: Sparkplug, Maglev, TurboFan)
- WebAssembly, ICU/Intl support (data embedded — no runtime files needed)
- `d8` developer shell
- CMake targets that work with `add_subdirectory()` or `find_package()`

## Quick Example

### Windows (MSVC)

```cmake
cmake_minimum_required(VERSION 3.20)
project(myapp LANGUAGES CXX C ASM_MASM)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# V8 defaults to static CRT (/MT) — your project must match
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

add_subdirectory("path/to/v8" "${CMAKE_BINARY_DIR}/v8-build")

add_executable(myapp main.cpp)
target_link_libraries(myapp PRIVATE v8)
```

```bash
# From a VS Developer Command Prompt (or use cmake/msvc-toolchain.cmake)
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

### Linux (GCC/Clang)

```cmake
cmake_minimum_required(VERSION 3.20)
project(myapp LANGUAGES CXX C ASM)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_subdirectory("path/to/v8" "${CMAKE_BINARY_DIR}/v8-build")

add_executable(myapp main.cpp)
target_link_libraries(myapp PRIVATE v8)
```

```bash
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

### Cross-Platform

The V8 CMake build auto-detects the platform — just set the appropriate
project languages (`ASM_MASM` on Windows, `ASM` on Linux) and V8 handles
the rest. The `v8` target automatically provides include paths, compile
definitions (`V8_COMPRESS_POINTERS`, etc.), and platform-appropriate flags.

Alternatively, install V8 once and use `find_package`:

```bash
# Install V8 SDK
cmake --install <v8-build-dir> --prefix /opt/v8-sdk
```

```cmake
find_package(v8 REQUIRED)
target_link_libraries(myapp PRIVATE v8::v8)
```

### Minimal Embedding Code

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
    v8::Local<v8::Context> ctx = v8::Context::New(isolate);
    v8::Context::Scope context_scope(ctx);

    v8::Local<v8::String> src = v8::String::NewFromUtf8Literal(isolate, "1 + 2");
    v8::Local<v8::Script> script = v8::Script::Compile(ctx, src).ToLocalChecked();
    v8::Local<v8::Value> result = script->Run(ctx).ToLocalChecked();
    v8::String::Utf8Value utf8(isolate, result);
    std::cout << "Result: " << *utf8 << std::endl;  // "Result: 3"
  }

  isolate->Dispose();
  v8::V8::Dispose();
  v8::V8::DisposePlatform();
  delete params.array_buffer_allocator;
  return 0;
}
```

## Prerequisites

### Windows
- Visual Studio with C++ workload (tested with VS 2025 / MSVC 19.50)
- CMake 3.20+
- Ninja
- Python 3

### Linux
- GCC 13+ or Clang 16+
- CMake 3.20+
- Ninja
- Python 3

## Getting Started

```bash
# Clone and checkout a version branch
git clone https://github.com/polycpp/v8.git
cd v8
git checkout v8-14.3.127.18

# Fetch V8 source and dependencies
python fetch_deps.py

# Apply patches (see version branch README for which patches to apply)
cd v8-src && git apply ../patches/001-msvc-compatibility.patch && cd ..

# Build
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

On Linux, a `build.sh` script is also provided:

```bash
./build.sh          # Release build
./build.sh debug    # Debug build
```

See the version branch README for full build options, test results, and details.

## License

The build system files in this repo are provided as-is. V8 itself is licensed
under the V8 project's BSD-style license.
