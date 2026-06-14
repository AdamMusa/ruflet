# Contributing To Ruflet

This guide covers the Ruby framework, client, Rails integration, and showcase.

## Architecture

Ruflet applications build controls in Ruby. The Ruby runtime serializes those
controls and their updates for the Flutter client, which renders the interface
and sends user events back to Ruby.

The main areas are:

- `packages/ruflet` - CLI, project generation, run, update, and build commands
- `packages/ruflet_core` - controls, builders, page APIs, events, and services
- `packages/ruflet_server` - server-driven application runtime
- `packages/ruflet_rails` - Rails mounting, generators, and integration helpers
- `ruflet_client` - mobile, desktop, and web Flutter client
- `ruby_runtime` - embedded Ruby runtime for self-contained native builds
- `showcase` - framework feature and client-behavior test application

## Application API

Use the same public API in examples and tests that developers use:

```ruby
require "ruflet"

Ruflet.run do |page|
  message = text("Hello Ruflet")

  page.add(
    column(
      children: [
        message,
        button(
          "Update",
          on_click: ->(_event) { page.update(message, value: "Updated") }
        )
      ]
    )
  )
end
```

Controls are built with helpers such as `text`, `button`, `row`, and `column`.
Use `page` for application-level operations such as `add`, `update`,
navigation, dialogs, and services.

## Adding Or Changing A Control

1. Add or update the Ruby control definition and builder in `ruflet_core`.
2. Update the client implementation when rendering or event behavior changes.
3. Keep the control catalog and property descriptions current.
4. Add a focused Ruby test and relevant client test.
5. Add or update the showcase example.
6. Update public documentation when the developer-facing API changes.

Protocol changes must remain compatible across the Ruby runtime and every
supported client target.

## Tests

Run focused tests from the package you changed:

```bash
cd packages/ruflet_core
bundle exec ruby -Itest test/bare_widget_helpers_test.rb

cd ../ruflet_server
bundle exec ruby -Itest test/wire_codec_test.rb

cd ../ruflet
bundle exec ruby -Itest test/new_command_test.rb

cd ../ruflet_rails
bundle exec ruby -Itest test/scaffold_generator_test.rb
```

Run all tests for a Ruby package:

```bash
bundle exec ruby -Itest -e 'Dir["test/**/*_test.rb"].sort.each { |file| require_relative file }'
```

Run Flutter checks in a changed Flutter package:

```bash
flutter analyze
flutter test
```

## Contribution Checklist

- Public examples use the current builder API.
- Behavior changes have focused tests.
- Ruby and client implementations agree on protocol fields and events.
- Showcase behavior is verified on affected platforms.
- Documentation describes developer workflows rather than repository internals.
- Generated files, build output, and packaged gems are not committed.
