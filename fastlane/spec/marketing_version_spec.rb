# frozen_string_literal: true

require "minitest/autorun"

ROOT = File.expand_path("../..", __dir__)
FASTFILE = File.join(ROOT, "fastlane", "Fastfile")
PBXPROJ = File.join(ROOT, "gumimap-v2.xcodeproj", "project.pbxproj")
APP_TARGET = "gumimap-v2"

def marketing_version_from_pbxproj(bundle_identifier)
  content = File.read(PBXPROJ)
  versions = content.scan(
    /MARKETING_VERSION = ([^;]+);[\s\S]*?PRODUCT_BUNDLE_IDENTIFIER = "#{Regexp.escape(bundle_identifier)}"/
  ).flatten.map(&:strip).uniq

  raise "MARKETING_VERSION missing for #{bundle_identifier}" if versions.empty?
  raise "MARKETING_VERSION differs across configs: #{versions.inspect}" if versions.length > 1

  versions.first
end

class MarketingVersionSpec < Minitest::Test
  def test_pbxproj_marketing_version_is_non_empty
    version = marketing_version_from_pbxproj("com.ijaejun.gumimap-v2")
    refute_empty version
    assert_equal "0.0.1", version
    assert_match(/\A\d+\.\d+\.\d+\z/, version)
  end

  def test_fastfile_get_version_number_calls_include_target
    fastfile = File.read(FASTFILE)
    assert_includes fastfile, "private_lane :current_marketing_version"
    assert_includes fastfile, "private_lane :release_marketing_version"
    assert_includes fastfile, "get_version_number(xcodeproj: XCODEPROJ, target: APP_TARGET)"

    get_calls = fastfile.scan(/get_version_number\([^)]+\)/)
    assert_operator get_calls.length, :>=, 2
    get_calls.each do |call|
      assert_includes call, "target: APP_TARGET", "Expected target on: #{call}"
    end
  end

  def test_fastfile_ensure_asc_version_has_empty_guard
    fastfile = File.read(FASTFILE)
    ensure_section = fastfile[/private_lane :ensure_asc_version.*?^  end/m]
    refute_nil ensure_section
    assert_includes ensure_section, "marketing_version.to_s.strip.empty?"
    assert_includes ensure_section, "UI.user_error!"
  end

  def test_prepare_version_numbers_reads_from_lanes_not_empty_helper
    fastfile = File.read(FASTFILE)
    prepare_section = fastfile[/private_lane :prepare_version_numbers.*?^  end/m]
    refute_nil prepare_section
    assert_includes prepare_section, "current_marketing_version"
    assert_includes prepare_section, "release_marketing_version"
    refute_includes prepare_section, "resolve_marketing_version"
  end

  def test_current_marketing_version_lane_returns_lane_context_value
    fastfile = File.read(FASTFILE)
    lane_section = fastfile[/private_lane :current_marketing_version.*?^  end/m]
    refute_nil lane_section
    assert_includes lane_section, "Actions.lane_context[SharedValues::VERSION_NUMBER]"
    assert_includes lane_section, "UI.message(\"Project marketing version:"
  end
end