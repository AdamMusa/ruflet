# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"

class RufletBuildLocalNetworkTest < Minitest::Test
  class Builder
    include Ruflet::CLI::BuildCommand
  end

  def test_self_profiles_can_explicitly_use_lan_without_changing_runtime_mode
    %i[lite full].product(%w[ios ipa macos], [true, false]).each do |profile, platform, experimental|
      Dir.mktmpdir do |dir|
        apple_platform = platform == "ipa" ? "ios" : platform
        plist = File.join(dir, apple_platform, "Runner", "Info.plist")
        FileUtils.mkdir_p(File.dirname(plist))
        File.write(plist, <<~PLIST)
          <plist><dict>
          <key>NSAppTransportSecurity</key><dict>
            <key>NSExceptionDomains</key><dict>
              <key>example.test</key><dict><key>NSIncludesSubdomains</key><true/></dict>
            </dict>
          </dict>
          </dict></plist>
        PLIST
        builder = Builder.new
        builder.instance_variable_set(:@ruflet_runtime_profile, profile)
        config = {apple_platform => {"local_network" => true,
          "local_network_usage_description" => "Connect to Ruby & LAN apps."}}
        2.times do
          builder.send(:configure_native_apple_runtime, dir, platform: platform,
            self_contained: true, config: config, experimental: experimental)
        end
        content = File.read(plist)
        assert_equal 1, content.scan("<key>NSAllowsLocalNetworking</key>").length
        assert_equal 1, content.scan("<key>NSAppTransportSecurity</key>").length
        assert_includes content, "Connect to Ruby &amp; LAN apps."
        assert_includes content, "example.test"
        assert_match(/<key>RufletRuntimeAutostart<\/key>\s*<true\s*\/>/, content)
        assert_match(/<key>RufletRuntimeProfile<\/key>\s*<string>#{profile}<\/string>/, content)
        refute_includes content, "NSAllowsArbitraryLoads"
      end
    end
  end

  def test_local_network_opt_in_restores_declarations_in_a_previously_pruned_client
    Dir.mktmpdir do |dir|
      plist = File.join(dir, "ios", "Runner", "Info.plist")
      FileUtils.mkdir_p(File.dirname(plist))
      File.write(plist, "<plist><dict></dict></plist>")
      builder = Builder.new
      builder.send(:configure_native_apple_runtime, dir, platform: "ios",
        self_contained: true, config: {"ios" => {"local_network" => true}})
      content = File.read(plist)
      assert_includes content, "NSLocalNetworkUsageDescription"
      assert_match(/<key>NSAllowsLocalNetworking<\/key>\s*<true\s*\/>/, content)
      builder.send(:configure_native_apple_runtime, dir, platform: "ios",
        self_contained: true)
      refute_includes File.read(plist), "NSLocalNetworkUsageDescription"
      refute_includes File.read(plist), "NSAppTransportSecurity"
    end
  end
end
