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

## Limits on client input

The server bounds what a client can send, so a client that is broken or
hostile cannot exhaust its CPU, memory or threads. Ordinary clients are
unaffected.

| Limit | Default | Setting |
| --- | --- | --- |
| Largest message, however many frames carry it | 16 MiB | `RUFLET_MAX_MESSAGE_BYTES` (bytes) |
| Connections handled at once (HTTP and WebSocket) | unlimited | `RUFLET_MAX_CONNECTIONS` |
| HTTP request line and headers | 128 KiB, 100 header fields | none |
| Time to finish sending the request headers | 30 s | none |
| Time from the WebSocket upgrade to the first message | 30 s | none |

A message over the limit closes that client's connection. The server logs a
`Ruflet::MessageTooLargeError` that names the limit, and any `on_result`
callback or `invoke_sync` still waiting on that client gets the error
instead of waiting forever. A file picker reply carrying the files' bytes
(`with_data: true`) is the usual way to reach the limit.

`ruflet_rails` applies the message limit, the first-message deadline and
`RUFLET_MAX_CONNECTIONS` to its WebSocket endpoint as well.
