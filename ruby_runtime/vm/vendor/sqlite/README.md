# Vendored SQLite

Ruflet embeds the official SQLite 3.53.4 amalgamation so every mruby target
uses the same public SQLite API and database format.

- Source: `https://www.sqlite.org/2026/sqlite-amalgamation-3530400.zip`
- Archive SHA3-256: `628a44cfe82c66aed1ccbbe85a562d2e33ebe64b3288981ed76285612227934e`
- SQLite source is dedicated to the public domain.

The build disables loadable extensions and enables foreign keys, JSON, and
FTS5. Do not edit the generated amalgamation files directly.
