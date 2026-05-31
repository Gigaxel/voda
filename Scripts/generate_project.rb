#!/usr/bin/env ruby
# frozen_string_literal: true

require "xcodeproj"
require "fileutils"

PROJECT_NAME = "Voda"
PROJECT_PATH = "#{PROJECT_NAME}.xcodeproj"

FileUtils.rm_rf(PROJECT_PATH)
project = Xcodeproj::Project.new(PROJECT_PATH)

root_group = project.main_group

def add_files_to_group(group, paths)
  paths.map do |path|
    group.find_file_by_path(path) || group.new_file(path)
  end
end

def add_sources(target, file_refs)
  file_refs.each do |ref|
    next unless ref.path.end_with?(".swift")
    target.add_file_references([ref])
  end
end

def add_resources(target, file_refs)
  refs = file_refs.reject { |ref| ref.path.end_with?(".swift") }
  target.add_resources(refs) unless refs.empty?
end

def configure_common(target)
  target.build_configurations.each do |config|
    settings = config.build_settings
    settings["SWIFT_VERSION"] = "6.0"
    settings["CLANG_ENABLE_MODULES"] = "YES"
    settings["ENABLE_USER_SCRIPT_SANDBOXING"] = "NO"
    settings["CODE_SIGN_STYLE"] = "Automatic"
    settings["CURRENT_PROJECT_VERSION"] = "1"
    settings["MARKETING_VERSION"] = "1.0"
    settings["DEVELOPMENT_TEAM"] = ENV.fetch("VODA_DEVELOPMENT_TEAM", "")
    settings["ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME"] = "AccentColor"
  end
end

shared_paths = Dir[
  "Voda/Domain/**/*.swift",
  "Voda/Persistence/**/*.swift",
  "Voda/Services/HydrationServices.swift"
].sort

ios_paths = Dir[
  "Voda/App/**/*.swift",
  "Voda/Features/**/*.swift",
  "Voda/SharedUI/**/*.swift",
  "Voda/Services/AppleHealthKitService.swift",
  "Voda/Services/LocalReminderScheduler.swift"
].sort

# Live Activity: attributes and preferences are shared with the widget; the
# controller is iOS app only because it owns foreground lifecycle timers.
live_activity_shared_paths = ["Voda/LiveActivity/HydrationActivityAttributes.swift"]
live_activity_app_paths = ["Voda/LiveActivity/LiveActivityController.swift"]

widget_paths = Dir["VodaWidget/**/*.swift"].sort
test_paths = Dir["VodaTests/**/*.swift"].sort
resource_paths = [
  "Voda/Resources/Assets.xcassets"
]

all_paths = (shared_paths + ios_paths + live_activity_shared_paths + live_activity_app_paths + widget_paths + test_paths + resource_paths + [
  "Voda/Resources/Info.plist",
  "Voda/Voda.entitlements",
  "VodaWidget/Info.plist",
  "VodaWidget/VodaWidget.entitlements"
]).uniq

file_refs = add_files_to_group(root_group, all_paths)
refs_by_path = file_refs.to_h { |ref| [ref.path, ref] }

ios_target = project.new_target(:application, "Voda", :ios, "17.0")
configure_common(ios_target)
ios_target.build_configurations.each do |config|
  config.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = "com.gigaxel.voda"
  config.build_settings["INFOPLIST_FILE"] = "Voda/Resources/Info.plist"
  config.build_settings["CODE_SIGN_ENTITLEMENTS"] = "Voda/Voda.entitlements"
  config.build_settings["TARGETED_DEVICE_FAMILY"] = "1"
  config.build_settings["SUPPORTED_PLATFORMS"] = "iphoneos iphonesimulator"
  config.build_settings["IPHONEOS_DEPLOYMENT_TARGET"] = "17.0"
  config.build_settings["ASSETCATALOG_COMPILER_APPICON_NAME"] = "AppIconFull"
end
add_sources(ios_target, (shared_paths + ios_paths + live_activity_shared_paths + live_activity_app_paths).map { |p| refs_by_path[p] })
add_resources(ios_target, resource_paths.map { |p| refs_by_path[p] })

widget_target = project.new_target(:app_extension, "VodaWidgetExtension", :ios, "17.0")
configure_common(widget_target)
widget_target.build_configurations.each do |config|
  config.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = "com.gigaxel.voda.widget"
  config.build_settings["INFOPLIST_FILE"] = "VodaWidget/Info.plist"
  config.build_settings["CODE_SIGN_ENTITLEMENTS"] = "VodaWidget/VodaWidget.entitlements"
  config.build_settings["SUPPORTED_PLATFORMS"] = "iphoneos iphonesimulator"
  config.build_settings["IPHONEOS_DEPLOYMENT_TARGET"] = "17.0"
  config.build_settings["APPLICATION_EXTENSION_API_ONLY"] = "YES"
  config.build_settings["SKIP_INSTALL"] = "YES"
end
add_sources(widget_target, (shared_paths + live_activity_shared_paths + widget_paths).map { |p| refs_by_path[p] })
add_resources(widget_target, resource_paths.map { |p| refs_by_path[p] })

ios_target.add_dependency(widget_target)
embed_widgets_phase = ios_target.new_copy_files_build_phase("Embed App Extensions")
embed_widgets_phase.symbol_dst_subfolder_spec = :plug_ins
embedded_widget = embed_widgets_phase.add_file_reference(widget_target.product_reference, true)
embedded_widget.settings = { "ATTRIBUTES" => ["RemoveHeadersOnCopy"] }

tests_target = project.new_target(:unit_test_bundle, "VodaTests", :ios, "17.0")
configure_common(tests_target)
tests_target.build_configurations.each do |config|
  config.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = "com.gigaxel.voda.tests"
  config.build_settings["INFOPLIST_FILE"] = ""
  config.build_settings["GENERATE_INFOPLIST_FILE"] = "YES"
  config.build_settings["SUPPORTED_PLATFORMS"] = "iphoneos iphonesimulator"
  config.build_settings["IPHONEOS_DEPLOYMENT_TARGET"] = "17.0"
  config.build_settings["BUNDLE_LOADER"] = "$(TEST_HOST)"
  config.build_settings["TEST_HOST"] = "$(BUILT_PRODUCTS_DIR)/Voda.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Voda"
end
tests_target.add_dependency(ios_target)
add_sources(tests_target, test_paths.map { |p| refs_by_path[p] })

project.recreate_user_schemes
project.save

puts "Generated #{PROJECT_PATH}"
