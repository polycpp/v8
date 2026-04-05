cmake_minimum_required(VERSION 3.20)

# =============================================================================
# V8 CMake Build (Windows MSVC / Linux GCC/Clang)
# Targets V8 14.3.127.18 (matching Node.js LTS)
# =============================================================================
if(WIN32)
  project(v8 VERSION 14.3.127 LANGUAGES CXX C ASM_MASM)
else()
  project(v8 VERSION 14.3.127 LANGUAGES CXX C ASM)
endif()

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# V8 source directory
set(V8_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/v8-src" CACHE PATH "Path to V8 source")

if(NOT EXISTS "${V8_ROOT}/src")
  message(FATAL_ERROR "V8 source not found at ${V8_ROOT}. Clone V8 first.")
endif()

# =============================================================================
# Build options
# =============================================================================
option(V8_ENABLE_I18N "Enable internationalization support (ICU)" ON)
option(V8_ENABLE_WEBASSEMBLY "Enable WebAssembly support" ON)
option(V8_ENABLE_MAGLEV "Enable Maglev compiler" ON)
option(V8_ENABLE_SPARKPLUG "Enable Sparkplug baseline compiler" ON)
option(V8_ENABLE_TURBOFAN "Enable TurboFan optimizing compiler" ON)
option(V8_ENABLE_POINTER_COMPRESSION "Enable pointer compression" ON)
option(V8_ENABLE_SANDBOX "Enable V8 sandbox" OFF)
option(V8_ENABLE_SNAPSHOT "Build with snapshot" ON)
option(V8_SHARED_LIBRARY "Build V8 as shared library" OFF)
if(WIN32)
  option(V8_ENABLE_ETW "Enable ETW stack walking (Windows)" ON)
endif()

# Generated files directory
set(V8_GENERATED_DIR "${CMAKE_BINARY_DIR}/gen" CACHE PATH "Generated files directory")
file(MAKE_DIRECTORY "${V8_GENERATED_DIR}")
file(MAKE_DIRECTORY "${V8_GENERATED_DIR}/torque-generated")
file(MAKE_DIRECTORY "${V8_GENERATED_DIR}/include")

# =============================================================================
# Platform detection
# =============================================================================
if(CMAKE_SIZEOF_VOID_P EQUAL 8)
  set(V8_TARGET_ARCH "x64")
else()
  set(V8_TARGET_ARCH "ia32")
endif()

message(STATUS "V8 target architecture: ${V8_TARGET_ARCH}")
message(STATUS "V8 version: 14.3.127.18")
message(STATUS "Compiler: ${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION}")

# =============================================================================
# Global compile definitions
# =============================================================================
add_compile_definitions(
  # V8 core (platform-independent)
  V8_TARGET_ARCH_X64
  V8_HOST_ARCH_X64
  V8_COMPRESS_POINTERS
  V8_31BIT_SMIS_ON_64BIT_ARCH
  V8_DEPRECATION_WARNINGS
  V8_IMMINENT_DEPRECATION_WARNINGS
  V8_ENABLE_TURBOFAN
  V8_ENABLE_SPARKPLUG
  V8_TYPED_ARRAY_MAX_SIZE_IN_HEAP=64
  V8_ATOMIC_OBJECT_FIELD_WRITES
  V8_ENABLE_LAZY_SOURCE_POSITIONS
  V8_ALLOCATION_FOLDING
  V8_ALLOCATION_SITE_TRACKING
  V8_ADVANCED_BIGINT_ALGORITHMS
  V8_COMPRESS_POINTERS_IN_SHARED_CAGE
  V8_SHORT_BUILTIN_CALLS
  V8_EXTERNAL_CODE_SPACE
  V8_ENABLE_REGEXP_INTERPRETER_THREADED_DISPATCH
  V8_SNAPSHOT_COMPRESSION
  V8_USE_ZLIB
  V8_CONTIGUOUS_COMPRESSED_RO_SPACE_SIZE_MB=8
  V8_ENABLE_LEAPTIERING
  CPPGC_CAGED_HEAP
  CPPGC_YOUNG_GENERATION
  V8_ENABLE_CONTINUATION_PRESERVED_EMBEDDER_DATA
  V8_HAVE_TARGET_OS
)

# Platform-specific definitions
if(WIN32)
  add_compile_definitions(
    WIN32 _WIN32 NOMINMAX
    _CRT_RAND_S
    _WIN32_WINNT=0x0A00
    _SILENCE_ALL_CXX20_DEPRECATION_WARNINGS
    _CRT_SECURE_NO_WARNINGS
    UNICODE _UNICODE
    V8_WIN64_UNWINDING_INFO
    V8_ENABLE_SYSTEM_INSTRUMENTATION
    V8_TARGET_OS_WIN
  )
else()
  add_compile_definitions(
    V8_TARGET_OS_LINUX
  )
endif()

if(V8_ENABLE_POINTER_COMPRESSION)
  add_compile_definitions(V8_COMPRESS_POINTERS V8_COMPRESS_POINTERS_IN_SHARED_CAGE)
endif()

if(V8_ENABLE_I18N)
  add_compile_definitions(
    V8_INTL_SUPPORT
    ICU_UTIL_DATA_IMPL=ICU_UTIL_DATA_STATIC
    UCONFIG_NO_SERVICE=1
    U_ENABLE_DYLOAD=0
    U_STATIC_IMPLEMENTATION
    U_HAVE_STD_STRING=1
    U_I18N_IMPLEMENTATION
    U_COMMON_IMPLEMENTATION
    UNISTR_FROM_CHAR_EXPLICIT=
    UNISTR_FROM_STRING_EXPLICIT=
  )
endif()

if(V8_ENABLE_WEBASSEMBLY)
  add_compile_definitions(V8_ENABLE_WEBASSEMBLY)
endif()

if(V8_ENABLE_MAGLEV)
  add_compile_definitions(V8_ENABLE_MAGLEV)
endif()

if(V8_ENABLE_SPARKPLUG)
  add_compile_definitions(V8_ENABLE_SPARKPLUG)
endif()

if(V8_ENABLE_ETW)
  add_compile_definitions(V8_ENABLE_ETW_STACK_WALKING)
endif()

if(V8_ENABLE_SANDBOX)
  add_compile_definitions(V8_ENABLE_SANDBOX)
endif()

# =============================================================================
# Compiler flags
# =============================================================================
if(MSVC)
  add_compile_options(
    /utf-8           # Source and execution charset
    /Zc:__cplusplus  # Correct __cplusplus macro
    /Zc:preprocessor # Standards-conforming preprocessor (needed for __VA_OPT__)
    /bigobj          # Large object files (V8 needs this)
    /Zm2000          # Increase compiler heap space
    /W3              # Warning level 3
    /std:c++20       # C++20 standard

    # Disabled warnings (from Node.js toolchain.gypi)
    /wd4129  # unrecognized character escape
    /wd4245  # signed/unsigned mismatch
    /wd4251  # needs dll-interface
    /wd4267  # possible loss of data
    /wd4275  # non dll-interface class
    /wd4324  # padding due to alignment
    /wd4351  # new behavior for array init
    /wd4355  # 'this' in base initializer
    /wd4506  # no definition for inline
    /wd4661  # no explicit instantiation
    /wd4701  # potentially uninitialized
    /wd4702  # unreachable code
    /wd4703  # potentially uninitialized pointer
    /wd4709  # comma operator in array index
    /wd4714  # forceinline not inlined
    /wd4715  # not all paths return
    /wd4718  # recursive call no side-effect
    /wd4723  # potential divide by zero
    /wd4724  # potential mod by zero
    /wd4800  # forcing to bool

    # Performance
    /MP      # Multi-processor compilation
    /GF      # String pooling
    /GS      # Buffer security check
  )

  # Release flags
  if(CMAKE_BUILD_TYPE STREQUAL "Release" OR CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo")
    add_compile_options(/O2 /Ob2 /Oi /Ot)
    add_link_options(/OPT:REF /OPT:ICF)
  endif()

  # Debug flags
  if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    add_compile_options(/Od /Z7)
    add_compile_definitions(_DEBUG V8_ENABLE_CHECKS)
  endif()

  # Runtime library
  if(V8_SHARED_LIBRARY)
    set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL")
  else()
    set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
  endif()

  # Linker: 2MB stack for x64
  add_link_options(/STACK:2097152)
else()
  # GCC / Clang
  add_compile_options(
    -fPIC
    -fno-strict-aliasing
    -fdata-sections
    -ffunction-sections
    -Wno-invalid-offsetof
    -Wno-unused-parameter
    -Wno-implicit-fallthrough
    -Wno-sign-compare
    -Wno-missing-field-initializers
    -Wno-comment
    -Wno-redundant-move
  )

  if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    add_compile_options(
      -Wno-undefined-var-template
      -Wno-tautological-constant-out-of-range-compare
    )
  endif()

  if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    add_compile_options(
      -Wno-stringop-overflow
      -Wno-class-memaccess
      -Wno-array-bounds
      -Wno-nonnull
      -Wno-dangling-pointer
    )
  endif()

  # Release flags
  if(CMAKE_BUILD_TYPE STREQUAL "Release" OR CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo")
    add_compile_options(-O2)
    add_link_options(-Wl,--gc-sections)
  endif()

  # Debug flags
  if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    add_compile_options(-O0 -g)
    add_compile_definitions(DEBUG V8_ENABLE_CHECKS)
  endif()

  set(CMAKE_POSITION_INDEPENDENT_CODE ON)
endif()

# =============================================================================
# Global include directories
# =============================================================================
include_directories(
  "${V8_ROOT}"
  "${V8_ROOT}/include"
  "${V8_GENERATED_DIR}"
  "${V8_GENERATED_DIR}/include"
  "${V8_ROOT}/third_party/highway/src"
  "${V8_ROOT}/third_party/fp16/src/include"
  "${V8_ROOT}/third_party/dragonbox/src/include"
  "${V8_ROOT}/third_party/fast_float/src/include"
  "${V8_ROOT}/third_party/simdutf"
  "${V8_ROOT}/third_party/zlib"
  "${V8_ROOT}/third_party/icu/source/common"
  "${V8_ROOT}/third_party/icu/source/i18n"
)

# =============================================================================
# Include sub-build files
# =============================================================================
include(cmake/sources.cmake)    # Source file lists
include(cmake/torque.cmake)     # Torque code generation
include(cmake/icu.cmake)        # ICU build
include(cmake/abseil.cmake)     # Abseil build
include(cmake/zlib.cmake)       # zlib build
include(cmake/targets.cmake)    # Library targets
include(cmake/snapshot.cmake)   # Snapshot generation
include(cmake/install.cmake)    # Install rules and find_package support
include(cmake/unittests.cmake)  # Unit tests (optional)
