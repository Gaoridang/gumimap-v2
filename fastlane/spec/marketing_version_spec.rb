# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/project_marketing_version"

ROOT = File.expand_path("../..", __dir__)
FASTFILE = File.join(ROOT, "fastlane", "Fastfile")
XCODEPROJ = File.join(ROOT, "gumimap-v2.xcodeproj")
APP_TARGET = "gumimap-v2"

class MarketingVersionSpec < Minitest::Test
  def test_project_marketing_version_read_returns_pbxproj_value
    version = ProjectMarketingVersion.read(XCODEPROJ, APP_TARGET)
    refute_empty version
    assert_equal "0.0.1", version
    assert_match(/\A\d+\.\d+\.\d+\z/, version)
  end

  def test_fastfile_version_actions_use_target_and_xcodeproj_reader
    fastfile = File.read(FASTFILE)
    assert_includes fastfile, "private_lane :current_marketing_version"
    assert_includes fastfile, "private_lane :release_marketing_version"
    assert_includes fastfile, "def read_project_marketing_version"
    assert_includes fastfile, "ProjectMarketingVersion.read(XCODEPROJ, APP_TARGET)"

    prepare_section = fastfile[/private_lane :prepare_version_numbers.*?^  end/m]
    refute_nil prepare_section
    assert_includes prepare_section, "increment_version_number"
    assert_includes prepare_section, "target: APP_TARGET"
    assert_includes prepare_section, "increment_build_number"
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

  def test_read_project_marketing_version_helper_uses_xcodeproj_reader
    fastfile = File.read(FASTFILE)
    helper_section = fastfile[/def read_project_marketing_version.*?^end/m]
    refute_nil helper_section
    assert_includes helper_section, "ProjectMarketingVersion.read(XCODEPROJ, APP_TARGET)"
    assert_includes helper_section, "Actions.lane_context[SharedValues::VERSION_NUMBER]"
    refute_includes helper_section, "get_version_number(xcodeproj: XCODEPROJ, target: APP_TARGET)"
  end

  def test_current_marketing_version_lane_delegates_to_helper
    fastfile = File.read(FASTFILE)
    lane_section = fastfile[/private_lane :current_marketing_version.*?^  end/m]
    refute_nil lane_section
    assert_includes lane_section, "read_project_marketing_version"
    assert_includes lane_section, "UI.message(\"Project marketing version:"
  end
end