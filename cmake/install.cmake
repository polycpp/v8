# =============================================================================
# V8 installation and CMake package configuration
# =============================================================================
# Provides:
#   cmake --install <build-dir> --prefix <install-dir>
#   find_package(v8) -> v8::v8 target for consumers
# =============================================================================

include(CMakePackageConfigHelpers)
include(GNUInstallDirs)

set(V8_INSTALL_CMAKEDIR "${CMAKE_INSTALL_LIBDIR}/cmake/v8" CACHE STRING
  "Install directory for V8 CMake package config files")

# =============================================================================
# Install V8 static libraries
# =============================================================================
set(_v8_install_targets
  v8_libbase
  v8_libplatform
  v8_libsampler
  v8_bigint
  v8_heap_base
  v8_cppgc
  v8_compiler
  v8_base_without_compiler
  v8_initializers
  v8_init
  v8_snapshot
  v8_zlib
)
if(TARGET v8_highway)
  list(APPEND _v8_install_targets v8_highway)
  set(V8_HAS_HIGHWAY TRUE)
else()
  set(V8_HAS_HIGHWAY FALSE)
endif()
if(TARGET v8_simdutf)
  list(APPEND _v8_install_targets v8_simdutf)
  set(V8_HAS_SIMDUTF TRUE)
else()
  set(V8_HAS_SIMDUTF FALSE)
endif()

# v8_zlib_google may be STATIC or INTERFACE depending on source availability
get_target_property(_zg_type v8_zlib_google TYPE)
if(_zg_type STREQUAL "STATIC_LIBRARY")
  list(APPEND _v8_install_targets v8_zlib_google)
  set(V8_ZLIB_GOOGLE_IS_STATIC TRUE)
else()
  set(V8_ZLIB_GOOGLE_IS_STATIC FALSE)
endif()

# ICU libraries
set(V8_ICUDATA_INSTALLED_AS "none")
if(V8_ENABLE_I18N)
  # Only install ICU if built from source (not external/imported)
  get_target_property(_icuuc_imported icuuc IMPORTED)
  if(NOT _icuuc_imported)
    list(APPEND _v8_install_targets icuuc icui18n)
  endif()

  if(TARGET icudata)
    get_target_property(_icudata_type icudata TYPE)
    get_target_property(_icudata_imported icudata IMPORTED)
    if(_icudata_type STREQUAL "STATIC_LIBRARY" AND NOT _icudata_imported)
      # Built from stubdata sources - regular static lib
      list(APPEND _v8_install_targets icudata)
      set(V8_ICUDATA_INSTALLED_AS "static")
    elseif(_icudata_imported)
      # IMPORTED target from generated object - install the file directly
      get_target_property(_icudata_loc icudata IMPORTED_LOCATION)
      if(_icudata_loc)
        if(WIN32)
          set(_icudata_install_name "icudata.obj")
        else()
          set(_icudata_install_name "icudata.o")
        endif()
        install(FILES "${_icudata_loc}"
          DESTINATION "${CMAKE_INSTALL_LIBDIR}"
          RENAME "${_icudata_install_name}"
        )
        set(V8_ICUDATA_INSTALLED_AS "object")
      endif()
    else()
      # Regular static library (Linux .incbin approach)
      list(APPEND _v8_install_targets icudata)
      set(V8_ICUDATA_INSTALLED_AS "static")
    endif()
  endif()
endif()

install(TARGETS ${_v8_install_targets}
  ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}"
  LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
)

# =============================================================================
# Install public headers (preserving subdirectory structure)
# =============================================================================
install(DIRECTORY "${V8_ROOT}/include/"
  DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}"
  FILES_MATCHING PATTERN "*.h"
)

# =============================================================================
# Install executables
# =============================================================================
install(TARGETS d8 RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}")
if(TARGET mksnapshot)
  install(TARGETS mksnapshot RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}")
endif()

# =============================================================================
# Generate and install CMake package config files
# =============================================================================
# Pass build configuration to the config template
set(V8_CONFIG_ENABLE_I18N ${V8_ENABLE_I18N})
set(V8_CONFIG_ENABLE_ETW ${V8_ENABLE_ETW})
set(V8_CONFIG_ENABLE_SANDBOX ${V8_ENABLE_SANDBOX})
set(V8_CONFIG_POINTER_COMPRESSION ${V8_ENABLE_POINTER_COMPRESSION})

configure_package_config_file(
  "${CMAKE_CURRENT_SOURCE_DIR}/cmake/v8Config.cmake.in"
  "${CMAKE_CURRENT_BINARY_DIR}/v8Config.cmake"
  INSTALL_DESTINATION "${V8_INSTALL_CMAKEDIR}"
)

write_basic_package_version_file(
  "${CMAKE_CURRENT_BINARY_DIR}/v8ConfigVersion.cmake"
  VERSION "${PROJECT_VERSION}"
  COMPATIBILITY SameMajorVersion
)

install(FILES
  "${CMAKE_CURRENT_BINARY_DIR}/v8Config.cmake"
  "${CMAKE_CURRENT_BINARY_DIR}/v8ConfigVersion.cmake"
  DESTINATION "${V8_INSTALL_CMAKEDIR}"
)
