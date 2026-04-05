# =============================================================================
# Abseil-cpp build
# =============================================================================
# V8 uses a subset of Abseil. Rather than building the full library,
# we use abseil's own CMake build system via add_subdirectory.
# =============================================================================

set(ABSEIL_ROOT "${V8_ROOT}/third_party/abseil-cpp")

if(NOT EXISTS "${ABSEIL_ROOT}/CMakeLists.txt")
  message(FATAL_ERROR "Abseil not found at ${ABSEIL_ROOT}. Run fetch_deps.py first.")
endif()

# Abseil options
set(ABSL_PROPAGATE_CXX_STD ON CACHE BOOL "" FORCE)
set(ABSL_BUILD_TESTING OFF CACHE BOOL "" FORCE)
set(ABSL_BUILD_TEST_HELPERS OFF CACHE BOOL "" FORCE)
set(BUILD_TESTING OFF CACHE BOOL "" FORCE)
# Ensure abseil uses the same runtime library as V8 on Windows
if(MSVC)
  set(ABSL_MSVC_STATIC_RUNTIME ON CACHE BOOL "" FORCE)
endif()
# Enable abseil installation alongside V8
set(ABSL_ENABLE_INSTALL ON CACHE BOOL "" FORCE)

add_subdirectory("${ABSEIL_ROOT}" "${CMAKE_BINARY_DIR}/abseil-cpp")

# Create an interface target that aggregates the abseil components V8 needs
add_library(v8_abseil INTERFACE)
target_link_libraries(v8_abseil INTERFACE
  absl::flat_hash_map
  absl::flat_hash_set
  absl::strings
  absl::optional
  absl::btree
)
