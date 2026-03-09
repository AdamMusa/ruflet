# Flet Python Protocol Shape

This reference is generated from current Flet Python (`flet-core`) sources.

## Extraction Rules
- Component type comes from `_get_control_name()` return value.
- Serialized attribute keys come from `_set_attr`, `_set_attr_json`, and `_get_attr` calls.
- API event fields come from constructor args starting with `on_`.
- Runtime event names come from `_add_event_handler("...")`.
- Service/method protocol calls come from `page.invoke_method(...)` and `page.invoke_method_async(...)`.
- Event payload models come from local classes inheriting `ControlEvent`.

## Envelope
- Message transport is MessagePack over WebSocket/TCP (see Flet messaging/runtime).
- Control updates are sent as command/patch operations by Page/Connection layers.

See [INDEX](./INDEX.md) for all extracted components.
