cmake_minimum_required(VERSION 3.20)

project(forge_v2_manifold LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

get_filename_component(FORGE_PROJECT_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../.." ABSOLUTE)

set(
    GODOT_CPP_SOURCE_DIR
    "C:/WORKSPACE/helper applications/cpp-dependencies/godot-cpp"
    CACHE PATH
    "Pinned godot-cpp source directory"
)
set(
    MANIFOLD_SOURCE_DIR
    "C:/WORKSPACE/helper applications/cpp-dependencies/manifold"
    CACHE PATH
    "Pinned Manifold source directory"
)
set(
    GODOT_EXTENSION_API_FILE
    "${FORGE_PROJECT_ROOT}/extension_api.json"
    CACHE FILEPATH
    "Exact Godot extension API JSON used by this project"
)

set(GODOT_CPP_EXPECTED_COMMIT "d7b6162249ed52796a8301d216c24ee71d68c2bf")
set(MANIFOLD_EXPECTED_COMMIT "798d83c8d7fabcddd23c1617097b95ba40f2597c")
set(GODOT_API_EXPECTED_SHA256 "53d37f85be32b6d10fb2266ca51f6ef0c3a55728acdb7c8301b1458a93c00943")

foreach(required_path IN ITEMS GODOT_CPP_SOURCE_DIR MANIFOLD_SOURCE_DIR GODOT_EXTENSION_API_FILE)
    if(NOT EXISTS "${${required_path}}")
        message(FATAL_ERROR "${required_path} does not exist: ${${required_path}}")
    endif()
endforeach()

function(require_git_revision source_dir expected_revision dependency_name)
    execute_process(
        COMMAND git -C "${source_dir}" rev-parse HEAD
        OUTPUT_VARIABLE actual_revision
        OUTPUT_STRIP_TRAILING_WHITESPACE
        RESULT_VARIABLE revision_result
    )
    if(NOT revision_result EQUAL 0 OR NOT actual_revision STREQUAL expected_revision)
        message(FATAL_ERROR
            "${dependency_name} revision mismatch: expected ${expected_revision}, got ${actual_revision}"
        )
    endif()
endfunction()

require_git_revision("${GODOT_CPP_SOURCE_DIR}" "${GODOT_CPP_EXPECTED_COMMIT}" "godot-cpp")
require_git_revision("${MANIFOLD_SOURCE_DIR}" "${MANIFOLD_EXPECTED_COMMIT}" "Manifold")
file(SHA256 "${GODOT_EXTENSION_API_FILE}" actual_godot_api_sha256)
if(NOT actual_godot_api_sha256 STREQUAL GODOT_API_EXPECTED_SHA256)
    message(FATAL_ERROR
        "Godot extension API SHA256 mismatch: expected ${GODOT_API_EXPECTED_SHA256}, got ${actual_godot_api_sha256}"
    )
endif()

set(GODOTCPP_CUSTOM_API_FILE "${GODOT_EXTENSION_API_FILE}" CACHE FILEPATH "" FORCE)
set(GODOTCPP_TARGET template_debug CACHE STRING "" FORCE)
set(GODOTCPP_USE_STATIC_CPP OFF CACHE BOOL "" FORCE)
set(GODOTCPP_ENABLE_TESTING OFF CACHE BOOL "" FORCE)
add_subdirectory("${GODOT_CPP_SOURCE_DIR}" "${CMAKE_BINARY_DIR}/godot-cpp" EXCLUDE_FROM_ALL)

# godot-cpp currently assumes Clang on Windows uses libstdc++. LLVM-MinGW ships
# libc++ and its clang++ driver selects it automatically. Remove only that
# incompatible propagated flag; keep the pinned vendor checkout untouched.
foreach(link_property IN ITEMS LINK_OPTIONS INTERFACE_LINK_OPTIONS)
    get_target_property(godot_cpp_link_options godot-cpp "${link_property}")
    if(godot_cpp_link_options AND NOT godot_cpp_link_options MATCHES "-NOTFOUND$")
        list(FILTER godot_cpp_link_options EXCLUDE REGEX "stdc\\+\\+")
        set_property(TARGET godot-cpp PROPERTY "${link_property}" "${godot_cpp_link_options}")
    endif()
endforeach()

set(MANIFOLD_PAR OFF CACHE BOOL "" FORCE)
set(MANIFOLD_CROSS_SECTION OFF CACHE BOOL "" FORCE)
set(MANIFOLD_TEST OFF CACHE BOOL "" FORCE)
set(MANIFOLD_PYBIND OFF CACHE BOOL "" FORCE)
set(MANIFOLD_CBIND OFF CACHE BOOL "" FORCE)
set(MANIFOLD_EXPORT OFF CACHE BOOL "" FORCE)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
add_subdirectory("${MANIFOLD_SOURCE_DIR}" "${CMAKE_BINARY_DIR}/manifold" EXCLUDE_FROM_ALL)

add_library(
    forge_v2_manifold
    SHARED
    src/forge_v2_manifold_boolean.cpp
    src/forge_v2_manifold_boolean.h
    src/register_types.cpp
)

target_link_libraries(forge_v2_manifold PRIVATE godot::cpp manifold)
target_compile_definitions(forge_v2_manifold PRIVATE NOMINMAX)

if(CMAKE_CXX_COMPILER_ID MATCHES "Clang|GNU")
    target_compile_options(forge_v2_manifold PRIVATE -Wall -Wextra -Wpedantic)
    target_link_options(forge_v2_manifold PRIVATE -static -Wl,--no-undefined)
endif()

set_target_properties(
    forge_v2_manifold
    PROPERTIES
        PREFIX ""
        OUTPUT_NAME "forge_v2_manifold.windows.template_debug.x86_64"
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/bin"
        LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/bin"
)
