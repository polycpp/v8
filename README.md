# V8 MSVC Build

CMake build system for the [V8 JavaScript engine](https://v8.dev/) on Windows
with MSVC — no depot_tools or GN required.

Each V8 version lives on its own branch with pinned sources, MSVC patches, and
tested CMake build files. Pick a branch below and follow the instructions there.

## Available Versions

| Branch | V8 Version | Node.js | Status |
|--------|-----------|---------|--------|
| [`v8-14.3.127.18`](../../tree/v8-14.3.127.18) | 14.3.127.18 | LTS | **v8_unittests 99.88%**, **mjsunit 97.5%** |

## What You Get

- Full V8 static library build (all tiers: Sparkplug, Maglev, TurboFan)
- WebAssembly, ICU/Intl support (data embedded — no runtime files needed)
- `d8` developer shell
- CMake targets that work with `add_subdirectory()` or `find_package()`

## Quick Example

Add V8 to your CMake project in a few lines:

```cmake
cmake_minimum_required(VERSION 3.20)
project(myapp LANGUAGES CXX C ASM_MASM)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(MSVC)
  # V8 defaults to static CRT (/MT) — your project must match
  set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
endif()

# Option A: build V8 from source alongside your project
add_subdirectory("path/to/v8" "${CMAKE_BINARY_DIR}/v8-build")

add_executable(myapp main.cpp)
target_link_libraries(myapp PRIVATE v8)
```

```bash
# From a VS Developer Command Prompt (or use cmake/msvc-toolchain.cmake)
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

The `v8` target automatically provides include paths, compile definitions
(`V8_COMPRESS_POINTERS`, etc.), and MSVC flags — no manual setup needed.

Alternatively, install V8 once and use `find_package`:

```bash
# Install V8 SDK
cmake --install <v8-build-dir> --prefix C:/v8-sdk
```

```cmake
find_package(v8 REQUIRED)
target_link_libraries(myapp PRIVATE v8::v8)
```

### Minimal Embedding Code

```cpp
#include "v8.h"
#include "libplatform/libplatform.h"
#include <cstdio>

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
    printf("Result: %s\n", *utf8);  // "Result: 3"
  }

  isolate->Dispose();
  v8::V8::Dispose();
  v8::V8::DisposePlatform();
  delete params.array_buffer_allocator;
  return 0;
}
```

## Prerequisites

- Visual Studio with C++ workload (tested with VS 2025 / MSVC 19.50)
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

# Apply MSVC patches
cd v8-src && git apply ../patches/001-msvc-compatibility.patch && cd ..

# Build (from VS Developer Command Prompt)
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

See the version branch README for full build options, test results, and details.

## License

The build system files in this repo are provided as-is. V8 itself is licensed
under the V8 project's BSD-style license.
