# ruflet_server

`ruflet_server` runs server-driven Ruflet applications and connects their Ruby
UI code to Ruflet clients.

It is installed automatically in projects created with `ruflet new`. Start an
application through the Ruflet CLI:

```bash
ruflet run
ruflet run --web
ruflet run --desktop
```

Application code uses the public `Ruflet.run` API supplied by `ruflet_core`.
Rails applications should use `ruflet_rails` instead of starting this server
directly.
