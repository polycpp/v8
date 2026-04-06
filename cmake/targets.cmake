# =============================================================================
# V8 library targets
# =============================================================================

# =============================================================================
# v8_libbase - Platform abstraction layer
# =============================================================================
add_library(v8_libbase STATIC ${V8_LIBBASE_SOURCES})
target_link_libraries(v8_libbase PUBLIC dbghelp.lib winmm.lib ws2_32.lib v8_abseil)
if(V8_ENABLE_ETW)
  target_link_libraries(v8_libbase PUBLIC advapi32.lib)
endif()

# =============================================================================
# v8_libplatform - Default platform implementation
# =============================================================================
add_library(v8_libplatform STATIC ${V8_LIBPLATFORM_SOURCES})
target_link_libraries(v8_libplatform PUBLIC v8_libbase)

# =============================================================================
# v8_libsampler - Sampling profiler
# =============================================================================
add_library(v8_libsampler STATIC ${V8_LIBSAMPLER_SOURCES})
target_link_libraries(v8_libsampler PUBLIC v8_libbase)

# =============================================================================
# Third-party libraries
# =============================================================================
if(V8_HIGHWAY_SOURCES)
  add_library(v8_highway STATIC ${V8_HIGHWAY_SOURCES})
  target_include_directories(v8_highway PUBLIC "${V8_ROOT}/third_party/highway/src")
endif()

if(V8_SIMDUTF_SOURCES)
  add_library(v8_simdutf STATIC ${V8_SIMDUTF_SOURCES})
  target_include_directories(v8_simdutf PUBLIC "${V8_ROOT}/third_party/simdutf")
  target_compile_definitions(v8_simdutf PRIVATE SIMDUTF_DLLIMPORTEXPORT=)
  if(MSVC)
    target_compile_options(v8_simdutf PRIVATE /wd4244 /wd4267)
  endif()
endif()

# Header-only libs (interface targets)
add_library(v8_fp16 INTERFACE)
target_include_directories(v8_fp16 INTERFACE "${V8_ROOT}/third_party/fp16/src/include")

if(EXISTS "${V8_ROOT}/third_party/dragonbox")
  add_library(v8_dragonbox INTERFACE)
  target_include_directories(v8_dragonbox INTERFACE "${V8_ROOT}/third_party/dragonbox/src/include")
endif()

if(EXISTS "${V8_ROOT}/third_party/fast_float")
  add_library(v8_fast_float INTERFACE)
  target_include_directories(v8_fast_float INTERFACE "${V8_ROOT}/third_party/fast_float/src/include")
endif()

# =============================================================================
# v8_bigint
# =============================================================================
add_library(v8_bigint STATIC ${V8_BIGINT_SOURCES})

# =============================================================================
# v8_heap_base
# =============================================================================
# Build MASM asm as a separate library to avoid CXX flags leaking to ml64
add_library(v8_heap_base_asm OBJECT ${V8_HEAP_BASE_ASM_SOURCES})
set_target_properties(v8_heap_base_asm PROPERTIES
  LINKER_LANGUAGE CXX
  # Remove all C/C++ compile flags from MASM target
  COMPILE_OPTIONS ""
  COMPILE_DEFINITIONS ""
)
set_source_files_properties(${V8_HEAP_BASE_ASM_SOURCES} PROPERTIES
  LANGUAGE ASM_MASM
  COMPILE_FLAGS ""
)

add_library(v8_heap_base STATIC ${V8_HEAP_BASE_SOURCES} $<TARGET_OBJECTS:v8_heap_base_asm>)
target_link_libraries(v8_heap_base PUBLIC v8_libbase)

# =============================================================================
# v8_cppgc
# =============================================================================
add_library(v8_cppgc STATIC ${V8_CPPGC_SOURCES})
target_link_libraries(v8_cppgc PUBLIC v8_heap_base v8_libbase)

# =============================================================================
# v8_compiler (TurboFan)
# =============================================================================
set(_v8_compiler_all ${V8_COMPILER_SOURCES})
if(V8_ENABLE_WEBASSEMBLY)
  list(APPEND _v8_compiler_all ${V8_COMPILER_WASM_SOURCES})
endif()

add_library(v8_compiler STATIC ${_v8_compiler_all})
target_link_libraries(v8_compiler PUBLIC v8_libbase)
add_dependencies(v8_compiler run_torque generate_bytecodes_builtins_list)


# =============================================================================
# v8_base_without_compiler - Core V8 runtime
# =============================================================================
set(_v8_base_all ${V8_BASE_SOURCES})

if(V8_ENABLE_SPARKPLUG)
  list(APPEND _v8_base_all ${V8_SPARKPLUG_SOURCES})
endif()
if(V8_ENABLE_MAGLEV)
  list(APPEND _v8_base_all ${V8_MAGLEV_SOURCES})
endif()
if(V8_ENABLE_WEBASSEMBLY)
  list(APPEND _v8_base_all ${V8_WASM_SOURCES})
endif()
if(V8_ENABLE_ETW)
  list(APPEND _v8_base_all ${V8_ETW_SOURCES})
endif()

# Add generated regexp special-case
list(APPEND _v8_base_all "${V8_GENERATED_DIR}/src/regexp/special-case.cc")
set_source_files_properties("${V8_GENERATED_DIR}/src/regexp/special-case.cc"
  PROPERTIES GENERATED TRUE)

# Add torque-generated definition sources
list(APPEND _v8_base_all ${TORQUE_GENERATED_DEFINITIONS_SOURCES})

add_library(v8_base_without_compiler STATIC ${_v8_base_all})
target_link_libraries(v8_base_without_compiler PUBLIC
  v8_libbase
  v8_bigint
  v8_heap_base
  v8_cppgc
  v8_fp16
  v8_abseil
  v8_zlib_google
  v8_libsampler
)
if(TARGET v8_highway)
  target_link_libraries(v8_base_without_compiler PUBLIC v8_highway)
endif()
if(TARGET v8_simdutf)
  target_link_libraries(v8_base_without_compiler PUBLIC v8_simdutf)
endif()
if(TARGET v8_dragonbox)
  target_link_libraries(v8_base_without_compiler PUBLIC v8_dragonbox)
endif()
if(TARGET v8_fast_float)
  target_link_libraries(v8_base_without_compiler PUBLIC v8_fast_float)
endif()
if(V8_ENABLE_I18N)
  target_link_libraries(v8_base_without_compiler PUBLIC icu_interface)
endif()
add_dependencies(v8_base_without_compiler run_torque generate_bytecodes_builtins_list generate_regexp_special_case)

# MSVC: prevent .cc/.cpp file name collisions in object dir
if(MSVC)
  set_target_properties(v8_base_without_compiler PROPERTIES
    VS_GLOBAL_ObjectFileName "$(IntDir)%(Extension)\\"
  )
endif()

# =============================================================================
# v8_initializers - Builtin initialization code
# =============================================================================
set(_v8_init_all
  ${V8_INITIALIZERS_SOURCES}
  ${TORQUE_GENERATED_INITIALIZERS_SOURCES}
)
if(V8_ENABLE_WEBASSEMBLY)
  list(APPEND _v8_init_all ${V8_INITIALIZERS_WASM_SOURCES})
endif()

add_library(v8_initializers STATIC ${_v8_init_all})
target_link_libraries(v8_initializers PUBLIC v8_base_without_compiler v8_compiler)
add_dependencies(v8_initializers run_torque generate_bytecodes_builtins_list)

# =============================================================================
# v8_init - Full isolate setup (for mksnapshot)
# =============================================================================
add_library(v8_init STATIC ${V8_INIT_SOURCES})
target_link_libraries(v8_init PUBLIC v8_initializers)
add_dependencies(v8_init run_torque)

# =============================================================================
# v8_base - Combined base + compiler (main V8 target for linking)
# =============================================================================
add_library(v8_base INTERFACE)
target_link_libraries(v8_base INTERFACE
  v8_base_without_compiler
  v8_compiler
)

# =============================================================================
# d8 - V8 developer shell
# =============================================================================
set(D8_SOURCES
  ${V8_ROOT}/src/d8/d8.cc
  ${V8_ROOT}/src/d8/d8.h
  ${V8_ROOT}/src/d8/d8-console.cc
  ${V8_ROOT}/src/d8/d8-console.h
  ${V8_ROOT}/src/d8/d8-js.cc
  ${V8_ROOT}/src/d8/d8-platforms.cc
  ${V8_ROOT}/src/d8/d8-platforms.h
  ${V8_ROOT}/src/d8/d8-test.cc
  ${V8_ROOT}/src/d8/d8-windows.cc
  ${V8_ROOT}/src/d8/async-hooks-wrapper.cc
  ${V8_ROOT}/src/d8/async-hooks-wrapper.h
  # Stub inspector (full inspector requires generated protocol headers)
  ${V8_ROOT}/src/inspector/v8-inspector-stub.cc
)

add_executable(d8 ${D8_SOURCES})
target_link_libraries(d8 PRIVATE
  v8_base
  v8_snapshot
  v8_init
  v8_initializers
  v8_libbase
  v8_libplatform
  v8_libsampler
  v8_bigint
  v8_cppgc
  v8_heap_base
  v8_zlib
  v8_zlib_google
  v8_abseil
  icu_interface
)
if(TARGET v8_simdutf)
  target_link_libraries(d8 PRIVATE v8_simdutf)
endif()
if(TARGET v8_highway)
  target_link_libraries(d8 PRIVATE v8_highway)
endif()
add_dependencies(d8 run_torque generate_bytecodes_builtins_list)

if(MSVC)
  target_compile_options(d8 PRIVATE /bigobj /wd4244 /wd4267 /wd4309)
  target_link_options(d8 PRIVATE /FORCE:MULTIPLE)
endif()
