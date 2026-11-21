# frozen_string_literal: true

require_relative "test_helper"

class RufletOriginPolicyTest < Minitest::Test
  def policy(**options)
    @messages = []
    Ruflet::OriginPolicy.new(log: ->(message) { @messages << message }, **options)
  end

  def test_no_origin_is_allowed_because_native_clients_send_none
    enforcing = policy(enforce: true)

    assert enforcing.allow?(nil, ["127.0.0.1:8550"])
    assert enforcing.allow?("", ["127.0.0.1:8550"])
    assert_empty @messages
  end

  def test_pages_served_from_this_machine_are_allowed
    enforcing = policy(enforce: true)

    %w[
      http://localhost:5173 http://LOCALHOST:5173 https://localhost http://app.localhost:3000
      http://127.0.0.1:8080 http://127.10.0.1 http://[::1]:5173 http://0.0.0.0:8550
    ].each do |origin|
      assert enforcing.allow?(origin, ["192.168.1.20:8550"]), origin
    end
    assert_empty @messages
  end

  def test_look_alike_hosts_are_not_local
    enforcing = policy(enforce: true)

    %w[
      http://localhost.evil.example http://evillocalhost http://127.0.0.1.evil.example
      http://127.0.0.256 http://128.0.0.1 http://[::2]
    ].each do |origin|
      refute enforcing.allow?(origin, ["127.0.0.1:8550"]), origin
    end
  end

  def test_the_server_s_own_address_is_allowed
    enforcing = policy(enforce: true)

    assert enforcing.allow?("http://192.168.1.242:8550", ["192.168.1.242:8550"])
    assert enforcing.allow?("http://MyMac.local:8550", ["mymac.local:8550"])
    assert enforcing.allow?("https://app.example.com", ["app.example.com"])
    assert enforcing.allow?("http://app.example.com", ["app.example.com"])
    assert enforcing.allow?("https://app.example.com", ["app.example.com:443"])
    assert enforcing.allow?("https://app.example.com:8443", ["app.example.com:8443"])
    assert enforcing.allow?("http://[fe80::1]:8550", ["[fe80::1]:8550"])
  end

  def test_another_port_or_host_is_foreign
    enforcing = policy(enforce: true)

    refute enforcing.allow?("http://192.168.1.242:9000", ["192.168.1.242:8550"])
    refute enforcing.allow?("http://192.168.1.50:8550", ["192.168.1.242:8550"])
    refute enforcing.allow?("https://app.example.com:8443", ["app.example.com"])
    refute enforcing.allow?("https://app.example.com", ["app.example.com:80"])
    refute enforcing.allow?("https://evil.example", [nil])
    refute enforcing.allow?("https://evil.example", [])
  end

  def test_a_forwarded_host_counts_as_the_server_s_address
    enforcing = policy(enforce: true)

    assert enforcing.allow?("https://dev.example.com", ["127.0.0.1:8550", "dev.example.com"])
    assert enforcing.allow?("https://dev.example.com", ["127.0.0.1:8550", "proxy.internal, dev.example.com"])
  end

  def test_unparseable_origins_are_foreign
    enforcing = policy(enforce: true)

    ["null", "evil.example", "://evil.example", "http://", "http://evil example", "http://evil.example:65536",
     "http://evil.example:abc", "http://[::1", "file://"].each do |origin|
      refute enforcing.allow?(origin, ["127.0.0.1:8550", "evil.example"]), origin
    end
  end

  def test_listed_origins_are_allowed_after_normalising
    enforcing = policy(allowed_origins: "https://App.Example.com/, http://tools.example:8080")

    assert enforcing.enforce?, "configuring allowed origins turns enforcement on"
    assert enforcing.allow?("https://app.example.com", [])
    assert enforcing.allow?("https://app.example.com:443", [])
    assert enforcing.allow?("http://tools.example:8080", [])
    refute enforcing.allow?("http://app.example.com", [])
    refute enforcing.allow?("http://tools.example", [])
  end

  def test_a_wildcard_allows_every_origin_silently
    open_policy = policy(enforce: true, allowed_origins: ["*"])

    assert open_policy.allow?("https://evil.example", [])
    assert open_policy.allow?("null", [])
    assert_empty @messages
  end

  def test_a_non_enforcing_policy_accepts_and_warns_once_per_origin
    lenient = policy

    refute lenient.enforce?
    assert lenient.allow?("https://evil.example", ["127.0.0.1:8550"])
    assert lenient.allow?("https://evil.example", ["127.0.0.1:8550"])
    assert lenient.allow?("https://other.example", ["127.0.0.1:8550"])

    assert_equal 2, @messages.size
    assert_includes @messages.first, 'accepted a WebSocket connection from Origin "https://evil.example"'
    assert_includes @messages.first, "RUFLET_ALLOWED_ORIGINS"
  end

  def test_an_enforcing_policy_names_the_origin_to_allow
    enforcing = policy(enforce: true, setting_hint: "Ruflet::Rails.config.allowed_origins")

    refute enforcing.allow?("HTTPS://Evil.Example:443", [])
    assert_equal 1, @messages.size
    assert_includes @messages.first, "add https://evil.example to Ruflet::Rails.config.allowed_origins"
  end

  def test_logged_origins_are_bounded
    enforcing = policy(enforce: true)

    (Ruflet::OriginPolicy::LOGGED_ORIGINS_LIMIT + 10).times { |index| enforcing.allow?("https://e#{index}.example", []) }

    assert_equal Ruflet::OriginPolicy::LOGGED_ORIGINS_LIMIT, @messages.size
  end

  def test_control_characters_in_a_logged_origin_are_escaped
    enforcing = policy(enforce: true)

    enforcing.allow?("https://\e[31mred", [])

    assert_equal 1, @messages.size
    refute_includes @messages.first, "\e"
    assert_includes @messages.first, "that origin"
  end

  def test_invalid_allowed_entries_are_reported_and_still_enforce
    enforcing = policy(allowed_origins: "app.example.com")

    assert enforcing.enforce?
    assert_includes @messages.first, 'ignoring allowed origin "app.example.com"'
    refute enforcing.allow?("https://app.example.com", [])
  end

  def test_entries_merge_arrays_and_separated_strings
    assert_equal %w[https://a.example https://b.example https://c.example *],
                 Ruflet::OriginPolicy.entries(["https://a.example", "https://b.example"], "https://c.example,  * ", nil, "")
    assert_empty Ruflet::OriginPolicy.entries(nil, " ", [])
  end

  def test_without_a_log_callable_messages_go_to_stderr
    lenient = Ruflet::OriginPolicy.new

    _out, err = capture_io { lenient.allow?("https://evil.example", []) }

    assert_includes err, "https://evil.example"
  end
end
