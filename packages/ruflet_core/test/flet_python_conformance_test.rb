# frozen_string_literal: true

require_relative "test_helper"
require_relative "conformance/component_inventory"
require "json"
require "open3"
require "set"
require "tempfile"

class RufletFletPythonConformanceTest < Minitest::Test
  CASES_PATH = File.expand_path("conformance/flet_cases.json", __dir__)
  OBSERVER_PATH = File.expand_path("conformance/observe_flet.py", __dir__)

  def setup
    @cases = JSON.parse(File.read(CASES_PATH)).fetch("cases") + auto_smoke_cases
    @python_observations = load_python_observations
  end

  def test_ruflet_matches_python_flet_control_conformance_cases
    @cases.each do |test_case|
      python_case = @python_observations.fetch(test_case.fetch("name"))
      ruby_case = observe_ruflet(test_case)

      if test_case.fetch("expect_status", "ok") == "error"
        assert_equal "error", python_case.fetch("status"), "#{test_case.fetch("name")} should fail in Python Flet"
        assert_equal "error", ruby_case.fetch("status"), "#{test_case.fetch("name")} should fail in Ruflet"
        next
      end

      assert_equal "ok", python_case.fetch("status"), "#{test_case.fetch("name")} failed in Python Flet"
      assert_equal "ok", ruby_case.fetch("status"), "#{test_case.fetch("name")} failed in Ruflet: #{ruby_case["error_class"]} #{ruby_case["error_message"]}"
      ruby_patch = ruby_case.fetch("patch")
      assert_equal test_case.fetch("expected_wire"), ruby_patch.fetch("_c"), "#{test_case.fetch("name")} wire control"

      skip_props = test_case.fetch("skip_props", [])
      test_case.fetch("props").each_key do |prop|
        next if skip_props.include?(prop)

        if python_case.fetch("props").key?(prop) && !python_case.fetch("props").fetch(prop).nil?
          assert_equal(
            canonical_expected_prop(prop, python_case.fetch("props").fetch(prop)),
            ruby_patch.fetch(prop),
            "#{test_case.fetch("name")} #{prop}"
          )
        else
          refute ruby_patch.key?(prop), "#{test_case.fetch("name")} should omit nil #{prop}"
        end
      end
    end
  end

  private

  def auto_smoke_cases
    explicit_classes = JSON.parse(File.read(CASES_PATH)).fetch("cases").map { |test_case| test_case.fetch("python_class") }.to_set
    inventory = RufletFletComponentInventory.inventory
    abstract = RufletFletComponentInventory.overrides.fetch("abstract").to_set

    (inventory[:implemented] - explicit_classes.to_a - abstract.to_a).map do |python_class|
      {
        "name" => "auto_#{snake_control_name(python_class)}",
        "python_class" => python_class,
        "ruby_control_type" => snake_control_name(python_class),
        "props" => auto_smoke_props(python_class),
        "expected_wire" => python_class,
        "skip_props" => auto_smoke_skip_props(python_class)
      }
    end
  end

  def auto_smoke_props(python_class)
    {
      "AnimatedSwitcher" => { "content" => "Body" },
      "AutofillGroup" => { "content" => "Body" },
      "BottomSheet" => { "content" => "Body" },
      "ContextMenu" => { "content" => "Body" },
      "CupertinoActionSheetAction" => { "content" => "Body" },
      "CupertinoBottomSheet" => { "content" => "Body" },
      "CupertinoContextMenuAction" => { "content" => "Body" },
      "CupertinoDialogAction" => { "content" => "Body" },
      "CupertinoSegmentedButton" => { "controls" => {} },
      "CupertinoSlidingSegmentedButton" => { "controls" => {} },
      "DataCell" => { "content" => "Cell" },
      "DataColumn" => { "label" => "Column" },
      "Dismissible" => { "content" => "Body" },
      "DragTarget" => { "content" => "Body" },
      "Draggable" => { "content" => "Body" },
      "Hero" => { "tag" => "hero", "content" => "Body" },
      "Icon" => { "icon" => "home" },
      "Image" => { "src" => "https://example.com/image.png" },
      "InteractiveViewer" => { "content" => "Body" },
      "KeyboardListener" => { "content" => "Body" },
      "NavigationBarDestination" => { "icon" => "home" },
      "NavigationDrawerDestination" => { "label" => "Label", "icon" => "home" },
      "NavigationRailDestination" => { "icon" => "home" },
      "Pagelet" => { "content" => "Body" },
      "RadioGroup" => { "content" => "one" },
      "ReorderableDragHandle" => { "content" => "Body" },
      "SafeArea" => { "content" => "Body" },
      "Segment" => { "value" => "one" },
      "SelectionArea" => { "content" => "Body" },
      "ShaderMask" => { "shader" => "linear" },
      "Shimmer" => { "content" => "Body" },
      "Tabs" => { "content" => [], "length" => 0 },
      "WindowDragArea" => { "content" => "Body" }
    }.fetch(python_class, {})
  end

  def auto_smoke_skip_props(python_class)
    {
      "CupertinoSegmentedButton" => ["controls"],
      "CupertinoSlidingSegmentedButton" => ["controls"],
      "Icon" => ["icon"],
      "NavigationBarDestination" => ["icon"],
      "NavigationDrawerDestination" => ["icon"],
      "NavigationRailDestination" => ["icon"]
    }.fetch(python_class, [])
  end

  def snake_control_name(name)
    name.gsub(/([a-z\d])([A-Z])/, "\\1_\\2").downcase
  end

  def load_python_observations
    python = ENV["RUFLET_FLET_PYTHON"]
    python ||= "/tmp/ruflet-flet-venv/bin/python" if File.executable?("/tmp/ruflet-flet-venv/bin/python")
    python ||= "python3"

    cases_file = Tempfile.new(["ruflet-flet-cases", ".json"])
    cases_file.write(JSON.generate("cases" => @cases))
    cases_file.close

    stdout, stderr, status = Open3.capture3(python, OBSERVER_PATH, cases_file.path)
    if !status.success? && stderr.include?("No module named 'flet'")
      skip "Python Flet is not installed; set RUFLET_FLET_PYTHON to a Python with flet"
    end
    assert status.success?, stderr

    JSON.parse(stdout).fetch("cases").to_h { |entry| [entry.fetch("name"), entry] }
  ensure
    cases_file&.unlink
  end

  def observe_ruflet(test_case)
    props = symbolize_keys(test_case.fetch("ruby_props", test_case.fetch("props")))
    control = if test_case.key?("ruby_control_type")
                Ruflet.control(test_case.fetch("ruby_control_type"), **props)
              else
                Ruflet.public_send(test_case.fetch("ruby_method"), **props)
              end
    patch = control.to_patch
    { "status" => "ok", "patch" => patch }
  rescue StandardError => e
    { "status" => "error", "error_class" => e.class.name, "error_message" => e.message }
  end

  def symbolize_keys(value)
    case value
    when Hash
      value.to_h { |key, nested| [key.to_sym, symbolize_keys(nested)] }
    when Array
      value.map { |nested| symbolize_keys(nested) }
    else
      value
    end
  end

  def canonical_expected_prop(prop, value)
    if prop.end_with?("color") || prop == "bgcolor"
      return value.downcase if value.is_a?(String) && value.start_with?("#")
    end

    value
  end
end
