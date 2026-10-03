cmake_minimum_required(VERSION 3.20)

project(grip_contact LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

get_filename_component(GRIP_PROJECT_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../.." ABSOLUTE)
set(GODOT_CPP_SOURCE_DIR "C:/WORKSPACE/helper applications/cpp-dependencies/godot-cpp"
    CACHE PATH "Pinned godot-cpp source directory")
set(GODOT_EXTENSION_API_FILE "${GRIP_PROJECT_ROOT}/extension_api.json"
    CACHE FILEPATH "Exact Godot extension API JSON used by this project")
option(GRIP_USE_PREBUILT_GODOT_CPP "Use the validated workspace godot-cpp bindings without running Python" ON)
set(GRIP_GODOT_CPP_PREBUILT_DIR "C:/WORKSPACE/helper applications/cpp-build/forge-v2-manifold"
    CACHE PATH "Existing build containing only the reusable godot-cpp archive and generated headers")

set(GODOT_CPP_EXPECTED_COMMIT "d7b6162249ed52796a8301d216c24ee71d68c2bf")
set(GODOT_API_EXPECTED_SHA256 "53d37f85be32b6d10fb2266ca51f6ef0c3a55728acdb7c8301b1458a93c00943")
set(GODOT_CPP_ARCHIVE_EXPECTED_SHA256 "69e2053f5c92c9703b2583bc900098a7bbc875b34b3bd3e83bc2321435305909")
set(GODOT_CPP_GENERATED_HEADERS_EXPECTED_SHA256 "d9349925517622eec7aca54fd3a9e89674ea34f821c5b78d6b120049c116355b")
set(GODOT_CPP_SOURCE_HEADERS_EXPECTED_SHA256 "322ce6c107258608c1d61affbb8f03bd6729a57ab8d880903493f1e1b3f8061b")

if(NOT CMAKE_SYSTEM_NAME STREQUAL "Windows" OR NOT CMAKE_SIZEOF_VOID_P EQUAL 8)
    message(FATAL_ERROR "This measured grip-contact build currently supports Windows x86_64 only.")
endif()
if(NOT CMAKE_BUILD_TYPE STREQUAL "Release")
    message(FATAL_ERROR "Configure with -DCMAKE_BUILD_TYPE=Release for the optimized grip-contact proof.")
endif()

foreach(required_path IN ITEMS GODOT_CPP_SOURCE_DIR GODOT_EXTENSION_API_FILE)
    if(NOT EXISTS "${${required_path}}")
        message(FATAL_ERROR "${required_path} does not exist: ${${required_path}}")
    endif()
endforeach()

execute_process(
    COMMAND git -C "${GODOT_CPP_SOURCE_DIR}" rev-parse HEAD
    OUTPUT_VARIABLE actual_godot_cpp_revision
    OUTPUT_STRIP_TRAILING_WHITESPACE
    RESULT_VARIABLE revision_result
)
if(NOT revision_result EQUAL 0 OR NOT actual_godot_cpp_revision STREQUAL GODOT_CPP_EXPECTED_COMMIT)
    message(FATAL_ERROR "godot-cpp revision mismatch: expected ${GODOT_CPP_EXPECTED_COMMIT}, got ${actual_godot_cpp_revision}")
endif()

function(require_file_sha256 path expected_sha256 label)
    if(NOT EXISTS "${path}")
        message(FATAL_ERROR "Missing ${label}: ${path}")
    endif()
    file(SHA256 "${path}" actual_sha256)
    if(NOT actual_sha256 STREQUAL expected_sha256)
        message(FATAL_ERROR "${label} SHA256 mismatch: expected ${expected_sha256}, got ${actual_sha256}")
    endif()
endfunction()

function(require_header_tree_sha256 root expected_sha256 label)
    if(NOT IS_DIRECTORY "${root}")
        message(FATAL_ERROR "Missing ${label}: ${root}")
    endif()
    file(GLOB_RECURSE relative_paths LIST_DIRECTORIES false RELATIVE "${root}" "${root}/*")
    list(SORT relative_paths)
    set(manifest "")
    foreach(relative_path IN LISTS relative_paths)
        file(SHA256 "${root}/${relative_path}" file_sha256)
        string(APPEND manifest "${relative_path}\t${file_sha256}\n")
    endforeach()
    string(SHA256 actual_sha256 "${manifest}")
    if(NOT actual_sha256 STREQUAL expected_sha256)
        message(FATAL_ERROR "${label} SHA256 mismatch: expected ${expected_sha256}, got ${actual_sha256}")
    endif()
endfunction()

require_file_sha256("${GODOT_EXTENSION_API_FILE}" "${GODOT_API_EXPECTED_SHA256}" "Godot extension API")

if(GRIP_USE_PREBUILT_GODOT_CPP)
    # This imports the generic Godot C++ bindings, not the Forge extension or
    # Manifold. Nothing in the existing build is changed or regenerated.
    if(NOT CMAKE_CXX_COMPILER_ID STREQUAL "Clang" OR NOT CMAKE_CXX_COMPILER_VERSION VERSION_EQUAL "22.1.8")
        message(FATAL_ERROR "Pinned bindings require the workspace LLVM-MinGW Clang 22.1.8 toolchain.")
    endif()
    set(bindings_cache "${GRIP_GODOT_CPP_PREBUILT_DIR}/CMakeCache.txt")
    set(bindings_archive "${GRIP_GODOT_CPP_PREBUILT_DIR}/bin/libgodot-cpp.windows.template_debug.x86_64.a")
    set(bindings_generated_headers "${GRIP_GODOT_CPP_PREBUILT_DIR}/godot-cpp/gen/include")
    if(NOT EXISTS "${bindings_cache}")
        message(FATAL_ERROR "Missing pinned bindings build provenance: ${bindings_cache}")
    endif()
    file(STRINGS "${bindings_cache}" bindings_cache_lines)
    foreach(expected_cache_entry IN ITEMS
        "CMAKE_BUILD_TYPE:STRING=Release"
        "GODOTCPP_TARGET:STRING=template_debug"
        "GODOTCPP_PRECISION:STRING=single"
        "GODOTCPP_DEV_BUILD:BOOL=OFF"
        "GODOTCPP_THREADS:BOOL=ON"
        "GODOTCPP_DEPRECATED:BOOL=ON"
        "GODOTCPP_USE_STATIC_CPP:BOOL=OFF"
        "GODOTCPP_CUSTOM_API_FILE:FILEPATH=${GODOT_EXTENSION_API_FILE}"
        "GODOT_CPP_SOURCE_DIR:PATH=${GODOT_CPP_SOURCE_DIR}"
    )
        list(FIND bindings_cache_lines "${expected_cache_entry}" cache_entry_index)
        if(cache_entry_index EQUAL -1)
            message(FATAL_ERROR "Pinned bindings cache mismatch; required entry: ${expected_cache_entry}")
        endif()
    endforeach()
    require_file_sha256("${bindings_archive}" "${GODOT_CPP_ARCHIVE_EXPECTED_SHA256}" "godot-cpp archive")
    require_header_tree_sha256("${bindings_generated_headers}" "${GODOT_CPP_GENERATED_HEADERS_EXPECTED_SHA256}" "Generated Godot headers")
    require_header_tree_sha256("${GODOT_CPP_SOURCE_DIR}/include" "${GODOT_CPP_SOURCE_HEADERS_EXPECTED_SHA256}" "Godot source headers")

    add_library(grip_godot_cpp STATIC IMPORTED)
    set_target_properties(grip_godot_cpp PROPERTIES
        IMPORTED_LOCATION "${bindings_archive}"
        INTERFACE_INCLUDE_DIRECTORIES "${bindings_generated_headers};${GODOT_CPP_SOURCE_DIR}/include"
        INTERFACE_COMPILE_DEFINITIONS "DEBUG_ENABLED;GDEXTENSION;THREADS_ENABLED;WINDOWS_ENABLED"
    )
    add_library(godot::cpp ALIAS grip_godot_cpp)
else()
    # Rebuilding bindings executes Python. Require the caller to deliberately
    # choose an already-authorized interpreter instead of discovering one.
    if(NOT DEFINED Python3_EXECUTABLE OR NOT EXISTS "${Python3_EXECUTABLE}")
        message(FATAL_ERROR "A full bindings rebuild requires an explicitly authorized -DPython3_EXECUTABLE=<path>.")
    endif()
    set(GODOTCPP_CUSTOM_API_FILE "${GODOT_EXTENSION_API_FILE}" CACHE FILEPATH "" FORCE)
    set(GODOTCPP_TARGET template_debug CACHE STRING "" FORCE)
    set(GODOTCPP_PRECISION single CACHE STRING "" FORCE)
    set(GODOTCPP_DEV_BUILD OFF CACHE BOOL "" FORCE)
    set(GODOTCPP_USE_STATIC_CPP OFF CACHE BOOL "" FORCE)
    set(GODOTCPP_ENABLE_TESTING OFF CACHE BOOL "" FORCE)
    add_subdirectory("${GODOT_CPP_SOURCE_DIR}" "${CMAKE_BINARY_DIR}/godot-cpp" EXCLUDE_FROM_ALL)

    # The pinned godot-cpp Windows build assumes Clang uses libstdc++; the
    # workspace LLVM-MinGW toolchain supplies libc++ instead. Keep vendor
    # sources untouched, as in the existing Forge native build.
    foreach(link_property IN ITEMS LINK_OPTIONS INTERFACE_LINK_OPTIONS)
        get_target_property(godot_cpp_link_options godot-cpp "${link_property}")
        if(godot_cpp_link_options AND NOT godot_cpp_link_options MATCHES "-NOTFOUND$")
            list(FILTER godot_cpp_link_options EXCLUDE REGEX "stdc\\+\\+")
            set_property(TARGET godot-cpp PROPERTY "${link_property}" "${godot_cpp_link_options}")
        endif()
    endforeach()
endif()

add_library(grip_contact SHARED
    src/grip_contact_kernel.cpp
    src/grip_saved_contact_kernel.cpp
    src/grip_ordered_target.cpp
    src/grip_contact_kernel.h
    src/grip_slice_kernel.cpp
    src/grip_slice_kernel.h
    src/grip_topology_kernel.cpp
    src/grip_topology_kernel.h
    src/register_types.cpp
    src/register_types.h
)
target_link_libraries(grip_contact PRIVATE godot::cpp)
target_compile_definitions(grip_contact PRIVATE NOMINMAX)
if(CMAKE_CXX_COMPILER_ID MATCHES "Clang|GNU")
    target_compile_options(grip_contact PRIVATE -Wall -Wextra -Wpedantic -fno-fast-math -ffp-contract=off)
    target_link_options(grip_contact PRIVATE -static -Wl,--no-undefined)
elseif(MSVC)
    target_compile_options(grip_contact PRIVATE /W4 /fp:strict)
endif()
set_target_properties(grip_contact PROPERTIES
    PREFIX ""
    CXX_VISIBILITY_PRESET hidden
    OUTPUT_NAME "grip_contact.windows.template_debug.x86_64"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/bin"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/bin"
)
