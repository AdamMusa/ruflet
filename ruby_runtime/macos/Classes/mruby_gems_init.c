#include <mruby.h>

void mrb_hal_posix_io_gem_init(mrb_state *mrb);
void mrb_hal_posix_socket_gem_init(mrb_state *mrb);
void mrb_mruby_digest_gem_init(mrb_state *mrb);
void mrb_mruby_sprintf_gem_init(mrb_state *mrb);
void mrb_mruby_pack_gem_init(mrb_state *mrb);
void GENERATED_TMP_mrb_mruby_fiber_gem_init(mrb_state *mrb);
void GENERATED_TMP_mrb_mruby_enumerator_gem_init(mrb_state *mrb);
void GENERATED_TMP_mrb_mruby_enum_ext_gem_init(mrb_state *mrb);
void GENERATED_TMP_mrb_mruby_enum_lazy_gem_init(mrb_state *mrb);
void GENERATED_TMP_mrb_mruby_enum_chain_gem_init(mrb_state *mrb);
void GENERATED_TMP_mrb_mruby_numeric_ext_gem_init(mrb_state *mrb);
void GENERATED_TMP_mrb_mruby_errno_gem_init(mrb_state *mrb);
void GENERATED_TMP_mrb_mruby_io_gem_init(mrb_state *mrb);
void GENERATED_TMP_mrb_mruby_socket_gem_init(mrb_state *mrb);

void
mrb_init_mrbgems(mrb_state *mrb)
{
  mrb_hal_posix_io_gem_init(mrb);
  mrb_hal_posix_socket_gem_init(mrb);
  mrb_mruby_digest_gem_init(mrb);
  mrb_mruby_sprintf_gem_init(mrb);
  mrb_mruby_pack_gem_init(mrb);
  GENERATED_TMP_mrb_mruby_fiber_gem_init(mrb);
  GENERATED_TMP_mrb_mruby_enumerator_gem_init(mrb);
  GENERATED_TMP_mrb_mruby_enum_ext_gem_init(mrb);
  GENERATED_TMP_mrb_mruby_enum_lazy_gem_init(mrb);
  GENERATED_TMP_mrb_mruby_enum_chain_gem_init(mrb);
  GENERATED_TMP_mrb_mruby_numeric_ext_gem_init(mrb);
  GENERATED_TMP_mrb_mruby_errno_gem_init(mrb);
  GENERATED_TMP_mrb_mruby_io_gem_init(mrb);
  GENERATED_TMP_mrb_mruby_socket_gem_init(mrb);
}
