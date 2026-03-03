# Contributing to Ruflet (Ruby Side)

This guide explains how Ruflet works, how protocol patches flow, and how to add a new feature step‑by‑step with a minimal `Row`/`Text` example.

## 1. How Ruflet Works (High Level)
1. **Ruby builds controls** (e.g., `page.text`, `page.row`).
2. **Controls are serialized** into protocol patches (maps with `_c`, `_i`, and props).
3. **Client renders** those patches into Flutter widgets.

Key Ruby files:
- `packages/ruflet/lib/ruflet_ui/ruflet/page.rb` — patch generation, updates.
- `packages/ruflet/lib/ruflet_ui/ruflet/control.rb` — control serialization.
- `packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/` — control classes.
- `packages/ruflet/lib/ruflet_ui/ruflet/ui/*_control_registry.rb` — mapping of control names.
- `examples/ruflet_studio/` — demo app.

## 2. Protocol in Practice
Ruflet controls serialize into patches like:

```json
{
  "_c": "Text",
  "_i": 101,
  "value": "Hello"
}
```

- `_c`: widget type
- `_i`: wire id
- Remaining fields: props

When you call:
```ruby
page.update(control, value: "New text")
```
Ruflet sends a patch like:
```json
[0, 0, "value", "New text"]
```

## 3. Step‑by‑Step: Add a New Feature (Example)
Let’s add a simple **"tag"** control that renders text in a styled container.

### Step 1 — Create a control class
Create a new control class in `packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/material/tag_control.rb`:

```ruby
# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      class TagControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "tag", id: id, **props)
        end
      end
    end
  end
end
```

### Step 2 — Register the control
Add a registry entry in:
`packages/ruflet/lib/ruflet_ui/ruflet/ui/material_control_registry.rb`

```ruby
"tag" => "Tag",
```

### Step 3 — Add a DSL helper (optional)
In `packages/ruflet/lib/ruflet_ui/ruflet/ui/material_control_methods.rb`:

```ruby
def tag(**props) = build_widget(:tag, **props)
```

### Step 4 — Demo the control in Studio
In `examples/ruflet_studio/sections_misc.rb` or a new section:

```ruby
page.column(
  spacing: 8,
  controls: [
    page.text(value: "New Tag Control"),
    page.row(
      controls: [
        page.tag(text: "Ruflet", bgcolor: "#dbe4ff", color: "#1f2328")
      ]
    )
  ]
)
```

### Step 5 — Test
- Run Ruflet Studio
- Navigate to the demo section
- Verify patch logs show `_c: "Tag"`

## 4. Minimal Examples (Row/Text)
Use these for quick validation:

```ruby
page.column(
  controls: [
    page.text(value: "Hello Ruflet"),
    page.row(controls: [page.text(value: "Row item")])
  ]
)
```

## 5. Contribution Checklist
- Control class added
- Registry updated
- Optional DSL helper added
- Example added
- Patch logs validated

## 6. Writing Tests (Step-by-Step)
Keep tests small and independent. Do not put an entire gem's coverage into one large file.

### Test Layout Rules
- Add tests under each gem package:
  - `packages/ruflet/test/`
  - `packages/ruflet_server/test/`
  - `packages/ruflet_cli/test/`
- Use one `test_helper.rb` per gem package.
- Split by behavior:
  - `run_interceptor_test.rb`
  - `wire_codec_test.rb`
  - `new_command_test.rb`

### Step 1 — Pick one behavior
Example: `Ruflet.run` should return interceptor result without requiring `ruflet_server`.

### Step 2 — Create (or reuse) test helper
`packages/ruflet/test/test_helper.rb`

```ruby
# frozen_string_literal: true

require "minitest/autorun"
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "ruflet"
```

### Step 3 — Write one focused test file
`packages/ruflet/test/run_interceptor_test.rb`

```ruby
# frozen_string_literal: true

require_relative "test_helper"

class RufletRunInterceptorTest < Minitest::Test
  def test_run_short_circuits_when_interceptor_handles_execution
    interceptor = ->(**) { :handled }

    result = Ruflet.with_run_interceptor(interceptor) do
      Ruflet.run { nil }
    end

    assert_equal :handled, result
  end
end
```

### Step 4 — Run only that file
From the package directory:

```bash
/opt/homebrew/opt/ruby/bin/ruby -Ilib -Itest test/run_interceptor_test.rb
```

### Step 5 — Add neighboring tests in separate files
Examples:
- `packages/ruflet/test/manifest_compiler_test.rb`
- `packages/ruflet_server/test/wire_codec_test.rb`
- `packages/ruflet_server/test/server_bind_test.rb`
- `packages/ruflet_cli/test/new_command_test.rb`
- `packages/ruflet_cli/test/templates_test.rb`

### Step 6 — Verify each gem independently
Run tests per gem package, not as one global monolith.

```bash
cd packages/ruflet
/opt/homebrew/opt/ruby/bin/ruby -Ilib -Itest test/run_interceptor_test.rb
/opt/homebrew/opt/ruby/bin/ruby -Ilib -Itest test/manifest_compiler_test.rb

cd ../ruflet_server
/opt/homebrew/opt/ruby/bin/ruby -Ilib -Itest test/wire_codec_test.rb
/opt/homebrew/opt/ruby/bin/ruby -Ilib -Itest test/server_bind_test.rb

cd ../ruflet_cli
/opt/homebrew/opt/ruby/bin/ruby -Ilib -Itest test/new_command_test.rb
/opt/homebrew/opt/ruby/bin/ruby -Ilib -Itest test/templates_test.rb
```

### Testing Checklist
- One behavior per test file.
- No cross-gem coupling in assertions.
- No hidden network dependency for unit tests.
- Deterministic assertions (no timing-sensitive flakiness).
- Tests runnable directly from each package.

