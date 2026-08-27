# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "pathname"
require "rubygems"
require "yaml"

module Ruflet
  module CRubyRuntime
    class AndroidBuilder
      RUBY_VERSION = "4.0.5"
      RUBY_ABI = "4.0.0"
      ANDROID_API = 24
      RUBY_ARCHES = {
        "arm64-v8a" => {
          compiler: "aarch64-linux-android",
          configure_host: "aarch64-linux",
          ruby_arch: "aarch64-linux-gnu-android"
        },
        "armeabi-v7a" => {
          compiler: "armv7a-linux-androideabi",
          configure_host: "arm-linux",
          ruby_arch: "arm-linux-gnu-android"
        },
        "x86_64" => {
          compiler: "x86_64-linux-android",
          configure_host: "x86_64-linux",
          ruby_arch: "x86_64-linux-gnu-android"
        }
      }.freeze
      RUBY_ARCHIVE_SHA256 = "7d6149079a63f8ae1d326c9fa65c6019ba2dc3155eae7b39159817911c88958e"

      def initialize(output: nil)
        @repo_root = Pathname.new(__dir__).join("../..").expand_path
        @lite_root = @repo_root.join("ruby_runtime")
        @source_root = @repo_root.join("cruby_runtime")
        @build_root = @repo_root.join("build/cruby_runtime")
        @output = Pathname.new(output || @build_root.join("android")).expand_path
        @ruby_source = @build_root.join("sources/ruby-#{RUBY_VERSION}")
        @ndk = locate_ndk
        @toolchain = Dir[@ndk.join("toolchains/llvm/prebuilt/*").to_s]
          .map { |path| Pathname.new(path) }
          .find(&:directory?)
      end

      def build
        validate_tools!
        ensure_ruby_source!
        RUBY_ARCHES.each { |abi, settings| ensure_ruby_build!(abi, settings) }
        FileUtils.rm_rf(@output)
        create_package
        copy_ruby_standard_library
        build_runtime_libraries
        write_manifest
        puts @output
      end

      private

      def locate_ndk
        explicit = ENV["ANDROID_NDK_HOME"].to_s.strip
        return Pathname.new(explicit).expand_path unless explicit.empty?

        sdk = ENV["ANDROID_HOME"].to_s.strip
        sdk = ENV["ANDROID_SDK_ROOT"].to_s.strip if sdk.empty?
        sdk = File.expand_path("~/Library/Android/sdk") if sdk.empty?
        candidates = Dir[File.join(sdk, "ndk", "*")].select { |path| File.directory?(path) }
        selected = candidates.max_by do |path|
          Gem::Version.new(File.basename(path).scan(/\d+(?:\.\d+)*/).first || "0")
        end
        abort "Android NDK not found below #{sdk}" unless selected
        Pathname.new(selected)
      end

      def validate_tools!
        abort "Android NDK toolchain not found in #{@ndk}" unless @toolchain&.directory?
        %w[ar curl make tar].each do |tool|
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

      def ensure_ruby_build!(abi, settings)
        build_dir = ruby_build_dir(abi)
        marker = build_dir.join(".ruflet-cruby-#{RUBY_VERSION}-android#{ANDROID_API}")
        library = build_dir.join("libruby-static.a")
        staged_lib = ruby_stage(abi).join("lib/ruby", RUBY_ABI)
        return if marker.file? && library.file? && staged_lib.directory?

        FileUtils.rm_rf(build_dir)
        FileUtils.mkdir_p(build_dir)
        compiler = settings.fetch(:compiler)
        environment = {
          "CC" => tool("#{compiler}#{ANDROID_API}-clang"),
          "CXX" => tool("#{compiler}#{ANDROID_API}-clang++"),
          "AR" => tool("llvm-ar"),
          "RANLIB" => tool("llvm-ranlib"),
          "STRIP" => tool("llvm-strip"),
          "NM" => tool("llvm-nm"),
          "OBJCOPY" => tool("llvm-objcopy"),
          "OBJDUMP" => tool("llvm-objdump"),
          "CPPFLAGS" => "",
          "LDFLAGS" => "",
          # nl_langinfo is API 26. Ruflet full retains the plugin's API 24 floor.
          "ac_cv_header_langinfo_h" => "no"
        }
        configure = [
          @ruby_source.join("configure").to_s,
          "--host=#{settings.fetch(:configure_host)}",
          "--target=#{settings.fetch(:configure_host)}",
          "--with-baseruby=#{RbConfig.ruby}",
          "--prefix=/ruflet-cruby",
          "--disable-shared",
          "--with-static-linked-ext",
          "--with-out-ext=-test-,win32,win32ole,openssl,psych,readline,gmp,fiddle",
          "--disable-install-doc",
          "--disable-yjit",
          "--disable-zjit",
          "optflags=-Os",
          "debugflags=-g0"
        ]
        run!(environment, *configure, chdir: build_dir)
        run!(environment, "make", "-j#{processor_count}", chdir: build_dir)
        run!(environment, "make", "install", "DESTDIR=#{ruby_stage_root(abi)}", chdir: build_dir)
        expected = staged_lib.join(settings.fetch(:ruby_arch))
        abort "CRuby produced an unexpected Android architecture for #{abi}" unless expected.directory?
        marker.write("#{RUBY_VERSION}\n#{abi}\n#{ANDROID_API}\n#{@ndk.basename}\n")
      end

      def processor_count
        output, status = Open3.capture2("sysctl", "-n", "hw.ncpu")
        status.success? ? output.to_i.clamp(1, 16) : 4
      end

      def tool(name)
        path = @toolchain.join("bin", name)
        abort "Missing Android NDK tool: #{path}" unless path.executable?
        path.to_s
      end

      def ruby_build_dir(abi)
        @build_root.join("ruby-android-#{abi}")
      end

      def ruby_stage_root(abi)
        ruby_build_dir(abi).join("stage")
      end

      def ruby_stage(abi)
        ruby_stage_root(abi).join("ruflet-cruby")
      end

      def create_package
        FileUtils.mkdir_p(@output)
        FileUtils.mkdir_p(@output.join("android"))
        FileUtils.cp(@repo_root.join("LICENSE"), @output.join("LICENSE"))
        FileUtils.cp(@ruby_source.join("COPYING"), @output.join("CRUBY-COPYING"))
        FileUtils.cp_r(@lite_root.join("lib"), @output.join("lib"))
        FileUtils.mkdir_p(@output.join("desktop"))
        FileUtils.cp(@lite_root.join("desktop/ruflet_vm_host.h"), @output.join("desktop"))
        %w[build.gradle.kts settings.gradle settings.gradle.kts].each do |name|
          source = @lite_root.join("android", name)
          FileUtils.cp(source, @output.join("android", name)) if source.file?
        end
        FileUtils.mkdir_p(@output.join("android/src/main"))
        FileUtils.cp(
          @lite_root.join("android/src/main/AndroidManifest.xml"),
          @output.join("android/src/main/AndroidManifest.xml")
        )
        FileUtils.cp_r(
          @lite_root.join("android/src/main/kotlin"),
          @output.join("android/src/main/kotlin")
        )
        write_pubspec
      end

      def write_pubspec
        pubspec = {
          "name" => "ruby_runtime",
          "description" => "Ruflet full embedded CRuby runtime for Android.",
          "version" => "0.1.0",
          "homepage" => "https://github.com/AdamMusa/ruflet",
          "environment" => {"sdk" => "^3.11.0", "flutter" => ">=3.3.0"},
          "dependencies" => {
            "flutter" => {"sdk" => "flutter"},
            "plugin_platform_interface" => "^2.0.2"
          },
          "flutter" => {
            "plugin" => {
              "platforms" => {
                "android" => {
                  "package" => "com.izeesoft.ruby_runtime",
                  "pluginClass" => "MrubyRuntimePlugin"
                }
              }
            }
          }
        }
        @output.join("pubspec.yaml").write(YAML.dump(pubspec).sub(/\A---\n/, ""))
      end

      def copy_ruby_standard_library
        assets = @output.join("android/src/main/assets/ruflet_cruby/lib/ruby", RUBY_ABI)
        arm64 = ruby_stage("arm64-v8a").join("lib/ruby", RUBY_ABI)
        FileUtils.mkdir_p(assets.dirname)
        FileUtils.cp_r(arm64, assets)
        RUBY_ARCHES.each do |abi, settings|
          destination = assets.join(settings.fetch(:ruby_arch))
          FileUtils.rm_rf(destination)
          FileUtils.cp_r(
            ruby_stage(abi).join("lib/ruby", RUBY_ABI, settings.fetch(:ruby_arch)),
            destination
          )
        end
      end

      def build_runtime_libraries
        RUBY_ARCHES.each do |abi, settings|
          build_dir = ruby_build_dir(abi)
          ruby_arch = settings.fetch(:ruby_arch)
          compiler = settings.fetch(:compiler)
          static_extensions = static_extension_archives(build_dir)
          extension_registry = build_static_extension_registry(build_dir, compiler, ruby_arch)
          destination = @output.join("android/src/main/jniLibs", abi, "libruby_runtime.so")
          FileUtils.mkdir_p(destination.dirname)
          run!(
            tool("#{compiler}#{ANDROID_API}-clang++"),
            "-std=c++17", "-Os", "-DNDEBUG", "-DRUFLET_CRUBY_STATIC_EXTENSIONS=1",
            "-fPIC", "-shared", "-static-libstdc++",
            "-Wl,-soname,libruby_runtime.so", "-Wl,--exclude-libs,ALL",
            "-Wl,-z,max-page-size=16384",
            "-I#{ruby_stage(abi).join('include/ruby-' + RUBY_ABI)}",
            "-I#{ruby_stage(abi).join('include/ruby-' + RUBY_ABI, ruby_arch)}",
            "-I#{@lite_root.join('desktop')}",
            @source_root.join("native/ruflet_cruby_vm.cpp").to_s,
            @source_root.join("native/ruflet_cruby_jni.cpp").to_s,
            @lite_root.join("desktop/ruflet_in_process_bridge.cpp").to_s,
            *extension_registry,
            "-Wl,--whole-archive", *static_extensions, "-Wl,--no-whole-archive",
            build_dir.join("libruby-static.a").to_s,
            "-lz", "-ldl", "-lm", "-llog", "-latomic",
            "-o", destination.to_s
          )
          run!(tool("llvm-strip"), "--strip-unneeded", destination.to_s)
        end
      end

      def static_extension_archives(build_dir)
        makefile = build_dir.join("exts.mk").read.gsub(/\\\n\s*/, " ")
        definition = makefile.lines.find { |line| line.start_with?("EXTOBJS =") }
        abort "Could not find CRuby's static extension list in #{build_dir}/exts.mk" unless definition

        archives = definition.sub(/\AEXTOBJS\s*=\s*/, "").split.grep(/\.a\z/)
          .map { |relative| build_dir.join(relative) }
        archives.concat(%w[enc/libenc.a enc/libtrans.a].map { |relative| build_dir.join(relative) })
        missing = archives.reject(&:file?)
        abort "Missing CRuby static extensions: #{missing.join(', ')}" unless missing.empty?
        archives.map(&:to_s)
      end

      def build_static_extension_registry(build_dir, compiler, ruby_arch)
        source = build_dir.join("ext/extinit.c").read.sub(
          "void Init_ext(void)",
          "void Ruflet_Init_ext(void)"
        )
        abort "Could not rename CRuby's static extension registry" unless source.include?("Ruflet_Init_ext")
        extensions = source.scan(/init\(([^,]+),\s*"([^"]+)"\)/)
        encoding_source = build_dir.join("enc/encinit.c").read.sub(
          "Init_enc(void)",
          "Ruflet_Init_enc(void)"
        )
        abort "Could not rename CRuby's encoding registry" unless encoding_source.include?("Ruflet_Init_enc")
        encoding_source.each_line.reject { |line| line.lstrip.start_with?("#") }.each do |line|
          line.scan(/init_enc\(([^)]+)\)/) do |match|
            name = match.first.strip
            extensions << ["Init_#{name}", "enc/#{name}"]
          end
          line.scan(/init_trans\(([^)]+)\)/) do |match|
            name = match.first.strip
            extensions << ["Init_trans_#{name}", "enc/trans/#{name}"]
          end
        end
        abort "Could not read CRuby's static extension names" if extensions.empty?
        source << <<~C

          #include <string.h>

          #{extensions.map { |function, _name| "extern void #{function}(void);" }.join("\n")}

          int Ruflet_Load_static_ext(const char *name)
          {
              struct entry {
                  const char *name;
                  void (*initialize)(void);
                  int loaded;
              };
              static struct entry entries[] = {
          #{extensions.map { |function, name| "        {#{name.dump}, #{function}, 0}," }.join("\n")}
              };
              const size_t count = sizeof(entries) / sizeof(entries[0]);
              for (size_t index = 0; index < count; ++index) {
                  const size_t length = strlen(entries[index].name);
                  const int exact = strcmp(name, entries[index].name) == 0;
                  const int suffixed = strncmp(name, entries[index].name, length) == 0 &&
                      strcmp(name + length, ".so") == 0;
                  if (!exact && !suffixed) continue;
                  if (entries[index].loaded) return 0;
                  entries[index].initialize();
                  entries[index].loaded = 1;
                  return 1;
              }
              return -1;
          }
        C

        source_path = build_dir.join("ruflet_android_extinit.c")
        object_path = build_dir.join("ruflet_android_extinit.o")
        source_path.write(source)
        encoding_source_path = build_dir.join("ruflet_android_encinit.c")
        encoding_object_path = build_dir.join("ruflet_android_encinit.o")
        encoding_source_path.write(encoding_source)
        includes = [
          "-I#{build_dir.join('stage/ruflet-cruby/include/ruby-' + RUBY_ABI)}",
          "-I#{build_dir.join('stage/ruflet-cruby/include/ruby-' + RUBY_ABI, ruby_arch)}"
        ]
        run!(
          tool("#{compiler}#{ANDROID_API}-clang"),
          "-Os", "-DNDEBUG", "-fPIC",
          *includes,
          "-c", source_path.to_s, "-o", object_path.to_s
        )
        run!(
          tool("#{compiler}#{ANDROID_API}-clang"),
          "-Os", "-DNDEBUG", "-fPIC",
          *includes,
          "-c", encoding_source_path.to_s, "-o", encoding_object_path.to_s
        )
        [object_path.to_s, encoding_object_path.to_s]
      end

      def write_manifest
        manifest = {
          "schema" => 1,
          "engine" => "cruby",
          "ruby_version" => RUBY_VERSION,
          "ruby_abi" => RUBY_ABI,
          "architectures" => RUBY_ARCHES.keys,
          "platforms" => ["android"],
          "minimum_android_api" => ANDROID_API,
          "warm_launch" => "androidx-startup",
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
        abort "Command failed: #{command.join(' ')}" unless success
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  output = ARGV.shift
  abort "usage: ruby build_android.rb [OUTPUT]" unless ARGV.empty?
  Ruflet::CRubyRuntime::AndroidBuilder.new(output: output).build
end
