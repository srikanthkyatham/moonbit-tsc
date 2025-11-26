cmake_minimum_required(VERSION 3.16)
project(moonbit-tsc VERSION 0.1.0 LANGUAGES C)

# Options
option(BUILD_TESTS "Build tests" ON)

# Platform detection
if(APPLE)
    set(PLATFORM "macos")
elseif(UNIX)
    set(PLATFORM "linux")
elseif(WIN32)
    set(PLATFORM "windows")
endif()

message(STATUS "Building for platform: ${PLATFORM}")

# Directories
set(MOONBIT_DIR ${CMAKE_SOURCE_DIR}/src/moonbit)
set(ZIG_DIR ${CMAKE_SOURCE_DIR}/src/zig)
set(FFI_LIB_DIR ${MOONBIT_DIR}/ffi_lib)

# Find MoonBit include directory
if(DEFINED ENV{HOME})
    set(MOONBIT_INCLUDE_DIR "$ENV{HOME}/.moon/include")
    set(MOONBIT_RUNTIME_O "$ENV{HOME}/.moon/lib/libmoonbitrun.o")
elseif(DEFINED ENV{USERPROFILE})
    set(MOONBIT_INCLUDE_DIR "$ENV{USERPROFILE}/.moon/include")
    set(MOONBIT_RUNTIME_O "$ENV{USERPROFILE}/.moon/lib/libmoonbitrun.o")
endif()

# Generated file paths
set(MOONBIT_TARGET_DIR ${MOONBIT_DIR}/target/native/release/build/ffi_lib)
set(MOONBIT_BUILD_DIR ${MOONBIT_DIR}/target/native/release/build)
set(MOONBIT_GENERATED_C ${MOONBIT_TARGET_DIR}/ffi_lib.c)
set(MOONBIT_GENERATED_RUNTIME_O ${MOONBIT_BUILD_DIR}/runtime.o)

# ============================================================================
# Step 1: Custom command to generate MoonBit C code
# ============================================================================
add_custom_command(
    OUTPUT ${MOONBIT_GENERATED_C} ${MOONBIT_GENERATED_RUNTIME_O}
    COMMAND moon build --target native ffi_lib
    WORKING_DIRECTORY ${MOONBIT_DIR}
    DEPENDS
        ${FFI_LIB_DIR}/ffi_exports.mbt
        ${FFI_LIB_DIR}/moon.pkg.json
    COMMENT "Generating C code from MoonBit..."
)

add_custom_target(moonbit_codegen
    DEPENDS ${MOONBIT_GENERATED_C}
)

# ============================================================================
# Step 2: Build static library from generated C code
# ============================================================================
add_library(moonbit_tsc_lib STATIC
    ${MOONBIT_GENERATED_C}
    ${FFI_LIB_DIR}/moonbit_tsc_wrapper.c
)

add_dependencies(moonbit_tsc_lib moonbit_codegen)

target_include_directories(moonbit_tsc_lib PRIVATE
    ${MOONBIT_INCLUDE_DIR}
    ${FFI_LIB_DIR}
)

target_compile_options(moonbit_tsc_lib PRIVATE
    -O2 -fwrapv -fno-strict-aliasing
)

# Link MoonBit runtime object file
target_link_libraries(moonbit_tsc_lib PRIVATE
    ${MOONBIT_GENERATED_RUNTIME_O}
)

# Platform-specific settings
if(APPLE)
    target_link_libraries(moonbit_tsc_lib PRIVATE "-framework CoreFoundation")
elseif(UNIX)
    target_link_libraries(moonbit_tsc_lib PRIVATE pthread m)
elseif(WIN32)
    target_compile_definitions(moonbit_tsc_lib PRIVATE _CRT_SECURE_NO_WARNINGS)
endif()

# Set output name
set_target_properties(moonbit_tsc_lib PROPERTIES
    OUTPUT_NAME moonbit_tsc
    ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib
)

# ============================================================================
# Step 3: Build Zig executable with static library
# ============================================================================
set(ZIG_OUTPUT ${CMAKE_BINARY_DIR}/bin/moonbit-tsc)

add_custom_command(
    OUTPUT ${ZIG_OUTPUT}
    COMMAND ${CMAKE_COMMAND} -E env
        zig build
        -Dmoonbit-static-lib=$<TARGET_FILE:moonbit_tsc_lib>
        -Doptimize=ReleaseFast
        --prefix ${CMAKE_BINARY_DIR}
    WORKING_DIRECTORY ${ZIG_DIR}
    DEPENDS moonbit_tsc_lib
    COMMENT "Building Zig executable with static MoonBit library..."
)

add_custom_target(moonbit_tsc ALL
    DEPENDS ${ZIG_OUTPUT}
)

# ============================================================================
# Installation
# ============================================================================
install(PROGRAMS ${ZIG_OUTPUT}
    DESTINATION bin
    RENAME moonbit-tsc
)

install(FILES ${FFI_LIB_DIR}/moonbit_tsc.h
    DESTINATION include
)

# ============================================================================
# Testing
# ============================================================================
if(BUILD_TESTS)
    enable_testing()

    add_test(NAME version_test
        COMMAND ${ZIG_OUTPUT} --version
    )

    add_test(NAME help_test
        COMMAND ${ZIG_OUTPUT} --help
    )
endif()

# ============================================================================
# Package configuration
# ============================================================================
include(CPack)
set(CPACK_PACKAGE_NAME "moonbit-tsc")
set(CPACK_PACKAGE_VERSION ${PROJECT_VERSION})
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "High-performance TypeScript compiler")

if(APPLE)
    set(CPACK_GENERATOR "DragNDrop;TGZ")
elseif(UNIX)
    set(CPACK_GENERATOR "TGZ;DEB;RPM")
elseif(WIN32)
    set(CPACK_GENERATOR "ZIP;NSIS")
endif()
