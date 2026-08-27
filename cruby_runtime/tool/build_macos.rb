# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "pathname"
require "yaml"

module Ruflet
  module CRubyRuntime
    class MacOSBuilder
      RUBY_VERSION = "4.0.5"
      RUBY_ABI = "4.0.0"
      RUBY_ARCHES = {
        "arm64" => "arm64-darwin25",
        "x86_64" => "x86_64-darwin25"
      }.freeze
      RUBY_ARCHIVE_SHA256 = "7d6149079a63f8ae1d326c9fa65c6019ba2dc3155eae7b39159817911c88958e"
      MACOS_DEPLOYMENT_TARGET = "11.0"

      def initialize(output: nil)
        @repo_root = Pathname.new(__dir__).join("../..").expand_path
        @lite_root = @repo_root.join("ruby_runtime")
        @source_root = @repo_root.join("cruby_runtime")
        @build_root = @repo_root.join("build/cruby_runtime")
        @output = Pathname.new(output || @build_root.join("macos-universal")).expand_path
        @ruby_source = @build_root.join("sources/ruby-#{RUBY_VERSION}")
        @ruby_library_name = "libruby.#{RUBY_ABI.split('.').first(2).join('.')}.dylib"
      end

      def build
        validate_tools!
        ensure_ruby_source!
        RUBY_ARCHES.each_key { |architecture| ensure_ruby_build!(architecture) }
        FileUtils.rm_rf(@output)
        create_package
        copy_ruby
        build_vm_archive
        write_manifest
        puts @output
      end

      private

      def validate_tools!
        %w[ar clang++ curl install_name_tool lipo make tar].each do |tool|
          abort "Missing required tool: #{tool}" unless system("command", "-v", tool, out: File::NULL)
        end
      end

      def ensure_ruby_source!
        archive = @build_root.join("sources/ruby-#{RUBY_VERSION}.tar.gz")
        FileUtils.mkdir_p(archive.dirname)
        unless archive.file? && Digest::SHA256.file(archive).hexdigest == RUBY_ARCHIVE_SHA256
          FileUtils.rm_f(archive)
          run!("curl", "-fL", "https://cache.ruby-lang.org/pub/ruby/4.0/ruby-#{RUBY_VERSION}.tar.gz",
               "-o", archive.to_s)
        end
        abort "Ruby source checksum mismatch" unless Digest::SHA256.file(archive).hexdigest == RUBY_ARCHIVE_SHA256
        return if @ruby_source.join("configure").file?

        FileUtils.rm_rf(@ruby_source)
        run!("tar", "-xzf", archive.to_s, "-C", archive.dirname.to_s)
      end

      def ensure_ruby_build!(architecture)
        build_dir = ruby_build_dir(architecture)
        marker = build_dir.join(".ruflet-cruby-#{RUBY_VERSION}-macos#{MACOS_DEPLOYMENT_TARGET}")
        library = ruby_stage(architecture).join("lib", @ruby_library_name)
        return if marker.file? && library.file?

        FileUtils.rm_rf(build_dir)
        FileUtils.mkdir_p(build_dir)
        arch_flags = "-arch #{architecture} -mmacosx-version-min=#{MACOS_DEPLOYMENT_TARGET}"
        environment = {
          "MACOSX_DEPLOYMENT_TARGET" => MACOS_DEPLOYMENT_TARGET,
          "CC" => "clang -arch #{architecture}",
          "CXX" => "clang++ -arch #{architecture}",
          "CFLAGS" => "-mmacosx-version-min=#{MACOS_DEPLOYMENT_TARGET}",
          "CXXFLAGS" => "-mmacosx-version-min=#{MACOS_DEPLOYMENT_TARGET}",
          "LDFLAGS" => arch_flags
        }
        configure = [
          @ruby_source.join("configure").to_s,
          "--prefix=/ruflet-cruby",
          "--enable-shared",
          "--enable-load-relative",
          "--with-static-linked-ext",
          "--with-out-ext=-test-,win32,win32ole",
          "--disable-install-doc",
          "--disable-yjit",
          "--disable-zjit",
          "--without-gmp",
          "--without-openssl",
          "--without-psych",
          "--without-readline",
          "optflags=-Os",
          "debugflags=-g0"
        ]
        run!(environment, *configure, chdir: build_dir)
        run!(environment, "make", "-j#{processor_count}", chdir: build_dir)
        run!(environment, "make", "install", "DESTDIR=#{ruby_stage(architecture)}", chdir: build_dir)
        marker.write("#{RUBY_VERSION}\n#{architecture}\n#{MACOS_DEPLOYMENT_TARGET}\n")
      end

      def processor_count
        output, status = Open3.capture2("sysctl", "-n", "hw.ncpu")
        status.success? ? output.to_i.clamp(1, 16) : 4
      end

      def ruby_build_dir(architecture)
        @build_root.join("ruby-#{architecture}")
      end

      def ruby_stage(architecture)
        ruby_build_dir(architecture).join("stage")
      end

      def create_package
        FileUtils.mkdir_p(@output)
        FileUtils.cp(@repo_root.join("LICENSE"), @output.join("LICENSE"))
        FileUtils.cp(@ruby_source.join("COPYING"), @output.join("CRUBY-COPYING"))
        FileUtils.cp_r(@lite_root.join("lib"), @output.join("lib"))
        FileUtils.mkdir_p(@output.join("desktop"))
        FileUtils.cp(@lite_root.join("desktop/ruflet_vm_host.h"), @output.join("desktop"))
        FileUtils.cp(@lite_root.join("desktop/ruflet_in_process_bridge.h"), @output.join("desktop"))
        FileUtils.mkdir_p(@output.join("apple"))
        FileUtils.cp(@lite_root.join("apple/ruflet_runtime_autostart.h"), @output.join("apple"))
        FileUtils.mkdir_p(@output.join("macos/Classes"))
        FileUtils.cp(@lite_root.join("macos/Classes/RubyRuntimeMacosPlugin.h"), @output.join("macos/Classes"))
        plugin = @lite_root.join("macos/Classes/RubyRuntimeMacosPlugin.m").read
        definitions = <<~OBJC.chomp
          #define RUFLET_CRUBY_RUNTIME 1
          #define RUFLET_CRUBY_ABI @"#{RUBY_ABI}"
          #if defined(__arm64__)
          #define RUFLET_CRUBY_ARCH @"#{RUBY_ARCHES.fetch('arm64')}"
          #else
          #define RUFLET_CRUBY_ARCH @"#{RUBY_ARCHES.fetch('x86_64')}"
          #endif
        OBJC
        plugin.sub!('#include "ruflet_runtime_autostart.h"', "#{definitions}\n#include \"ruflet_runtime_autostart.h\"")
        @output.join("macos/Classes/RubyRuntimeMacosPlugin.m").write(plugin)
        write_pubspec
        write_podspec
      end

      def write_pubspec
        pubspec = {
          "name" => "ruby_runtime",
          "description" => "Ruflet full embedded CRuby runtime for macOS.",
          "version" => "0.1.0",
          "homepage" => "https://github.com/AdamMusa/ruflet",
          "environment" => {"sdk" => "^3.11.0", "flutter" => ">=3.3.0"},
          "dependencies" => {
            "flutter" => {"sdk" => "flutter"},
            "plugin_platform_interface" => "^2.0.2"
          },
          "flutter" => {"plugin" => {"platforms" => {"macos" => {"pluginClass" => "RubyRuntimeMacosPlugin"}}}}
        }
        @output.join("pubspec.yaml").write(YAML.dump(pubspec).sub(/\A---\n/, ""))
      end

      def write_podspec
        spec = <<~RUBY
          Pod::Spec.new do |s|
            s.name             = 'ruby_runtime'
            s.version          = '0.1.0'
            s.summary          = 'Embedded full CRuby VM for Ruflet macOS apps.'
            s.description      = "Bundles CRuby, its standard library, and Ruflet's in-process VM bridge."
            s.homepage         = 'https://github.com/AdamMusa/ruflet'
            s.license          = { :file => '../LICENSE' }
            s.author           = { 'Izeesoft' => 'dev@izeesoft.com' }
            s.source           = { :path => '.' }
            s.source_files     = ['Classes/RubyRuntimeMacosPlugin.{h,m}']
            s.public_header_files = 'Classes/RubyRuntimeMacosPlugin.h'
            s.preserve_paths   = ['../desktop/*.h', '../apple/*.h']
            s.vendored_libraries = ['Frameworks/libruflet_cruby_vm.a', 'Frameworks/#{@ruby_library_name}']
            s.resources        = ['Resources/ruflet_cruby']
            s.dependency 'FlutterMacOS'
            s.platform = :osx, '#{MACOS_DEPLOYMENT_TARGET}'
            s.libraries = 'm', 'c++'
            s.pod_target_xcconfig = {
              'DEFINES_MODULE' => 'YES',
              'HEADER_SEARCH_PATHS' => '$(inherited) "$(PODS_TARGET_SRCROOT)/../desktop" "$(PODS_TARGET_SRCROOT)/../apple"'
            }
          end
        RUBY
        @output.join("macos/ruby_runtime.podspec").write(spec)
      end

      def copy_ruby
        frameworks = @output.join("macos/Frameworks")
        resources = @output.join("macos/Resources/ruflet_cruby/lib/ruby")
        FileUtils.mkdir_p(frameworks)
        FileUtils.mkdir_p(resources)
        packaged_ruby = frameworks.join(@ruby_library_name)
        libraries = RUBY_ARCHES.keys.map { |arch| ruby_stage(arch).join("lib", @ruby_library_name).to_s }
        run!("lipo", "-create", *libraries, "-output", packaged_ruby.to_s)
        run!("install_name_tool", "-id", "@rpath/#{packaged_ruby.basename}", packaged_ruby.to_s)

        common = ruby_stage("arm64").join("lib/ruby", RUBY_ABI)
        FileUtils.cp_r(common, resources.join(RUBY_ABI))
        RUBY_ARCHES.each do |architecture, ruby_arch|
          source = ruby_stage(architecture).join("lib/ruby", RUBY_ABI, ruby_arch)
          destination = resources.join(RUBY_ABI, ruby_arch)
          FileUtils.rm_rf(destination)
          FileUtils.cp_r(source, destination)
        end
        Dir.glob(resources.join("**/*.dSYM").to_s).each { |path| FileUtils.rm_rf(path) }
      end

      def build_vm_archive
        build_dir = @build_root.join("native-macos")
        FileUtils.rm_rf(build_dir)
        FileUtils.mkdir_p(build_dir)
        archives = RUBY_ARCHES.map do |architecture, ruby_arch|
          common_headers = ruby_stage(architecture).join("include/ruby-#{RUBY_ABI}")
          arch_headers = common_headers.join(ruby_arch)
          include_flags = [common_headers, arch_headers, @lite_root.join("desktop")]
            .flat_map { |path| ["-I", path.to_s] }
          common = ["clang++", "-arch", architecture,
                    "-mmacosx-version-min=#{MACOS_DEPLOYMENT_TARGET}", "-std=c++17", "-Os",
                    "-DNDEBUG", "-fvisibility=hidden", "-fPIC", *include_flags]
          vm_object = build_dir.join("ruflet_cruby_vm-#{architecture}.o")
          bridge_object = build_dir.join("ruflet_in_process_bridge-#{architecture}.o")
          run!(*common, "-c", @source_root.join("native/ruflet_cruby_vm.cpp").to_s, "-o", vm_object.to_s)
          run!(*common, "-c", @lite_root.join("desktop/ruflet_in_process_bridge.cpp").to_s,
               "-o", bridge_object.to_s)
          archive = build_dir.join("libruflet_cruby_vm-#{architecture}.a")
          run!("ar", "rcs", archive.to_s, vm_object.to_s, bridge_object.to_s)
          archive.to_s
        end
        run!("lipo", "-create", *archives,
             "-output", @output.join("macos/Frameworks/libruflet_cruby_vm.a").to_s)
      end

      def write_manifest
        manifest = {
          "schema" => 1,
          "engine" => "cruby",
          "ruby_version" => RUBY_VERSION,
          "ruby_abi" => RUBY_ABI,
          "architectures" => RUBY_ARCHES.keys,
          "platforms" => ["macos"],
          "minimum_macos" => MACOS_DEPLOYMENT_TARGET,
          "warm_launch" => "native-preload",
          "gems" => "Gemfile.lock"
        }
        @output.join("ruflet-full-runtime.json").write("#{JSON.pretty_generate(manifest)}\n")
      end

      def run!(*arguments, chdir: nil)
        environment = arguments.first.is_a?(Hash) ? arguments.shift : {}
        command = arguments.map(&:to_s)
        success = if chdir
          system(environment, *command, chdir: chdir.to_s)
        else
          system(environment, *command)
        end
        return if success

        abort "#{command.join(' ')} failed"
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  output_index = ARGV.index("--output")
  output = output_index ? ARGV.fetch(output_index + 1) : nil
  Ruflet::CRubyRuntime::MacOSBuilder.new(output: output).build
end
