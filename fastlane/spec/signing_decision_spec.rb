# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/signing_decision"

class SigningDecisionSpec < Minitest::Test
  def test_reuse_when_p12_exists_regardless_of_allow
    assert_equal :reuse, SigningDecision.resolve(p12_exists: true, allow_create: "true")
    assert_equal :reuse, SigningDecision.resolve(p12_exists: true, allow_create: "false")
    assert_equal :reuse, SigningDecision.resolve(p12_exists: true, allow_create: nil)
  end

  def test_create_only_when_p12_missing_and_allow_true_exactly
    assert_equal :create, SigningDecision.resolve(p12_exists: false, allow_create: "true")
  end

  def test_controlled_error_when_p12_missing_and_allow_not_true
    assert_equal :controlled_error, SigningDecision.resolve(p12_exists: false, allow_create: "false")
    assert_equal :controlled_error, SigningDecision.resolve(p12_exists: false, allow_create: nil)
    assert_equal :controlled_error, SigningDecision.resolve(p12_exists: false, allow_create: "")
    assert_equal :controlled_error, SigningDecision.resolve(p12_exists: false, allow_create: "TRUE")
  end

  def test_controlled_error_message_contains_required_text
    message = SigningDecision.controlled_error_message
    assert_includes message, "No reusable Distribution certificate is available for CI"
    refute_includes message, "Could not create another Distribution certificate"
  end
end