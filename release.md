# Releasing Ruflet

Release packages only after their tests, generated-project workflow, and
affected clients have been verified.

## Ruby Gems

Ruflet's Ruby packages are released independently:

- `ruflet_core`
- `ruflet_server`
- `ruflet`
- `ruflet_rails`
- `ruflet_record`

Update each package version in its own `lib/ruflet/version.rb`. When several
packages are released together, publish dependencies before dependents:

1. `ruflet_core`
2. `ruflet_server`
3. `ruflet`
4. `ruflet_rails`

`ruflet_record` has no Ruflet package dependency and can be published at any
point in that sequence.

Run the package's tests before building it, the same way CI does
(`.github/workflows/ruby-tests.yml`):

```bash
cd packages/ruflet_core
bundle install
ruby ../../tools/run_ruby_tests.rb --strict ruflet_core
gem build ruflet_core.gemspec
```

Repeat from each package directory, using that package's suite name and
gemspec. Building from the package directory ensures the gem contains the
intended files.

- `bundle install` installs the test toolchain from the package's Gemfile.
  That Gemfile is development-only and is not part of the gem.
- `tools/run_ruby_tests.rb` runs the core packages one process per test file.
  It runs `ruflet_rails` and `ruflet_record` through `bundle exec rake test`.
- CI sets three variables. Set them the same way locally:
  - `RUFLET_TEMPLATE_ROOT`: a ruflet-template checkout, for `ruflet`.
  - `RUFLET_ENGINE_ROOT`: a ruflet-engine checkout, for `ruflet_core`'s
    engine cross-check.
  - `RUFLET_MRUBY`: the pinned mruby, for `tools`.
- `--strict` fails on any skipped test. Without the last two variables, the
  checks that need them skip. In that case, drop `--strict` and read the
  skips it lists by name.

Inspect and publish the resulting gem:

```bash
gem specification ruflet_core-VERSION.gem
gem push ruflet_core-VERSION.gem
```

Replace `VERSION` with the version being released. Do not commit generated
`.gem` files.

## Ruflet Clients

Client release archives are consumed by CLI and Rails update/install commands.
Build and test every target included in a release, then attach archives using
the filenames expected by the update pipeline.

Publish the versioned GitHub client release before publishing the matching
`ruflet` gem. For Ruflet `VERSION`, the client release tag must be `vVERSION`
or `VERSION`; stable CLI installs never fall back to `latest` or a prebuild
channel. Development channels such as `prebuild-main` must be selected
explicitly with `RUFLET_CLIENT_CHANNEL`.

Verify at minimum:

```bash
bundle exec ruflet update --check
bundle exec ruflet run --web
bundle exec ruflet run --desktop
```

Also verify any affected native target on a real device or emulator.

## Embedded Ruby Runtime

For `ruby_runtime`, update its package version and changelog, run Flutter
analysis/tests, and verify the packaged VM loads the expected Ruflet gems:

```bash
cd ruby_runtime
flutter analyze
flutter test
cd ..
tools/embedded_vm_harness/build.sh
tools/embedded_vm_harness/build/embedded_mruby --preload \
  tools/embedded_vm_harness/tests/ruflet_gem_test.rb
```

## Release Checklist

- Package versions and changelogs are updated.
- Ruby package tests pass.
- Flutter analysis and tests pass for affected clients/plugins.
- A generated Ruflet project can run and build with released packages.
- Rails install, web mount, and affected generators are verified.
- Client archives are attached with expected filenames.
- The client release tag exactly matches the `ruflet` gem version.
- Generated build artifacts and `.gem` files remain untracked.
