cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "ruby_runtime")
project(${PROJECT_NAME} LANGUAGES CXX)
cmake_policy(VERSION 3.14...3.25)
set(PLUGIN_NAME "ruby_runtime_plugin")

add_library(${PLUGIN_NAME} SHARED
  "include/ruby_runtime/ruby_runtime_plugin_c_api.h"
  "ruby_runtime_plugin_c_api.cpp"
  "ruby_runtime_plugin.cpp"
  "ruby_runtime_plugin.h")
apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)

set(RUFLET_VM_LIBRARY "${CMAKE_CURRENT_SOURCE_DIR}/bin/ruflet_vm.dll")
if(NOT EXISTS "${RUFLET_VM_LIBRARY}")
  message(FATAL_ERROR "Missing packaged Ruflet VM: ${RUFLET_VM_LIBRARY}")
endif()
set(ruby_runtime_bundled_libraries "${RUFLET_VM_LIBRARY}" PARENT_SCOPE)
