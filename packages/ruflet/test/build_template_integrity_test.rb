# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"

class RufletCliBuildTemplateIntegrityTest < Minitest::Test
  class Builder
    include Ruflet::CLI::BuildCommand
  end

  def with_template
    Dir.mktmpdir("ruflet template integrity ") do |template|
      files = {
        "ruflet/pubspec.yaml" => "name: ruflet\nversion: 0.81.0\n",
        "ruflet/lib/ruflet.dart" => "library ruflet;\n"
      }
      files.each do |relative, content|
        path = File.join(template, "ruflet_packages", relative)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, content)
      end

      manifest = {
        "manifest_version" => 5,
        "package_name" => "ruflet-engine",
        "source_ref" => "a" * 40,
        "files" => files.to_h do |relative, content|
          [relative, {
            "classification" => "exact_source",
            "source_path" => relative,
            "vendored_sha256" => Digest::SHA256.hexdigest(content)
          }]
        end
      }
      manifest_path = File.join(
        template,
        Ruflet::CLI::BuildCommand::RUFLET_SOURCE_INTEGRITY_PATH
      )
      FileUtils.mkdir_p(File.dirname(manifest_path))
      File.write(manifest_path, JSON.generate(manifest))
      yield Builder.new, template, manifest_path
    end
  end

  def verify(builder, template)
    result = nil
    capture_io do
      result = builder.send(:validate_template_ruflet_source_integrity, template)
    end
    result
  end

  def test_accepts_exact_pinned_engine_source
    with_template do |builder, template, _manifest_path|
      assert verify(builder, template)
    end
  end

  def test_rejects_modified_engine_source
    with_template do |builder, template, _manifest_path|
      File.write(
        File.join(template, "ruflet_packages", "ruflet", "lib", "ruflet.dart"),
        "library modified;\n"
      )

      refute verify(builder, template)
    end
  end

  def test_rejects_untracked_engine_source
    with_template do |builder, template, _manifest_path|
      File.write(
        File.join(template, "ruflet_packages", "ruflet", "lib", "dead_copy.dart"),
        "library dead_copy;\n"
      )

      refute verify(builder, template)
    end
  end

  def test_rejects_template_without_source_manifest
    with_template do |builder, template, manifest_path|
      File.delete(manifest_path)

      refute verify(builder, template)
    end
  end
end
