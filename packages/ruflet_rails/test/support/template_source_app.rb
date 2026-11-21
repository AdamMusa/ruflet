# frozen_string_literal: true

# Boots a minimal Rails app in this process (development reloading, the
# ruflet_rails Railtie loaded) with a NativeController and its ERB screens,
# fetches screens through Ruflet::Rails::HtmlDsl::TemplateSource, the fetcher
# erb_to_native uses in production, and prints what came back as one JSON line.
#
# template_source_test.rb runs it in its own process: a booted Rails app must
# not share a process with the other test files, some of which stub ::Rails.
#
#   ruby -Ilib test/support/template_source_app.rb

require "json"
require "tmpdir"
require "fileutils"
require "logger"

RESULT_MARKER = "RUFLET_TEMPLATE_SOURCE_RESULT "

def report(result)
  $stdout.puts(RESULT_MARKER + JSON.generate(result))
  $stdout.flush
  FileUtils.rm_rf(APP_ROOT) if defined?(APP_ROOT)
  exit!(0)
end

Thread.new do
  sleep 60
  report("error" => "scenario did not finish within 60s")
end

begin
  require "rails"
  require "action_controller/railtie"
rescue LoadError => e
  report("skip" => "Rails is not available: #{e.message}")
end

APP_ROOT = Dir.mktmpdir("ruflet-template-source")
at_exit { FileUtils.rm_rf(APP_ROOT) }

def write(relative, body)
  path = File.join(APP_ROOT, relative)
  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, body)
end

write("config/routes.rb", "Rails.application.routes.draw { }\n")
write("app/helpers/application_helper.rb", <<~RUBY)
  module ApplicationHelper
    def shout(value) = value.to_s.upcase
  end
RUBY
write("app/controllers/native_controller.rb", <<~RUBY)
  class NativeController < ActionController::Base
    def home
      @who = "ada"
    end

    def counter
      @count = session[:count].to_i
    end

    # No template of its own: it changes state, and counter.html.erb shows it.
    def counter_increment
      session[:count] = session[:count].to_i + 1
    end

    def go_counter
      redirect_to "/native/counter"
    end

    def loop_forever
      redirect_to "/native/loop_forever"
    end

    def summary
      @count = 99
      render :counter
    end

    def device
      @feature = params[:id]
    end

    def greet
      @name = params[:name]
    end
  end
RUBY
write("app/views/native/home.html.erb", <<~ERB)
  <column><text>home <%= shout(@who) %></text><%= button "Up", on_click: "/native/counter/increment" %><%= render "nav" %></column>
ERB
write("app/views/native/_nav.html.erb", "<text>nav</text>\n")
write("app/views/native/counter.html.erb", "<column><text>count <%= @count %></text></column>\n")
write("app/views/native/device.html.erb", "<text>feature <%= @feature %></text>\n")
write("app/views/native/greet.html.erb", "<text>hi <%= @name %></text>\n")

class TemplateSourceApp < Rails::Application
  config.load_defaults "#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}"
  config.root = APP_ROOT
  config.enable_reloading = true # the development default
  config.eager_load = false
  config.secret_key_base = "x" * 64
  config.logger = Logger.new(nil)
  config.active_support.deprecation = :silence
  config.hosts.clear
end

# Before initialize!, as Bundler.require loads it in a real app, so the
# Railtie's initializers (the view helpers among them) run.
require "ruflet_rails"
TemplateSourceApp.initialize!

source = Ruflet::Rails::HtmlDsl::TemplateSource.new
fetch = lambda do |url, params = nil|
  response = source.fetch(url, params: params)
  { "url" => response.url, "body" => response.body.to_s.gsub(/\s+/, " ").strip }
end

result = {}
result["home"] = fetch.call("/native")
result["counter"] = fetch.call("/native/counter")
result["increment_1"] = fetch.call("/native/counter/increment")
result["increment_2"] = fetch.call("/native/counter/increment")
result["redirect"] = fetch.call("/native/go_counter")
result["redirect_loop"] = fetch.call("/native/loop_forever")
result["render_other"] = fetch.call("/native/summary")
result["path_param"] = fetch.call("/native/device/camera")
result["form_params"] = fetch.call("/native/greet", { "name" => "Grace" })
result["missing"] = fetch.call("/native/nowhere")

# A developer edits a screen while the client is connected. A stat is all
# that tells the fetcher, so step the mtime past the first render's.
counter = File.join(APP_ROOT, "app/views/native/counter.html.erb")
File.write(counter, "<column><text>tally <%= @count %></text></column>\n")
later = Time.now + 5
File.utime(later, later, counter)
result["edited"] = fetch.call("/native/counter")

report(result)
