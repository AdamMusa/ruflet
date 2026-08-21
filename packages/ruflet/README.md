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
ruflet run --web
```

Generated projects include `ruflet_core` and `ruflet_server` as application
dependencies. Run Ruflet commands directly inside the generated project.

## Commands

```bash
ruflet new <appname>
ruflet run [scriptname|path] [--web|--desktop] [--experimental|--exp] [--port PORT]
ruflet debug [scriptname|path]
ruflet devices
ruflet emulators
ruflet doctor [--fix]
ruflet update [web|desktop|all] [--check] [--force]
ruflet build <apk|android|ios|ipa|aab|web|macos|windows|linux> [--self] [--experimental|--exp]
ruflet install [--device DEVICE_ID]
```

`--experimental` is available only for iOS and macOS builds. It selects the
native Apple renderer while the normal Ruflet build pipeline continues to
resolve the declared services, extensions, permissions, assets, and runtime
mode. Without it, Apple builds use only the Flutter renderer.

Before Flutter resolves or bundles packages, Ruflet removes extension plugins
that are not selected by the current services/extensions configuration. With
the experimental Apple renderer, built-in declarations are registered as Swift
extensions and their duplicate Dart/Flutter plugins are excluded entirely.

On macOS, `ruflet run --experimental` (or `ruflet run --exp`) downloads the
experimental Ruflet Explorer iOS Simulator prebuild the first time, reuses its
versioned cache afterward, and launches it on the already-booted simulator
with the current backend URL. Add `--desktop` to download and launch the native
macOS prebuild instead: `ruflet run --desktop --exp`.

Commands that create, diagnose, or build a Flutter client compare the cached
template revision with `AdamMusa/ruflet-template` on GitHub. When `main`
changes, Ruflet downloads the new template and refreshes its managed
`build/client` automatically. If GitHub is unavailable, Ruflet keeps using the
last complete cached template. Use `ruflet doctor --fix` to force a clean
template download.

Desktop and web runs use the completed `prebuild-main` client channel by
default. Ruflet checks the channel at most once every six hours and downloads
a new platform build only after every required prebuild job has finished.
Use `ruflet update --force` for an immediate refresh. Set
`RUFLET_CLIENT_CHANNEL=stable` to stay on versioned release assets,
`RUFLET_CLIENT_UPDATE_INTERVAL=0` to check on every run, or
`RUFLET_CLIENT_AUTO_UPDATE=0` to disable automatic client updates.

Run `ruflet install` without `--device` to choose from a numbered list of
connected devices. Pass `--device DEVICE_ID` to skip the prompt.

Run `ruflet help <command>` for all options.
