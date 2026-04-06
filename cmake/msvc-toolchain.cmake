# MSVC Toolchain file for V8 build
# Auto-detects Visual Studio and Windows SDK paths

# Find Visual Studio
execute_process(
  COMMAND "C:/Program Files (x86)/Microsoft Visual Studio/Installer/vswhere.exe"
    -latest -property installationPath
  OUTPUT_VARIABLE VS_PATH
  OUTPUT_STRIP_TRAILING_WHITESPACE
)

if(NOT VS_PATH)
  message(FATAL_ERROR "Visual Studio not found. Install VS with C++ workload.")
endif()

# Normalize backslashes to forward slashes
string(REPLACE "\\" "/" VS_PATH "${VS_PATH}")

# Find latest MSVC version
file(GLOB _msvc_versions "${VS_PATH}/VC/Tools/MSVC/*")
list(SORT _msvc_versions)
list(GET _msvc_versions -1 MSVC_TOOLS_PATH)

set(CMAKE_C_COMPILER "${MSVC_TOOLS_PATH}/bin/Hostx64/x64/cl.exe")
set(CMAKE_CXX_COMPILER "${MSVC_TOOLS_PATH}/bin/Hostx64/x64/cl.exe")
set(CMAKE_ASM_MASM_COMPILER "${MSVC_TOOLS_PATH}/bin/Hostx64/x64/ml64.exe")
set(CMAKE_LINKER "${MSVC_TOOLS_PATH}/bin/Hostx64/x64/link.exe")
set(CMAKE_AR "${MSVC_TOOLS_PATH}/bin/Hostx64/x64/lib.exe")

# Find Windows SDK
set(WIN_SDK_ROOT "C:/Program Files (x86)/Windows Kits/10")
file(GLOB _sdk_versions "${WIN_SDK_ROOT}/Include/*")
list(SORT _sdk_versions)
list(GET _sdk_versions -1 _sdk_inc_path)
get_filename_component(WIN_SDK_VERSION "${_sdk_inc_path}" NAME)

# RC compiler and MT tool from Windows SDK
set(CMAKE_RC_COMPILER "${WIN_SDK_ROOT}/bin/${WIN_SDK_VERSION}/x64/rc.exe")
set(CMAKE_MT "${WIN_SDK_ROOT}/bin/${WIN_SDK_VERSION}/x64/mt.exe")

# MSVC include paths
set(CMAKE_C_STANDARD_INCLUDE_DIRECTORIES
  "${MSVC_TOOLS_PATH}/include"
  "${WIN_SDK_ROOT}/Include/${WIN_SDK_VERSION}/ucrt"
  "${WIN_SDK_ROOT}/Include/${WIN_SDK_VERSION}/shared"
  "${WIN_SDK_ROOT}/Include/${WIN_SDK_VERSION}/um"
  "${WIN_SDK_ROOT}/Include/${WIN_SDK_VERSION}/winrt"
)
set(CMAKE_CXX_STANDARD_INCLUDE_DIRECTORIES ${CMAKE_C_STANDARD_INCLUDE_DIRECTORIES})

# Library paths
link_directories(
  "${MSVC_TOOLS_PATH}/lib/x64"
  "${WIN_SDK_ROOT}/Lib/${WIN_SDK_VERSION}/ucrt/x64"
  "${WIN_SDK_ROOT}/Lib/${WIN_SDK_VERSION}/um/x64"
)

set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR AMD64)
