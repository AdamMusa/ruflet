# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause the
# plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

# Project-level configuration.
set(PROJECT_NAME "ruby_runtime")
project(${PROJECT_NAME} LANGUAGES C CXX)

# This value is used when generating builds using this plugin, so it must
# not be changed.
set(PLUGIN_NAME "ruby_runtime_plugin")

# Vendored mruby sources are shared with the iOS/Android plugins (Android also
# reuses ios/mruby_src). Build them into a static library kept separate from the
# plugin so upstream mruby warnings never fail the build under -Werror.
set(MRUBY_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../ios/mruby_src")
set(MRUBY_BUILD_ROOT "${MRUBY_ROOT}/build_host")
set(SHARED_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../shared")

file(GLOB MRUBY_CORE_SOURCES "${MRUBY_ROOT}/src/*.c")
set(MRUBY_COMPILER_SOURCES
  "${MRUBY_ROOT}/mrbgems/mruby-compiler/core/codegen.c"
  "${MRUBY_ROOT}/mrbgems/mruby-compiler/core/y.tab.c"
)
set(MRUBY_GEM_SOURCES
  "${MRUBY_ROOT}/mrbgems/mruby-error/src/exception.c"
  "${MRUBY_ROOT}/mrbgems/mruby-errno/src/errno.c"
  "${MRUBY_ROOT}/mrbgems/mruby-io/src/io.c"
  "${MRUBY_ROOT}/mrbgems/mruby-io/src/file.c"
  "${MRUBY_ROOT}/mrbgems/mruby-io/src/file_test.c"
  "${MRUBY_ROOT}/mrbgems/mruby-io/src/mruby_io_gem.c"
  "${MRUBY_ROOT}/mrbgems/mruby-socket/src/socket.c"
  "${MRUBY_ROOT}/mrbgems/mruby-sprintf/src/sprintf.c"
  "${MRUBY_ROOT}/mrbgems/mruby-pack/src/pack.c"
  "${MRUBY_ROOT}/mrbgems/mruby-metaprog/src/metaprog.c"
  "${MRUBY_ROOT}/mrbgems/hal-posix-io/src/io_hal.c"
  "${MRUBY_ROOT}/mrbgems/hal-posix-socket/src/socket_hal.c"
  "${MRUBY_ROOT}/mrbgems/hal-posix-dir/src/dir_hal.c"
  "${MRUBY_ROOT}/mrbgems/mruby-fiber/src/fiber.c"
  "${MRUBY_ROOT}/mrbgems/mruby-time/src/time.c"
  "${MRUBY_ROOT}/mrbgems/mruby-math/src/math.c"
  "${MRUBY_ROOT}/mrbgems/mruby-random/src/random.c"
  "${MRUBY_ROOT}/mrbgems/mruby-binding/src/binding.c"
  "${MRUBY_ROOT}/mrbgems/mruby-eval/src/eval.c"
  "${MRUBY_ROOT}/mrbgems/mruby-data/src/data.c"
  "${MRUBY_ROOT}/mrbgems/mruby-kernel-ext/src/kernel.c"
  "${MRUBY_ROOT}/mrbgems/mruby-class-ext/src/class.c"
  "${MRUBY_ROOT}/mrbgems/mruby-array-ext/src/array.c"
  "${MRUBY_ROOT}/mrbgems/mruby-string-ext/src/string.c"
  "${MRUBY_ROOT}/mrbgems/mruby-hash-ext/src/hash_ext.c"
  "${MRUBY_ROOT}/mrbgems/mruby-numeric-ext/src/numeric_ext.c"
  "${MRUBY_ROOT}/mrbgems/mruby-object-ext/src/object.c"
  "${MRUBY_ROOT}/mrbgems/mruby-range-ext/src/range.c"
  "${MRUBY_ROOT}/mrbgems/mruby-symbol-ext/src/symbol.c"
  "${MRUBY_ROOT}/mrbgems/mruby-proc-ext/src/proc.c"
  "${MRUBY_ROOT}/mrbgems/mruby-struct/src/struct.c"
  "${MRUBY_ROOT}/mrbgems/mruby-set/src/set.c"
  "${MRUBY_ROOT}/mrbgems/mruby-catch/src/catch.c"
  "${MRUBY_ROOT}/mrbgems/mruby-method/src/method.c"
  "${MRUBY_ROOT}/mrbgems/mruby-dir/src/dir.c"
)
set(MRUBY_GENERATED_SOURCES
  "${MRUBY_BUILD_ROOT}/mrblib/mrblib.c"
  "${MRUBY_BUILD_ROOT}/mrbgems/mruby-errno/gem_init.c"
  "${MRUBY_BUILD_ROOT}/mrbgems/mruby-io/gem_init.c"
  "${MRUBY_BUILD_ROOT}/mrbgems/mruby-socket/gem_init.c"
  "${MRUBY_BUILD_ROOT}/mrbgems/mruby-compar-ext/gem_init.c"
  "${MRUBY_BUILD_ROOT}/mrbgems/mruby-enum-ext/gem_init.c"
  "${MRUBY_BUILD_ROOT}/mrbgems/mruby-array-ext/gem_init.c"
  "${MRUBY_BUILD_ROOT}/mrbgems/mruby-string-ext/gem_init.c"
  "${MRUBY_BUILD_ROOT}/mrbgems/mruby-hash-ext/gem_init.c"
  "${MRUBY_BUILD_ROOT}/mrbgems/mruby-numeric-ext/gem_init.c"
  "${MRUBY_BUILD_ROOT}/mrbgems/mruby-object-ext/gem_init.c"
  "${MRUBY_BUILD_ROOT}/mrbgems/mruby-range-ext/gem_init.c"
  "${MRUBY_BUILD_ROOT}/mrbgems/mruby-symbol-ext/gem_init.c"
  "${MRUBY_BUILD_ROOT}/mrbgems/mruby-proc-ext/gem_init.c"
  "${MRUBY_BUILD_ROOT}/mrbgems/mruby-toplevel-ext/gem_init.c"
  "${MRUBY_BUILD_ROOT}/mrbgems/mruby-enumerator/gem_init.c"
  "${MRUBY_BUILD_ROOT}/mrbgems/mruby-enum-chain/gem_init.c"
  "${MRUBY_BUILD_ROOT}/mrbgems/mruby-enum-lazy/gem_init.c"
  "${MRUBY_BUILD_ROOT}/mrbgems/mruby-struct/gem_init.c"
  "${MRUBY_BUILD_ROOT}/mrbgems/mruby-set/gem_init.c"
  "${MRUBY_BUILD_ROOT}/mrbgems/mruby-catch/gem_init.c"
  "${MRUBY_BUILD_ROOT}/mrbgems/mruby-method/gem_init.c"
  "${MRUBY_BUILD_ROOT}/mrbgems/mruby-dir/gem_init.c"
)

add_library(ruby_runtime_mruby STATIC
  ${MRUBY_CORE_SOURCES}
  ${MRUBY_COMPILER_SOURCES}
  ${MRUBY_GEM_SOURCES}
  ${MRUBY_GENERATED_SOURCES}
  "${SHARED_ROOT}/mruby_gems_init.c"
  "${SHARED_ROOT}/mruby_digest_gem.c"
)

set_property(TARGET ruby_runtime_mruby PROPERTY POSITION_INDEPENDENT_CODE ON)
target_compile_definitions(ruby_runtime_mruby PUBLIC MRB_NO_PRESYM=1)
# Vendored upstream C; do not let its warnings break the host app's -Werror.
target_compile_options(ruby_runtime_mruby PRIVATE -w)
target_include_directories(ruby_runtime_mruby PUBLIC
  "${MRUBY_BUILD_ROOT}/include"
  "${MRUBY_ROOT}/include"
  "${MRUBY_ROOT}/src"
  "${MRUBY_ROOT}/mrbgems/mruby-compiler/core"
  "${MRUBY_ROOT}/mrbgems/mruby-io/include"
  "${MRUBY_ROOT}/mrbgems/mruby-socket/include"
  "${MRUBY_ROOT}/mrbgems/mruby-time/include"
  "${MRUBY_ROOT}/mrbgems/mruby-dir/include"
)

add_library(${PLUGIN_NAME} SHARED
  "ruby_runtime_linux_plugin.cc"
)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_include_directories(${PLUGIN_NAME} PRIVATE
  "${SHARED_ROOT}")

target_link_libraries(${PLUGIN_NAME} PRIVATE flutter)
target_link_libraries(${PLUGIN_NAME} PRIVATE PkgConfig::GTK)
target_link_libraries(${PLUGIN_NAME} PRIVATE ruby_runtime_mruby)
target_link_libraries(${PLUGIN_NAME} PRIVATE m)

find_package(Threads REQUIRED)
target_link_libraries(${PLUGIN_NAME} PRIVATE Threads::Threads)

# List of absolute paths to libraries that should be bundled with the plugin.
# mruby is statically linked into the plugin, so there is nothing extra to ship.
set(ruby_runtime_bundled_libraries "" PARENT_SCOPE)
