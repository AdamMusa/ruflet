# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "pathname"
require "rbconfig"
require "yaml"

module Ruflet
  module CRubyRuntime
    class IOSBuilder
      RUBY_VERSION = "4.0.5"
      RUBY_ABI = "4.0.0"
      RUBY_ARCH = "arm64-darwin25"
      IOS_DEPLOYMENT_TARGET = "13.0"
      IOS_BUILD_SCHEMA = 4
      RUBY_ARCHIVE_SHA256 = "7d6149079a63f8ae1d326c9fa65c6019ba2dc3155eae7b39159817911c88958e"

      def initialize(output: nil)
        @repo_root = Pathname.new(__dir__).join("../..").expand_path
        @lite_root = @repo_root.join("ruby_runtime")
        @source_root = @repo_root.join("cruby_runtime")
        @build_root = @repo_root.join("build/cruby_runtime")
        @output = Pathname.new(output || @build_root.join("ios-arm64")).expand_path
        configured_build = ENV["RUFLET_IOS_BUILD_DIR"].to_s.strip
        @ruby_build = Pathname.new(
          configured_build.empty? ? @build_root.join("ruby-ios-arm64") : configured_build
        ).expand_path
        @ruby_source = @build_root.join("sources/ruby-#{RUBY_VERSION}")
        @sdk = sdk_path
      end

      def build
        validate_tools!
        ensure_ruby_source!
        apply_ios_source_patches!
        ensure_ruby_build!
        FileUtils.rm_rf(@output)
        create_package
        copy_standard_library
        build_runtime_xcframework
        write_manifest
        puts @output
      end

      private

      def sdk_path
        output, status = Open3.capture2("xcrun", "--sdk", "iphoneos", "--show-sdk-path")
        abort "Could not locate the iPhoneOS SDK" unless status.success?
        Pathname.new(output.strip)
      end

      def validate_tools!
        %w[ar clang clang++ curl libtool make ranlib tar].each do |tool|
          abort "Missing required tool: #{tool}" unless system("xcrun", "--find", tool, out: File::NULL)
        end
        abort "Missing required tool: xcodebuild" unless system("command", "-v", "xcodebuild", out: File::NULL)
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

      def apply_ios_source_patches!
        replace_source(
          "dir.c",
          <<~'BEFORE'.rstrip,
            #ifdef __APPLE__
            # define NORMALIZE_UTF8PATH 1
            # include <sys/param.h>
            # include <sys/mount.h>
            # include <sys/vnode.h>
            #else
            # define NORMALIZE_UTF8PATH 0
            #endif
          BEFORE
          <<~'AFTER'.rstrip
            #ifdef __APPLE__
            # if defined(RUFLET_IOS)
            #  define NORMALIZE_UTF8PATH 0
            # else
            #  define NORMALIZE_UTF8PATH 1
            # endif
            # include <sys/param.h>
            # include <sys/mount.h>
            # include <sys/vnode.h>
            #else
            # define NORMALIZE_UTF8PATH 0
            #endif
          AFTER
        )
        replace_source(
          "dir.c",
          "#ifdef __APPLE__\n    cwd = rb_str_normalize_ospath(path, strlen(path));",
          "#if defined(__APPLE__) && !defined(RUFLET_IOS)\n    cwd = rb_str_normalize_ospath(path, strlen(path));"
        )
        replace_source(
          "file.c",
          "#ifdef __APPLE__\n# define NORMALIZE_UTF8PATH 1",
          "#if defined(__APPLE__) && !defined(RUFLET_IOS)\n# define NORMALIZE_UTF8PATH 1"
        )
        replace_source(
          "file.c",
          "#ifdef __APPLE__\n            {\n                int n = ignored_char_p(s, fend, enc);",
          "#if defined(__APPLE__) && !defined(RUFLET_IOS)\n            {\n                int n = ignored_char_p(s, fend, enc);"
        )
        replace_source(
          "process.c",
          "# else\n    status = system(rb_execarg_commandline(eargp, &prog));\n    pid = 1;",
          "# else\n#  if defined(RUFLET_IOS)\n    errno = ENOTSUP;\n    status = -1;\n#  else\n    status = system(rb_execarg_commandline(eargp, &prog));\n#  endif\n    pid = 1;"
        )
        replace_source(
          "vm_dump.c",
          <<~'BEFORE'.rstrip,
            if (cmd) {
                    char buf[0x100];
                    snprintf(buf, sizeof(buf), "%s %"PRI_PIDT_PREFIX"d", cmd, getpid());
                    int r = system(buf);
                    if (r == -1) {
                        snprintf(buf, sizeof(buf), "Launching RUBY_ON_BUG command failed.");
                    }
                }
          BEFORE
          <<~'AFTER'.rstrip
            if (cmd) {
            #if defined(RUFLET_IOS)
                    (void)cmd;
            #else
                    char buf[0x100];
                    snprintf(buf, sizeof(buf), "%s %"PRI_PIDT_PREFIX"d", cmd, getpid());
                    int r = system(buf);
                    if (r == -1) {
                        snprintf(buf, sizeof(buf), "Launching RUBY_ON_BUG command failed.");
                    }
            #endif
                }
          AFTER
        )
        replace_source(
          "ext/strscan/strscan.c",
          "/* rb_reg_onig_match is available in Ruby 3.3 and later. */\n#ifndef HAVE_RB_REG_ONIG_MATCH",
          "/* rb_reg_onig_match is available in Ruby 3.3 and later. */\n#if defined(RUFLET_IOS)\n# define HAVE_RB_REG_ONIG_MATCH 1\n#endif\n#ifndef HAVE_RB_REG_ONIG_MATCH"
        )
        replace_source(
          "ext/json/parser/parser.c",
          "#include \"../simd/simd.h\"\n\nstatic VALUE mJSON",
          "#include \"../simd/simd.h\"\n\n#if defined(RUFLET_IOS)\n# define HAVE_RB_ENC_INTERNED_STR 1\n# define HAVE_RB_HASH_BULK_INSERT 1\n# define HAVE_RB_HASH_NEW_CAPA 1\n# define HAVE_RB_STR_TO_INTERNED_STR 1\n#endif\n\nstatic VALUE mJSON"
        )
      end

      def replace_source(relative, before, after)
        path = @ruby_source.join(relative)
        contents = path.read
        return if contents.include?(after)
        abort "Pinned CRuby patch no longer applies to #{relative}" unless contents.include?(before)

        path.write(contents.sub(before, after))
      end

      def ensure_ruby_build!
        library = @ruby_build.join("libruby.4.0-static.a")
        stamp = @ruby_build.join(".ruflet-ios-build.json")
        expected_stamp = {
          "schema" => IOS_BUILD_SCHEMA,
          "ruby_version" => RUBY_VERSION,
          "minimum_ios" => IOS_DEPLOYMENT_TARGET,
          "architecture" => "arm64"
        }
        cached_stamp = JSON.parse(stamp.read) if stamp.file?
        return if cached_stamp == expected_stamp && library.file? &&
          static_extension_archives(allow_missing: true).all?(&:file?)

        FileUtils.rm_rf(@ruby_build)
        FileUtils.mkdir_p(@ruby_build)
        environment = build_environment
        configure = [
          @ruby_source.join("configure").to_s,
          "--build=arm64-apple-darwin25",
          "--host=aarch64-apple-darwin25",
          "--with-baseruby=#{RbConfig.ruby}",
          "--prefix=/ruflet-cruby",
          "--disable-shared",
          "--with-static-linked-ext",
          "--with-out-ext=-test-,win32,win32ole,openssl,psych,readline,gmp,fiddle,pty",
          "--disable-install-doc",
          "--disable-yjit",
          "--disable-zjit",
          "--without-gmp",
          "optflags=-Os",
          "debugflags=-g0"
        ]
        run!(environment, *configure, chdir: @ruby_build)
        run!(environment, "make", "-j#{processor_count}", "libruby.4.0-static.a",
             "exts.mk", chdir: @ruby_build)
        run!(environment, "make", "-j#{processor_count}", "libencs", chdir: @ruby_build)

        archives = static_extension_archives(allow_missing: true)
        targets = extension_build_targets(archives.reject(&:file?))
        run!(environment, "make", "-f", "exts.mk", "-j#{processor_count}", *targets,
             chdir: @ruby_build) unless targets.empty?
        run!(environment, "make", "-f", "exts.mk", "-j#{processor_count}",
             "ext/extinit.o", chdir: @ruby_build)
        missing = static_extension_archives(allow_missing: true).reject(&:file?)
        abort "Missing iOS CRuby static extensions: #{missing.join(', ')}" unless missing.empty?
        stamp.write("#{JSON.pretty_generate(expected_stamp)}\n")
      rescue JSON::ParserError
        FileUtils.rm_f(stamp)
        retry
      end

      def extension_build_targets(archives)
        makefile = @ruby_build.join("exts.mk").read
        archives.filter_map do |archive|
          relative = archive.relative_path_from(@ruby_build).to_s
          next if relative.start_with?("enc/")

          rule = makefile.lines.find { |line| line.start_with?("#{relative}:") }
          abort "Could not find the static build rule for #{relative}" unless rule
          rule.split(":", 2).last.split.first
        end.uniq
      end

      def build_environment
        flags = "-arch arm64 -miphoneos-version-min=#{IOS_DEPLOYMENT_TARGET} -isysroot #{@sdk}"
        unavailable = %w[
          fork vfork dlopen getattrlist fgetattrlist system getentropy popen
          execl execle execv execve
        ].to_h { |name| ["ac_cv_func_#{name}", "no"] }
        unavailable.merge(
          "SDKROOT" => @sdk.to_s,
          "CC" => "xcrun --sdk iphoneos clang -arch arm64 -miphoneos-version-min=#{IOS_DEPLOYMENT_TARGET}",
          "CXX" => "xcrun --sdk iphoneos clang++ -arch arm64 -miphoneos-version-min=#{IOS_DEPLOYMENT_TARGET}",
          "CPP" => "xcrun --sdk iphoneos clang -E -arch arm64 -miphoneos-version-min=#{IOS_DEPLOYMENT_TARGET}",
          "CFLAGS" => "-Os -g0 -isysroot #{@sdk}",
          "CXXFLAGS" => "-Os -g0 -isysroot #{@sdk}",
          "CPPFLAGS" => "-DRUFLET_IOS=1 -I#{@source_root.join('ios_shims')} -isysroot #{@sdk}",
          "LDFLAGS" => flags,
          "ac_cv_header_sys_attr_h" => "no"
        )
      end

      def processor_count
        output, status = Open3.capture2("sysctl", "-n", "hw.ncpu")
        status.success? ? output.to_i.clamp(1, 16) : 4
      end

      def create_package
        FileUtils.mkdir_p(@output)
        FileUtils.cp(@repo_root.join("LICENSE"), @output.join("LICENSE"))
        FileUtils.cp(@ruby_source.join("COPYING"), @output.join("CRUBY-COPYING"))
        FileUtils.cp_r(@lite_root.join("lib"), @output.join("lib"))
        FileUtils.mkdir_p(@output.join("desktop"))
        %w[ruflet_vm_host.h ruflet_in_process_bridge.h].each do |name|
          FileUtils.cp(@lite_root.join("desktop", name), @output.join("desktop"))
        end
        FileUtils.mkdir_p(@output.join("apple"))
        FileUtils.cp(@lite_root.join("apple/ruflet_runtime_autostart.h"), @output.join("apple"))
        FileUtils.mkdir_p(@output.join("ios/Classes"))
        FileUtils.cp(@lite_root.join("ios/Classes/MrubyRuntimePlugin.h"), @output.join("ios/Classes"))
        plugin = @lite_root.join("ios/Classes/MrubyRuntimePlugin.m").read
        definitions = <<~OBJC.chomp
          #define RUFLET_CRUBY_RUNTIME 1
          #define RUFLET_CRUBY_ABI @"#{RUBY_ABI}"
          #define RUFLET_CRUBY_ARCH @"#{RUBY_ARCH}"
        OBJC
        plugin.sub!("#include \"ruflet_runtime_autostart.h\"", "#{definitions}\n#include \"ruflet_runtime_autostart.h\"")
        @output.join("ios/Classes/MrubyRuntimePlugin.m").write(plugin)
        FileUtils.mkdir_p(@output.join("ios/Resources"))
        FileUtils.cp(@lite_root.join("ios/Resources/PrivacyInfo.xcprivacy"), @output.join("ios/Resources"))
        write_pubspec
        write_podspec
      end

      def write_pubspec
        pubspec = {
          "name" => "ruby_runtime",
          "description" => "Ruflet full embedded CRuby runtime for physical iOS devices.",
          "version" => "0.1.0",
          "homepage" => "https://github.com/AdamMusa/ruflet",
          "environment" => {"sdk" => "^3.11.0", "flutter" => ">=3.3.0"},
          "dependencies" => {
            "flutter" => {"sdk" => "flutter"},
            "plugin_platform_interface" => "^2.0.2"
          },
          "flutter" => {"plugin" => {"platforms" => {"ios" => {"pluginClass" => "MrubyRuntimePlugin"}}}}
        }
        @output.join("pubspec.yaml").write(YAML.dump(pubspec).sub(/\A---\n/, ""))
      end

      def write_podspec
        podspec = <<~RUBY
          Pod::Spec.new do |s|
            s.name             = 'ruby_runtime'
            s.version          = '0.1.0'
            s.summary          = 'Embedded full CRuby VM for Ruflet iOS apps.'
            s.description      = "Bundles static CRuby, its standard library, and Ruflet's in-process bridge."
            s.homepage         = 'https://github.com/AdamMusa/ruflet'
            s.license          = { :file => '../LICENSE' }
            s.author           = { 'Izeesoft' => 'dev@izeesoft.com' }
            s.source           = { :path => '.' }
            s.source_files     = ['Classes/MrubyRuntimePlugin.{h,m}']
            s.public_header_files = 'Classes/MrubyRuntimePlugin.h'
            s.preserve_paths   = ['../desktop/*.h', '../apple/*.h']
            s.vendored_frameworks = 'Frameworks/RufletCRuby.xcframework'
            s.resources        = ['Resources/PrivacyInfo.xcprivacy', 'Resources/ruflet_cruby']
            s.dependency 'Flutter'
            s.platform = :ios, '#{IOS_DEPLOYMENT_TARGET}'
            s.libraries = 'm', 'c++', 'z'
            s.frameworks = 'CoreFoundation'
            s.pod_target_xcconfig = {
              'DEFINES_MODULE' => 'YES',
              'HEADER_SEARCH_PATHS' => '$(inherited) "$(PODS_TARGET_SRCROOT)/../desktop" "$(PODS_TARGET_SRCROOT)/../apple"'
            }
          end
        RUBY
        @output.join("ios/ruby_runtime.podspec").write(podspec)
      end

      def copy_standard_library
        destination = @output.join("ios/Resources/ruflet_cruby/lib/ruby", RUBY_ABI)
        FileUtils.mkdir_p(destination.parent)
        FileUtils.cp_r(@ruby_source.join("lib"), destination)
        overlay_tree(@ruby_build.join(".ext/common"), destination)
        architecture = destination.join(RUBY_ARCH)
        FileUtils.mkdir_p(architecture)
        FileUtils.cp(@ruby_build.join("rbconfig.rb"), architecture.join("rbconfig.rb"))
      end

      def overlay_tree(source, destination)
        return unless source.directory?

        source.children.each do |entry|
          target = destination.join(entry.basename)
          FileUtils.rm_rf(target)
          FileUtils.cp_r(entry, target)
        end
      end

      def build_runtime_xcframework
        native = @build_root.join("native-ios")
        FileUtils.rm_rf(native)
        FileUtils.mkdir_p(native)
        registry_objects = build_static_extension_registry(native)
        includes = ruby_include_flags + ["-I#{@lite_root.join('desktop')}"]
        common = [
          "xcrun", "--sdk", "iphoneos", "clang++", "-arch", "arm64",
          "-miphoneos-version-min=#{IOS_DEPLOYMENT_TARGET}", "-isysroot", @sdk.to_s,
          "-std=c++17", "-Os", "-DNDEBUG", "-DRUFLET_IOS=1",
          "-DRUFLET_CRUBY_STATIC_EXTENSIONS=1", "-fvisibility=hidden", *includes
        ]
        vm_object = native.join("ruflet_cruby_vm.o")
        bridge_object = native.join("ruflet_in_process_bridge.o")
        run!(*common, "-c", @source_root.join("native/ruflet_cruby_vm.cpp").to_s,
             "-o", vm_object.to_s)
        run!(*common, "-c", @lite_root.join("desktop/ruflet_in_process_bridge.cpp").to_s,
             "-o", bridge_object.to_s)

        archive = native.join("libruflet_cruby.a")
        run!("xcrun", "libtool", "-static", "-o", archive.to_s,
             vm_object.to_s, bridge_object.to_s, *registry_objects,
             *static_extension_archives.map(&:to_s),
             @ruby_build.join("libruby.4.0-static.a").to_s)
        run!("xcrun", "ranlib", archive.to_s)

        headers = native.join("Headers")
        FileUtils.mkdir_p(headers)
        %w[ruflet_vm_host.h ruflet_in_process_bridge.h].each do |name|
          FileUtils.cp(@lite_root.join("desktop", name), headers)
        end
        frameworks = @output.join("ios/Frameworks")
        FileUtils.mkdir_p(frameworks)
        run!("xcodebuild", "-create-xcframework", "-library", archive.to_s,
             "-headers", headers.to_s, "-output", frameworks.join("RufletCRuby.xcframework").to_s)
      end

      def static_extension_archives(allow_missing: false)
        makefile = @ruby_build.join("exts.mk")
        return [] if allow_missing && !makefile.file?

        contents = makefile.read.gsub(/\\\n\s*/, " ")
        definition = contents.lines.find { |line| line.start_with?("EXTOBJS =") }
        abort "Could not find CRuby's static extension list" unless definition
        archives = definition.sub(/\AEXTOBJS\s*=\s*/, "").split.grep(/\.a\z/)
          .map { |relative| @ruby_build.join(relative) }
        archives.concat(%w[enc/libenc.a enc/libtrans.a].map { |relative| @ruby_build.join(relative) })
        missing = archives.reject(&:file?)
        abort "Missing CRuby static extensions: #{missing.join(', ')}" if !allow_missing && !missing.empty?
        archives
      end

      def build_static_extension_registry(native)
        source = @ruby_build.join("ext/extinit.c").read.sub(
          "void Init_ext(void)", "void Ruflet_Init_ext(void)"
        )
        abort "Could not rename CRuby's static extension registry" unless source.include?("Ruflet_Init_ext")
        extensions = source.scan(/init\(([^,]+),\s*"([^"]+)"\)/)
        encoding_source = @ruby_build.join("enc/encinit.c").read.sub(
          "Init_enc(void)", "Ruflet_Init_enc(void)"
        )
        abort "Could not rename CRuby's encoding registry" unless encoding_source.include?("Ruflet_Init_enc")
        encoding_source.each_line.reject { |line| line.lstrip.start_with?("#") }.each do |line|
          line.scan(/init_enc\(([^)]+)\)/) { |match| extensions << ["Init_#{match.first.strip}", "enc/#{match.first.strip}"] }
          line.scan(/init_trans\(([^)]+)\)/) { |match| extensions << ["Init_trans_#{match.first.strip}", "enc/trans/#{match.first.strip}"] }
        end
        source << <<~C

          #include <string.h>
          #{extensions.map { |function, _name| "extern void #{function}(void);" }.join("\n")}
          int Ruflet_Load_static_ext(const char *name)
          {
              struct entry { const char *name; void (*initialize)(void); int loaded; };
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

        source_path = native.join("ruflet_ios_extinit.c")
        source_path.write(source)
        encoding_path = native.join("ruflet_ios_encinit.c")
        encoding_path.write(encoding_source)
        [source_path, encoding_path].map do |path|
          object = path.sub_ext(".o")
          run!("xcrun", "--sdk", "iphoneos", "clang", "-arch", "arm64",
               "-miphoneos-version-min=#{IOS_DEPLOYMENT_TARGET}", "-isysroot", @sdk.to_s,
               "-Os", "-DNDEBUG", "-DRUFLET_IOS=1", *ruby_include_flags,
               "-c", path.to_s, "-o", object.to_s)
          object.to_s
        end
      end

      def ruby_include_flags
        [
          "-I#{@ruby_build.join('.ext/include')}",
          "-I#{@ruby_build.join('.ext/include', RUBY_ARCH)}",
          "-I#{@ruby_source.join('include')}",
          "-I#{@ruby_source}"
        ]
      end

      def write_manifest
        manifest = {
          "schema" => 1,
          "engine" => "cruby",
          "ruby_version" => RUBY_VERSION,
          "ruby_abi" => RUBY_ABI,
          "architectures" => ["arm64"],
          "platforms" => ["ios"],
          "minimum_ios" => IOS_DEPLOYMENT_TARGET,
          "device_only" => true,
          "warm_launch" => "native-preload",
          "gems" => "Gemfile.lock"
        }
        @output.join("ruflet-full-runtime.json").write("#{JSON.pretty_generate(manifest)}\n")
      end

      def run!(*arguments, chdir: nil)
        environment = arguments.first.is_a?(Hash) ? arguments.shift : {}
        command = arguments.map(&:to_s)
        success = chdir ? system(environment, *command, chdir: chdir.to_s) : system(environment, *command)
        abort "Command failed: #{command.join(' ')}" unless success
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  output = ARGV.shift
  abort "usage: ruby build_ios.rb [OUTPUT]" unless ARGV.empty?
  Ruflet::CRubyRuntime::IOSBuilder.new(output: output).build
end
