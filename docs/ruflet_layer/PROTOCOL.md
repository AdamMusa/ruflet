# Flet Python Layer Protocol and Serialization

Source scope:
- `sdk/python/packages/flet/src/flet/messaging/protocol.py`
- `sdk/python/packages/flet/src/flet/messaging/session.py`
- `sdk/python/packages/flet/src/flet/messaging/flet_socket_server.py`
- `sdk/python/packages/flet/src/flet/controls/base_control.py`
- `sdk/python/packages/flet/src/flet/controls/page.py`

## Transport
- Python side uses MessagePack (`msgpack`) for wire frames.
- Frame envelope is `[action_code, body]`.
- `FletSocketServer` handles TCP/UDS connection, receive loop, send loop, and dispatch.

## ClientAction Codes
- `REGISTER_CLIENT` = `1`
- `PATCH_CONTROL` = `2`
- `CONTROL_EVENT` = `3`
- `UPDATE_CONTROL_PROPS` = `4`
- `INVOKE_METHOD` = `5`
- `SESSION_CRASHED` = `6`

## Serialization Rules (Python -> Flutter client)
- Dataclass objects are encoded via `configure_encode_object_for_msgpack()`.
- Fields with metadata `skip` are excluded.
- `on_*` event fields are serialized as booleans (true when handler exists).
- Enum values are encoded as `.value`.
- Extension types:
- `ExtType(1)`: datetime/date ISO-8601 string
- `ExtType(2)`: time as HH:MM
- `ExtType(3)`: Duration in microseconds
- `ExtType(4)`: UTF-8 string

## Patch Flow
- Session computes object diffs using `ObjectPatch`.
- Outbound UI updates are sent with `ClientAction.PATCH_CONTROL` and `PatchControlBody`.
- Client->server updates arrive as `UPDATE_CONTROL_PROPS` and are applied with `patch_dataclass`.

## Event Flow
- Client emits `CONTROL_EVENT` with `{target, name, data}`.
- Session dispatches to control handlers via `_trigger_event`.

## Invoke-Method Flow
- Method calls use `INVOKE_METHOD` frames with correlation IDs.
- Results/errors are matched and resumed in waiting tasks.
