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

## Browser origins

Browsers send an `Origin` header when they open the WebSocket; native Ruflet
clients send none. Under `ruflet run`, the server refuses a WebSocket from a
browser page on another host with `403`, so a page you have open elsewhere
cannot read or drive your app. These still connect:

- native clients;
- pages served from localhost, on any port;
- pages on the host the WebSocket URL names, on any port. That covers the web
  client `ruflet run --web` serves and a `ruflet build web` output you serve
  from the same machine, opened on localhost or on your LAN address.

A page whose host differs from the WebSocket URL's host is refused, even when
both name this machine (for example a page opened at `http://mymac.local:8000`
whose `app.backend_url` is `http://192.168.1.20:8550`). So is `Origin: null`,
which `file://` pages and sandboxed iframes send.

A server started any other way, such as `ruby main.rb` or in production,
accepts such connections as before and logs a warning once per origin.

To allow other origins, list them in `RUFLET_ALLOWED_ORIGINS`, separated by
commas. You can also pass `allowed_origins:` to `Ruflet::Server.new`:

```bash
RUFLET_ALLOWED_ORIGINS=https://app.example.com,https://admin.example.com ruby main.rb
```

Setting a list makes any server refuse the origins it does not name. `*` allows
every origin, including `null`, and turns the warning off.
