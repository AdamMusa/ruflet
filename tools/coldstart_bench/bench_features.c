/*
 * Attributes framework boot cost to individual framework files.
 *
 * mrb_open() on the shipped VM costs ~300ms; on the same gem set without
 * ruflet-framework/ruflet-record it costs under 1ms. This walks the framework's
 * features in the order the mrbgem concatenates them, compiling and executing
 * each one separately, so the cost lands on a filename.
 *
 * Compile and execute are timed apart on purpose: in the shipped VM the
 * compile has already happened at build time (the gem ships precompiled irep),
 * so only the execute column is boot cost an application actually pays.
 *
 * Usage: bench_features <features_dir>   (as produced by profile_framework.rb)
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include <mruby.h>
#include <mruby/compile.h>
#include <mruby/irep.h>
#include <mruby/proc.h>
#include <mruby/string.h>

static double now_ms(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (double)ts.tv_sec * 1000.0 + (double)ts.tv_nsec / 1000000.0;
}

static int report(mrb_state *mrb, const char *name) {
  if (mrb->exc == NULL) {
    return 0;
  }
  mrb_value exception = mrb_obj_value(mrb->exc);
  mrb->exc = NULL;
  mrb_value message = mrb_funcall(mrb, exception, "to_s", 0);
  mrb->exc = NULL;
  fprintf(stderr, "  !! %s: %s\n", name, mrb_string_value_cstr(mrb, &message));
  return 1;
}

int main(int argc, char **argv) {
  if (argc < 2) {
    fprintf(stderr, "usage: %s <features_dir>\n", argv[0]);
    return 2;
  }
  const char *dir = argv[1];

  char manifest_path[1024];
  snprintf(manifest_path, sizeof(manifest_path), "%s/manifest.txt", dir);
  FILE *manifest = fopen(manifest_path, "r");
  if (manifest == NULL) {
    fprintf(stderr, "cannot read %s\n", manifest_path);
    return 2;
  }

  mrb_state *mrb = mrb_open();
  if (mrb == NULL) {
    fprintf(stderr, "mrb_open failed\n");
    return 1;
  }

  /* The framework expects a require/$LOADED_FEATURES shape it normally gets
   * from the VM bootstrap. Stub just enough that features which require each
   * other become no-ops -- everything is being loaded explicitly here. */
  mrb_load_string(mrb,
                  "$LOADED_FEATURES ||= []\n"
                  "$LOAD_PATH ||= []\n"
                  "module Kernel\n"
                  "  def require(name); false; end\n"
                  "  def require_relative(name); false; end\n"
                  "end\n");
  mrb->exc = NULL;

  char line[512];
  double total_compile = 0.0;
  double total_execute = 0.0;
  while (fgets(line, sizeof(line), manifest) != NULL) {
    line[strcspn(line, "\r\n")] = '\0';
    if (line[0] == '\0') {
      continue;
    }

    char path[1536];
    snprintf(path, sizeof(path), "%s/%s", dir, line);
    FILE *source = fopen(path, "rb");
    if (source == NULL) {
      fprintf(stderr, "cannot open %s\n", path);
      continue;
    }

    mrbc_context *context = mrbc_context_new(mrb);
    mrbc_filename(mrb, context, line);
    const double c0 = now_ms();
    struct mrb_parser_state *parser = mrb_parse_file(mrb, source, context);
    struct RProc *proc =
        parser == NULL ? NULL : mrb_generate_code(mrb, parser);
    const double c1 = now_ms();
    fclose(source);

    double e0 = c1;
    double e1 = c1;
    if (proc != NULL) {
      e0 = now_ms();
      mrb_vm_run(mrb, proc, mrb_top_self(mrb), 0);
      e1 = now_ms();
      report(mrb, line);
    } else {
      fprintf(stderr, "  !! %s: failed to compile\n", line);
    }
    if (parser != NULL) {
      mrb_parser_free(parser);
    }
    mrbc_context_free(mrb, context);

    total_compile += c1 - c0;
    total_execute += e1 - e0;
    printf("%8.2f %8.2f  %s\n", c1 - c0, e1 - e0, line);
  }
  fclose(manifest);

  printf("%8.2f %8.2f  TOTAL (compile, execute)\n", total_compile,
         total_execute);
  mrb_close(mrb);
  return 0;
}
