# InteractiveViewer

- Python class: `InteractiveViewer`
- Source: `sdk/python/packages/flet/src/flet/controls/core/interactive_viewer.py`

## Serialized Properties (Python layer)
- `content`
- `pan_enabled`
- `scale_enabled`
- `trackpad_scroll_causes_scale`
- `constrained`
- `max_scale`
- `min_scale`
- `interaction_end_friction_coefficient`
- `scale_factor`
- `clip_behavior`
- `alignment`
- `boundary_margin`
- `interaction_update_interval`

## Event Fields
- `on_interaction_start`
- `on_interaction_update`
- `on_interaction_end`

## Notes
- Extracted from `@control("InteractiveViewer")` class declaration.
- Property list is based on dataclass field declarations in class body.
- Final wire payload is MessagePack-encoded by Python messaging protocol.
