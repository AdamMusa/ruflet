cmake_minimum_required(VERSION 3.10)

set(PROJECT_NAME "ruby_runtime")
project(${PROJECT_NAME} LANGUAGES CXX)
set(PLUGIN_NAME "ruby_runtime_plugin")

add_library(${PLUGIN_NAME} SHARED "ruby_runtime_plugin.cc")
apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter PkgConfig::GTK)

if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(aarch64|arm64)$")
  set(RUFLET_VM_ARCH "aarch64")
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|amd64|AMD64)$")
  set(RUFLET_VM_ARCH "x64")
else()
  message(FATAL_ERROR "ruby_runtime has no packaged Linux VM for ${CMAKE_SYSTEM_PROCESSOR}")
endif()

set(RUFLET_VM_LIBRARY
  "${CMAKE_CURRENT_SOURCE_DIR}/lib/${RUFLET_VM_ARCH}/libruflet_vm.so")
if(NOT EXISTS "${RUFLET_VM_LIBRARY}")
  message(FATAL_ERROR "Missing packaged Ruflet VM: ${RUFLET_VM_LIBRARY}")
endif()
target_link_libraries(${PLUGIN_NAME} PRIVATE "${RUFLET_VM_LIBRARY}")
set(ruby_runtime_bundled_libraries "${RUFLET_VM_LIBRARY}" PARENT_SCOPE)
