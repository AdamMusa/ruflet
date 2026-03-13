# frozen_string_literal: true

require_relative "test_helper"

class RufletExamplesApiTest < Minitest::Test
  EXAMPLE_FILES = Dir[File.expand_path("../../../examples/*.rb", __dir__)].sort.freeze

  def test_top_level_examples_use_new_shorthand_api
    EXAMPLE_FILES.each do |file|
      contents = File.read(file)

      refute_match(/text\(value:/, contents, "#{File.basename(file)} should use text(...) shorthand")
      refute_match(/icon\(icon:/, contents, "#{File.basename(file)} should not wrap icon(icon: ...)")
    end
  end
end
