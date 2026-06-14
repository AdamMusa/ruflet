# Releasing Ruflet

Release packages only after their tests, generated-project workflow, and
affected clients have been verified.

## Ruby Gems

Ruflet's Ruby packages are released independently:

- `ruflet_core`
- `ruflet_server`
- `ruflet`
- `ruflet_rails`

Update each package version in its own `lib/ruflet/version.rb`. When several
packages are released together, publish dependencies before dependents:

1. `ruflet_core`
2. `ruflet_server`
3. `ruflet`
4. `ruflet_rails`

Run the package tests before building:

```bash
cd packages/ruflet_core
bundle exec ruby -Itest -e 'Dir["test/**/*_test.rb"].sort.each { |file| require_relative file }'
gem build ruflet_core.gemspec
```

Repeat from each package directory with its matching gemspec. Building from
the package directory ensures the gem contains the intended files.

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

Verify at minimum:

```bash
bundle exec ruflet update --check
bundle exec ruflet run --web
bundle exec ruflet run --desktop
```

Also verify any affected native target on a real device or emulator.

## Embedded Ruby Runtime

For `ruby_runtime`, update its package version and changelog, run Flutter
analysis/tests, and run the embedded VM compatibility harness:

```bash
cd ruby_runtime
flutter analyze
flutter test
tools/embedded_vm_harness/build.sh
tools/embedded_vm_harness/build/embedded_mruby --preload \
  tools/embedded_vm_harness/tests/compat_test.rb
```

## Release Checklist

- Package versions and changelogs are updated.
- Ruby package tests pass.
- Flutter analysis and tests pass for affected clients/plugins.
- A generated Ruflet project can run and build with released packages.
- Rails install, web mount, and affected generators are verified.
- Client archives are attached with expected filenames.
- Generated build artifacts and `.gem` files remain untracked.
