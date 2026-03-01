cmake_minimum_required(VERSION 3.22.1)
project(ruby_runtime LANGUAGES C CXX)

set(CMAKE_C_STANDARD 99)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(MRUBY_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../third_party/mruby")
set(MRUBY_BUILD_ROOT "${MRUBY_ROOT}/build/host")

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
  "${MRUBY_ROOT}/mrbgems/hal-posix-io/src/io_hal.c"
  "${MRUBY_ROOT}/mrbgems/hal-posix-socket/src/socket_hal.c"
)
set(MRUBY_GENERATED_SOURCES
  "${MRUBY_BUILD_ROOT}/mrblib/mrblib.c"
  "${MRUBY_BUILD_ROOT}/mrbgems/mruby-errno/gem_init.c"
  "${MRUBY_BUILD_ROOT}/mrbgems/mruby-io/gem_init.c"
  "${MRUBY_BUILD_ROOT}/mrbgems/mruby-socket/gem_init.c"
)

add_library(
  ruby_runtime
  SHARED
  ruby_runtime_jni.cpp
  ../../../../shared/mruby_gems_init.c
  ${MRUBY_CORE_SOURCES}
  ${MRUBY_COMPILER_SOURCES}
  ${MRUBY_GEM_SOURCES}
  ${MRUBY_GENERATED_SOURCES}
)

target_include_directories(
  ruby_runtime
  PRIVATE
  "${MRUBY_ROOT}/include"
  "${MRUBY_ROOT}/src"
  "${MRUBY_ROOT}/mrbgems/mruby-compiler/core"
  "${MRUBY_ROOT}/mrbgems/mruby-io/include"
  "${MRUBY_ROOT}/mrbgems/mruby-socket/include"
)

target_compile_definitions(
  ruby_runtime
  PRIVATE
  MRB_NO_PRESYM=1
)

target_link_libraries(
  ruby_runtime
  m
  log
)
