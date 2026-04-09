#include <stdint.h>
#include <string.h>

#include <mruby.h>
#include <mruby/class.h>
#include <mruby/string.h>

typedef struct {
  uint32_t h[5];
  uint64_t total_len;
  unsigned char buffer[64];
  size_t buffer_len;
} sha1_ctx;

static uint32_t
sha1_rotl(uint32_t value, int bits)
{
  return (value << bits) | (value >> (32 - bits));
}

static void
sha1_init(sha1_ctx *ctx)
{
  ctx->h[0] = 0x67452301u;
  ctx->h[1] = 0xEFCDAB89u;
  ctx->h[2] = 0x98BADCFEu;
  ctx->h[3] = 0x10325476u;
  ctx->h[4] = 0xC3D2E1F0u;
  ctx->total_len = 0;
  ctx->buffer_len = 0;
}

static void
sha1_process_block(sha1_ctx *ctx, const unsigned char *block)
{
  uint32_t w[80];
  uint32_t a, b, c, d, e;
  int i;

  for (i = 0; i < 16; ++i) {
    int j = i * 4;
    w[i] = ((uint32_t)block[j] << 24) |
           ((uint32_t)block[j + 1] << 16) |
           ((uint32_t)block[j + 2] << 8) |
           (uint32_t)block[j + 3];
  }

  for (i = 16; i < 80; ++i) {
    w[i] = sha1_rotl(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1);
  }

  a = ctx->h[0];
  b = ctx->h[1];
  c = ctx->h[2];
  d = ctx->h[3];
  e = ctx->h[4];

  for (i = 0; i < 80; ++i) {
    uint32_t f, k, temp;
    if (i < 20) {
      f = (b & c) | ((~b) & d);
      k = 0x5A827999u;
    }
    else if (i < 40) {
      f = b ^ c ^ d;
      k = 0x6ED9EBA1u;
    }
    else if (i < 60) {
      f = (b & c) | (b & d) | (c & d);
      k = 0x8F1BBCDCu;
    }
    else {
      f = b ^ c ^ d;
      k = 0xCA62C1D6u;
    }

    temp = sha1_rotl(a, 5) + f + e + k + w[i];
    e = d;
    d = c;
    c = sha1_rotl(b, 30);
    b = a;
    a = temp;
  }

  ctx->h[0] += a;
  ctx->h[1] += b;
  ctx->h[2] += c;
  ctx->h[3] += d;
  ctx->h[4] += e;
}

static void
sha1_update(sha1_ctx *ctx, const unsigned char *data, size_t len)
{
  size_t offset = 0;
  ctx->total_len += len;

  if (ctx->buffer_len > 0) {
    size_t needed = 64 - ctx->buffer_len;
    if (needed > len) needed = len;
    memcpy(ctx->buffer + ctx->buffer_len, data, needed);
    ctx->buffer_len += needed;
    offset += needed;
    if (ctx->buffer_len == 64) {
      sha1_process_block(ctx, ctx->buffer);
      ctx->buffer_len = 0;
    }
  }

  while (offset + 64 <= len) {
    sha1_process_block(ctx, data + offset);
    offset += 64;
  }

  if (offset < len) {
    size_t remain = len - offset;
    memcpy(ctx->buffer, data + offset, remain);
    ctx->buffer_len = remain;
  }
}

static void
sha1_final(sha1_ctx *ctx, unsigned char out[20])
{
  uint64_t bit_len = ctx->total_len * 8;
  size_t i;

  ctx->buffer[ctx->buffer_len++] = 0x80;
  if (ctx->buffer_len > 56) {
    while (ctx->buffer_len < 64) ctx->buffer[ctx->buffer_len++] = 0x00;
    sha1_process_block(ctx, ctx->buffer);
    ctx->buffer_len = 0;
  }

  while (ctx->buffer_len < 56) ctx->buffer[ctx->buffer_len++] = 0x00;
  for (i = 0; i < 8; ++i) {
    ctx->buffer[56 + i] = (unsigned char)((bit_len >> ((7 - i) * 8)) & 0xff);
  }
  sha1_process_block(ctx, ctx->buffer);

  for (i = 0; i < 5; ++i) {
    out[i * 4] = (unsigned char)((ctx->h[i] >> 24) & 0xff);
    out[i * 4 + 1] = (unsigned char)((ctx->h[i] >> 16) & 0xff);
    out[i * 4 + 2] = (unsigned char)((ctx->h[i] >> 8) & 0xff);
    out[i * 4 + 3] = (unsigned char)(ctx->h[i] & 0xff);
  }
}

static mrb_value
mrb_digest_sha1_digest(mrb_state *mrb, mrb_value self)
{
  mrb_value input;
  unsigned char out[20];
  sha1_ctx ctx;
  (void)self;

  mrb_get_args(mrb, "S", &input);
  sha1_init(&ctx);
  sha1_update(&ctx, (const unsigned char *)RSTRING_PTR(input), (size_t)RSTRING_LEN(input));
  sha1_final(&ctx, out);
  return mrb_str_new(mrb, (const char *)out, 20);
}

void
mrb_mruby_digest_gem_init(mrb_state *mrb)
{
  struct RClass *digest = mrb_define_module(mrb, "Digest");
  struct RClass *sha1 = mrb_define_module_under(mrb, digest, "SHA1");
  mrb_define_class_method(mrb, sha1, "digest", mrb_digest_sha1_digest, MRB_ARGS_REQ(1));
}

void
mrb_mruby_digest_gem_final(mrb_state *mrb)
{
  (void)mrb;
}
