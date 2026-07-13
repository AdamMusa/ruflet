cmake_minimum_required(VERSION 3.22.1)
project(ruby_runtime LANGUAGES C CXX)

set(CMAKE_C_STANDARD 99)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(MRUBY_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../third_party/mruby")
set(MRUBY_BUILD_ROOT "${MRUBY_ROOT}/build/host")
set(ONIG_REGEXP_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../third_party/mruby-onig-regexp")

file(GLOB MRUBY_CORE_SOURCES "${MRUBY_ROOT}/src/*.c")
set(MRUBY_GEM_SOURCES
  "${MRUBY_ROOT}/mrbgems/mruby-error/src/exception.c"
  "${MRUBY_ROOT}/mrbgems/mruby-bigint/core/bigint.c"
  "${MRUBY_ROOT}/mrbgems/mruby-errno/src/errno.c"
  "${MRUBY_ROOT}/mrbgems/mruby-io/src/io.c"
  "${MRUBY_ROOT}/mrbgems/mruby-io/src/file.c"
  "${MRUBY_ROOT}/mrbgems/mruby-io/src/file_test.c"
  "${MRUBY_ROOT}/mrbgems/mruby-io/src/mruby_io_gem.c"
  "${MRUBY_ROOT}/mrbgems/mruby-socket/src/socket.c"
  "${MRUBY_ROOT}/mrbgems/mruby-sprintf/src/sprintf.c"
  "${MRUBY_ROOT}/mrbgems/mruby-fiber/src/fiber.c"
  "${MRUBY_ROOT}/mrbgems/mruby-numeric-ext/src/numeric_ext.c"
  "${MRUBY_ROOT}/mrbgems/mruby-metaprog/src/metaprog.c"
  "${MRUBY_ROOT}/mrbgems/mruby-pack/src/pack.c"
  "${MRUBY_ROOT}/mrbgems/mruby-compiler/core/codegen.c"
  "${MRUBY_ROOT}/mrbgems/mruby-compiler/core/y.tab.c"
  "${MRUBY_ROOT}/mrbgems/hal-posix-io/src/io_hal.c"
  "${MRUBY_ROOT}/mrbgems/hal-posix-socket/src/socket_hal.c"
)
set(MRUBY_GENERATED_SOURCES
  "${MRUBY_BUILD_ROOT}/mrblib/mrblib.c"
  "${MRUBY_BUILD_ROOT}/mrbgems/mruby-errno/gem_init.c"
  "${MRUBY_BUILD_ROOT}/mrbgems/mruby-io/gem_init.c"
  "${MRUBY_BUILD_ROOT}/mrbgems/mruby-socket/gem_init.c"
  "${MRUBY_BUILD_ROOT}/mrbgems/mruby-fiber/gem_init.c"
  "${MRUBY_BUILD_ROOT}/mrbgems/mruby-enumerator/gem_init.c"
  "${MRUBY_BUILD_ROOT}/mrbgems/mruby-enum-ext/gem_init.c"
  "${MRUBY_BUILD_ROOT}/mrbgems/mruby-enum-lazy/gem_init.c"
  "${MRUBY_BUILD_ROOT}/mrbgems/mruby-enum-chain/gem_init.c"
  "${MRUBY_BUILD_ROOT}/mrbgems/mruby-numeric-ext/gem_init.c"
  "${MRUBY_ROOT}/build/host_vm/mrbgems/mruby-onig-regexp/gem_init.c"
  "${MRUBY_ROOT}/build/host_vm/mrbgems/ruflet-framework/gem_init.c"
)

file(GLOB ONIGMO_SOURCES
  "${ONIG_REGEXP_ROOT}/onigmo/*.c"
  "${ONIG_REGEXP_ROOT}/onigmo/enc/*.c"
)
list(REMOVE_ITEM ONIGMO_SOURCES "${ONIG_REGEXP_ROOT}/onigmo/enc/mktable.c")

add_library(
  ruby_runtime
  SHARED
  ruby_runtime_jni.cpp
  ../../../../shared/mruby_gems_init.c
  ../../../../shared/mruby_digest_gem.c
  "${ONIG_REGEXP_ROOT}/mruby_onig_regexp.c"
  ${ONIGMO_SOURCES}
  ${MRUBY_CORE_SOURCES}
  ${MRUBY_GEM_SOURCES}
  ${MRUBY_GENERATED_SOURCES}
)

target_include_directories(
  ruby_runtime
  PRIVATE
  "${MRUBY_BUILD_ROOT}/include"
  "${MRUBY_ROOT}/include"
  "${MRUBY_ROOT}/src"
  "${MRUBY_ROOT}/mrbgems/mruby-io/include"
  "${MRUBY_ROOT}/mrbgems/mruby-socket/include"
  "${ONIG_REGEXP_ROOT}/onigmo"
  "${ONIG_REGEXP_ROOT}/onigmo/enc/unicode"
  "${ONIG_REGEXP_ROOT}/onigmo/enc/jis"
)

target_compile_definitions(
  ruby_runtime
  PRIVATE
  HAVE_ONIGMO_H=1
  MRB_USE_BIGINT=1
)

target_link_libraries(
  ruby_runtime
  m
  log
)
