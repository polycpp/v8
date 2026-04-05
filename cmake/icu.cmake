# =============================================================================
# ICU (International Components for Unicode) build
# =============================================================================
# V8 requires ICU for internationalization support.
# This builds ICU from the chromium-bundled sources in third_party/icu.
# =============================================================================

if(NOT V8_ENABLE_I18N)
  # Create empty target for dependencies
  add_library(icu_interface INTERFACE)
  return()
endif()

set(ICU_ROOT "${V8_ROOT}/third_party/icu")
set(ICU_SOURCE "${ICU_ROOT}/source")

if(NOT EXISTS "${ICU_SOURCE}/common")
  message(FATAL_ERROR "ICU source not found at ${ICU_SOURCE}. Run fetch_deps.py first.")
endif()

# Collect ICU common sources
file(GLOB ICU_COMMON_SOURCES "${ICU_SOURCE}/common/*.cpp")
# Collect ICU i18n sources
file(GLOB ICU_I18N_SOURCES "${ICU_SOURCE}/i18n/*.cpp")
# Collect ICU stubdata
file(GLOB ICU_STUBDATA_SOURCES "${ICU_SOURCE}/stubdata/*.cpp")

# =============================================================================
# ICU common library
# =============================================================================
add_library(icuuc STATIC ${ICU_COMMON_SOURCES})
target_include_directories(icuuc
  PUBLIC "${ICU_SOURCE}/common"
  PRIVATE "${ICU_SOURCE}/i18n"
)
target_compile_definitions(icuuc PRIVATE
  U_COMMON_IMPLEMENTATION
  U_STATIC_IMPLEMENTATION
  UCONFIG_NO_SERVICE=1
  U_ENABLE_DYLOAD=0
  U_HAVE_STD_STRING=1
  HAVE_DLOPEN=0
  UCONFIG_NO_FILTERED_BREAK_ITERATION=0
)
if(MSVC)
  target_compile_options(icuuc PRIVATE /wd4005 /wd4068 /wd4244 /wd4267 /wd4996)
else()
  # GCC: -fpermissive needed for incomplete type in is_convertible_v template trait
  target_compile_options(icuuc PRIVATE -Wno-deprecated-declarations -Wno-unused-function -fpermissive)
endif()

# =============================================================================
# ICU i18n library
# =============================================================================
add_library(icui18n STATIC ${ICU_I18N_SOURCES})
target_include_directories(icui18n
  PUBLIC "${ICU_SOURCE}/i18n"
  PRIVATE "${ICU_SOURCE}/common"
)
target_compile_definitions(icui18n PRIVATE
  U_I18N_IMPLEMENTATION
  U_STATIC_IMPLEMENTATION
  UCONFIG_NO_SERVICE=1
  U_ENABLE_DYLOAD=0
  U_HAVE_STD_STRING=1
  HAVE_DLOPEN=0
)
target_link_libraries(icui18n PUBLIC icuuc)
if(MSVC)
  target_compile_options(icui18n PRIVATE /wd4005 /wd4068 /wd4244 /wd4267 /wd4996)
else()
  target_compile_options(icui18n PRIVATE -Wno-deprecated-declarations -Wno-unused-function -fpermissive)
endif()

# =============================================================================
# ICU data - embed real data or use stubdata
# =============================================================================
set(ICU_DATA_FILE "")
file(GLOB _icu_dat_files "${ICU_ROOT}/common/icudtl.dat")
if(_icu_dat_files)
  list(GET _icu_dat_files 0 ICU_DATA_FILE)
  message(STATUS "Found ICU data file: ${ICU_DATA_FILE}")
endif()

if(ICU_DATA_FILE)
  if(WIN32)
    # Windows: generate a COFF .obj file embedding the real ICU data directly.
    set(ICU_DATA_OBJ "${CMAKE_BINARY_DIR}/gen/icudata.obj")
    add_custom_command(
      OUTPUT "${ICU_DATA_OBJ}"
      COMMAND ${CMAKE_COMMAND} -E env python3
        "${CMAKE_CURRENT_SOURCE_DIR}/cmake/generate_icu_data.py"
        "${ICU_DATA_FILE}" "${ICU_DATA_OBJ}"
      DEPENDS "${ICU_DATA_FILE}" "${CMAKE_CURRENT_SOURCE_DIR}/cmake/generate_icu_data.py"
      COMMENT "Generating embedded ICU data object from icudtl.dat (COFF)"
    )
    add_custom_target(icudata_generate DEPENDS "${ICU_DATA_OBJ}")
    add_library(icudata STATIC IMPORTED GLOBAL)
    set_target_properties(icudata PROPERTIES IMPORTED_LOCATION "${ICU_DATA_OBJ}")
    add_dependencies(icudata icudata_generate)
  else()
    # Linux: use a .S assembly file with .incbin to embed ICU data
    # with the exact symbol name ICU expects (icudt78_dat).
    set(ICU_DATA_ASM "${CMAKE_BINARY_DIR}/gen/icudata.S")
    file(WRITE "${ICU_DATA_ASM}" "\
.section .rodata\n\
.global icudt78_dat\n\
.type icudt78_dat, @object\n\
.balign 16\n\
icudt78_dat:\n\
.incbin \"${ICU_DATA_FILE}\"\n\
.size icudt78_dat, . - icudt78_dat\n\
\n\
.section .note.GNU-stack,\"\",@progbits\n\
")
    add_library(icudata STATIC "${ICU_DATA_ASM}")
    set_target_properties(icudata PROPERTIES LINKER_LANGUAGE C)
  endif()
  message(STATUS "ICU: embedding real data from ${ICU_DATA_FILE}")
else()
  # Fallback to stubdata (empty data, requires runtime file loading)
  file(GLOB ICU_STUBDATA_SOURCES "${ICU_SOURCE}/stubdata/*.cpp")
  add_library(icudata STATIC ${ICU_STUBDATA_SOURCES})
  target_include_directories(icudata PRIVATE "${ICU_SOURCE}/common")
  target_compile_definitions(icudata PRIVATE U_STATIC_IMPLEMENTATION)
  message(STATUS "ICU: using stubdata (no icudtl.dat found)")
endif()

# =============================================================================
# Combined ICU interface target
# =============================================================================
add_library(icu_interface INTERFACE)
target_link_libraries(icu_interface INTERFACE icui18n icuuc icudata)
target_include_directories(icu_interface INTERFACE
  "${ICU_SOURCE}/common"
  "${ICU_SOURCE}/i18n"
)
