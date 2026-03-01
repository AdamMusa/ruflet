#include <mruby.h>

void mrb_hal_posix_io_gem_init(mrb_state *mrb);
void mrb_hal_posix_socket_gem_init(mrb_state *mrb);
void GENERATED_TMP_mrb_mruby_errno_gem_init(mrb_state *mrb);
void GENERATED_TMP_mrb_mruby_io_gem_init(mrb_state *mrb);
void GENERATED_TMP_mrb_mruby_socket_gem_init(mrb_state *mrb);

void
mrb_init_mrbgems(mrb_state *mrb)
{
  mrb_hal_posix_io_gem_init(mrb);
  mrb_hal_posix_socket_gem_init(mrb);
  GENERATED_TMP_mrb_mruby_errno_gem_init(mrb);
  GENERATED_TMP_mrb_mruby_io_gem_init(mrb);
  GENERATED_TMP_mrb_mruby_socket_gem_init(mrb);
}
