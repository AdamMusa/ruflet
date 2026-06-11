/*
 * Desktop test harness for the embedded Ruflet mruby VM.
 *
 * Compiles the exact same vendored mruby sources the macOS/iOS plugins use
 * (see ruby_runtime/macos/ruby_runtime.podspec) into a CLI runner, so the
 * embedded runtime can be exercised on desktop without booting Flutter.
 *
 * Usage: embedded_mruby [--preload] script.rb
 *   --preload  load ruby_runtime/shared/embedded_ruflet_runtime.h first,
 *              exactly like the plugin does at startup.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <mruby.h>
#include <mruby/compile.h>
#include <mruby/string.h>
#include <mruby/variable.h>

#include "../../ruby_runtime/shared/embedded_ruflet_runtime.h"

static int report_exception(mrb_state *mrb, const char *stage) {
  if (mrb->exc == NULL) {
    return 0;
  }

  mrb_value exc = mrb_obj_value(mrb->exc);
  mrb->exc = NULL;

  mrb_value backtrace = mrb_funcall(mrb, exc, "backtrace", 0);
  mrb->exc = NULL;

  mrb_value message = mrb_funcall(mrb, exc, "to_s", 0);
  if (mrb->exc != NULL) {
    mrb->exc = NULL;
    fprintf(stderr, "[%s] exception (unrenderable message)\n", stage);
    return 1;
  }

  fprintf(stderr, "[%s] %s: %s\n", stage, mrb_obj_classname(mrb, exc),
          mrb_string_value_cstr(mrb, &message));

  if (mrb_array_p(backtrace)) {
    mrb_value rendered = mrb_funcall(mrb, backtrace, "join", 1,
                                     mrb_str_new_cstr(mrb, "\n"));
    if (mrb->exc == NULL && mrb_string_p(rendered)) {
      fprintf(stderr, "%s\n", mrb_string_value_cstr(mrb, &rendered));
    }
    mrb->exc = NULL;
  }

  return 1;
}

int main(int argc, char **argv) {
  int preload = 0;
  const char *path = NULL;

  for (int i = 1; i < argc; i++) {
    if (strcmp(argv[i], "--preload") == 0) {
      preload = 1;
    } else {
      path = argv[i];
    }
  }

  if (path == NULL) {
    fprintf(stderr, "usage: %s [--preload] script.rb\n", argv[0]);
    return 2;
  }

  mrb_state *mrb = mrb_open();
  if (mrb == NULL) {
    fprintf(stderr, "failed to open mruby state\n");
    return 2;
  }

  if (preload) {
    mrbc_context *context = mrbc_context_new(mrb);
    mrbc_filename(mrb, context, "/__ruflet__/embedded_runtime.rb");
    mrb_load_string_cxt(mrb, kEmbeddedRufletRuntime, context);
    mrbc_context_free(mrb, context);
    if (report_exception(mrb, "preload")) {
      mrb_close(mrb);
      return 1;
    }
  }

  FILE *file = fopen(path, "rb");
  if (file == NULL) {
    fprintf(stderr, "cannot open %s\n", path);
    mrb_close(mrb);
    return 2;
  }

  mrbc_context *context = mrbc_context_new(mrb);
  mrbc_filename(mrb, context, path);
  mrb_load_file_cxt(mrb, file, context);
  mrbc_context_free(mrb, context);
  fclose(file);

  int failed = report_exception(mrb, "script");
  mrb_close(mrb);
  return failed;
}
