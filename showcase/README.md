# Ruflet Showcase

The showcase is a development application for exercising Ruflet controls,
layouts, services, and client behavior.

## Run

```bash
bundle install
bundle exec ruflet run
```

Open it directly in a web or desktop client:

```bash
bundle exec ruflet run --web
bundle exec ruflet run --desktop
```

## Build

```bash
bundle exec ruflet build apk
bundle exec ruflet build ios
```

The showcase is intended for framework testing. Start new applications with
`ruflet new <appname>` instead of copying this directory.
