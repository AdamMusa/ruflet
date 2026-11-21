# frozen_string_literal: true

require_relative "test_helper"
require "action_controller"
require "action_view"
require "minitest/mock"
require "fileutils"
require "open3"
require "rbconfig"

# erb_to_native calls a screen's action directly, with no request, so the
# controller's callbacks do not run. That stays as it is; what this pins down
# is that it is no longer silent: the first time a controller class with
# callbacks of the app's own serves a screen, one log line names them.
class RufletSkippedCallbacksTest < Minitest::Test
  SkippedCallbacks = Ruflet::Rails::HtmlDsl::TemplateSource::SkippedCallbacks

  # What a gem that installs a callback on every controller looks like
  # (turbo-rails' request id tracking, paper_trail's whodunnit). Every
  # controller inherits it; it is not something the app declared.
  module GemInstalledCallback
    def self.included(base) = base.before_action(:ruflet_test_gem_callback)

    private

    def ruflet_test_gem_callback; end
  end
  ActionController::Base.include(GemInstalledCallback)

  # The same on ActionController::API, whose chain an API-only controller
  # inherits instead of Base's.
  module ApiGemInstalledCallback
    def self.included(base) = base.before_action(:ruflet_test_api_gem_callback)

    private

    def ruflet_test_api_gem_callback; end
  end
  ActionController::API.include(ApiGemInstalledCallback)

  CALLS = []

  class CbguardedController < ActionController::Base
    before_action :require_admin!
    around_action :wrap
    after_action { CALLS << :after_block }

    def home = @secret = "admin data"

    private

    def require_admin!
      CALLS << :require_admin!
      raise "not an admin"
    end

    def wrap
      CALLS << :wrap
      yield
    end
  end

  class CbplainController < ActionController::Base
    def home = @secret = "plain"
  end

  # Callbacks Rails itself declares guard parts of a request that do not
  # exist for a native screen.
  class CbframeworkController < ActionController::Base
    protect_from_forgery with: :exception
    allow_browser versions: :modern if respond_to?(:allow_browser)

    def home = @secret = "framework"
  end

  class CbapiController < ActionController::API
    before_action :authenticate!

    def home; end

    private

    def authenticate!; end
  end

  # One block per action, declared on one line: two callbacks, one name.
  class CbrepeatedController < ActionController::Base
    %w[home other].each { |action| before_action(only: action) { CALLS << action } }

    def home; end

    def other; end
  end

  VIEWS = Dir.mktmpdir("ruflet-skipped-callbacks")
  Minitest.after_run { FileUtils.rm_rf(VIEWS) }
  [CbguardedController, CbplainController, CbframeworkController].each do |klass|
    FileUtils.mkdir_p(File.join(VIEWS, klass.controller_path))
    File.write(File.join(VIEWS, klass.controller_path, "home.html.erb"), "<text><%= @secret %></text>")
  end
  ActionController::Base.prepend_view_path(VIEWS)

  def setup
    { CbguardedController: CbguardedController, CbplainController: CbplainController,
      CbframeworkController: CbframeworkController }.each do |name, klass|
      Object.const_set(name, klass) unless Object.const_defined?(name)
    end
    CALLS.clear
    SkippedCallbacks.reset!
    @logged = []
  end

  def fetch(path)
    SkippedCallbacks.stub(:log, ->(message) { @logged << message }) do
      Ruflet::Rails::HtmlDsl::TemplateSource.new.fetch(path).body
    end
  end

  def test_a_controller_with_its_own_callbacks_is_named_once
    body = fetch("/cbguarded")

    # The behavior is unchanged: the action runs, the callbacks do not.
    assert_includes body, "<text>admin data</text>"
    assert_empty CALLS

    assert_equal 1, @logged.length
    line = @logged.first
    assert_includes line, "[ruflet_rails] RufletSkippedCallbacksTest::CbguardedController:"
    assert_includes line, "before_action :require_admin!"
    assert_includes line, "around_action :wrap"
    assert_match %r{after_action \(block at [^)]*skipped_callbacks_test\.rb:\d+\)}, line
    assert_includes line, "do not run for erb_to_native screens"
    assert_includes line, "RUFLET_RAILS_QUIET_CALLBACKS=1"
    refute_includes line, "ruflet_test_gem_callback"

    # A second session, and a second screen of the same session, stay quiet.
    fetch("/cbguarded")
    source = Ruflet::Rails::HtmlDsl::TemplateSource.new
    SkippedCallbacks.stub(:log, ->(message) { @logged << message }) { 2.times { source.fetch("/cbguarded") } }
    assert_equal 1, @logged.length
  end

  def test_inherited_and_framework_callbacks_are_not_listed
    assert_includes fetch("/cbplain"), "<text>plain</text>"
    assert_includes fetch("/cbframework"), "<text>framework</text>"

    assert_empty @logged
    assert_empty SkippedCallbacks.skipped(CbplainController)
    assert_empty SkippedCallbacks.skipped(CbframeworkController)
  end

  def test_the_line_can_be_silenced
    ENV["RUFLET_RAILS_QUIET_CALLBACKS"] = "1"
    assert_includes fetch("/cbguarded"), "<text>admin data</text>"
    assert_empty @logged
  ensure
    ENV.delete("RUFLET_RAILS_QUIET_CALLBACKS")
  end

  def test_a_failure_while_reporting_never_breaks_the_screen
    SkippedCallbacks.stub(:skipped, ->(_klass) { raise "boom" }) do
      assert_includes fetch("/cbguarded"), "<text>admin data</text>"
    end
    assert_empty @logged
  end

  def test_a_plain_class_without_a_callback_chain_is_ignored
    assert_empty SkippedCallbacks.skipped(Class.new)
  end

  def test_an_api_controller_lists_its_own_callbacks_but_not_inherited_ones
    assert_equal ["before_action :authenticate!"], SkippedCallbacks.skipped(CbapiController)
  end

  def test_blocks_declared_on_one_line_are_listed_once
    names = SkippedCallbacks.skipped(CbrepeatedController)

    assert_equal 1, names.length, names.inspect
    assert_match %r{\Abefore_action \(block at [^)]*skipped_callbacks_test\.rb:\d+\)\z}, names.first
  end

  # Loading a controller base runs its load hooks, so reporting must not load
  # one the app has not. That needs a process where ActionController::API is
  # still an autoload, which this one is not (it is used above).
  def test_reporting_does_not_load_an_unused_controller_base
    script = <<~RUBY
      require "action_controller"
      require #{File.expand_path("../lib/ruflet_rails", __dir__).dump}
      abort "ActionController::API is already loaded" unless ActionController.autoload?(:API)
      klass = Class.new(ActionController::Base) { before_action :guard; def guard; end }
      names = Ruflet::Rails::HtmlDsl::TemplateSource::SkippedCallbacks.skipped(klass)
      puts [names, ActionController.autoload?(:API) ? :not_loaded : :loaded].inspect
    RUBY
    out, status = Open3.capture2e(RbConfig.ruby, *$LOAD_PATH.flat_map { |dir| ["-I", dir] }, "-e", script)

    assert status.success?, out
    assert_equal %([["before_action :guard"], :not_loaded]), out.lines.last.to_s.strip
  end
end
