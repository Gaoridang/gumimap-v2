# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/project_marketing_version"

ROOT = File.expand_path("../..", __dir__)
XCODEPROJ = File.join(ROOT, "gumimap-v2.xcodeproj")
APP_TARGET = "gumimap-v2"
SCRATCH = ENV.fetch("FASTLANE_VERIFY_SCRATCH", File.join(Dir.tmpdir, "grok-goal-fastlane-verify"))

class GetVersionNumberRuntimeSpec < Minitest::Test
  def setup
    FileUtils.mkdir_p(SCRATCH)
  end

  def test_read_marketing_version_matches_pbxproj
    version = ProjectMarketingVersion.read(XCODEPROJ, APP_TARGET)
    log = <<~LOG
      xcodeproj_path=#{XCODEPROJ}
      target=#{APP_TARGET}
      objectVersion=77
      get_version_number_equivalent_return=#{version.inspect}
    LOG
    File.write(File.join(SCRATCH, "get_version_number_runtime.log"), log)

    refute_empty version
    assert_equal "0.0.1", version
  end

  def test_fastlane_action_when_available
    skip "fastlane gem not installed" unless defined?(Bundler)

    begin
      require "fastlane"
      require "fastlane/actions/get_version_number"
    rescue LoadError
      skip "fastlane action unavailable on this host"
    end

    returned = Fastlane::Actions::GetVersionNumberAction.run(
      xcodeproj: "gumimap-v2.xcodeproj",
      target: APP_TARGET
    )
    context_value = Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::VERSION_NUMBER]

    log = <<~LOG
      fastlane_action_return=#{returned.inspect}
      lane_context_VERSION_NUMBER=#{context_value.inspect}
    LOG
    File.write(File.join(SCRATCH, "fastlane_get_version_number_action.log"), log)

    assert_equal "0.0.1", returned
    assert_equal "0.0.1", context_value
  end
end