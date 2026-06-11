## 0.0.5

- Bind any free port instead of failing on a busy one: the embedded server
  now reports its actual bound port through a `server.port` file in the app
  work dir (seeded via `RUFLET_PORT_FILE`), exposed to Dart with the new
  `RubyRuntime.serverPort()` method. The plugins no longer force
  `RUFLET_STRICT_PORT=1`; strict binding remains available by setting that
  variable explicitly.
- Seed `ENV` through the Ruby prelude on all platforms: the embedded VM's
  `ENV` is isolated from the process environment, so the plugins' `setenv`
  calls (`RUFLET_PORT_FILE`, `RUFLET_PROD_STOP_FILE`) never reached the
  server.
- Add a pure-Ruby `Regexp`/`MatchData` engine: regex literals (mruby compiles
  them to `Regexp.compile`), named captures, lookahead, backreferences,
  `i m x` options, and full `String` integration (`match`, `match?`, `=~`,
  `scan`, `gsub`/`sub` with backreference replacements, `split`, `[]`,
  `partition`, `index`, `start_with?`, `case/when`). Validated by a test
  suite that also passes under CRuby.
- Make the embedded runtime general-purpose: vendor the standard mruby
  extension gems (time, math, random, struct, set, data, enumerator, fiber,
  catch, method, dir, eval/binding, kernel-ext, class-ext, and all
  array/hash/string/numeric/object/range/symbol/proc/compar/enum/toplevel
  ext gems) into the Android, iOS, and macOS builds.
- Add pure-Ruby stdlib supplements: JSON generation (`JSON.generate`,
  `#to_json`), `StringIO`, `OpenStruct`, `Forwardable`, `Base64`,
  `SecureRandom.uuid`/`random_bytes`, `Time#strftime`/`#iso8601`,
  `SystemExit`/`exit`/`abort`, `pp`, richer `FileUtils` and `File` helpers.
- Replace the deterministic LCG fallbacks: `Kernel.rand`, `SecureRandom`,
  and control IDs now draw from mruby-random; `Process.clock_gettime` uses
  the real clock; `Kernel#sleep` actually sleeps (via `IO.select`).
- Add a desktop test harness (`tools/embedded_vm_harness`) that compiles the
  exact packaged mruby sources plus a standard-Ruby compatibility regression
  suite.

## 0.0.4

- Fix Android native builds to compile from the packaged mruby source tree.

## 0.0.3

- Fix native Android, iOS, and macOS includes to load the packaged embedded Ruflet runtime header from `shared/`.

## 0.0.2

- Align Android plugin packaging and publish metadata for Ruflet self-contained builds.
- Document supported runtime behavior and developer usage more clearly.
- Prepare the package for pub.dev publication from the standalone `ruby_runtime` package.

## 0.0.1

- Initial `ruby_runtime` Flutter plugin release.
- Added embedded mruby execution APIs for Ruflet.
- Added embedded file server support used by self-contained Ruflet apps.
- Added Android, iOS, and macOS platform implementations.
