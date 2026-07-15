# frozen_string_literal: true

require_relative "test_helper"

class RufletExamplesApiTest < Minitest::Test
  EXAMPLE_FILES = Dir[File.expand_path("../../../examples/*.rb", __dir__)].sort.freeze

  def test_top_level_examples_match_supported_text_and_icon_api
    EXAMPLE_FILES.each do |file|
      contents = File.read(file)

      refute_match(/text\((?![^\)]*style:)[^\)]*,\s*(size|color|weight):/, contents, "#{File.basename(file)} should put text styling inside style: { ... }")
      refute_match(/icon\(icon:/, contents, "#{File.basename(file)} should not wrap icon(icon: ...)")
    end
  end
end
