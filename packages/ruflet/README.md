# ruflet

`ruflet` is the command-line package for creating, running, diagnosing, and
building Ruflet applications.

## Install

```bash
gem install ruflet
```

Create a project and run it:

```bash
ruflet new my_app
cd my_app
bundle install
bundle exec ruflet run --web
```

Generated projects include `ruflet_core` and `ruflet_server` as application
dependencies. Use `bundle exec ruflet` inside a project so commands run with
the versions declared in its `Gemfile`.

## Commands

```bash
ruflet new <appname>
ruflet run [scriptname|path] [--web|--desktop] [--port PORT]
ruflet debug [scriptname|path]
ruflet devices
ruflet emulators
ruflet doctor
ruflet update [web|desktop|all] [--check] [--force]
ruflet build <apk|android|ios|aab|web|macos|windows|linux> [--self]
ruflet install [--device DEVICE_ID]
```

Run `ruflet help <command>` for all options.
