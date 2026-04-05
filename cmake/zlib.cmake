# =============================================================================
# zlib build (Chromium's bundled version with Cr_z_ prefix)
# =============================================================================

set(ZLIB_ROOT "${V8_ROOT}/third_party/zlib")

# Core zlib sources
file(GLOB ZLIB_CORE_SOURCES "${ZLIB_ROOT}/*.c")
# Remove non-essential files
list(FILTER ZLIB_CORE_SOURCES EXCLUDE REGEX "example|minigzip|contrib")

add_library(v8_zlib STATIC ${ZLIB_CORE_SOURCES})
target_include_directories(v8_zlib PUBLIC "${ZLIB_ROOT}")
target_compile_definitions(v8_zlib PRIVATE
  ZLIB_IMPLEMENTATION
  HAVE_STDARG_H
)
if(WIN32)
  target_compile_definitions(v8_zlib PRIVATE X86_WINDOWS)
endif()
if(MSVC)
  target_compile_options(v8_zlib PRIVATE /wd4244 /wd4267 /wd4996)
endif()

# Compression utils (used by V8 for snapshot compression)
set(ZLIB_GOOGLE_SOURCES
  "${ZLIB_ROOT}/google/compression_utils_portable.cc"
)
if(EXISTS "${ZLIB_ROOT}/google/compression_utils_portable.cc")
  add_library(v8_zlib_google STATIC ${ZLIB_GOOGLE_SOURCES})
  target_include_directories(v8_zlib_google PUBLIC "${ZLIB_ROOT}")
  target_link_libraries(v8_zlib_google PUBLIC v8_zlib)
else()
  add_library(v8_zlib_google INTERFACE)
  target_link_libraries(v8_zlib_google INTERFACE v8_zlib)
endif()
