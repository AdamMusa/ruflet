# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"
require "open3"
require "rbconfig"

# The client's android/app/build.gradle.kts reads build/client/android/key.properties
# with java.util.Properties#load, so whatever the CLI writes there must load
# back as the signing values the developer set. These read the file the way
# Gradle does (JavaProperties below, cross-checked against a real JVM when one
# is installed) instead of comparing text.
class RufletCliBuildAndroidSigningTest < Minitest::Test
  class DummyBuilder
    include Ruflet::CLI::BuildCommand
  end

  # java.util.Properties#load(InputStream), ported from the JDK
  # (Properties.LineReader and loadConvert). The bytes are ISO-8859-1; a line
  # ending in an odd number of backslashes continues on the next one, whose
  # leading blanks are dropped; # and ! start a comment; the key ends at the
  # first unescaped =, : or blank; \uXXXX, \t, \n, \r, \f and \<char> are
  # decoded, and a malformed \u raises as load does.
  module JavaProperties
    BLANK = [" ", "\t", "\f"].freeze

    module_function

    def load(bytes)
      text = bytes.b.force_encoding(Encoding::ISO_8859_1).encode(Encoding::UTF_8)
      logical_lines(text).each_with_object({}) do |line, out|
        key, value = split(line)
        out[convert(key)] = convert(value)
      end
    end

    def logical_lines(text)
      lines = []
      current = nil
      text.split(/\r\n|\r|\n/, -1).each do |physical|
        stripped = physical.sub(/\A[ \t\f]+/, "")
        if current.nil?
          next if stripped.empty? || stripped.start_with?("#", "!")

          current = +""
        end
        trailing = stripped[/\\*\z/].length
        if trailing.odd?
          current << stripped.chop
        else
          lines << (current << stripped)
          current = nil
        end
      end
      lines << current if current
      lines
    end

    def split(line)
      chars = line.chars
      key_end = 0
      value_start = chars.length
      separator = false
      backslash = false
      while key_end < chars.length
        char = chars[key_end]
        if !backslash && ["=", ":"].include?(char)
          value_start = key_end + 1
          separator = true
          break
        elsif !backslash && BLANK.include?(char)
          value_start = key_end + 1
          break
        end
        backslash = char == "\\" ? !backslash : false
        key_end += 1
      end
      while value_start < chars.length
        char = chars[value_start]
        unless BLANK.include?(char)
          break unless !separator && ["=", ":"].include?(char)

          separator = true
        end
        value_start += 1
      end
      [chars[0, key_end].join, chars[value_start..].to_a.join]
    end

    def convert(text)
      units = []
      chars = text.chars
      index = 0
      while index < chars.length
        char = chars[index]
        index += 1
        unless char == "\\"
          units.concat(char.encode(Encoding::UTF_16BE).unpack("n*"))
          next
        end

        char = chars[index].to_s
        index += 1
        if char == "u"
          hex = chars[index, 4].to_a.join
          raise ArgumentError, "Malformed \\uxxxx encoding." unless hex.match?(/\A\h{4}\z/)

          units << hex.to_i(16)
          index += 4
        else
          units << ({ "t" => 9, "n" => 10, "r" => 13, "f" => 12 }[char] || char.encode(Encoding::UTF_16BE).unpack1("n"))
        end
      end
      units.pack("n*").force_encoding(Encoding::UTF_16BE).encode(Encoding::UTF_8)
    end
  end

  ENV_KEYS = {
    "storeFile" => "RUFLET_ANDROID_KEYSTORE",
    "storePassword" => "RUFLET_ANDROID_KEYSTORE_PASSWORD",
    "keyAlias" => "RUFLET_ANDROID_KEY_ALIAS",
    "keyPassword" => "RUFLET_ANDROID_KEY_PASSWORD"
  }.freeze

  def setup
    @saved_env = ENV_KEYS.values.to_h { |name| [name, ENV.fetch(name, nil)] }
    ENV_KEYS.each_value { |name| ENV.delete(name) }
  end

  def teardown
    @saved_env.each { |name, value| value.nil? ? ENV.delete(name) : ENV[name] = value }
  end

  # Runs the build's signing step in a fresh project and returns the bytes it
  # wrote to build/client/android/key.properties. `project` lays out the
  # project directory, which may be renamed (to a non-ASCII folder) by `name`.
  def write_signing(env: {}, name: "app", project: nil)
    Dir.mktmpdir do |root|
      # The CLI resolves against Dir.pwd, which is the real path (/private/var
      # on macOS, not /var).
      dir = File.join(File.realpath(root), name)
      client_dir = File.join(dir, "build", "client")
      FileUtils.mkdir_p(File.join(client_dir, "android"))
      project&.call(dir)
      env.each { |variable, value| ENV[variable] = value.respond_to?(:call) ? value.call(dir) : value }
      out = StringIO.new
      original_stdout = $stdout
      $stdout = out
      begin
        result = Dir.chdir(dir) { DummyBuilder.new.send(:apply_android_signing_config, client_dir, "aab") }
      ensure
        $stdout = original_stdout
      end
      refute_equal false, result, out.string
      path = File.join(client_dir, "android", "key.properties")
      yield path, dir if block_given?
      File.binread(path)
    end
  end

  def signing_env(store_password:, key_password:, key_alias: "upload", keystore: ->(dir) { File.join(dir, "upload.jks") })
    {
      "RUFLET_ANDROID_KEYSTORE" => keystore,
      "RUFLET_ANDROID_KEYSTORE_PASSWORD" => store_password,
      "RUFLET_ANDROID_KEY_ALIAS" => key_alias,
      "RUFLET_ANDROID_KEY_PASSWORD" => key_password
    }
  end

  # The documented CI route: the environment holds the passwords themselves.
  # Each of these reached Gradle as another value before (pssw0rd#1,
  # C:keyspass, pÃ¤sswÃ¶rdâ¬, a password that swallowed the keyAlias line),
  # and release signing failed with "keystore password was incorrect".
  ENV_PASSWORDS = [
    ["p\\ssw0rd#1", "C:\\keys\\pass"],
    ["pa\\ss\\word", "p\u00E4ssw\u00F6rd\u20AC"],
    ["endslash\\", "k\\\\y"],
    ["\u{1F511}emoji\u{1F600}", "\u5BC6\u7801"],
    ["multi\nline", "carriage\rreturn"]
  ].freeze

  def test_environment_passwords_load_back_as_set
    ENV_PASSWORDS.each do |store_password, key_password|
      loaded = nil
      bytes = write_signing(env: signing_env(store_password: store_password, key_password: key_password)) do |_path, dir|
        loaded = JavaProperties.load(File.binread(File.join(dir, "build", "client", "android", "key.properties")))
        assert_equal File.join(dir, "upload.jks"), loaded["storeFile"]
      end
      label = [store_password, key_password].inspect
      assert_equal store_password, loaded["storePassword"], label
      assert_equal key_password, loaded["keyPassword"], label
      assert_equal "upload", loaded["keyAlias"], label
      assert bytes.ascii_only?, "#{label}: Properties text is ASCII once escaped"
    end
  end

  def test_environment_keystore_path_and_alias_load_back_as_set
    loaded = nil
    write_signing(
      name: "D\u00E9veloppement \u6587\u6863",
      env: signing_env(store_password: "pw", key_password: "pw", key_alias: "cl\u00E9",
                       keystore: ->(dir) { File.join(dir, "cl\u00E9s", "up\\load.jks") })
    ) do |path, dir|
      loaded = JavaProperties.load(File.binread(path))
      assert_equal File.join(dir, "cl\u00E9s", "up\\load.jks"), loaded["storeFile"]
    end
    assert_equal "cl\u00E9", loaded["keyAlias"]
  end

  # Working configurations are written exactly as before: plain ASCII values,
  # including the characters Properties#store would escape but load reads as
  # they are (# and ! at the start, =, :, tabs and form feeds inside).
  def test_values_load_already_reads_are_written_unchanged
    [
      ["compat-not-a-secret", "compat-not-a-secret", "compat"],
      ["#hash123", "!bang\tx\fy", "a=b:c"],
      ["k3y!#=:x", "sp ace d", "up load"]
    ].each do |store_password, key_password, key_alias|
      keystore = nil
      bytes = write_signing(env: signing_env(store_password: store_password, key_password: key_password, key_alias: key_alias,
                                             keystore: ->(dir) { keystore = File.join(dir, "upload.jks") }))
      expected = "storeFile=#{keystore}\nstorePassword=#{store_password}\nkeyAlias=#{key_alias}\nkeyPassword=#{key_password}\n"
      assert_equal expected.b, bytes
    end
  end

  # A project's own android/key.properties is Properties text already: its
  # escapes are the author's and are copied as written. Only the folder the
  # CLI resolves a relative storeFile against is new text, and a non-ASCII
  # folder made Gradle look for .../DÃ©veloppement/upload.jks.
  def test_project_key_properties_are_copied_and_the_resolved_store_file_loads
    project_file = "storePassword=C:\\\\keys\\\\pass\nkeyPassword=p\\u00e4ss\nkeyAlias=upload\nstoreFile=../upload.jks\n"
    loaded = nil
    bytes = write_signing(
      name: "D\u00E9veloppement",
      project: lambda do |dir|
        FileUtils.mkdir_p(File.join(dir, "android"))
        File.write(File.join(dir, "upload.jks"), "keystore")
        File.write(File.join(dir, "android", "key.properties"), project_file)
      end
    ) do |path, dir|
      loaded = JavaProperties.load(File.binread(path))
      assert_equal File.realpath(File.join(dir, "upload.jks")), File.realpath(loaded["storeFile"])
    end
    assert_equal "C:\\keys\\pass", loaded["storePassword"]
    assert_equal "p\u00E4ss", loaded["keyPassword"]
    assert_includes bytes, "storePassword=C:\\\\keys\\\\pass\n"
    assert_includes bytes, "keyPassword=p\\u00e4ss\n"
  end

  def test_project_key_properties_in_an_ascii_folder_are_written_unchanged
    project_file = "storePassword=s3cret\nkeyPassword=k3y\nkeyAlias=upload\nstoreFile=../keys/upload.jks\n"
    expected = nil
    bytes = write_signing(project: lambda do |dir|
      FileUtils.mkdir_p(File.join(dir, "android"))
      File.write(File.join(dir, "android", "key.properties"), project_file)
      expected = "storeFile=#{File.join(dir, 'keys', 'upload.jks')}\nstorePassword=s3cret\nkeyAlias=upload\nkeyPassword=k3y\n"
    end)
    assert_equal expected.b, bytes
  end

  # Under a C/POSIX locale (many Docker images) Ruby tags the environment as
  # binary, and writing a non-ASCII password raised
  # Encoding::UndefinedConversionError instead of building.
  def test_non_ascii_environment_values_are_written_under_a_c_locale
    Dir.mktmpdir do |dir|
      client_dir = File.join(dir, "build", "client")
      FileUtils.mkdir_p(File.join(client_dir, "android"))
      script = <<~RUBY
        require "ruflet_cli"
        builder = Class.new { include Ruflet::CLI::BuildCommand }.new
        exit(builder.send(:apply_android_signing_config, ARGV.fetch(0), "aab") == false ? 1 : 0)
      RUBY
      env = { "LC_ALL" => "C", "LANG" => "C", "LC_CTYPE" => "C",
              "RUFLET_ANDROID_KEYSTORE" => File.join(dir, "upload.jks"),
              "RUFLET_ANDROID_KEYSTORE_PASSWORD" => "pa\\ss",
              "RUFLET_ANDROID_KEY_ALIAS" => "upload",
              "RUFLET_ANDROID_KEY_PASSWORD" => "p\u00E4ssw\u00F6rd\u20AC" }
      output, status = Open3.capture2e(env, RbConfig.ruby, "-I", File.expand_path("../lib", __dir__), "-e", script,
                                       client_dir, chdir: dir)
      assert status.success?, output

      loaded = JavaProperties.load(File.binread(File.join(client_dir, "android", "key.properties")))
      assert_equal "pa\\ss", loaded["storePassword"]
      assert_equal "p\u00E4ssw\u00F6rd\u20AC", loaded["keyPassword"]
    end
  end

  # The file holds the passwords in plain text; it used to be 0644.
  def test_key_properties_is_readable_only_by_its_owner
    skip "POSIX file modes" if Gem.win_platform?

    write_signing(env: signing_env(store_password: "pw", key_password: "pw")) do |path, _dir|
      assert_equal 0o600, File.stat(path).mode & 0o777
    end

    # A file an earlier build left behind is rewritten, not recreated.
    write_signing(
      env: signing_env(store_password: "pw", key_password: "pw"),
      project: lambda do |dir|
        stale = File.join(dir, "build", "client", "android", "key.properties")
        File.write(stale, "storePassword=stale-value\n")
        File.chmod(0o644, stale)
      end
    ) do |path, _dir|
      assert_equal 0o600, File.stat(path).mode & 0o777
      refute_includes File.read(path), "stale-value"
    end
  end

  def test_escape_helpers
    builder = DummyBuilder.new
    escape = ->(value) { builder.send(:java_properties_escape, value) }
    assert_equal "plain-#!=:\tvalue", escape.call("plain-#!=:\tvalue")
    assert_equal "a\\\\b\\nc\\rd", escape.call("a\\b\nc\rd")
    # load skips the blanks a value starts with; the CLI strips them from the
    # environment, but the helper keeps them when given one.
    assert_equal "\\  x", escape.call("  x")
    assert_equal "\\tx", escape.call("\tx")
    assert_equal "\\u00E9\\uD83D\\uDE00", escape.call("\u00E9\u{1F600}")
    # Bytes that are not UTF-8 are kept as they were always written.
    assert_equal "p\xE4\\\\ss".b, escape.call("p\xE4\\ss".b).b
    assert_equal "/D\\u00E9v/..\\\\x", builder.send(:java_properties_escape_non_ascii, "/D\u00E9v/..\\\\x")

    [" lead", "a\\b", "\u00E9\u{1F600}", "x\ny", "\tt", "\f f"].each do |value|
      assert_equal value, JavaProperties.load("k=#{escape.call(value)}\n".b)["k"], value.inspect
    end
  end

  # The port above is what the other tests trust, so check it, and the
  # escaping, against java.util.Properties itself when a JVM is installed.
  def test_a_real_jvm_reads_the_written_file_the_same_way
    java = java_command
    skip "no JVM to check java.util.Properties against" unless java

    Dir.mktmpdir do |tools|
      source = File.join(tools, "LoadProps.java")
      File.write(source, <<~JAVA)
        import java.io.FileInputStream;
        import java.util.Properties;
        public class LoadProps {
          public static void main(String[] args) throws Exception {
            Properties properties = new Properties();
            try (FileInputStream in = new FileInputStream(args[0])) { properties.load(in); }
            for (String key : new String[] {"storeFile", "storePassword", "keyAlias", "keyPassword"}) {
              String value = properties.getProperty(key);
              StringBuilder units = new StringBuilder(key).append(':');
              if (value == null) { units.append("null"); }
              else { for (char unit : value.toCharArray()) units.append(String.format("%04X", (int) unit)); }
              System.out.println(units);
            }
          }
        }
      JAVA
      (ENV_PASSWORDS + [["compat-not-a-secret", "!bang\tx\fy"]]).each do |store_password, key_password|
        write_signing(name: "D\u00E9v", env: signing_env(store_password: store_password, key_password: key_password)) do |path, _dir|
          output, status = Open3.capture2e(java, source, path)
          assert status.success?, output
          from_java = output.lines.to_h do |line|
            key, units = line.strip.split(":", 2)
            [key, units == "null" ? nil : [units].pack("H*").force_encoding(Encoding::UTF_16BE).encode(Encoding::UTF_8)]
          end
          assert_equal JavaProperties.load(File.binread(path)), from_java, [store_password, key_password].inspect
          assert_equal store_password, from_java["storePassword"]
          assert_equal key_password, from_java["keyPassword"]
        end
      end
    end
  end

  # A java that runs single-file source programs (JDK 11+), or nil.
  def java_command
    java = ENV["JAVA_HOME"].to_s.empty? ? "java" : File.join(ENV["JAVA_HOME"], "bin", "java")
    _output, status = Open3.capture2e(java, "-version")
    status.success? ? java : nil
  rescue SystemCallError
    nil
  end
end
