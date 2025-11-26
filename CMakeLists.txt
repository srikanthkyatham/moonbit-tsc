cmake_minimum_required(VERSION 3.16)
project(moonbit-tsc VERSION 0.1.0)

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
set(CLI_OUTPUT ${MOONBIT_DIR}/target/native/release/build/cli/cli.exe)

# ============================================================================
# Build MoonBit CLI (pure MoonBit implementation)
# ============================================================================
add_custom_command(
    OUTPUT ${CLI_OUTPUT}
    COMMAND moon build --target native cli
    WORKING_DIRECTORY ${MOONBIT_DIR}
    COMMENT "Building pure MoonBit TypeScript compiler CLI..."
)

add_custom_target(moonbit_tsc ALL
    DEPENDS ${CLI_OUTPUT}
)

# Copy to bin directory
add_custom_command(
    TARGET moonbit_tsc POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_BINARY_DIR}/bin
    COMMAND ${CMAKE_COMMAND} -E copy ${CLI_OUTPUT} ${CMAKE_BINARY_DIR}/bin/moonbit-tsc
    COMMENT "Copying CLI to bin directory..."
)

# ============================================================================
# Installation
# ============================================================================
install(PROGRAMS ${CMAKE_BINARY_DIR}/bin/moonbit-tsc
    DESTINATION bin
)

# ============================================================================
# Testing
# ============================================================================
if(BUILD_TESTS)
    enable_testing()

    add_test(NAME version_test
        COMMAND ${CMAKE_BINARY_DIR}/bin/moonbit-tsc --version
    )

    add_test(NAME help_test
        COMMAND ${CMAKE_BINARY_DIR}/bin/moonbit-tsc --help
    )

    # Test single file compilation
    add_test(NAME compile_test
        COMMAND ${CMAKE_COMMAND} -E env
            sh -c "echo 'const x: number = 1;' > /tmp/cmake_test.ts && ${CMAKE_BINARY_DIR}/bin/moonbit-tsc /tmp/cmake_test.ts && cat /tmp/cmake_test.js"
    )
endif()

# ============================================================================
# Package configuration
# ============================================================================
include(CPack)
set(CPACK_PACKAGE_NAME "moonbit-tsc")
set(CPACK_PACKAGE_VERSION ${PROJECT_VERSION})
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "High-performance TypeScript compiler written in pure MoonBit")

if(APPLE)
    set(CPACK_GENERATOR "DragNDrop;TGZ")
elseif(UNIX)
    set(CPACK_GENERATOR "TGZ;DEB;RPM")
elseif(WIN32)
    set(CPACK_GENERATOR "ZIP;NSIS")
endif()
