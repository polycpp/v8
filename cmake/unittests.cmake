# =============================================================================
# V8 unit tests build
# =============================================================================

# GoogleTest/GoogleMock
set(GTEST_ROOT "${V8_ROOT}/third_party/googletest/src")

if(NOT EXISTS "${GTEST_ROOT}/googletest/CMakeLists.txt")
  message(STATUS "GoogleTest not found, skipping unit tests")
  return()
endif()

set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
set(BUILD_GMOCK ON CACHE BOOL "" FORCE)
set(INSTALL_GTEST OFF CACHE BOOL "" FORCE)
add_subdirectory("${GTEST_ROOT}" "${CMAKE_BINARY_DIR}/googletest" EXCLUDE_FROM_ALL)

# =============================================================================
# Collect unittest sources from the filesystem
# We include all *-unittest.cc files plus required helpers
# =============================================================================
set(V8_UNITTEST_DIR "${V8_ROOT}/test/unittests")

# Gather all unittest source files
file(GLOB_RECURSE V8_UNITTEST_CC_FILES
  "${V8_UNITTEST_DIR}/*-unittest.cc"
)

# Exclude architecture-specific files for non-target architectures
# Match both directory-based (/arm/) and filename-based (-arm-) patterns
list(FILTER V8_UNITTEST_CC_FILES EXCLUDE REGEX "[-/]arm[-/.]")
list(FILTER V8_UNITTEST_CC_FILES EXCLUDE REGEX "[-/]arm64[-/.]")
if(NOT V8_TARGET_ARCH STREQUAL "ia32")
  list(FILTER V8_UNITTEST_CC_FILES EXCLUDE REGEX "[-/]ia32[-/.]")
endif()
if(NOT V8_TARGET_ARCH STREQUAL "x64")
  list(FILTER V8_UNITTEST_CC_FILES EXCLUDE REGEX "[-/]x64[-/.]")
endif()
list(FILTER V8_UNITTEST_CC_FILES EXCLUDE REGEX "[-/]mips[-/.]")
list(FILTER V8_UNITTEST_CC_FILES EXCLUDE REGEX "[-/]mips64[-/.]")
list(FILTER V8_UNITTEST_CC_FILES EXCLUDE REGEX "[-/]s390[-/.]")
list(FILTER V8_UNITTEST_CC_FILES EXCLUDE REGEX "[-/]ppc[-/.]")
list(FILTER V8_UNITTEST_CC_FILES EXCLUDE REGEX "[-/]ppc64[-/.]")
list(FILTER V8_UNITTEST_CC_FILES EXCLUDE REGEX "[-/]riscv[-/.]")
list(FILTER V8_UNITTEST_CC_FILES EXCLUDE REGEX "[-/]riscv32[-/.]")
list(FILTER V8_UNITTEST_CC_FILES EXCLUDE REGEX "[-/]riscv64[-/.]")
list(FILTER V8_UNITTEST_CC_FILES EXCLUDE REGEX "[-/]loong64[-/.]")

# Exclude tests that require 64-bit features on ia32
if(V8_TARGET_ARCH STREQUAL "ia32")
  list(FILTER V8_UNITTEST_CC_FILES EXCLUDE REGEX "age-table-unittest")
  # Maglev tests reference arch-specific backend (no ia32 Maglev backend)
  list(FILTER V8_UNITTEST_CC_FILES EXCLUDE REGEX "[-/]maglev[-/]")
endif()

# Exclude platform-specific test files
list(FILTER V8_UNITTEST_CC_FILES EXCLUDE REGEX "fuchsia")
list(FILTER V8_UNITTEST_CC_FILES EXCLUDE REGEX "gdbserver")
if(WIN32)
  list(FILTER V8_UNITTEST_CC_FILES EXCLUDE REGEX "posix-unittest")
else()
  list(FILTER V8_UNITTEST_CC_FILES EXCLUDE REGEX "win-unittest")
  list(FILTER V8_UNITTEST_CC_FILES EXCLUDE REGEX "etw-")
endif()

# Exclude tests that need generated inspector protocol headers (not built yet)
list(FILTER V8_UNITTEST_CC_FILES EXCLUDE REGEX "inspector/")

# Exclude tests that need jsoncpp (third_party/jsoncpp not built)
list(FILTER V8_UNITTEST_CC_FILES EXCLUDE REGEX "json/json-unittest")
list(FILTER V8_UNITTEST_CC_FILES EXCLUDE REGEX "profiler/heap-snapshot-unittest")

# Exclude tests with compiler-specific issues pending fixes
list(FILTER V8_UNITTEST_CC_FILES EXCLUDE REGEX "runtime-call-stats-unittest")
list(FILTER V8_UNITTEST_CC_FILES EXCLUDE REGEX "member-unittest")  # needs CPPGC_POINTER_COMPRESSION

# Exclude fuzztest/fuzzer-dependent files
list(FILTER V8_UNITTEST_CC_FILES EXCLUDE REGEX "fuzztest")
list(FILTER V8_UNITTEST_CC_FILES EXCLUDE REGEX "fuzzer")

# Exclude tests with zone alignment issues (alignof(CreationObserver) > kAlignmentInBytes)
# Not FreeBSD-specific — reproduces on Linux with clang too (V8 upstream bug).
list(FILTER V8_UNITTEST_CC_FILES EXCLUDE REGEX "sloppy-equality-unittest")

# Exclude trap-handler-native test on FreeBSD: TryHandleWebAssemblyTrapPosix
# is guarded by V8_OS_LINUX || V8_OS_DARWIN in api.cc:6276, so the symbol
# doesn't exist on FreeBSD. V8 upstream issue — FreeBSD is POSIX and should
# have this handler.
if(CMAKE_SYSTEM_NAME STREQUAL "FreeBSD")
  list(FILTER V8_UNITTEST_CC_FILES EXCLUDE REGEX "trap-handler-native-unittest")
endif()

# Exclude tests needing sources not in our build
list(FILTER V8_UNITTEST_CC_FILES EXCLUDE REGEX "linear-scheduler-unittest")  # needs revec sources
list(FILTER V8_UNITTEST_CC_FILES EXCLUDE REGEX "revec-unittest")             # needs revec sources
list(FILTER V8_UNITTEST_CC_FILES EXCLUDE REGEX "ls-json-unittest")           # needs torque LS
list(FILTER V8_UNITTEST_CC_FILES EXCLUDE REGEX "ls-message-unittest")        # needs torque LS
list(FILTER V8_UNITTEST_CC_FILES EXCLUDE REGEX "wasm-tracing-unittest")      # needs fuzzer-common

# Helper/support files needed by tests
file(GLOB_RECURSE V8_UNITTEST_HELPERS
  "${V8_UNITTEST_DIR}/*.cc"
)
# Remove *-unittest.cc files (those are the tests, already in V8_UNITTEST_CC_FILES)
list(FILTER V8_UNITTEST_HELPERS EXCLUDE REGEX "-unittest\\.cc$")
# Remove run-all-unittests.cc (that's the main)
list(FILTER V8_UNITTEST_HELPERS EXCLUDE REGEX "run-all-unittests\\.cc$")
# Remove generate-bytecode-expectations.cc (standalone tool, has its own main)
list(FILTER V8_UNITTEST_HELPERS EXCLUDE REGEX "generate-bytecode-expectations\\.cc$")
# Remove fuzztest/fuzzer helpers
list(FILTER V8_UNITTEST_HELPERS EXCLUDE REGEX "fuzz")

# Common test helpers from test/common/
list(APPEND V8_UNITTEST_HELPERS
  "${V8_ROOT}/test/common/value-helper.cc"
  "${V8_ROOT}/test/common/wasm/wasm-module-runner.cc"
)

# Run-all entry point
set(V8_UNITTEST_MAIN
  "${V8_UNITTEST_DIR}/run-all-unittests.cc"
)

# Verify run-all-unittests.cc exists
if(NOT EXISTS "${V8_UNITTEST_MAIN}")
  message(STATUS "run-all-unittests.cc not found, skipping unit tests")
  return()
endif()

# =============================================================================
# v8_unittests executable
# =============================================================================
add_executable(v8_unittests
  ${V8_UNITTEST_MAIN}
  ${V8_UNITTEST_CC_FILES}
  ${V8_UNITTEST_HELPERS}
)

target_include_directories(v8_unittests PRIVATE
  "${V8_ROOT}"
  "${V8_ROOT}/include"
  "${V8_ROOT}/test"
  "${V8_ROOT}/testing"
  "${V8_GENERATED_DIR}"
  "${V8_GENERATED_DIR}/include"
  "${GTEST_ROOT}/googletest/include"
  "${GTEST_ROOT}/googlemock/include"
)

# Torque base library (needed for torque parser tests)
add_library(v8_torque_base_for_test STATIC ${V8_TORQUE_BASE_SOURCES})
target_link_libraries(v8_torque_base_for_test PUBLIC v8_libbase v8_abseil)

if(WIN32)
  target_link_libraries(v8_unittests PRIVATE
    v8
    v8_compiler
    v8_init
    v8_torque_base_for_test
    v8_abseil
    v8_zlib_google
    icu_interface
    gtest
    gmock
  )
else()
  target_link_libraries(v8_unittests PRIVATE
    -Wl,--start-group
    v8_snapshot
    v8_base_without_compiler
    v8_compiler
    v8_init
    v8_initializers
    v8_libbase
    v8_libplatform
    v8_libsampler
    v8_bigint
    v8_cppgc
    v8_heap_base
    v8_simdutf
    v8_zlib
    v8_zlib_google
    v8_highway
    v8_abseil
    v8_torque_base_for_test
    icu_interface
    gtest
    gmock
    -Wl,--end-group
  )
endif()

target_compile_definitions(v8_unittests PRIVATE
  V8_ENABLE_WEBASSEMBLY
)
if(V8_ENABLE_MAGLEV)
  target_compile_definitions(v8_unittests PRIVATE V8_ENABLE_MAGLEV)
endif()

if(MSVC)
  target_compile_options(v8_unittests PRIVATE /bigobj /wd4244 /wd4267 /wd4309)
  target_link_options(v8_unittests PRIVATE /FORCE:MULTIPLE)
endif()

add_dependencies(v8_unittests run_torque generate_bytecodes_builtins_list generate_regexp_special_case)

# Print how many test files we found
list(LENGTH V8_UNITTEST_CC_FILES _test_count)
message(STATUS "V8 unittests: ${_test_count} test files")

# Create symlink to golden files for bytecode generator tests.
# The test expects them at "test/unittests/interpreter/bytecode_expectations/"
# relative to the working directory.
set(_golden_src "${V8_ROOT}/test/unittests/interpreter/bytecode_expectations")
set(_golden_dst "${CMAKE_BINARY_DIR}/test/unittests/interpreter/bytecode_expectations")
if(EXISTS "${_golden_src}" AND NOT EXISTS "${_golden_dst}")
  file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/test/unittests/interpreter")
  file(CREATE_LINK "${_golden_src}" "${_golden_dst}" SYMBOLIC)
  message(STATUS "Created symlink for bytecode golden files")
endif()
