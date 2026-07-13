cmake_minimum_required(VERSION 3.22.1)
project(ruby_runtime LANGUAGES C CXX)

set(CMAKE_C_STANDARD 99)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(MRUBY_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../third_party/mruby")
set(MRUBY_BUILD_ROOT "${MRUBY_ROOT}/build/host_vm")
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
  "${MRUBY_ROOT}/mrbgems/mruby-binding/src/binding.c"
  "${MRUBY_ROOT}/mrbgems/mruby-proc-binding/src/proc_binding.c"
  "${MRUBY_ROOT}/mrbgems/mruby-eval/src/eval.c"
  "${MRUBY_ROOT}/mrbgems/mruby-numeric-ext/src/numeric_ext.c"
  "${MRUBY_ROOT}/mrbgems/mruby-metaprog/src/metaprog.c"
  "${MRUBY_ROOT}/mrbgems/mruby-pack/src/pack.c"
  "${MRUBY_ROOT}/mrbgems/mruby-compiler/core/codegen.c"
  "${MRUBY_ROOT}/mrbgems/mruby-compiler/core/y.tab.c"
  "${MRUBY_ROOT}/mrbgems/hal-posix-io/src/io_hal.c"
  "${MRUBY_ROOT}/mrbgems/hal-posix-socket/src/socket_hal.c"
)
file(GLOB MRUBY_ADDITIONAL_GEM_SOURCES
  "${MRUBY_ROOT}/mrbgems/mruby-*-ext/src/*.c"
  "${MRUBY_ROOT}/mrbgems/mruby-method/src/*.c"
  "${MRUBY_ROOT}/mrbgems/mruby-data/src/*.c"
  "${MRUBY_ROOT}/mrbgems/mruby-struct/src/*.c"
  "${MRUBY_ROOT}/mrbgems/mruby-set/src/*.c"
  "${MRUBY_ROOT}/mrbgems/mruby-enumerator/src/*.c"
  "${MRUBY_ROOT}/mrbgems/mruby-math/src/*.c"
  "${MRUBY_ROOT}/mrbgems/mruby-random/src/*.c"
  "${MRUBY_ROOT}/mrbgems/mruby-time/src/*.c"
  "${MRUBY_ROOT}/mrbgems/mruby-catch/src/*.c"
  "${MRUBY_ROOT}/mrbgems/mruby-encoding/src/*.c"
  "${MRUBY_ROOT}/mrbgems/mruby-dir/src/*.c"
  "${MRUBY_ROOT}/mrbgems/hal-posix-dir/src/*.c"
)
list(APPEND MRUBY_GEM_SOURCES ${MRUBY_ADDITIONAL_GEM_SOURCES})
list(REMOVE_DUPLICATES MRUBY_GEM_SOURCES)
file(GLOB MRUBY_GEM_INIT_SOURCES "${MRUBY_BUILD_ROOT}/mrbgems/*/gem_init.c")
list(REMOVE_ITEM MRUBY_GEM_INIT_SOURCES
  "${MRUBY_BUILD_ROOT}/mrbgems/mruby-complex/gem_init.c"
  "${MRUBY_BUILD_ROOT}/mrbgems/mruby-rational/gem_init.c"
  "${MRUBY_BUILD_ROOT}/mrbgems/mruby-objectspace/gem_init.c"
)
set(MRUBY_GENERATED_SOURCES
  "${MRUBY_BUILD_ROOT}/mrblib/mrblib.c"
  ${MRUBY_GEM_INIT_SOURCES}
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
  "${MRUBY_ROOT}/mrbgems/mruby-dir/include"
  "${MRUBY_ROOT}/mrbgems/mruby-time/include"
  "${ONIG_REGEXP_ROOT}/onigmo"
  "${ONIG_REGEXP_ROOT}/onigmo/enc/unicode"
  "${ONIG_REGEXP_ROOT}/onigmo/enc/jis"
)

target_compile_definitions(
  ruby_runtime
  PRIVATE
  HAVE_ONIGMO_H=1
  MRB_USE_BIGINT=1
  MRB_UTF8_STRING=1
)

target_link_libraries(
  ruby_runtime
  m
  log
)
