# frozen_string_literal: true

module SigningDecision
  CONTROLLED_ERROR_MESSAGE = <<~MSG
    No reusable Distribution certificate is available for CI.

    Apple already has orphaned Distribution certificates from earlier CI runs,
    but their private keys were lost on ephemeral runners. CI will not create
    new certificates automatically.

    Windows / no-Mac one-time setup:
      .\\scripts\\bootstrap-testflight-signing.ps1 -Phase enable
    Then merge this fix, run TestFlight once, and:
      .\\scripts\\bootstrap-testflight-signing.ps1 -Phase disable

    Mac alternative:
      ./scripts/export-signing-for-ci.sh
      Add BUILD_CERTIFICATE_BASE64, P12_PASSWORD, PROVISIONING_PROFILE_BASE64

    After the first successful run, fastlane/signing is cached and reused.
  MSG

  # @return [:reuse, :create, :controlled_error]
  def self.resolve(p12_exists:, allow_create:)
    return :reuse if p12_exists
    return :create if allow_create == "true"

    :controlled_error
  end

  def self.controlled_error_message
    CONTROLLED_ERROR_MESSAGE
  end
end