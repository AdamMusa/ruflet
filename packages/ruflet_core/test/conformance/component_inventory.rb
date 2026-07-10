# frozen_string_literal: true

require "json"
require "open3"
require "set"

module RufletFletComponentInventory
  ROOT = File.expand_path("../../../..", __dir__)
  OVERRIDES_PATH = File.expand_path("component_inventory_overrides.json", __dir__)

  PYTHON_SNIPPET = <<~PY
    import flet as ft, inspect
    classes = []
    for name in dir(ft):
        obj = getattr(ft, name)
        if inspect.isclass(obj):
            if any(getattr(base, "__name__", "") in ("Control", "BaseControl") for base in getattr(obj, "__mro__", ())):
                classes.append(name)
    print("\\n".join(sorted(set(classes))))
  PY

  module_function

  def python_executable
    ENV["RUFLET_FLET_PYTHON"] || "/tmp/ruflet-flet-venv/bin/python"
  end

  def python_controls
    stdout, stderr, status = Open3.capture3(python_executable, "-c", PYTHON_SNIPPET)
    raise "Python Flet inventory failed: #{stderr}" unless status.success?

    stdout.lines.map(&:strip).reject(&:empty?).to_set
  end

  def ruflet_controls
    Dir[File.join(ROOT, "packages/ruflet_core/lib/ruflet_ui/ruflet/ui/controls/**/*_control.rb")].filter_map do |file|
      File.read(file)[/WIRE = "([^"]+)"/, 1]
    end.to_set
  end

  def ruflet_services
    Dir[File.join(ROOT, "packages/ruflet_core/lib/ruflet_ui/ruflet/ui/services/**/*_control.rb")].filter_map do |file|
      File.read(file)[/WIRE = "([^"]+)"/, 1]
    end.to_set
  end

  def overrides
    JSON.parse(File.read(OVERRIDES_PATH))
  end

  def inventory
    data = overrides
    python = python_controls
    ruflet = ruflet_controls
    ruflet_service_controls = ruflet_services
    abstract = data.fetch("abstract").to_set
    aliases = data.fetch("aliases")
    services = data.fetch("services").to_set
    todo_controls = data.fetch("todo_controls").to_set

    missing = python - ruflet - abstract
    service_missing = missing & services
    service_covered = service_missing & ruflet_service_controls
    {
      python_count: python.length,
      ruflet_count: ruflet.length,
      ruflet_service_count: ruflet_service_controls.length,
      implemented: (python & ruflet).sort,
      aliases: aliases.keys.sort,
      service_covered: service_covered.sort,
      service_deferred: (service_missing - service_covered).sort,
      todo_controls: (missing & todo_controls).sort,
      unclassified_missing: (missing - services - todo_controls - aliases.keys.to_set).sort,
      ruflet_extra: (ruflet - python).sort
    }
  end

  def markdown
    inv = inventory
    sections = []
    sections << "# Python Flet Component Inventory"
    sections << ""
    sections << "- Python Flet controls: #{inv[:python_count]}"
    sections << "- Ruflet wire controls: #{inv[:ruflet_count]}"
    sections << "- Ruflet service controls: #{inv[:ruflet_service_count]}"
    sections << "- Implemented Python controls: #{inv[:implemented].length}"
    sections << "- Alias-covered controls: #{inv[:aliases].length}"
    sections << "- Service-covered controls: #{inv[:service_covered].length}"
    sections << "- Service-deferred controls: #{inv[:service_deferred].length}"
    sections << "- Todo UI controls: #{inv[:todo_controls].length}"
    sections << "- Unclassified missing controls: #{inv[:unclassified_missing].length}"
    sections << ""
    sections << "## Todo UI Controls"
    sections.concat(markdown_list(inv[:todo_controls]))
    sections << ""
    sections << "## Alias Covered"
    sections.concat(inv[:aliases].map { |name| "- #{name}: #{overrides.fetch("aliases").fetch(name)}" })
    sections << ""
    sections << "## Service-Covered Controls"
    sections.concat(markdown_list(inv[:service_covered]))
    sections << ""
    sections << "## Service-Deferred Controls"
    sections.concat(markdown_list(inv[:service_deferred]))
    sections << ""
    sections << "## Unclassified Missing"
    sections.concat(markdown_list(inv[:unclassified_missing]))
    sections << ""
    sections << "## Ruflet Extra Or Non-Python Wire Controls"
    sections.concat(markdown_list(inv[:ruflet_extra]))
    sections.join("\n")
  end

  def markdown_list(items)
    return ["None."] if items.empty?

    items.map { |name| "- #{name}" }
  end
end

if $PROGRAM_NAME == __FILE__
  puts RufletFletComponentInventory.markdown
end
