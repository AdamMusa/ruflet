/*
 * Phase breakdown of the embedded VM's boot.
 *
 * bench_vm reports the total start -> port-bound time. This splits that total
 * into the stages ruflet_vm_start walks through, so it is clear which part of
 * the boot a parallel-initialization change would actually be hiding:
 *
 *   mrb_open       allocating the interpreter
 *   bootstrap      loading kRubyRuntimeVmBootstrapIrep (require/$LOAD_PATH/ENV)
 *   require ruflet pulling in ruflet_protocol, ruflet_ui, ruflet_server
 *
 * The stages are measured in one process, in the same order the real host uses,
 * against the same prebuilt archive.
 *
 * Usage: bench_phases <project_root>
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include <mruby.h>
#include <mruby/array.h>
#include <mruby/compile.h>
#include <mruby/irep.h>
#include <mruby/string.h>
#include <mruby/variable.h>

#include "../../ruby_runtime/shared/vm_bootstrap.h"

static double now_ms(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (double)ts.tv_sec * 1000.0 + (double)ts.tv_nsec / 1000000.0;
}

static int failed(mrb_state *mrb, const char *stage) {
  if (mrb->exc == NULL) {
    return 0;
  }
  mrb_value exception = mrb_obj_value(mrb->exc);
  mrb->exc = NULL;
  mrb_value message = mrb_funcall(mrb, exception, "to_s", 0);
  mrb->exc = NULL;
  fprintf(stderr, "[%s] %s\n", stage, mrb_string_value_cstr(mrb, &message));
  return 1;
}

/* The bootstrap exposes require/$LOAD_PATH through these, exactly as the real
 * host registers them in desktop/ruflet_vm_host.cpp. */
static mrb_value runtime_eval(mrb_state *mrb, mrb_value self) {
  mrb_value source;
  mrb_value filename = mrb_nil_value();
  mrb_get_args(mrb, "S|S", &source, &filename);
  mrbc_context *context = mrbc_context_new(mrb);
  context->capture_errors = TRUE;
  if (mrb_string_p(filename)) {
    mrbc_filename(mrb, context, mrb_string_value_cstr(mrb, &filename));
  }
  mrb_value result = mrb_load_nstring_cxt(mrb, RSTRING_PTR(source),
                                          RSTRING_LEN(source), context);
  mrbc_context_free(mrb, context);
  return result;
}

static mrb_value runtime_load_irep(mrb_state *mrb, mrb_value self) {
  mrb_value bytes;
  mrb_get_args(mrb, "S", &bytes);
  return mrb_load_irep_buf(mrb, (const uint8_t *)RSTRING_PTR(bytes),
                           RSTRING_LEN(bytes));
}

static mrb_value runtime_getenv(mrb_state *mrb, mrb_value self) {
  mrb_value name;
  mrb_get_args(mrb, "S", &name);
  const char *value = getenv(mrb_string_value_cstr(mrb, &name));
  return value == NULL ? mrb_nil_value() : mrb_str_new_cstr(mrb, value);
}

int main(int argc, char **argv) {
  if (argc < 2) {
    fprintf(stderr, "usage: %s <project_root>\n", argv[0]);
    return 2;
  }
  const char *root = argv[1];

  const double t0 = now_ms();
  mrb_state *mrb = mrb_open();
  const double t_open = now_ms();
  if (mrb == NULL) {
    fprintf(stderr, "mrb_open failed\n");
    return 1;
  }

  struct RClass *runtime = mrb_define_module(mrb, "RubyRuntime");
  mrb_define_module_function(mrb, runtime, "__eval", runtime_eval,
                             MRB_ARGS_ARG(1, 1));
  mrb_define_module_function(mrb, runtime, "__load_irep", runtime_load_irep,
                             MRB_ARGS_REQ(1));
  mrb_define_module_function(mrb, runtime, "__getenv", runtime_getenv,
                             MRB_ARGS_REQ(1));

  mrb_load_irep(mrb, kRubyRuntimeVmBootstrapIrep);
  const double t_bootstrap = now_ms();
  if (failed(mrb, "bootstrap")) {
    return 1;
  }

  /* Put $LOAD_PATH in place the way RubyRuntime.boot would, without running an
   * entrypoint, so the next stage measures require in isolation. */
  char setup[2048];
  snprintf(setup, sizeof(setup),
           "$LOAD_PATH ||= []; $LOAD_PATH << '%s'; "
           "Dir.chdir('%s') if Dir.respond_to?(:chdir)",
           root, root);
  mrb_load_string(mrb, setup);
  mrb->exc = NULL;
  const double t_setup = now_ms();

  mrb_load_string(mrb, "require 'ruflet'");
  const double t_require = now_ms();
  if (failed(mrb, "require ruflet")) {
    return 1;
  }

  printf("mrb_open_ms=%.2f bootstrap_ms=%.2f loadpath_ms=%.2f "
         "require_ruflet_ms=%.2f total_ms=%.2f\n",
         t_open - t0, t_bootstrap - t_open, t_setup - t_bootstrap,
         t_require - t_setup, t_require - t0);

  mrb_close(mrb);
  return 0;
}
