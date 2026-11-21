# frozen_string_literal: true

# Boots a minimal Rails app the way a host app loads ruflet_rails (the gem is
# required before the app initializes, as Bundler.require does from
# config/application.rb), renders each template below through a real request
# and prints what came back as a single JSON line.
#
# rails_form_helpers_test.rb runs it twice in its own processes: once with
# ruflet_rails and once without it (WITHOUT_RUFLET=1), so it can compare the
# markup Action View renders on its own with what it renders once ruflet_rails
# is installed. A booted Rails app must not share a process with the other test
# files, some of which stub ::Rails.
#
#   ruby -Ilib test/support/rails_form_helpers_app.rb
#   WITHOUT_RUFLET=1 ruby -Ilib test/support/rails_form_helpers_app.rb

require "json"
require "tmpdir"
require "fileutils"
require "logger"

RESULT_MARKER = "RUFLET_FORM_HELPERS_RESULT "

def report(result)
  $stdout.puts(RESULT_MARKER + JSON.generate(result))
  $stdout.flush
  # exit! skips at_exit, so remove the app directory here.
  FileUtils.rm_rf(APP_ROOT) if defined?(APP_ROOT)
  exit!(0)
end

begin
  require "rails"
  require "action_controller/railtie"
  require "active_model"
rescue LoadError => e
  report("skip" => "Rails is not available: #{e.message}")
end

WITH_RUFLET = ENV["WITHOUT_RUFLET"].to_s.empty?
require "ruflet_rails" if WITH_RUFLET

class Post
  include ActiveModel::Model
  attr_accessor :title, :body, :published, :tag_ids

  def persisted? = false
end

# Templates an ordinary Rails web page uses: the form builder, form_for, and
# Action View's form helpers called directly.
RAILS_CASES = {
  "form_with_text_field" => '<%= form_with model: Post.new, url: "/posts" do |f| %><%= f.text_field :title %><% end %>',
  "form_with_text_field_options" => '<%= form_with model: Post.new, url: "/posts" do |f| %><%= f.text_field :title, class: "input", placeholder: "Title" %><% end %>',
  "form_with_text_area" => '<%= form_with model: Post.new, url: "/posts" do |f| %><%= f.text_area :body, rows: 4 %><% end %>',
  "form_with_check_box" => '<%= form_with model: Post.new, url: "/posts" do |f| %><%= f.check_box :published %><% end %>',
  "form_with_check_box_values" => '<%= form_with model: Post.new, url: "/posts" do |f| %><%= f.check_box :published, {}, "yes", "no" %><% end %>',
  "form_with_collection_check_boxes" => '<%= form_with model: Post.new, url: "/posts" do |f| %><%= f.collection_check_boxes :tag_ids, [[1, "Ruby"], [2, "Rails"]], :first, :last %><% end %>',
  "form_with_label_and_email" => '<%= form_with model: Post.new, url: "/posts" do |f| %><%= f.label :title %><%= f.email_field :title %><% end %>',
  "form_for_text_field" => '<%= form_for Post.new, url: "/posts" do |f| %><%= f.text_field :title %><% end %>',
  "fields_for_text_field" => '<%= fields_for :post, Post.new do |f| %><%= f.text_field :title %><% end %>',
  "direct_text_field" => "<%= text_field :post, :title %>",
  "direct_text_field_options" => '<%= text_field :post, :title, class: "input" %>',
  "direct_text_area" => "<%= text_area :post, :body %>",
  "direct_check_box" => "<%= check_box :post, :published %>",
  "text_field_tag" => "<%= text_field_tag :q %>"
}
# Rails 8 added textarea and checkbox (text_area and check_box became their
# aliases); Rails 7 has only the older names.
if ActionView::Helpers::FormBuilder.method_defined?(:textarea)
  RAILS_CASES.merge!(
    "form_with_textarea" => '<%= form_with model: Post.new, url: "/posts" do |f| %><%= f.textarea :body %><% end %>',
    "form_with_checkbox" => '<%= form_with model: Post.new, url: "/posts" do |f| %><%= f.checkbox :published %><% end %>',
    "direct_textarea" => "<%= textarea :post, :body %>",
    "direct_textarea_options" => "<%= textarea :post, :body, rows: 4 %>",
    "direct_checkbox" => "<%= checkbox :post, :published %>"
  )
end

# Ruflet HTML DSL helpers written in the same app's views.
DSL_CASES = {
  "dsl_text_field" => '<%= text_field label: "Name", name: "name" %>',
  "dsl_text_field_content" => '<%= text_field "Ada" %>',
  "dsl_textarea" => '<%= textarea "bio", "Hi", rows: 3 %>',
  "dsl_textarea_symbol_name" => '<%= textarea :bio, "Hi" %>',
  "dsl_textarea_name_only" => "<%= textarea :bio %>",
  "dsl_checkbox" => '<%= checkbox name: "ok", label: "Agree" %>',
  "dsl_form" => '<%= form action: "/signup" do %><%= text_field name: "email" %><%= checkbox name: "terms" %><%= textarea "note" %><% end %>'
}

CASES = WITH_RUFLET ? RAILS_CASES.merge(DSL_CASES) : RAILS_CASES

APP_ROOT = Dir.mktmpdir("ruflet-rails-form-helpers")
at_exit { FileUtils.rm_rf(APP_ROOT) }
FileUtils.mkdir_p(File.join(APP_ROOT, "config"))
File.write(File.join(APP_ROOT, "config/routes.rb"), <<~RUBY)
  Rails.application.routes.draw { get "/render/:case", to: "pages#show" }
RUBY

class FormHelpersApp < Rails::Application
  config.load_defaults "#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}"
  config.root = APP_ROOT
  config.eager_load = false
  config.secret_key_base = "x" * 64
  config.logger = Logger.new(nil)
  config.active_support.deprecation = :silence
  config.hosts.clear
  config.consider_all_requests_local = true
  config.action_dispatch.show_exceptions = :none
  # Keep the markup deterministic: no per-request authenticity token.
  config.action_controller.allow_forgery_protection = false
end

FormHelpersApp.initialize!

class PagesController < ActionController::Base
  def show = render(inline: CASES.fetch(params[:case]))
end

result = {
  "ruflet_rails" => WITH_RUFLET,
  "rails" => Rails.version,
  "rails_cases" => RAILS_CASES.keys,
  "rendered" => CASES.keys.to_h do |name|
    status, _headers, body = FormHelpersApp.call(Rack::MockRequest.env_for("http://localhost/render/#{name}"))
    html = +""
    body.each { |part| html << part }
    body.close if body.respond_to?(:close)
    [name, status == 200 ? html : "HTTP #{status}"]
  rescue StandardError, ScriptError => e
    [name, "RAISED #{e.class}: #{e.message}"]
  end
}
report(result)
