# frozen_string_literal: true

require "xcodeproj"

# Mirrors fastlane GetVersionNumberAction resolution for GENERATE_INFOPLIST_FILE projects.
module ProjectMarketingVersion
  module_function

  def read(xcodeproj_path, target_name)
    project = Xcodeproj::Project.open(xcodeproj_path)
    target = project.targets.find { |t| t.name == target_name }
    raise "Target #{target_name} not found" unless target

    version_number = "$(MARKETING_VERSION)"
    if version_number =~ /\$\(([\w\-]+)\)/
      variable = Regexp.last_match(1)
      version_number = resolve_build_setting(target, variable) ||
                       resolve_build_setting(project, variable)
    end

    raise "Unable to find Xcode build setting: MARKETING_VERSION" if version_number.nil? || version_number.to_s.strip.empty?

    version_number.to_s
  end

  def resolve_build_setting(object, variable, configuration = nil)
    object.build_configurations.each do |config|
      next unless configuration.nil? || config.name == configuration

      value = config.resolve_build_setting(variable)
      return value if value && !value.to_s.strip.empty?
    end
    nil
  end
end