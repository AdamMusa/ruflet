# frozen_string_literal: true

require "tmpdir"
require_relative "test_helper"

class RufletRuntimeErrorReportingTest < Minitest::Test
  def test_reports_callback_error_to_runtime_status_file
    Dir.mktmpdir do |directory|
      path = File.join(directory, ".ruflet-runtime.error")
      previous_path = ENV["RUFLET_RUNTIME_ERROR_FILE"]
      ENV["RUFLET_RUNTIME_ERROR_FILE"] = path
      server = Ruflet::Server.new { |_page| nil }

      error = RuntimeError.new("callback failed")
      error.set_backtrace(["main.rb:12:in `block in <main>'"])
      server.send(:report_runtime_error, error, "handle_message")

      report = File.read(path)
      assert_includes report, "handle_message: RuntimeError: callback failed"
      assert_includes report, "main.rb:12:in `block in <main>'"
    ensure
      ENV["RUFLET_RUNTIME_ERROR_FILE"] = previous_path
    end
  end
end
