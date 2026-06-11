cmake_minimum_required(VERSION 3.22.1)
project(ruby_runtime LANGUAGES C CXX)

set(CMAKE_C_STANDARD 99)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(MRUBY_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../ios/mruby_src")
set(MRUBY_BUILD_ROOT "${MRUBY_ROOT}/build_host")

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

add_library(
  ruby_runtime
  SHARED
  ruby_runtime_jni.cpp
  ../../../../shared/mruby_gems_init.c
  ../../../../shared/mruby_digest_gem.c
  ${MRUBY_CORE_SOURCES}
  ${MRUBY_COMPILER_SOURCES}
  ${MRUBY_GEM_SOURCES}
  ${MRUBY_GENERATED_SOURCES}
)

target_include_directories(
  ruby_runtime
  PRIVATE
  "${MRUBY_BUILD_ROOT}/include"
  "${MRUBY_ROOT}/include"
  "${MRUBY_ROOT}/src"
  "${MRUBY_ROOT}/mrbgems/mruby-compiler/core"
  "${MRUBY_ROOT}/mrbgems/mruby-io/include"
  "${MRUBY_ROOT}/mrbgems/mruby-socket/include"
  "${MRUBY_ROOT}/mrbgems/mruby-time/include"
  "${MRUBY_ROOT}/mrbgems/mruby-dir/include"
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
